extends Node

signal stats_updated(player_hp: int, player_shield: int, enemy_hp: int, enemy_shield: int)
signal status_updated(target: String, status_dict: Dictionary)
signal reaction_triggered(reaction_name: String, reaction_color: Color)
signal battle_ended(is_victory: bool)
signal activate_random_subslot_requested()

var card_db: Dictionary = {}

var enemy_name: String = ""
var enemy_element: String = ""
var enemy_max_hp: int = 0
var enemy_hp: int = 0
var enemy_shield: int = 0
var enemy_turn_counter: int = 0
var enemy_atk_buff: int = 0
var base_attack_damage: int = 0
var player_shield: int = 0
var is_game_over: bool = false
var should_reactivate: bool = false

var player_statuses: Dictionary = {}
var enemy_statuses: Dictionary = {}

const ELEMENT_COLORS = {
	"火": Color("#E64A19"),
	"木": Color("#43A047"),
	"水": Color("#1E88E5"),
	"金": Color("#FBC02D"),
	"土": Color("#8D6E63"),
	"以太": Color("#9C27B0")
}

func initialize_battle(p_name: String, p_element: String, p_max_hp: int, p_base_damage: int, p_card_db: Dictionary) -> void:
	card_db = p_card_db
	enemy_name = p_name
	enemy_element = p_element
	enemy_max_hp = p_max_hp
	enemy_hp = p_max_hp
	base_attack_damage = p_base_damage
	enemy_shield = 0
	player_shield = 0
	enemy_turn_counter = 0
	enemy_atk_buff = 0
	is_game_over = false
	player_statuses.clear()
	enemy_statuses.clear()
	emit_stats()
	emit_status_updates()

func emit_stats() -> void:
	stats_updated.emit(GameManager.current_health, player_shield, enemy_hp, enemy_shield)

func emit_status_updates() -> void:
	status_updated.emit("player", player_statuses)
	status_updated.emit("enemy", enemy_statuses)

func play_card(card_id: String, active_sub_ids: Array, target: Node = null) -> void:
	if is_game_over: return
	
	if not card_db.has(card_id):
		print("ERROR: BattleManager attempted to play invalid card ID: ", card_id)
		return
		
	var card_data = card_db[card_id]
	var type = card_data["main_slot"]["type"]
	var main_slot_data = card_data.get("main_slot", {})
	
	# Trigger non-stat sub-slot effects (like generate_element) at card play
	for sub_id in active_sub_ids:
		if sub_id != "" and card_db.has(sub_id):
			var sub_card_data = card_db[sub_id]
			var sub_slot_data = sub_card_data.get("sub_slot", {})
			var sub_type = sub_slot_data.get("type", "")
			if sub_type == "generate_element":
				_add_element(sub_slot_data.get("stat", ""), sub_slot_data.get("value", 0))

	# Apply Shield (if any)
	if type == "shield" or type == "damage_and_shield":
		var final_value = main_slot_data.get("value", main_slot_data.get("shield_value", 0))
		for sub_id in active_sub_ids:
			if sub_id != "" and card_db.has(sub_id):
				var sub_card_data = card_db[sub_id]
				var sub_slot_data = sub_card_data.get("sub_slot", {})
				var sub_stat = sub_slot_data.get("stat", "")
				var sub_val = sub_slot_data.get("value", 0)
				if sub_stat == "shield":
					final_value += sub_val
							
		player_shield += final_value
		print("Player gained ", final_value, " shield.")
		
	# Apply Damage (if any)
	if type == "damage" or type == "damage_and_shield":
		var final_value = main_slot_data.get("value", main_slot_data.get("damage_value", 0))
		for sub_id in active_sub_ids:
			if sub_id != "" and card_db.has(sub_id):
				var sub_card_data = card_db[sub_id]
				var sub_slot_data = sub_card_data.get("sub_slot", {})
				var sub_stat = sub_slot_data.get("stat", "")
				var sub_val = sub_slot_data.get("value", 0)
				if sub_stat == "damage":
					final_value += sub_val

		var damage = final_value
		
		if GameManager.acquired_equipment.has("小刀"):
			damage += 3
			print("小刀 equipment triggered! +3 Damage")
		
		var attacker_element = card_data.get("element", "")
		
		if player_statuses.has("elemental_infusion") and player_statuses["elemental_infusion"] is Dictionary:
			attacker_element = player_statuses["elemental_infusion"].get("element", "")
			damage += player_statuses["elemental_infusion"].get("value", 0)
			print("Elemental Infusion Active! Attack changed to " + attacker_element)
		
		var reaction_triggered_flag: bool = false
		var reaction_name: String = ""
		var reaction_color: Color = Color.WHITE
		
		if ELEMENT_COLORS.has(attacker_element):
			reaction_color = ELEMENT_COLORS[attacker_element]
			
		var target_element = "木"
		if target and "element" in target:
			target_element = target.element
		elif enemy_element != "":
			target_element = enemy_element
		
		# Reaction Lookup
		var reaction = null
		var sorted_elements = [attacker_element, target_element]
		sorted_elements.sort()
		var key = sorted_elements[0] + "_" + sorted_elements[1]
		
		if GameManager.equipped_reactions.has(key):
			var reaction_res = GameManager.equipped_reactions[key]
			reaction_name = reaction_res.reaction_name
			reaction = reaction_res.effect
			reaction_triggered_flag = true
			
		# Execution
		var is_true_damage = false
		should_reactivate = false
		if reaction_triggered_flag and reaction != null:
			match reaction.get("type", ""):
				"damage_mult":
					damage = int(damage * reaction.get("value", 1.0))
					print("Elemental Reaction: ", reaction_name, "! Damage multiplied!")
				"shield_break_then_damage":
					enemy_shield = 0
					print("Elemental Reaction: ", reaction_name, "! Shield broken!")
				"true_damage":
					is_true_damage = true
					if "value" in reaction:
						damage += reaction.get("value", 0)
					print("Elemental Reaction: ", reaction_name, "! True damage bypasses shield!")
				"composite":
					for sub_effect in reaction.get("effects", []):
						_execute_reaction_effect(sub_effect, card_data)
				_:
					_execute_reaction_effect(reaction, card_data)
					
			reaction_triggered.emit(reaction_name, reaction_color)
			
		# Apply Frail status modifier (damage x 1.5)
		if enemy_statuses.has("frail"):
			damage = int(damage * 1.5)
			print("Enemy is frail! Incoming damage increased.")
			
		# Apply Damage to HP / Shield
		var final_applied_damage = damage
		if is_true_damage:
			enemy_hp -= final_applied_damage
		else:
			if enemy_shield > 0:
				if final_applied_damage >= enemy_shield:
					final_applied_damage -= enemy_shield
					enemy_shield = 0
				else:
					enemy_shield -= final_applied_damage
					final_applied_damage = 0
			
			enemy_hp -= final_applied_damage
			
		print("Dealt ", final_value, " (Final: ", damage, ") damage to Enemy.")
		
		if enemy_hp <= 0:
			enemy_hp = 0
			_trigger_victory()
			
	emit_stats()
	emit_status_updates()

