extends Node
class_name BattleManager

const CARD_DATA_CONST = preload("res://Data/Card_data.gd")
const ENEMY_DATA_CONST = preload("res://Data/EnemyData.gd")

# Effect system preloads (Phase 2)
const EFFECT_BASE = preload("res://Data/Effects/EffectBase.gd")
const EQUIPMENT_DATA_CLS = preload("res://Data/EquipmentData.gd")

# -- Sub-systems ---------------------------------------------
var status_manager: StatusManager
var element_system: ElementSystem
var damage_resolver: DamageResolver

# -- Battle state --------------------------------------------
var current_enemy: EnemyData
var enemy_hp: int
var enemy_shield: int
var enemy_turn_counter: int
var enemy_atk_buff: int

var player_shield: int = 0
var has_activated_card_this_turn: bool = false
var activated_card_prev_turn: bool = false
var enemy_intent_override: String = ""

# Reaction persistent effects
var player_damage_reduction: int = 0
var reactivate_current_card: bool = false

# -- Signals -------------------------------------------------
signal battle_ended(is_victory: bool)
signal out_of_combat_reaction_triggered(effect_name: String)
signal formation_readiness_changed(is_ready: bool)
signal formation_activated(formation_name: String)

# Formation system
var formation_ready: bool = false


func _init_sub_systems() -> void:
	if status_manager == null:
		status_manager = StatusManager.new()
	if element_system == null:
		element_system = ElementSystem.new()
	if damage_resolver == null:
		damage_resolver = DamageResolver.new()

# ActionQueue accessor
func _aq() -> ActionQueue:
	return GameManager.action_queue


# ============================================================
#  EFFECT SYSTEM HELPER
# ============================================================
func _run_phase(effect: EffectBase, phase: int, context: Dictionary) -> void:
	if effect and effect.phase == phase:
		effect.execute(context)


# ============================================================
#  PASSIVE CARD SYSTEM
#  处理 携带/嵌入/初动 等持续生效的卡牌效果
# ============================================================

# 战斗开始时扫描牌库，应用所有"携带"卡牌的被动效果
func _apply_passive_card_effects() -> void:
	for card in GameManager.card_pool:
		if not card is CardData:
			continue
		if card.is_carry:
			_process_carry_card(card)

func _process_carry_card(card: CardData) -> void:
	print("[被动] 携带卡牌生效: ", card.card_name)
	for kw in card.get_all_keywords():
		if kw and kw.effect:
			_run_phase(kw.effect, kw.effect.phase, _make_passive_context())

func _make_passive_context() -> Dictionary:
	return {
		"damage_resolver": damage_resolver,
		"status_manager": status_manager,
		"player_has_shield": player_shield > 0,
	}


