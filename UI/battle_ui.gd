extends Control

# --- Resource Pool Data ---
var player_shield: int = 0

# --- Enemy Data ---
var enemy_name: String = ""
var enemy_element: String = ""
var enemy_max_hp: int = 0
var enemy_hp: int = 0
var enemy_shield: int = 0
var enemy_turn_counter: int = 0
var enemy_atk_buff: int = 0
var base_attack_damage: int = 0

# --- State Variables ---
var has_manually_activated: bool = false
var pending_activation_slot: CardSlot = null
var pending_play_slot: CardSlot = null
var card_database: Dictionary = {}
var is_game_over: bool = false
var element_colors: Dictionary = {}
var reaction_matrix: Dictionary = {}
var card_db: Dictionary = {}
var reaction_db: Dictionary = {}
var player_statuses: Dictionary = {}
var enemy_statuses: Dictionary = {}
var should_reactivate: bool = false

var array_db: Dictionary = {}
var is_array_activated: bool = false
var array_button: Button

# --- Node References ---
@onready var master_layout: VBoxContainer = $MasterLayout
@onready var end_turn_button: Button = $MasterLayout/PlayerStatusBar/MarginContainer/HBoxContainer/EndTurnButton
@onready var player_status_bar: PanelContainer = $MasterLayout/PlayerStatusBar
@onready var player_status_container: HBoxContainer = $MasterLayout/PlayerStatusBar/MarginContainer/HBoxContainer/PlayerStatusContainer
@onready var enemy_status_container: HBoxContainer = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity/VBoxContainer/StatusContainer

@onready var slots_container: VBoxContainer = $MasterLayout/MiddleArea/SlotsContainer
@onready var payment_panel: PanelContainer = $PaymentPanel
@onready var payment_title: Label = $PaymentPanel/VBoxContainer/TitleLabel
@onready var resource_sliders: VBoxContainer = $PaymentPanel/VBoxContainer/ResourceSliders
@onready var remaining_label: Label = $PaymentPanel/VBoxContainer/HBoxContainer/RemainingLabel
@onready var confirm_activation_button: Button = $PaymentPanel/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_activation_button: Button = $PaymentPanel/VBoxContainer/HBoxContainer/CancelButton

@onready var reserve_panel: PanelContainer = $ReservePanel
@onready var reserve_options: HBoxContainer = $ReservePanel/VBoxContainer/OptionsContainer
@onready var reserve_cancel_btn: Button = $ReservePanel/VBoxContainer/CancelButton

var reserve_cards: Array = ["wood_growth_001", "fire_attack_001", "earth_defense_001", "earth_rock_001", "wood_thorn_001", "water_torrent_001", "metal_knife_001", "fire_law_001"]
var current_replace_slot: CardSlot = null

@onready var enemy_entity: PanelContainer = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity
@onready var enemy_intent_label: Label = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity/VBoxContainer/IntentLabel
@onready var enemy_name_label: Label = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity/VBoxContainer/NameLabel
@onready var enemy_stats_label: Label = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity/VBoxContainer/EnemyStatsLabel