func _execute_reaction_effect(effect: Dictionary, _card_data: Dictionary) -> void:
	match effect.get("type", ""):
		"apply_status":
			var target = effect.get("target", "enemy")
			var duration = effect.get("duration", 2)
			var val = effect.get("value", 0.0)
			_apply_status(target, effect.get("status_id", ""), duration, val, effect.get("element", ""))
		"generate_element":
			_add_element(effect.get("element", ""), effect.get("value", 0))
		"generate_random_element":
			var exclude = effect.get("exclude", "")
			var val = effect.get("value", 2)
			_generate_random_elements(val, exclude)
		"reactivate_card":
			should_reactivate = true
			print("淬火! Scheduled card reactivation.")
		"steal_element":
			_add_element("以太", effect.get("value", 1))
			print("吸纳! Stole element from enemy.")
		"apply_buff":
			var target = effect.get("target", "player")
			var duration = effect.get("duration", -1)
			var val = effect.get("value", 0.0)
			_apply_status(target, effect.get("buff_id", ""), duration, val, effect.get("element", ""))
		"add_shield":
			player_shield += effect.get("value", 0)
		"global_persistent_buff":
			_apply_status("player", effect.get("buff_id", ""), -1, effect.get("value", 0.0))
		"heal_player":
			GameManager.current_health = min(GameManager.max_health, GameManager.current_health + effect.get("value", 4))
			print("固本! Healed player by ", effect.get("value", 4))
		"activate_random_subslot":
			activate_random_subslot_requested.emit()

func _add_element(element: String, amount: int) -> void:
	match element:
		"金": GameManager.element_metal += amount
		"木": GameManager.element_wood += amount
		"水": GameManager.element_water += amount
		"火": GameManager.element_fire += amount
		"土": GameManager.element_earth += amount
		"以太": GameManager.aether += amount
		"all":
			GameManager.element_metal += amount
			GameManager.element_wood += amount
			GameManager.element_water += amount
			GameManager.element_fire += amount
			GameManager.element_earth += amount

func _generate_random_elements(amount: int, exclude: String) -> void:
	var elements = ["金", "木", "水", "火", "土"]
	if exclude != "":
		elements.erase(exclude)
	for i in range(amount):
		var chosen = elements[randi() % elements.size()]
		_add_element(chosen, 1)
		print("润泽! Gained 1 ", chosen)

func _apply_status(target_name: String, status_id: String, duration: int, value: float = 0.0, element: String = "") -> void:
	var target_dict = null
	if target_name == "enemy":
		target_dict = enemy_statuses
	else:
		target_dict = player_statuses
		
	target_dict[status_id] = {
		"duration": duration,
		"value": value if value != null else 0.0,
		"element": element if element != null else ""
	}
	print("Applied status: ", status_id, " to ", target_name, " for ", duration, " turns (value: ", value, ")")

func end_turn() -> void:
	if is_game_over: return
	print("=== END TURN ===")
	player_shield = 0 # Shield decay at turn end
	
	_execute_enemy_intent()
	enemy_turn_counter += 1
	
	emit_stats()
	emit_status_updates()