# ============================================================
#  CORE PLAY CARD PIPELINE
# ============================================================
func play_card(main_card: CardData, sub_cards: Array, target: Node = null) -> void:
	_init_sub_systems()
	if not _is_valid_card(main_card, "主槽"):
		return

	print("\n=== [管道执行] 打出卡牌: ", main_card.card_name, " ===")
	reactivate_current_card = false

	var valid_subs: Array = []
	for sub_card in sub_cards:
		if sub_card is CardData and _is_valid_card(sub_card, "副槽"):
			valid_subs.append(sub_card)

	EventBus.card_played.emit(main_card, valid_subs, target)

	# Build context for Effect system
	var context = {
		"damage_resolver": damage_resolver,
		"status_manager": status_manager,
		"battle_manager": self,
		"target": target,
		"player_has_shield": player_shield > 0,
		"prev_turn_active": activated_card_prev_turn,
		"enemy_has_shield": enemy_shield > 0,
	}

	# -- a) PRE-HIT -------------------------------------------
	print("[PRE-HIT 阶段] 开始处理前置特殊效果...")
	for eff in main_card.get_main_effects():
		_run_phase(eff, EFFECT_BASE.Phase.PRE_HIT, context)
	for sub_card in valid_subs:
		for eff in sub_card.get_sub_effects():
			_run_phase(eff, EFFECT_BASE.Phase.PRE_HIT, context)

	# -- b) AGGREGATION ---------------------------------------
	print("[AGGREGATION 阶段] 开始聚合计算伤害和护盾...")
	damage_resolver.reset()

	# Main card aggregation
	for eff in main_card.get_main_effects():
		_run_phase(eff, EFFECT_BASE.Phase.AGGREGATION, context)

	# Sub cards aggregation
	for sub_card in valid_subs:
		for eff in sub_card.get_sub_effects():
			_run_phase(eff, EFFECT_BASE.Phase.AGGREGATION, context)

	# Dynamic modifiers from enemy statuses
	var total_damage_ref = damage_resolver.total_damage
	if status_manager.has("burn", "enemy") and total_damage_ref > 0:
		damage_resolver.add_damage(3)
		print("  [动态加成] 敌人处于灼烧 (burn) 状态 -> 最终伤害 +3")
	if status_manager.has("bleed", "enemy") and total_damage_ref > 0:
		damage_resolver.add_damage(2)
		print("  [动态加成] 敌人处于流血 (bleed) 状态 -> 最终伤害 +2")
	if status_manager.has("strength", "player") and total_damage_ref > 0:
		var str_amt = status_manager.get_data("strength", "player").get("amount", 0)
		damage_resolver.add_damage(str_amt)
		print("  [力量] 伤害 +", str_amt)
	if status_manager.has("vigor", "player") and total_damage_ref > 0:
		var vig_amt = status_manager.get_data("vigor", "player").get("amount", 0)
		damage_resolver.add_damage(vig_amt)
		print("  [活力] 下次攻击额外伤害 +", vig_amt)

	print("  [计算结果] 总聚合伤害: ", damage_resolver.total_damage, ", 总聚合护盾: ", damage_resolver.total_shield)

	# -- c) REACTION CHECK ------------------------------------
	print("[REACTION CHECK 阶段] 开始检查并执行五行元素反应...")
	damage_resolver.damage_multiplier = 1.0
	damage_resolver.true_damage = 0

	var attach_result = element_system.attach(main_card.element,
		main_card.get("element_attachment_layers") if "element_attachment_layers" in main_card else 1)

	match attach_result:
		"attach":
			print("  [元素附着] 敌人首次附着: ", element_system.enemy_element, " (", element_system.enemy_element_layers, " 层)")
		"stack":
			print("  [元素附着] 同元素叠加: ", element_system.enemy_element, " (", element_system.enemy_element_layers, " 层)")
		"skip":
			print("  [元素附着] 跳过附着/反应逻辑")
		_:
			# combo_key returned -- trigger reaction
			print("  [元素反应] 反应触发: ", attach_result)
			if GameManager.equipped_reactions.has(attach_result):
				var reaction = GameManager.equipped_reactions[attach_result]
				if reaction is ReactionData:
					var mods = _trigger_reaction(reaction, main_card)
					if mods.has("damage_multiplier"):
						damage_resolver.damage_multiplier = mods["damage_multiplier"]
					if mods.has("true_damage"):
						damage_resolver.true_damage = mods["true_damage"]
			else:
				print("  [元素反应] 未装备对应元素反应 (", attach_result, ")")
			if element_system.enemy_element == "":
				print("  [元素附着] 敌人附着层数归零, 清除附着。")

	# -- d) EXECUTION -----------------------------------------
	print("[EXECUTION 阶段] 执行最终生命/护盾变更...")
	var gained_shield = damage_resolver.total_shield
	if gained_shield > 0:
		# Dexterity: bonus shield
		if status_manager.has("dexterity", "player"):
			var dex_amt = status_manager.get_data("dexterity", "player").get("amount", 0)
			gained_shield += dex_amt
			print("  [敏捷] 格挡 +", dex_amt)
		player_shield += gained_shield
		EventBus.shield_gained.emit("player", gained_shield, player_shield)
		print("  玩家获得护盾: ", gained_shield, " (当前护盾: ", player_shield, ")")

	var final_damage = damage_resolver.get_final_damage()
	if final_damage > 0:
		if target and target.has_method("take_damage"):
			target.take_damage(final_damage, main_card.element)
		else:
			take_damage(final_damage, main_card.element)

	if damage_resolver.true_damage > 0:
		enemy_hp = max(0, enemy_hp - damage_resolver.true_damage)
		print("  [真实伤害] 敌人受到 ", damage_resolver.true_damage, " 点真实伤害 (剩余 HP: ", enemy_hp, ")")
		_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "enemy", "hp": enemy_hp, "shield": enemy_shield})
		if enemy_hp <= 0:
			print("敌人被真实伤害击杀，战斗胜利！")
			battle_ended.emit(true)
			EventBus.battle_won.emit()
			return

	# Reflect
	if final_damage > 0 and (status_manager.has("reflect", "enemy") or status_manager.has("反震", "enemy")):
		var reflect_data = status_manager.get_data("reflect", "enemy")
		if reflect_data.is_empty():
			reflect_data = status_manager.get_data("反震", "enemy")
		var reflect_dmg = reflect_data.get("amount", 0)
		if reflect_dmg > 0:
			print("  [反震触发] 敌人反震伤害: ", reflect_dmg)
			_damage_player(reflect_dmg)

	# -- e) POST-HIT ------------------------------------------
	print("[POST-HIT 阶段] 处理状态施加、元素产出及治疗...")

	# Main card post-hit
	for eff in main_card.get_main_effects():
		_run_phase(eff, EFFECT_BASE.Phase.POST_HIT, context)

	# Sub cards post-hit
	for sub_card in valid_subs:
		for eff in sub_card.get_sub_effects():
			_run_phase(eff, EFFECT_BASE.Phase.POST_HIT, context)

	has_activated_card_this_turn = true
	_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "enemy", "hp": enemy_hp, "shield": enemy_shield})
	_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "player", "hp": GameManager.current_health, "shield": player_shield})
	GameManager.update_player_stats()
	print("=== [管道执行结束] ===\n")