func _load_json_data(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		print("Error: File not found: ", file_path)
		return {}
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Error: Could not open file: ", file_path)
		return {}
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		return parsed
	else:
		print("Error: Parsed JSON is not a Dictionary: ", file_path)
		return {}

func _ready() -> void:
	GlobalHUD.set_scene_name("战斗 (Battle)")
	# Load Databases from JSON
	card_db = _load_json_data("res://card_database.json")
	reaction_db = _load_json_data("res://reaction_database.json")
	array_db = _load_json_data("res://array_database.json")
	card_database = card_db
	reaction_matrix = reaction_db
	
	array_button = Button.new()
	array_button.text = "阵法: 未就绪"
	array_button.disabled = true
	array_button.pressed.connect(_on_array_button_pressed)
	array_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	array_button.offset_left = 20
	array_button.offset_top = 105 # Pushed further down to clear 2-tier Global HUD
	array_button.custom_minimum_size = Vector2(150, 40)
	add_child(array_button)
	
	# Dynamically determine node type and load enemy
	var node_type = ""
	if GameManager.current_node_index < GameManager.current_map_path.size():
		node_type = GameManager.current_map_path[GameManager.current_node_index]
	
	var category = "normal"
	if "Boss" in node_type or "将/帅" in node_type:
		category = "boss"
	elif "Elite" in node_type or "士" in node_type:
		category = "elite"
		
	var enemy_db = _load_json_data("res://enemy_database.json")
	if enemy_db.has(category):
		var enemies = enemy_db[category]
		if not enemies.is_empty():
			var chosen = enemies[randi() % enemies.size()]
			enemy_name = chosen.get("name", "Unknown")
			enemy_element = chosen.get("element", "木")
			enemy_max_hp = chosen.get("hp", 32)
			enemy_hp = enemy_max_hp
			base_attack_damage = chosen.get("intent_base_dmg", 8)
			print("Dynamic encounter loaded Category: ", category, " -> Enemy: ", enemy_name)

	
	element_colors = {
		"火": Color("#E64A19"),
		"木": Color("#43A047"),
		"水": Color("#1E88E5"),
		"金": Color("#FBC02D"),
		"土": Color("#8D6E63"),
		"以太": Color("#9C27B0")
	}
	
	# Connect signals
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if confirm_activation_button:
		confirm_activation_button.pressed.connect(_on_confirm_payment)
	if cancel_activation_button:
		cancel_activation_button.pressed.connect(_on_cancel_payment)
	if reserve_cancel_btn:
		reserve_cancel_btn.pressed.connect(_on_reserve_cancel)
		
	# Setup card slots and connect activation_requested signals
	_initialize_card_slots()
	
	if enemy_entity:
		var script = GDScript.new()
		script.source_code = "extends PanelContainer\nvar element: String = \"木\"\nvar hp: int = 32\nvar shield: int = 0\nvar max_hp: int = 32"
		script.reload()
		enemy_entity.set_script(script)
		enemy_entity.element = enemy_element
		enemy_entity.hp = enemy_hp
		enemy_entity.shield = enemy_shield
		enemy_entity.max_hp = enemy_max_hp

		var target_btn = Button.new()
		target_btn.name = "TargetButton"
		target_btn.flat = true
		enemy_entity.add_child(target_btn)
		target_btn.pressed.connect(_on_enemy_targeted)
	
	_update_end_turn_button()
	_update_resource_ui()
	_update_enemy_ui()
	_update_enemy_intent()
	_update_status_displays()
	
	# Apply premium glassmorphic/flat styling to player_status_bar
	if player_status_bar:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		player_status_bar.add_theme_stylebox_override("panel", style)
	
	# --- DEBUG INSTA-KILL BUTTON ---
	var debug_kill_btn = Button.new()
	debug_kill_btn.text = "🛠️ [测试] 一键秒杀"
	debug_kill_btn.add_theme_color_override("font_color", Color.RED)
	debug_kill_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_kill_btn.offset_left = -200
	debug_kill_btn.offset_top = 60
	debug_kill_btn.offset_right = -20
	debug_kill_btn.offset_bottom = 100
	debug_kill_btn.pressed.connect(_on_debug_instakill_pressed)
	add_child(debug_kill_btn)
	# -------------------------------
	


func _initialize_card_slots() -> void:
	var slots_data = GameManager.active_deck_layout
	
	for data in slots_data:
		var row = slots_container.get_node_or_null(data["row"])
		if not row: continue
		
		var main_idx = data["row"].right(1)
		var main_slot = row.get_node_or_null("MainSlot_" + main_idx)
		if main_slot and card_database.has(data["main"]):
			var c_data = card_database[data["main"]]
			main_slot.set_meta("card_id", data["main"])
			main_slot.name_label.text = c_data.get("name", "Unknown Card")
			
			var cost_dict = c_data.get("cost", {})
			var stat_text = "Cost: " + _format_cost(cost_dict)
			
			var main_slot_data = c_data.get("main_slot", {})
			if main_slot_data is Dictionary:
				var m_type = main_slot_data.get("type", "")
				var m_val = main_slot_data.get("value", 0)
				if m_type == "damage":
					stat_text += " | Dmg: " + str(m_val)
				elif m_type == "shield":
					stat_text += " | Shd: " + str(m_val)
					
			main_slot.stats_label.text = stat_text
			main_slot.cost_dict = cost_dict.duplicate()
			main_slot._update_visuals()
			
		for i in range(data["subs"].size()):
			var sub_slot = row.get_node_or_null("SubSlot_" + main_idx + "_" + str(i+1))
			var sub_id = data["subs"][i]
			if sub_slot and card_database.has(sub_id):
				var c_data = card_database[sub_id]
				sub_slot.set_meta("card_id", sub_id)
				sub_slot.name_label.text = "Sub: " + c_data.get("name", "Unknown Card")
				
				var sub_slot_data = c_data.get("sub_slot", {})
				var sub_val = 0
				if sub_slot_data is Dictionary:
					sub_val = sub_slot_data.get("value", 0)
					
				sub_slot.stats_label.text = "Buff: +" + str(sub_val)
				sub_slot._update_visuals()

	# Listen to activation signals on all Main Slots and add Swap buttons
	for row in slots_container.get_children():
		if row is HBoxContainer:
			for slot in row.get_children():
				if slot is CardSlot and not slot.is_sub_slot:
					slot.activation_requested.connect(_on_slot_activation_requested)
					
					var replace_btn = Button.new()
					replace_btn.text = "Swap"
					replace_btn.add_theme_font_size_override("font_size", 11)
					replace_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
					replace_btn.offset_left = -45
					replace_btn.offset_bottom = 22
					replace_btn.pressed.connect(_on_replace_button_pressed.bind(slot))
					slot.add_child(replace_btn)

func _format_cost(cost_dict: Dictionary) -> String:
	var result = []
	for key in cost_dict.keys():
		result.append(str(cost_dict[key]) + key)
	return ", ".join(result)

func _update_resource_ui() -> void:
	pass

func _update_end_turn_button() -> void:
	if has_manually_activated:
		end_turn_button.text = "结束回合 (End Turn)"
	else:
		end_turn_button.text = "引气入体 (End Turn)"

var current_card_cost_dict: Dictionary = {}
var current_card_total_cost: int = 0
var allocated_amounts: Dictionary = {}
var element_spinboxes: Dictionary = {}

func _on_slot_activation_requested(slot: CardSlot, cost: Dictionary) -> void:
	pending_activation_slot = slot
	current_card_cost_dict = cost.duplicate()
	
	if current_card_cost_dict.is_empty():
		current_card_cost_dict = {"Aether": 2}
		
	current_card_total_cost = 0
	for element in current_card_cost_dict.keys():
		current_card_total_cost += current_card_cost_dict[element]
		
	var card_name = slot.name_label.text
	payment_title.text = "Allocate Resources for " + card_name
	
	for child in resource_sliders.get_children():
		child.queue_free()
		
	allocated_amounts.clear()
	element_spinboxes.clear()
	
	for element in current_card_cost_dict.keys():
		if element == "Aether": continue
		_create_allocation_row(element, min(_get_element_current(element), current_card_cost_dict[element]))
		
	_create_allocation_row("Aether", GameManager.aether)
	
	_update_payment_calculation()
	payment_panel.show()

func _get_element_current(element: String) -> int:
	match element:
		"火": return GameManager.element_fire
		"土": return GameManager.element_earth
		"金": return GameManager.element_metal
		"木": return GameManager.element_wood
		"水": return GameManager.element_water
	return 0

func _create_allocation_row(element: String, max_val: int) -> void:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = element + ":"
	label.custom_minimum_size = Vector2(80, 0)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = 0
	spinbox.max_value = max_val
	spinbox.value = 0
	spinbox.value_changed.connect(_on_allocation_changed)
	
	hbox.add_child(label)
	hbox.add_child(spinbox)
	resource_sliders.add_child(hbox)
	
	element_spinboxes[element] = spinbox
	allocated_amounts[element] = 0

func _on_allocation_changed(_value: float) -> void:
	_update_payment_calculation()

func _update_payment_calculation() -> void:
	var total_allocated = 0
	for element in element_spinboxes.keys():
		var val = int(element_spinboxes[element].value)
		allocated_amounts[element] = val
		total_allocated += val
		
	var remaining = current_card_total_cost - total_allocated
	remaining_label.text = "Remaining Cost: %d" % remaining
	
	if total_allocated == current_card_total_cost:
		confirm_activation_button.disabled = false
	else:
		confirm_activation_button.disabled = true

func _on_confirm_payment() -> void:
	for element in allocated_amounts.keys():
		var amount = allocated_amounts[element]
		if amount > 0:
			match element:
				"火": GameManager.element_fire -= amount
				"土": GameManager.element_earth -= amount
				"金": GameManager.element_metal -= amount
				"木": GameManager.element_wood -= amount
				"水": GameManager.element_water -= amount
				"Aether": GameManager.aether -= amount
				
	_update_resource_ui()
	
	if pending_activation_slot:
		pending_activation_slot._activate_confirmed()
		has_manually_activated = true
		_update_end_turn_button()
		check_five_elements_array()
		
	payment_panel.hide()
	pending_activation_slot = null

func _on_cancel_payment() -> void:
	payment_panel.hide()
	pending_activation_slot = null

func _on_enemy_targeted(card_id: String = "", enemy_node: Node = null) -> void:
	if is_game_over: return
	
	if card_id == "":
		if pending_play_slot != null:
			card_id = pending_play_slot.get_meta("card_id", "")
			
	if enemy_node == null:
		enemy_node = enemy_entity
		
	if pending_play_slot != null or card_id != "":
		if card_id == "" or not card_db.has(card_id):
			print("ERROR: Attempted to execute an invalid card ID: ", card_id)
			if pending_play_slot:
				pending_play_slot._finalize_play()
				pending_play_slot = null
			return
			
		var card_data = card_db[card_id]
		var type = card_data["main_slot"]["type"]
		
		var main_slot_data = card_data.get("main_slot", {})
		
		# Trigger non-stat sub-slot effects (like generate_element) at card play
		if pending_play_slot:
			for sub_slot in pending_play_slot.sub_slots:
				if sub_slot.current_state == CardSlot.SlotState.ACTIVATED:
					var sub_id = sub_slot.get_meta("card_id", "")
					if sub_id != "" and card_db.has(sub_id):
						var sub_card_data = card_db[sub_id]
						var sub_slot_data = sub_card_data.get("sub_slot", {})
						var sub_type = sub_slot_data.get("type", "")
						if sub_type == "generate_element":
							_add_element(sub_slot_data.get("stat", ""), sub_slot_data.get("value", 0))

		# Apply Shield (if any)
		if type == "shield" or type == "damage_and_shield":
			# Step A: Base Value & Sub-slot Merge for Shield
			var final_value = main_slot_data.get("value", main_slot_data.get("shield_value", 0))
			if pending_play_slot:
				for sub_slot in pending_play_slot.sub_slots:
					if sub_slot.current_state == CardSlot.SlotState.ACTIVATED:
						var sub_id = sub_slot.get_meta("card_id", "")
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
			# Step A: Base Value & Sub-slot Merge for Damage
			var final_value = main_slot_data.get("value", main_slot_data.get("damage_value", 0))
			if pending_play_slot:
				for sub_slot in pending_play_slot.sub_slots:
					if sub_slot.current_state == CardSlot.SlotState.ACTIVATED:
						var sub_id = sub_slot.get_meta("card_id", "")
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
			
			# Step B: Strict Main-Slot Reaction Lookup
			# Crucial Rule: attacker_element = card_data.element (Main Slot ONLY)
			var attacker_element = card_data.get("element", "")
			
			if player_statuses.has("elemental_infusion") and player_statuses["elemental_infusion"] is Dictionary:
				attacker_element = player_statuses["elemental_infusion"].get("element", "")
				damage += player_statuses["elemental_infusion"].get("value", 0)
				print("Elemental Infusion Active! Attack changed to " + attacker_element)
			
			var reaction_triggered: bool = false
			var reaction_name: String = ""
			var reaction_color: Color = Color.WHITE
			
			if element_colors.has(attacker_element):
				reaction_color = element_colors[attacker_element]
				
			var target_element = enemy_node.element if enemy_node and "element" in enemy_node else enemy_element
			
			# Reaction Lookup
			var reaction = null
			if reaction_db.has(attacker_element) and reaction_db[attacker_element].has(target_element):
				reaction = reaction_db[attacker_element][target_element]
				reaction_name = reaction.get("name", "")
				reaction_triggered = true
				
			# Execution
			var is_true_damage = false
			should_reactivate = false
			if reaction_triggered and reaction != null:
				match reaction.get("type", ""):
					"damage_mult":
						damage = int(damage * reaction.get("value", 1.0))
						print("Elemental Reaction: ", reaction_name, "! Damage multiplied!")
					"shield_break_then_damage":
						if enemy_node and "shield" in enemy_node:
							enemy_node.shield = 0
						enemy_shield = 0
						print("Elemental Reaction: ", reaction_name, "! Shield broken!")
					"true_damage":
						is_true_damage = true
						if "value" in reaction:
							damage += reaction.get("value", 0)
						print("Elemental Reaction: ", reaction_name, "! True damage bypasses shield!")
					"composite":
						for sub_effect in reaction.get("effects", []):
							_execute_reaction_effect(sub_effect, enemy_node, card_data)
					_:
						_execute_reaction_effect(reaction, enemy_node, card_data)
						
				_spawn_floating_text(reaction_name + "!", reaction_color)
				
			# Apply Frail status modifier (damage x 1.5)
			if enemy_statuses.has("frail"):
				damage = int(damage * 1.5)
				print("Enemy is frail! Incoming damage increased.")
				
			# Apply Damage to HP / Shield
			var final_applied_damage = damage
			if is_true_damage:
				if enemy_node and "hp" in enemy_node:
					enemy_node.hp -= final_applied_damage
				else:
					enemy_hp -= final_applied_damage
			else:
				var current_shield = enemy_node.shield if enemy_node and "shield" in enemy_node else enemy_shield
				if current_shield > 0:
					if final_applied_damage >= current_shield:
						final_applied_damage -= current_shield
						current_shield = 0
					else:
						current_shield -= final_applied_damage
						final_applied_damage = 0
				
				var current_hp = enemy_node.hp if enemy_node and "hp" in enemy_node else enemy_hp
				current_hp -= final_applied_damage
				
				if enemy_node:
					if "shield" in enemy_node: enemy_node.shield = current_shield
					if "hp" in enemy_node: enemy_node.hp = current_hp
				enemy_shield = current_shield
				enemy_hp = current_hp
				
			print("Dealt ", final_value, " (Final: ", damage, ") damage to Enemy.")
			
			var final_enemy_hp = enemy_node.hp if enemy_node and "hp" in enemy_node else enemy_hp
			if final_enemy_hp <= 0:
				_trigger_victory()
				
		_update_resource_ui()
		_update_enemy_ui()
		
		if pending_play_slot:
			var slot_to_finalize = pending_play_slot
			slot_to_finalize._finalize_play()
			pending_play_slot = null
			
			if should_reactivate:
				slot_to_finalize.current_state = CardSlot.SlotState.INACTIVE
				slot_to_finalize._update_visuals()
				for sub_slot in slot_to_finalize.sub_slots:
					sub_slot.current_state = CardSlot.SlotState.INACTIVE
					sub_slot._update_visuals()
				print("淬火! Card reset to INACTIVE for repayment.")

func _execute_reaction_effect(effect: Dictionary, enemy_node: Node, _card_data: Dictionary) -> void:
	match effect.get("type", ""):
		"apply_status":
			var target = effect.get("target", "enemy")
			var target_node = enemy_node if target == "enemy" else self
			var duration = effect.get("duration", 2)
			var val = effect.get("value", 0.0)
			_apply_status(target_node, effect.get("status_id", ""), duration, val, effect.get("element", ""))
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
			var target_node = self if target == "player" else enemy_node
			var duration = effect.get("duration", -1)
			var val = effect.get("value", 0.0)
			_apply_status(target_node, effect.get("buff_id", ""), duration, val, effect.get("element", ""))
		"add_shield":
			player_shield += effect.get("value", 0)
			_update_resource_ui()
		"global_persistent_buff":
			_apply_status(self, effect.get("buff_id", ""), -1, effect.get("value", 0.0))
		"heal_player":
			GameManager.current_health = min(GameManager.max_health, GameManager.current_health + effect.get("value", 4))
			_update_resource_ui()
			print("固本! Healed player by ", effect.get("value", 4))
		"activate_random_subslot":
			_activate_random_subslot()

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
	_update_resource_ui()

func check_five_elements_array() -> void:
	if GameManager.active_five_elements_array == "" or is_array_activated: return
	
	var active_count = 0
	for row in slots_container.get_children():
		if row is HBoxContainer:
			for slot in row.get_children():
				if slot is CardSlot and not slot.is_sub_slot:
					if slot.current_state == CardSlot.SlotState.ACTIVATED:
						active_count += 1
						
	if active_count == 5:
		is_array_activated = true
		array_button.disabled = false
		var array_id = GameManager.active_five_elements_array
		if array_db.has(array_id):
			var array_name = array_db[array_id]["name"]
			array_button.text = array_name + " (点击释放)"
			_spawn_floating_text("阵法充能完毕！", Color.GOLD)

func _on_array_button_pressed() -> void:
	if not is_array_activated: return
	
	is_array_activated = false
	array_button.disabled = true
	array_button.text = "阵法: 消耗中/未就绪"
	
	var array_id = GameManager.active_five_elements_array
	if array_db.has(array_id):
		var effects = array_db[array_id].get("effects", [])
		for effect in effects:
			_execute_reaction_effect(effect, enemy_entity, {})
			
	_spawn_floating_text("阵法发动！", Color.CYAN)

func _generate_random_elements(amount: int, exclude: String) -> void:
	var elements = ["金", "木", "水", "火", "土"]
	if exclude != "":
		elements.erase(exclude)
	for i in range(amount):
		var chosen = elements[randi() % elements.size()]
		_add_element(chosen, 1)
		print("润泽! Gained 1 ", chosen)

func _activate_random_subslot() -> void:
	var inactive_subs = []
	for row in slots_container.get_children():
		if row is HBoxContainer:
			for slot in row.get_children():
				if slot is CardSlot and slot.is_sub_slot and slot.current_state == CardSlot.SlotState.INACTIVE:
					inactive_subs.append(slot)
	if inactive_subs.size() > 0:
		var chosen = inactive_subs[randi() % inactive_subs.size()]
		chosen.current_state = CardSlot.SlotState.ACTIVATED
		chosen._update_visuals()
		print("过载! Activated sub-slot: ", chosen.name)

func _apply_status(target, status_id: String, duration: int, value: float = 0.0, element: String = "") -> void:
	var target_dict = null
	var target_name = ""
	if target is String:
		target_name = target
	else:
		target_name = "enemy" if target == enemy_entity else "player"
		
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
	_update_status_displays()

func _spawn_floating_text(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	
	add_child(label)
	
	if enemy_entity:
		var target_pos = enemy_entity.global_position + Vector2(enemy_entity.size.x / 2 - 50, -30)
		target_pos += Vector2(randf_range(-20, 20), randf_range(-10, 10))
		label.global_position = target_pos
	else:
		label.global_position = Vector2(800, 100)
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -60), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color(color, 0.0), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(label.queue_free)

func _on_replace_button_pressed(slot_node: CardSlot) -> void:
	if reserve_cards.is_empty():
		print("Reserve deck is empty!")
		return
		
	current_replace_slot = slot_node
	
	# Randomly pick up to 3 options
	var options = []
	var pool = reserve_cards.duplicate()
	pool.shuffle()
	
	for i in range(min(3, pool.size())):
		options.append(pool[i])
		
	# Clear old options
	for child in reserve_options.get_children():
		child.queue_free()
		
	# Populate new options
	for card_id in options:
		if not card_database.has(card_id):
			print("CRITICAL: Swap failed. ID '", card_id, "' not found in card_database.json")
			continue
			
		var btn = Button.new()
		var card_data = card_database[card_id]
		btn.text = card_data["name"] + "\nCost: " + _format_cost(card_data["cost"])
		btn.custom_minimum_size = Vector2(140, 180)
		btn.pressed.connect(_on_reserve_option_selected.bind(card_id))
		reserve_options.add_child(btn)
		
	reserve_panel.show()

func _on_reserve_option_selected(card_id: String) -> void:
	if GameManager.aether < 5:
		print("Not enough Aether to swap! Need 5.")
		return
		
	# Deduct Aether
	GameManager.aether -= 5
	_update_resource_ui()
	
	# Swap cards
	var old_card_id = current_replace_slot.get_meta("card_id", "")
	if old_card_id != "":
		reserve_cards.append(old_card_id)
		
	reserve_cards.erase(card_id)
	
	# Update slot
	if not card_database.has(card_id):
		print("CRITICAL: Swap failed. ID '", card_id, "' not found in card_database.json")
		return
		
	current_replace_slot.set_meta("card_id", card_id)
	var card_data = card_database[card_id]
	current_replace_slot.name_label.text = card_data["name"]
	var stat_text = "Cost: " + _format_cost(card_data["cost"])
	if card_data["main_slot"]["type"] == "damage":
		stat_text += " | Dmg: " + str(card_data["main_slot"]["value"])
	elif card_data["main_slot"]["type"] == "shield":
		stat_text += " | Shd: " + str(card_data["main_slot"]["value"])
	current_replace_slot.stats_label.text = stat_text
	current_replace_slot.cost_dict = card_data["cost"].duplicate()
	current_replace_slot._update_visuals()
	
	reserve_panel.hide()
	current_replace_slot = null

func _on_reserve_cancel() -> void:
	reserve_panel.hide()
	current_replace_slot = null

func _on_end_turn_pressed() -> void:
	if is_game_over: return
	print("=== END TURN ===")
	player_shield = 0 # Shield decay at turn end
	
	if not has_manually_activated:
		GameManager.element_metal += 5
		GameManager.element_wood += 5
		GameManager.element_water += 5
		GameManager.element_fire += 5
		GameManager.element_earth += 5
		print("Yin Qi Ru Ti activated! Rewarded 5 to all basic elements.")
		
	# Progress enemy intent
	_execute_enemy_intent()
	enemy_turn_counter += 1
	_update_enemy_intent()
	
	# Reset state of PLAYED slots to INACTIVE
	for row in slots_container.get_children():
		if row is HBoxContainer:
			for slot in row.get_children():
				if slot is CardSlot:
					slot.reset_turn()
					
	# Reset activation tracking
	has_manually_activated = false
	_update_end_turn_button()
	_update_resource_ui()
	_update_status_displays()
	print("New turn started. PLAYED slots reset to INACTIVE. ACTIVATED slots persist.")
	print(export_state_to_json())

func _update_enemy_ui() -> void:
	if enemy_entity and "hp" in enemy_entity:
		enemy_hp = enemy_entity.hp
		enemy_shield = enemy_entity.shield
		enemy_element = enemy_entity.element
		
	enemy_name_label.text = "%s (%s)" % [enemy_name, enemy_element]
	enemy_stats_label.text = "HP: %d/%d | Shield: %d" % [enemy_hp, enemy_max_hp, enemy_shield]
	
	if element_colors.has(enemy_element):
		var color = element_colors[enemy_element]
		enemy_name_label.modulate = color
		if enemy_entity:
			enemy_entity.self_modulate = color

func _execute_enemy_intent() -> void:
	if is_game_over: return
	
	if enemy_entity and "hp" in enemy_entity:
		enemy_hp = enemy_entity.hp
		enemy_shield = enemy_entity.shield
		enemy_element = enemy_entity.element
		
	# Apply burn damage first
	if enemy_statuses.has("burn"):
		var burn_dmg = 3
		enemy_hp -= burn_dmg
		print("Enemy takes ", burn_dmg, " Burn damage.")
		enemy_statuses["burn"]["duration"] -= 1
		if enemy_statuses["burn"]["duration"] <= 0:
			enemy_statuses.erase("burn")
			
	if enemy_hp <= 0:
		if enemy_entity and "hp" in enemy_entity:
			enemy_entity.hp = enemy_hp
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
							if enemy_entity and "hp" in enemy_entity:
								enemy_entity.hp = enemy_hp
							_trigger_victory()
							return
							
					if GameManager.current_health <= 0:
						_trigger_game_over()
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
			if enemy_entity and "hp" in enemy_entity:
				enemy_entity.hp = enemy_hp
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
				
	# Sync back to enemy_entity fields
	if enemy_entity and "hp" in enemy_entity:
		enemy_entity.hp = enemy_hp
		enemy_entity.shield = enemy_shield
		
	_update_resource_ui()
	_update_enemy_ui()
	_update_status_displays()

func _trigger_game_over() -> void:
	print("GAME OVER")
	is_game_over = true
	GameManager.current_health = 0
	_update_resource_ui()
	if has_node("/root/GlobalHUD"):
		GlobalHUD.close_all_overlays()
	get_tree().change_scene_to_file("res://game_over_ui.tscn")

func _trigger_victory() -> void:
	print("VICTORY! Enemy Defeated.")
	is_game_over = true
	var target_btn = enemy_entity.get_node_or_null("TargetButton") if enemy_entity else null
	if target_btn:
		target_btn.disabled = true
		
	# Create a dynamic "Collect Loot" Button centered on screen
	var loot_btn = Button.new()
	loot_btn.text = "收集战利品 (Collect Loot)"
	loot_btn.custom_minimum_size = Vector2(250, 60)
	loot_btn.add_theme_font_size_override("font_size", 20)
	
	# Center it on screen
	loot_btn.set_anchors_preset(Control.PRESET_CENTER)
	loot_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loot_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	loot_btn.offset_left = -125
	loot_btn.offset_right = 125
	loot_btn.offset_top = -30
	loot_btn.offset_bottom = 30
	
	add_child(loot_btn)
	loot_btn.pressed.connect(_go_to_loot)

func _go_to_loot() -> void:
	if has_node("/root/GlobalHUD"):
		GlobalHUD.close_all_overlays()
	get_tree().change_scene_to_file("res://victory_ui.tscn")

func _update_enemy_intent() -> void:
	var intent_type = enemy_turn_counter % 3
	match intent_type:
		0:
			enemy_intent_label.text = "意图: 攻击 (%d 伤害)" % (base_attack_damage + enemy_atk_buff)
		1:
			enemy_intent_label.text = "意图: 防御 (15 护盾)"
		2:
			enemy_intent_label.text = "意图: 强化 (+3 攻击力)"

func export_state_to_json() -> String:
	var player_status = {
		"hp": GameManager.current_health,
		"max_hp": GameManager.max_health,
		"shield": player_shield,
		"elements": {
			"aether": GameManager.aether,
			"element_metal": GameManager.element_metal,
			"element_wood": GameManager.element_wood,
			"element_water": GameManager.element_water,
			"element_fire": GameManager.element_fire,
			"element_earth": GameManager.element_earth
		}
	}
	
	var deck_system: Array = []
	for row in slots_container.get_children():
		if row is HBoxContainer:
			for slot in row.get_children():
				if slot is CardSlot and not slot.is_sub_slot:
					deck_system.append(slot.to_dict())
					
	var combat_state = {
		"enemy_name": enemy_name,
		"enemy_element": enemy_element,
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"enemy_shield": enemy_shield,
		"player_statuses": player_statuses,
		"enemy_statuses": enemy_statuses
	}
	
	var state_dict = {
		"player_status": player_status,
		"deck_system": deck_system,
		"combat_state": combat_state
	}
	
	return JSON.stringify(state_dict, "\t")

# --- Visual Status Effect System ---
const STATUS_INFO = {
	"burn": {"name": "烧伤", "emoji": "🔥", "color": Color(0.95, 0.3, 0.2)},
	"frail": {"name": "脆化", "emoji": "☠️", "color": Color(0.8, 0.2, 0.8)},
	"weak": {"name": "虚弱", "emoji": "💤", "color": Color(0.5, 0.5, 0.7)},
	"slow": {"name": "减速", "emoji": "🐌", "color": Color(0.6, 0.4, 0.2)},
	"bleed": {"name": "流血", "emoji": "🩸", "color": Color(0.8, 0.1, 0.1)},
	"stun_attack": {"name": "禁锢", "emoji": "🕸️", "color": Color(0.4, 0.8, 0.9)},
	
	"thorns": {"name": "反震", "emoji": "🌵", "color": Color(0.3, 0.8, 0.3)},
	"damage_reduction": {"name": "合金", "emoji": "🛡️", "color": Color(0.9, 0.8, 0.2)},
	"retaliate_generate": {"name": "余烬", "emoji": "🌋", "color": Color(0.9, 0.5, 0.1)}
}

func _update_status_displays() -> void:
	if not enemy_status_container or not player_status_container:
		return
		
	# Clear existing children
	for child in enemy_status_container.get_children():
		child.queue_free()
	for child in player_status_container.get_children():
		child.queue_free()
		
	# Populate enemy statuses
	for status_id in enemy_statuses.keys():
		var data = enemy_statuses[status_id]
		if data is Dictionary:
			_create_status_badge(status_id, data, enemy_status_container)
			
	# Populate player statuses
	for status_id in player_statuses.keys():
		var data = player_statuses[status_id]
		if data is Dictionary:
			_create_status_badge(status_id, data, player_status_container)

func _create_status_badge(status_id: String, status_data: Dictionary, container: HBoxContainer) -> void:
	var info = STATUS_INFO.get(status_id, {"name": status_id.capitalize(), "emoji": "✨", "color": Color(0.5, 0.5, 0.5)})
	
	var panel = PanelContainer.new()
	
	# Flat stylebox for the badge background
	var style = StyleBoxFlat.new()
	style.bg_color = info["color"]
	style.bg_color.a = 0.22 # Semi-transparent colored background
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = info["color"]
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_top = 4
	style.content_margin_right = 8
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	var duration = status_data.get("duration", 1)
	var dur_text = ""
	if duration != -1:
		dur_text = " x%d" % duration
		
	label.text = info["emoji"] + " " + info["name"] + dur_text
	label.add_theme_color_override("font_color", info["color"].lightened(0.25))
	label.add_theme_font_size_override("font_size", 12)
	
	panel.add_child(label)
	container.add_child(panel)

func _on_debug_instakill_pressed() -> void:
	if is_game_over: 
		return
	print("DEBUG: Insta-kill triggered!")
	enemy_hp = 0
	_update_enemy_ui()
	_trigger_victory()