func _execute_enemy_intent() -> void:
	if is_game_over: return
	
	# Apply burn damage first
	if enemy_statuses.has("burn"):
		var burn_dmg = 3
		enemy_hp -= burn_dmg
		print("Enemy takes ", burn_dmg, " Burn damage.")
		enemy_statuses["burn"]["duration"] -= 1
		if enemy_statuses["burn"]["duration"] <= 0:
			enemy_statuses.erase("burn")
			
	if enemy_hp <= 0:
		enemy_hp = 0
		_trigger_victory()
		return
		
	enemy_shield = 0 # Enemy shield resets BEFORE resolving new intent
	var intent_type = enemy_turn_counter % 3
	
	# Check stun_attack
	var is_stunned = false
	if enemy_statuses.has("stun_attack") and intent_type == 0:
		is_stunned = true
		print("Enemy attack is Stunned/Intercepted by '阻截'!")
		enemy_statuses["stun_attack"]["duration"] -= 1
		if enemy_statuses["stun_attack"]["duration"] <= 0:
			enemy_statuses.erase("stun_attack")
			
	match intent_type:
		0:
			if not is_stunned:
				var damage = base_attack_damage + enemy_atk_buff
				# Apply Weak status multiplier
				if enemy_statuses.has("weak"):
					damage = int(damage * 0.75)
					print("Enemy is weakened! Damage reduced.")
					
				print("Enemy attacking for ", damage, " damage!")
				
				# Player damage reduction buff (alloy / 合金)
				if player_statuses.has("damage_reduction"):
					damage = max(0, damage - 1)
					print("Player '合金' reduced damage by 1.")
				
				# Rattan Armor (藤甲) passive logic
				if GameManager.acquired_equipment.has("藤甲"):
					if enemy_element == "火":
						damage += 4
						print("藤甲弱点！受到额外4点火属性伤害！")
					else:
						damage = max(0, damage - 4)
						print("藤甲坚固！抵挡了4点伤害！")
					
				if player_shield >= damage:
					player_shield -= damage
				else:
					var leftover = damage - player_shield
					player_shield = 0
					GameManager.current_health -= leftover
					
					# Retaliate Generate (余烬)
					if player_statuses.has("retaliate_generate"):
						_add_element("火", 1)
						print("Player '余烬' triggered! Gained 1 Fire.")
						
					# Thorns (坚韧)
					if player_statuses.has("thorns"):
						var thorns_dmg = 3
						enemy_hp -= thorns_dmg
						print("Player '坚韧' Thorns dealt ", thorns_dmg, " damage to enemy.")
						if enemy_hp <= 0:
							enemy_hp = 0
							_trigger_victory()
							return
							
					if GameManager.current_health <= 0:
						GameManager.current_health = 0
						_trigger_game_over()
						return
		1:
			var shd_gain = 15
			# Apply Slow status multiplier
			if enemy_statuses.has("slow"):
				shd_gain = int(shd_gain * 0.5)
				print("Enemy is slowed! Shield gain halved.")
			enemy_shield += shd_gain
			print("Enemy defended, gained ", shd_gain, " shield!")
		2:
			enemy_atk_buff += 3
			print("Enemy buffed, gained 3 ATK!")
			
	# Apply bleed damage after enemy action
	if enemy_statuses.has("bleed"):
		var bleed_dmg = 4
		enemy_hp -= bleed_dmg
		print("Enemy takes ", bleed_dmg, " Bleed damage.")
		enemy_statuses["bleed"]["duration"] -= 1
		if enemy_statuses["bleed"]["duration"] <= 0:
			enemy_statuses.erase("bleed")
		if enemy_hp <= 0:
			enemy_hp = 0
			_trigger_victory()
			return
			
	# Decay other statuses at end of enemy turn
	for status_id in enemy_statuses.keys():
		if enemy_statuses[status_id] is Dictionary and status_id in ["frail", "weak", "slow"]:
			enemy_statuses[status_id]["duration"] = enemy_statuses[status_id].get("duration", 0) - 1
			if enemy_statuses[status_id]["duration"] <= 0:
				enemy_statuses.erase(status_id)
				
	for status_id in player_statuses.keys():
		if player_statuses[status_id] is Dictionary:
			var dur = player_statuses[status_id].get("duration", -1)
			if dur != -1:
				player_statuses[status_id]["duration"] = dur - 1
				if player_statuses[status_id]["duration"] <= 0:
					player_statuses.erase(status_id)

func _trigger_victory() -> void:
	is_game_over = true
	battle_ended.emit(true)

func _trigger_game_over() -> void:
	is_game_over = true
	battle_ended.emit(false)

func execute_array_effects(effects: Array) -> void:
	for effect in effects:
		_execute_reaction_effect(effect, {})
	emit_stats()
	emit_status_updates()

func get_state_dict() -> Dictionary:
	return {
		"enemy_hp": enemy_hp,
		"enemy_shield": enemy_shield,
		"player_shield": player_shield,
		"player_statuses": player_statuses,
		"enemy_statuses": enemy_statuses
	}