# ============================================================
#  STATUS APPLY
# ============================================================
func _apply_status_effect(status_id: String, amount: int, duration: int) -> void:
	var target = "player" if (status_id == "reflect" or status_id == "反震") else "enemy"
	status_manager.apply(status_id, amount, duration, target)
	_aq().enqueue(ActionQueue.ActionType.STATUS_APPLY, {"target": target, "statuses": status_manager.get_all(target)})
	print("  对", target, "施加状态 [", status_id, "]: 回合数=", duration, ", 强度/反震伤害=", amount)


# ============================================================
#  PLAYER DAMAGE
# ============================================================
func _damage_player(amount: int, element: String = "") -> void:
	if amount <= 0:
		return

	# Equipment effects on incoming damage
	var reduced = _equip_damage_reduction()
	var vulnerable = _equip_element_vulnerability(element)
	var modified_amount = max(1, amount - reduced + vulnerable)
	# Ethereal: all damage this turn reduced to 1
	if status_manager.has("ethereal", "player"):
		modified_amount = 1
		print("  [虚化] 本回合伤害降为 1 点")
	var result = damage_resolver.damage_player(modified_amount, player_shield, player_damage_reduction)
	# Buffer: prevent next life loss
	if result.hp_loss > 0 and status_manager.has("buffer", "player"):
		print("  [缓冲] 阻止了 ", result.hp_loss, " 点生命损失")
		result.hp_loss = 0
	if result.damage_reduced > 0:
		print("  [合金效果] 伤害减免 ", result.damage_reduced, " 点")

	if result.hp_loss == 0 and player_shield == result.shield_remaining:
		# Fully absorbed
		player_shield = result.shield_remaining
		print("  [合金效果] 玩家受到 0 点伤害 (已完全减免伤害！)")
		return

	player_shield = result.shield_remaining
	if result.hp_loss > 0:
		GameManager.current_health = max(0, GameManager.current_health - result.hp_loss)
		print("  [玩家生命扣除] 受到伤害: ", result.hp_loss, " (剩余生命: ", GameManager.current_health, ")")
		EventBus.damage_taken.emit("player", result.hp_loss, "", GameManager.current_health)
		_aq().enqueue(ActionQueue.ActionType.DAMAGE, {"target": "player", "amount": result.hp_loss})
	else:
		print("  [玩家护盾抵扣] 受到伤害: ", amount, " (剩余护盾: ", player_shield, ")")
	_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "player", "hp": GameManager.current_health, "shield": player_shield})

	if status_manager.has("retaliate_generate_fire", "player") or status_manager.has("余烬", "player"):
		GameManager.element_fire += 1
		print("  [余烬效果触发] 玩家受到伤害，返还 1 点火元素 (当前: ", GameManager.element_fire, ")")


# ============================================================
#  HELPER: find CardSlot nodes (for "过载" reaction)
# ============================================================
func _find_card_slots_recursive(node: Node, list: Array) -> void:
	if node is CardSlot:
		list.append(node)
	for child in node.get_children():
		_find_card_slots_recursive(child, list)


# ============================================================
#  REACTION EXECUTION
# ============================================================
func _trigger_reaction(reaction: ReactionData, _current_card: CardData) -> Dictionary:
	if reaction == null: return {}
	var reaction_name = reaction.reaction_name
	print("  >>> [五行反应触发] 反应名称: ", reaction_name, " <<<")
	EventBus.reaction_triggered.emit(reaction_name, "")
	_aq().enqueue(ActionQueue.ActionType.REACTION, {"name": reaction_name, "color": reaction.reaction_color})

	var modifiers: Dictionary = {}

	match reaction_name:
		"蒸腾":
			_apply_status_effect("burn", 4, 2)

		"烧制":
			_apply_status_effect("frail", 1, 2)
			GameManager.element_earth += 1
			print("  [烧制反应] 敌人脆化，玩家获得 1 土元素")

		"焚烬":
			modifiers["damage_multiplier"] = 2.0
			print("  [焚烬反应] 本次伤害翻倍 (x2.0)！")

		"熔炼":
			break_shield()
			print("  [熔炼反应] 敌人护盾已被破除！")

		"润泽":
			var possible_elements = ["金", "木", "火", "土"]
			for i in range(2):
				var el = possible_elements[RNGService.randi() % possible_elements.size()]
				match el:
					"金": GameManager.element_metal += 1
					"木": GameManager.element_wood += 1
					"火": GameManager.element_fire += 1
					"土": GameManager.element_earth += 1
				print("  [润泽反应] 随机获得元素: ", el, " +1")

		"熄灭":
			_apply_status_effect("weak", 1, 2)

		"泥沼":
			_apply_status_effect("slow", 1, 2)

		"淬火":
			reactivate_current_card = true
			print("  [淬火反应] 卡牌重新激活标记已设置！")

		"添柴":
			GameManager.element_fire += 3
			print("  [添柴反应] 玩家获得 3 点火元素")

		"破土":
			modifiers["true_damage"] = 5
			print("  [破土反应] 追加 5 点真实伤害！")

		"吸纳":
			GameManager.aether += 1
			print("  [吸纳反应] 玩家获得 1 点以太")

		"坚韧":
			_apply_status_effect("reflect", 3, 2)

		"涌泉":
			GameManager.element_water += 2
			print("  [涌泉反应] 玩家获得 2 点水元素")

		"伐断":
			_apply_status_effect("bleed", 5, 2)

		"合金":
			player_damage_reduction += 1
			print("  [合金反应] 玩家永久获得 1 点伤害减免 (当前总减免: ", player_damage_reduction, ")")

		"过载":
			overload_random_sub_slot()
			print("  [过载反应] 触发过载")

		"埋藏":
			GameManager.workshop_discount_amount += 2
			print("  [埋藏反应] 车间折扣 +2（当前折扣: ", GameManager.workshop_discount_amount, "）")

		"阻截":
			_apply_status_effect("stun_attack", 1, 1)

		"余烬":
			_apply_status_effect("retaliate_generate_fire", 1, 1)

		"固本":
			GameManager.current_health = mini(GameManager.current_health + 4, GameManager.max_health)
			print("  [固本反应] 恢复 4 点生命值")

		_:
			printerr("  [未实现的元素反应]: ", reaction_name)

	return modifiers


# ============================================================
#  BATTLE INIT
# ============================================================
func start_battle(enemy_res: EnemyData) -> void:
	_init_sub_systems()
	current_enemy = enemy_res
	enemy_hp = enemy_res.max_hp
	enemy_shield = 0
	enemy_turn_counter = 0
	enemy_atk_buff = 0
	player_shield = 0

	status_manager.reset()
	element_system.reset()
	element_system.enemy_element = enemy_res.initial_element_attachment
	element_system.enemy_element_layers = enemy_res.initial_element_layers

	player_damage_reduction = 0
	reactivate_current_card = false
	has_activated_card_this_turn = false
	activated_card_prev_turn = false
	# 处理携带类卡牌被动效果
	_apply_passive_card_effects()
	enemy_intent_override = ""

	print("战斗初始化成功！敌人: ", enemy_res.enemy_name, " HP: ", enemy_hp,
		" (初始附着: ", element_system.enemy_element, " 层数: ", element_system.enemy_element_layers, ")")
	_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "enemy", "hp": enemy_hp, "shield": enemy_shield})
	_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "player", "hp": GameManager.current_health, "shield": player_shield})
	_aq().enqueue(ActionQueue.ActionType.STATUS_APPLY, {"target": "enemy", "statuses": status_manager.get_all("enemy")})
	_aq().enqueue(ActionQueue.ActionType.STATUS_APPLY, {"target": "player", "statuses": status_manager.get_all("player")})
	EventBus.turn_started.emit(0)


# ============================================================
#  END TURN
# ============================================================
func end_turn() -> void:
	print("--- 开始结算回合终止逻辑 ---")
	EventBus.turn_ended.emit(enemy_turn_counter)

	if not has_activated_card_this_turn:
		print("本回合未激活任何卡牌，触发【引气入体】！全基础元素 +5")
		GameManager.element_metal += 5
		GameManager.element_wood += 5
		GameManager.element_water += 5
		GameManager.element_fire += 5
		GameManager.element_earth += 5
		GameManager.update_player_stats()

	activated_card_prev_turn = has_activated_card_this_turn
	has_activated_card_this_turn = false

	# 1. Reset player shield
	player_shield = 0

	# 2. Enemy DOTs
	if enemy_hp > 0:
		if status_manager.has("burn", "enemy"):
			var dmg = status_manager.get_data("burn", "enemy").get("amount", 4)
			enemy_hp = max(0, enemy_hp - dmg)
			print("敌人受到 [burn] 伤害: ", dmg, ", 剩余生命: ", enemy_hp)
		if status_manager.has("bleed", "enemy"):
			var dmg = status_manager.get_data("bleed", "enemy").get("amount", 5)
			enemy_hp = max(0, enemy_hp - dmg)
			print("敌人受到 [bleed] 伤害: ", dmg, ", 剩余生命: ", enemy_hp)

	if enemy_hp <= 0:
		print("敌人被 DOT 击杀，战斗胜利！")
		_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "enemy", "hp": enemy_hp, "shield": enemy_shield})
		battle_ended.emit(true)
		EventBus.battle_won.emit()
		return

	# 2.5. Player DOTs
	if GameManager.current_health > 0:
		if status_manager.has("burn", "player"):
			var dmg = status_manager.get_data("burn", "player").get("amount", 4)
			GameManager.current_health = max(0, GameManager.current_health - dmg)
			print("玩家受到 [burn] 伤害: ", dmg, ", 剩余生命: ", GameManager.current_health)
		if status_manager.has("bleed", "player"):
			var dmg = status_manager.get_data("bleed", "player").get("amount", 5)
			GameManager.current_health = max(0, GameManager.current_health - dmg)
			print("玩家受到 [bleed] 伤害: ", dmg, ", 剩余生命: ", GameManager.current_health)

	if GameManager.current_health <= 0:
		print("玩家被 DOT 击杀，战斗失败！")
		_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "enemy", "hp": enemy_hp, "shield": enemy_shield})
		_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "player", "hp": GameManager.current_health, "shield": player_shield})
		battle_ended.emit(false)
		EventBus.battle_lost.emit()
		return

	# 3. Enemy action
	_execute_enemy_intent()
	if GameManager.current_health <= 0:
		print("玩家生命归零，战斗失败！")
		_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "enemy", "hp": enemy_hp, "shield": enemy_shield})
		_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "player", "hp": GameManager.current_health, "shield": player_shield})
		battle_ended.emit(false)
		EventBus.battle_lost.emit()
		return

	# 4. Advance turn counter
	enemy_turn_counter += 1

	# 5. Decay statuses
	status_manager.decay("enemy")
	status_manager.decay("player")
	_aq().enqueue(ActionQueue.ActionType.STATUS_APPLY, {"target": "enemy", "statuses": status_manager.get_all("enemy")})
	_aq().enqueue(ActionQueue.ActionType.STATUS_APPLY, {"target": "player", "statuses": status_manager.get_all("player")})

	EventBus.turn_started.emit(enemy_turn_counter + 1)

	# 6. UI sync
	_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "enemy", "hp": enemy_hp, "shield": enemy_shield})
	_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "player", "hp": GameManager.current_health, "shield": player_shield})


# ============================================================
#  ENEMY INTENT
# ============================================================
func _execute_enemy_intent() -> void:
	if not current_enemy:
		return

	var turn_intent = ""
	if enemy_intent_override != "":
		turn_intent = enemy_intent_override
		enemy_intent_override = ""
		print("敌人行动受到特殊效果干扰，意图被覆盖为: [", turn_intent, "]")
	else:
		var turn = enemy_turn_counter % 3
		match turn:
			0: turn_intent = "attack"
			1: turn_intent = "defend"
			2: turn_intent = "buff"

	match turn_intent:
		"attack":
			if status_manager.has("stun_attack", "enemy"):
				print("敌人处于 stun_attack 状态，跳过攻击意图！")
				return

			var dmg = current_enemy.intent_base_dmg + enemy_atk_buff
			if status_manager.has("weak", "enemy"):
				var weak_amt = status_manager.get_data("weak", "enemy").get("amount", 0)
				dmg = int(dmg * max(0.25, 1.0 - 0.25 * weak_amt))

			print("敌人发动攻击！造成伤害: ", dmg)
			_damage_player(dmg, current_enemy.element if current_enemy else "")

			if status_manager.has("reflect", "player") or status_manager.has("反震", "player"):
				var reflect_data = status_manager.get_data("reflect", "player")
				if reflect_data.is_empty():
					reflect_data = status_manager.get_data("反震", "player")
				var reflect_dmg = reflect_data.get("amount", 0)
				if reflect_dmg > 0:
					print("玩家 [反震] 触发！对敌人造成反震伤害: ", reflect_dmg)
					take_damage(reflect_dmg, "以太")

		"defend":
			var shield_gain = 15
			if status_manager.has("slow", "enemy"):
				shield_gain = int(shield_gain * 0.5)
			enemy_shield += shield_gain
			print("敌人进行防御，获得护盾: ", shield_gain, ", 当前总护盾: ", enemy_shield)

		"buff":
			enemy_atk_buff += 3
			print("敌人获得攻击力加成！atk_buff: +3, 当前总加成: ", enemy_atk_buff)


# ============================================================


# ============================================================
#  OVERLOAD / DRAW CARD
# ============================================================
func overload_random_sub_slot() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		var all_slots = []
		_find_card_slots_recursive(tree.current_scene, all_slots)
		var inactive_slots = []
		for slot in all_slots:
			if slot.current_state == CardSlot.SlotState.INACTIVE and slot.card_data != null and slot.is_sub_slot:
				inactive_slots.append(slot)
		if not inactive_slots.is_empty():
			var random_slot = inactive_slots[RNGService.randi() % inactive_slots.size()]
			random_slot._activate_confirmed()
			print("  [Overload] Activated sub-slot: ", random_slot.card_data.card_name)
		else:
			print("  [Overload] No inactive sub-slot found")

func draw_card_from_pool() -> void:
	if GameManager.card_pool.is_empty():
		print("  [DrawCard] Pool is empty!")
		return
	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene:
		return
	var all_slots = []
	_find_card_slots_recursive(tree.current_scene, all_slots)
	var empty_slots = []
	for slot in all_slots:
		if slot.is_sub_slot and slot.card_data == null:
			empty_slots.append(slot)
	if empty_slots.is_empty():
		print("  [DrawCard] No empty sub-slot available")
		return
	var random_card = GameManager.card_pool[RNGService.randi() % GameManager.card_pool.size()]
	var target_slot = empty_slots[RNGService.randi() % empty_slots.size()]
	target_slot.set_card(random_card)
	target_slot._activate_confirmed()
	print("  [DrawCard] Drew: ", random_card.card_name, " -> sub-slot")

# ============================================================

func charge_random_slot() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		var all_slots = []
		_find_card_slots_recursive(tree.current_scene, all_slots)
		var inactive_slots = []
		for slot in all_slots:
			if slot.current_state == CardSlot.SlotState.INACTIVE and slot.card_data != null:
				inactive_slots.append(slot)
		if not inactive_slots.is_empty():
			var target = inactive_slots[RNGService.randi() % inactive_slots.size()]
			target._activate_confirmed()
			# Skip cooldown after activation
			target.current_state = CardSlot.SlotState.ACTIVATED
			print("  [Charge] Activated without cooldown: ", target.card_data.card_name)
		else:
			print("  [Charge] No inactive slot found")

func eject_card_from_slot() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		var all_slots = []
		_find_card_slots_recursive(tree.current_scene, all_slots)
		var filled_sub_slots = []
		for slot in all_slots:
			if slot.is_sub_slot and slot.card_data != null:
				filled_sub_slots.append(slot)
		if not filled_sub_slots.is_empty():
			var target = filled_sub_slots[RNGService.randi() % filled_sub_slots.size()]
			var card = target.card_data
			target.set_card(null)
			if GameManager.card_pool.size() < 30:
				GameManager.card_pool.append(card)
			print("  [Eject] Returned card to pool: ", card.card_name)
		else:
			print("  [Eject] No filled sub-slot found")

func collapse_card() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		var all_slots = []
		_find_card_slots_recursive(tree.current_scene, all_slots)
		for slot in all_slots:
			if slot.is_sub_slot and slot.card_data != null and slot.current_state == CardSlot.SlotState.ACTIVATED:
				slot.current_state = CardSlot.SlotState.COOLDOWN
				slot.cooldown_turns = 999
				print("  [Collapse] Card cooldown until battle end: ", slot.card_data.card_name)
				return
		print("  [Collapse] No activated sub-slot found")

#  TARGET API (battle_manager acts as the enemy target)
# ============================================================
func take_damage(amount: int, element: String = "") -> void:
	var actual_dmg = amount + _equip_damage_bonus()
	if status_manager.has("frail", "enemy"):
		actual_dmg = int(actual_dmg * 1.5)
	if status_manager.has("vulnerable", "enemy"):
		var vuln_amt = status_manager.get_data("vulnerable", "enemy").get("amount", 0)
		actual_dmg = int(actual_dmg * (1.0 + 0.5 * vuln_amt))
		print("  [易伤] 敌人受到额外伤害 x", 1.0 + 0.5 * vuln_amt)

	var result = damage_resolver.damage_after_shield(actual_dmg, enemy_shield)
	enemy_shield = result.shield_remaining
	enemy_hp = max(0, enemy_hp - result.hp_loss)

	print("敌人受到伤害: ", amount, " (元素: ", element, "), 实际扣除生命: ", result.hp_loss,
		", 剩余生命: ", enemy_hp, ", 剩余护盾: ", enemy_shield)
	EventBus.damage_taken.emit("enemy", result.hp_loss, element, enemy_hp)
	_aq().enqueue(ActionQueue.ActionType.DAMAGE, {"target": "enemy", "amount": result.hp_loss, "element": element})
	_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "enemy", "hp": enemy_hp, "shield": enemy_shield})

	if enemy_hp <= 0:
		print("敌人生命值归零，战斗胜利！")
		battle_ended.emit(true)
		EventBus.battle_won.emit()


func get_status() -> String:
	return element_system.enemy_element


func set_status(element: String) -> void:
	element_system.set_element(element)
	print("敌人附着元素更新为: ", element_system.enemy_element, " (", element_system.enemy_element_layers, " 层)")


func break_shield() -> void:
	enemy_shield = 0
	print("敌人的护盾已被强行破除！")
	_aq().enqueue(ActionQueue.ActionType.SHIELD_BREAK, {"target": "enemy"})
	_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "enemy", "hp": enemy_hp, "shield": enemy_shield})


# ============================================================
#  FORMATION (五行阵法) SYSTEM
# ============================================================
func check_formation_readiness(main_slot_states: Array) -> void:
	var all_activated = true
	for state in main_slot_states:
		if state != CardSlot.SlotState.ACTIVATED:
			all_activated = false
			break

	if all_activated != formation_ready:
		formation_ready = all_activated
		formation_readiness_changed.emit(formation_ready)

	if formation_ready:
		print("【五行阵法】5 个主槽全部激活！阵法就绪！")


func activate_formation() -> void:
	if not formation_ready:
		return

	var formation = GameManager.active_formation
	if formation == null:
		print("【五行阵法】未拥有任何阵法！")
		return

	print("【五行阵法】发动: ", formation.formation_name)
	formation_activated.emit(formation.formation_name)

	# 阵法效果：15 点真实伤害
	enemy_hp = max(0, enemy_hp - 15)
	print("  -> 敌方受到 15 点真实伤害 (剩余 HP: ", enemy_hp, ")")

	if enemy_hp <= 0:
		print("敌人被阵法击杀，战斗胜利！")
		_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "enemy", "hp": enemy_hp, "shield": enemy_shield})
		_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "player", "hp": GameManager.current_health, "shield": player_shield})
		battle_ended.emit(true)
		EventBus.battle_won.emit()
		return

	# 阵法效果：10 点护盾
	player_shield += 10
	print("  -> 玩家获得 10 点护盾 (当前: ", player_shield, ")")

	# 阵法效果：全基础元素 +3
	GameManager.element_metal += 3
	GameManager.element_wood += 3
	GameManager.element_water += 3
	GameManager.element_fire += 3
	GameManager.element_earth += 3
	print("  -> 全基础元素 +3")

	formation_ready = false
	formation_readiness_changed.emit(false)
	_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "enemy", "hp": enemy_hp, "shield": enemy_shield})
	_aq().enqueue(ActionQueue.ActionType.HP_CHANGE, {"target": "player", "hp": GameManager.current_health, "shield": player_shield})


# ============================================================
#  INTENT TEXT (供 UI 调用)
# ============================================================
func get_enemy_intent_text() -> String:
	if not current_enemy:
		return ""

	var turn = enemy_turn_counter % 3
	var dmg = current_enemy.intent_base_dmg + enemy_atk_buff
	if status_manager.has("weak", "enemy"):
		var weak_amt = status_manager.get_data("weak", "enemy").get("amount", 0)
		dmg = int(dmg * max(0.25, 1.0 - 0.25 * weak_amt))

	match turn:
		0:
			if status_manager.has("stun_attack", "enemy"):
				return "Intent: Stunned (Skip Attack)"
			else:
				return "Intent: Attack " + str(dmg)
		1:
			var shield_gain = 15
			if status_manager.has("slow", "enemy"):
				shield_gain = int(shield_gain * 0.5)
			return "Intent: Defend " + str(shield_gain)
		2:
			return "Intent: Buff (+3 Atk)"
	return ""


# ============================================================
#  VALIDATION
# ============================================================
func _is_valid_card(card: CardData, slot_label: String) -> bool:
	if card == null:
		printerr("BattleManager: ", slot_label, " 卡牌资源为 null。",
				" 请检查 GameManager.active_deck_layout 中的 'main'/'subs' 是否正确赋值。")
		return false
	if card.id.is_empty():
		printerr("BattleManager: ", slot_label, " 卡牌资源 id 为空，",
				"可能是 .tres 文件未正确设置 id 字段。")
		return false
	return true


func to_dict() -> Dictionary:
	return {
		"enemy_path": current_enemy.resource_path if current_enemy else "",
		"enemy_hp": enemy_hp,
		"enemy_shield": enemy_shield,
		"enemy_turn_counter": enemy_turn_counter,
		"enemy_atk_buff": enemy_atk_buff,
		"player_shield": player_shield,
		"has_activated_card_this_turn": has_activated_card_this_turn,
		"activated_card_prev_turn": activated_card_prev_turn,
		"enemy_intent_override": enemy_intent_override,
		"player_damage_reduction": player_damage_reduction,
		"reactivate_current_card": reactivate_current_card,
		"formation_ready": formation_ready,
		"status_manager": status_manager.to_dict() if status_manager else {},
		"element_system": element_system.to_dict() if element_system else {},
	}


func from_dict(d: Dictionary) -> void:
	if d.is_empty(): return
	_init_sub_systems()

	var enemy_path: String = d.get("enemy_path", "")
	if enemy_path != "" and ResourceLoader.exists(enemy_path):
		current_enemy = load(enemy_path)
	enemy_hp = d.get("enemy_hp", enemy_hp)
	enemy_shield = d.get("enemy_shield", enemy_shield)
	enemy_turn_counter = d.get("enemy_turn_counter", enemy_turn_counter)
	enemy_atk_buff = d.get("enemy_atk_buff", enemy_atk_buff)
	player_shield = d.get("player_shield", player_shield)
	has_activated_card_this_turn = d.get("has_activated_card_this_turn", false)
	activated_card_prev_turn = d.get("activated_card_prev_turn", false)
	enemy_intent_override = d.get("enemy_intent_override", "")
	player_damage_reduction = d.get("player_damage_reduction", player_damage_reduction)
	reactivate_current_card = d.get("reactivate_current_card", false)
	formation_ready = d.get("formation_ready", false)

	if d.has("status_manager") and status_manager:
		status_manager.from_dict(d["status_manager"])
	if d.has("element_system") and element_system:
		element_system.from_dict(d["element_system"])


# ============================================================
#  EQUIPMENT EFFECTS
# ============================================================

# 所有装备的 damage_bonus 总和（玩家打出的伤害基础加值）。
func _equip_damage_bonus() -> int:
	var total := 0
	for eq in GameManager.acquired_equipment:
		if not eq is EQUIPMENT_DATA_CLS:
			continue
		for eff in eq.effects:
			if eff is EquipmentEffect and eff.effect_type == "damage_bonus":
				total += int(eff.value)
	return total


# 所有装备的 damage_reduction 总和（玩家受到的伤害减免）。
func _equip_damage_reduction() -> int:
	var total := 0
	for eq in GameManager.acquired_equipment:
		if not eq is EQUIPMENT_DATA_CLS:
			continue
		for eff in eq.effects:
			if eff is EquipmentEffect and eff.effect_type == "damage_reduction":
				total += int(eff.value)
	return total


# 针对指定元素的 element_vulnerability 总和（玩家受到的额外伤害）。
func _equip_element_vulnerability(element: String) -> int:
	if element.is_empty():
		return 0
	var total := 0
	for eq in GameManager.acquired_equipment:
		if not eq is EQUIPMENT_DATA_CLS:
			continue
		for eff in eq.effects:
			if eff is EquipmentEffect and eff.effect_type == "element_vulnerability" \
					and eff.element == element:
				total += int(eff.value)
	return total
