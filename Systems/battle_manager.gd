extends Node

# 引用 CardData 类，确保类型检查
const CARD_DATA_CONST = preload("res://Resources/Scripts/Card_data.gd")
const ENEMY_DATA_CONST = preload("res://Resources/Scripts/EnemyData.gd")

# --- 五行反应映射已重构为基于资源的 ReactionData 动态加载 ---

# --- 状态变量 ---
var current_enemy: EnemyData
var enemy_hp: int
var enemy_shield: int
var enemy_turn_counter: int
var enemy_atk_buff: int
var enemy_statuses: Dictionary = {}

# 元素层级系统变量
var enemy_element: String = ""
var enemy_element_layers: int = 0

var player_statuses: Dictionary = {}
var player_shield: int = 0
var has_activated_card_this_turn: bool = false
var activated_card_prev_turn: bool = false
var enemy_intent_override: String = ""

# 反应效果附加变量
var player_damage_reduction: int = 0
var reactivate_current_card: bool = false

# --- 信号（供 BattleUI 监听）---
signal stats_updated(p_hp: int, p_shield: int, e_hp: int, e_shield: int)
signal status_updated(target: String, status_dict: Dictionary)
signal reaction_triggered(reaction_name: String, reaction_color: Color)
signal battle_ended(is_victory: bool)
signal out_of_combat_reaction_triggered(effect_name: String)


# --- 核心打牌逻辑 (Pipeline 架构) ---
# main_card : 主槽 CardData 资源（已通过 is_valid() 校验）
# sub_cards  : 副槽 CardData 资源数组
# target     : 技能目标节点（通常是敌人节点）
func play_card(main_card: CardData, sub_cards: Array, target: Node = null) -> void:
	# 1. 安全校验主槽
	if not _is_valid_card(main_card, "主槽"):
		return

	print("\n=== [管道执行] 打出卡牌: ", main_card.card_name, " ===")
	
	# 重置单卡触发反应重新激活标志
	reactivate_current_card = false
	
	# 过滤出有效副卡
	var valid_subs: Array = []
	for sub_card in sub_cards:
		if sub_card is CardData and _is_valid_card(sub_card, "副槽"):
			valid_subs.append(sub_card)

	# =========================================================
	# a) PRE-HIT PHASE: Process special actions first (shield_break, change_enemy_intent)
	# =========================================================
	print("[PRE-HIT 阶段] 开始处理前置特殊效果...")
	# Check main card for special actions first
	if main_card.main_type == "special_action":
		_process_special_action(main_card, target)
	# Check sub slots
	for sub_card in valid_subs:
		if sub_card.sub_type == "special_action":
			_process_special_action(sub_card, target)

	# =========================================================
	# b) AGGREGATION PHASE: Sum up damage & shield, apply multipliers/conditions
	# =========================================================
	print("[AGGREGATION 阶段] 开始聚合计算伤害和护盾...")
	var total_damage: int = 0
	var total_shield: int = 0

	# 1. 主槽基础值
	match main_card.main_type:
		"damage":
			total_damage += main_card.main_value
		"shield":
			total_shield += main_card.main_value
		"damage_and_shield":
			total_damage += main_card.main_value
			total_shield += main_card.main_value
		"condition_damage":
			var base_dmg = main_card.main_value
			var cond_bonus = 0
			if main_card.status_id == "player_has_shield" and player_shield > 0:
				cond_bonus = main_card.status_amount
			elif main_card.status_id == "prev_turn_active" and activated_card_prev_turn:
				cond_bonus = main_card.status_amount
			else:
				# Fallback helper if condition is empty
				cond_bonus = main_card.status_amount if main_card.status_id == "" else 0
			total_damage += base_dmg + cond_bonus
			print("  主槽触发 [条件伤害] -> 基础:", base_dmg, " 追加:", cond_bonus)

	# 2. 副槽基础值
	for sub_card in valid_subs:
		match sub_card.sub_type:
			"damage":
				total_damage += sub_card.sub_value
			"shield":
				total_shield += sub_card.sub_value
			"condition_damage":
				var base_dmg = sub_card.sub_value
				var cond_bonus = 0
				if sub_card.status_id == "player_has_shield" and player_shield > 0:
					cond_bonus = sub_card.status_amount
				elif sub_card.status_id == "prev_turn_active" and activated_card_prev_turn:
					cond_bonus = sub_card.status_amount
				else:
					cond_bonus = sub_card.status_amount if sub_card.status_id == "" else 0
				total_damage += base_dmg + cond_bonus
				print("  副槽 [", sub_card.card_name, "] 触发 [条件伤害] -> 基础:", base_dmg, " 追加:", cond_bonus)

	# 3. 动态倍率与修正 (例如 "如果敌人有 burn，伤害 +3")
	if enemy_statuses.has("burn") and total_damage > 0:
		total_damage += 3
		print("  [动态加成] 敌人处于灼烧 (burn) 状态 -> 最终伤害 +3")
	if enemy_statuses.has("bleed") and total_damage > 0:
		total_damage += 2
		print("  [动态加成] 敌人处于流血 (bleed) 状态 -> 最终伤害 +2")

	print("  [计算结果] 总聚合伤害: ", total_damage, ", 总聚合护盾: ", total_shield)

	# =========================================================
	# c) REACTION CHECK PHASE: Determine if elements mix & trigger reaction
	# =========================================================
	print("[REACTION CHECK 阶段] 开始检查并执行五行元素反应...")
	var damage_multiplier: float = 1.0
	var true_damage_to_deal: int = 0
	
	if main_card.element in ["金", "木", "水", "火", "土"]:
		var layers_to_apply = main_card.get("element_attachment_layers") if "element_attachment_layers" in main_card else 1
		if layers_to_apply > 0:
			if enemy_element == "" or enemy_element_layers <= 0:
				# 附着首次元素并设置指定的层数
				enemy_element = main_card.element
				enemy_element_layers = layers_to_apply
				print("  [元素附着] 敌人无元素附着，首次附着: ", enemy_element, " (", enemy_element_layers, " 层)")
			elif enemy_element == main_card.element:
				# 同元素，层数相加
				enemy_element_layers += layers_to_apply
				print("  [元素附着] 敌人已有相同元素, 附着层数增加: ", enemy_element, " (当前: ", enemy_element_layers, " 层)")
			else:
				# 异元素相交 -> 消耗 1 层并触发 reaction
				var card_el = main_card.element
				var target_el = enemy_element
				
				enemy_element_layers -= 1
				print("  [元素反应] 异元素接触 (卡牌 ", card_el, " + 敌人 ", target_el, ") -> 消耗 1 层附着, 剩余: ", enemy_element_layers, " 层")
				
				var el_arr = [card_el, target_el]
				el_arr.sort()
				var combo_key = el_arr[0] + "_" + el_arr[1]
				
				if GameManager.equipped_reactions.has(combo_key):
					var reaction = GameManager.equipped_reactions[combo_key]
					if reaction is ReactionData:
						# 触发五行反应
						var mods = _trigger_reaction(reaction, main_card)
						if mods.has("damage_multiplier"):
							damage_multiplier = mods["damage_multiplier"]
						if mods.has("true_damage"):
							true_damage_to_deal = mods["true_damage"]
				else:
					print("  [元素反应] 未装备对应元素反应 (", combo_key, ")")
				
				# 如果层数归零，清除附着
				if enemy_element_layers <= 0:
					enemy_element = ""
					print("  [元素附着] 敌人附着层数归零, 清除附着。")
		else:
			print("  [元素附着] 卡牌附着层数为 0, 跳过附着/反应逻辑。")

	# =========================================================
	# d) EXECUTION PHASE: Apply damage & shield
	# =========================================================
	print("[EXECUTION 阶段] 执行最终生命/护盾变更...")
	# 1. 应用玩家护盾
	if total_shield > 0:
		player_shield += total_shield
		print("  玩家获得护盾: ", total_shield, " (当前护盾: ", player_shield, ")")

	# 2. 应用伤害到目标
	var final_damage = int(total_damage * damage_multiplier)
	if final_damage > 0:
		if target and target.has_method("take_damage"):
			target.take_damage(final_damage, main_card.element)
		else:
			take_damage(final_damage, main_card.element) # fallback to self
			
	# 3. 结算破土等真实伤害 (无视护盾)
	if true_damage_to_deal > 0:
		enemy_hp = max(0, enemy_hp - true_damage_to_deal)
		print("  [真实伤害] 敌人受到 ", true_damage_to_deal, " 点真实伤害 (剩余 HP: ", enemy_hp, ")")
		stats_updated.emit(int(GameManager.current_health), int(player_shield), int(enemy_hp), int(enemy_shield))
		if enemy_hp <= 0:
			print("敌人被真实伤害击杀，战斗胜利！")
			battle_ended.emit(true)
			return

	# 4. 结算敌人反震 (Reflect)
	if final_damage > 0 and (enemy_statuses.has("reflect") or enemy_statuses.has("反震")):
		var reflect_data = enemy_statuses.get("reflect", enemy_statuses.get("反震"))
		var reflect_dmg = reflect_data.get("amount", 0)
		if reflect_dmg > 0:
			print("  [反震触发] 敌人反震伤害: ", reflect_dmg)
			_damage_player(reflect_dmg)

	# =========================================================
	# e) POST-HIT PHASE: Apply statuses, triggers elements, heals
	# =========================================================
	print("[POST-HIT 阶段] 处理状态施加、元素产出及治疗...")
	# 1. 主槽状态施加与治疗
	if main_card.main_type == "status_apply" and main_card.status_id != "":
		_apply_status_effect(main_card.status_id, main_card.status_amount, main_card.status_duration)
	elif main_card.main_type == "heal":
		GameManager.current_health = mini(
			GameManager.current_health + main_card.main_value,
			GameManager.max_health
		)
		print("  主槽治疗效果: 玩家恢复 ", main_card.main_value, " 生命值")

	# 2. 副槽状态、产生元素、治疗效果
	for sub_card in valid_subs:
		match sub_card.sub_type:
			"status_apply":
				if sub_card.status_id != "":
					_apply_status_effect(sub_card.status_id, sub_card.status_amount, sub_card.status_duration)
			"heal":
				GameManager.current_health = mini(
					GameManager.current_health + sub_card.sub_value,
					GameManager.max_health
				)
				print("  副槽 [", sub_card.card_name, "] 触发治疗: +", sub_card.sub_value)
			"generate_element":
				_generate_element_sub(sub_card)

	# 3. 回合内激活标记
	has_activated_card_this_turn = true

	# 4. 更新状态与同步 UI
	stats_updated.emit(int(GameManager.current_health), int(player_shield), int(enemy_hp), int(enemy_shield))
	GameManager.update_player_stats()
	print("=== [管道执行结束] ===\n")


# --- 管道前置特殊效果处理 ---
func _process_special_action(card_res: CardData, target: Node) -> void:
	match card_res.status_id:
		"shield_break":
			print("  [PRE-HIT 特殊效果] 触发强力破盾！")
			if target and target.has_method("break_shield"):
				target.break_shield()
			else:
				break_shield() # 破坏 BattleManager 中的敌人护盾
		"change_enemy_intent":
			# 将敌人下一次的行动意图覆盖为 Defend
			enemy_intent_override = "defend"
			print("  [PRE-HIT 特殊效果] 改变敌人当前/下回合意图为: [DEFEND]")
		_:
			print("  [PRE-HIT 特殊效果] 未知或未实现的特殊效果: ", card_res.status_id)


# --- 管道后置状态施加 ---
func _apply_status_effect(status_id: String, amount: int, duration: int) -> void:
	var dur = duration if duration > 0 else 1
	var amt = amount if amount > 0 else 1
	
	# 如果状态是 reflect/反震，它应该施加在玩家身上；否则施加给敌人 (例如 burn, bleed, slow)
	if status_id == "reflect" or status_id == "反震":
		player_statuses[status_id] = {"duration": dur, "amount": amt}
		status_updated.emit("player", player_statuses)
		print("  对玩家施加状态 [", status_id, "]: 回合数=", dur, ", 强度/反震伤害=", amt)
	else:
		enemy_statuses[status_id] = {"duration": dur, "amount": amt}
		status_updated.emit("enemy", enemy_statuses)
		print("  对敌人施加状态 [", status_id, "]: 回合数=", dur, ", 强度/每回合伤害=", amt)


# --- 管道后置副槽产出元素 ---
func _generate_element_sub(sub_card: CardData) -> void:
	var value = sub_card.sub_value
	match sub_card.sub_element_type:
		"金": GameManager.element_metal += value
		"木": GameManager.element_wood  += value
		"水": GameManager.element_water += value
		"火": GameManager.element_fire  += value
		"土": GameManager.element_earth += value
		"以太": GameManager.aether      += value
		_: printerr("  generate_element: 未知的 sub_element_type: ", sub_card.sub_element_type)
	print("  副槽 [", sub_card.card_name, "] 产出元素: ", sub_card.sub_element_type, " +", value)


# --- 统一玩家受击扣减生命/护盾接口 (支持合金减免与余烬返还) ---
func _damage_player(amount: int) -> void:
	if amount <= 0:
		return
		
	# 1. 触发“合金”减伤
	var final_dmg = max(0, amount - player_damage_reduction)
	if final_dmg <= 0:
		print("  [合金效果] 玩家受到 0 点伤害 (已完全减免伤害！)")
		return
		
	# 2. 扣除玩家护盾 or HP
	if player_shield >= final_dmg:
		player_shield -= final_dmg
		print("  [玩家护盾抵扣] 受到伤害: ", final_dmg, " (剩余护盾: ", player_shield, ")")
	else:
		var remainder = final_dmg - player_shield
		player_shield = 0
		GameManager.current_health = max(0, GameManager.current_health - remainder)
		print("  [玩家生命扣除] 受到伤害: ", remainder, " (剩余生命: ", GameManager.current_health, ")")
		
	# 3. 触发“余烬”受伤返还火元素
	if player_statuses.has("retaliate_generate_fire") or player_statuses.has("余烬"):
		GameManager.element_fire += 1
		print("  [余烬效果触发] 玩家受到伤害，返还 1 点火元素 (当前: ", GameManager.element_fire, ")")


# --- 递归寻找 CardSlot 节点辅助函数 (用于“过载”反应) ---
func _find_card_slots_recursive(node: Node, list: Array) -> void:
	if node is CardSlot:
		list.append(node)
	for child in node.get_children():
		_find_card_slots_recursive(child, list)


# --- 五行反应核心执行逻辑 (Task 2 & 3) ---
func _trigger_reaction(reaction: ReactionData, _current_card: CardData) -> Dictionary:
	if reaction == null: return {}
	var reaction_name = reaction.reaction_name
	print("  >>> [五行反应触发] 反应名称: ", reaction_name, " <<<")
	
	reaction_triggered.emit(reaction_name, reaction.reaction_color)
	
	var modifiers: Dictionary = {}
	
	match reaction_name:
		"蒸腾":
			# 提供烧伤效果，每回合按层数结算扣血
			_apply_status_effect("burn", 4, 2)
			
		"烧制":
			# 敌方获得脆化（受伤x1.5）2回合，主控获得1点土元素
			_apply_status_effect("frail", 1, 2)
			GameManager.element_earth += 1
			print("  [烧制反应] 敌人脆化，玩家获得 1 土元素")
			
		"焚烬":
			# 本次火元素伤害翻倍
			modifiers["damage_multiplier"] = 2.0
			print("  [焚烬反应] 本次伤害翻倍 (x2.0)！")
			
		"熔炼":
			# 如果目标有护盾，则破除目标的护盾，再结算伤害
			break_shield()
			print("  [熔炼反应] 敌人护盾已被破除！")
			
		"润泽":
			# 主控随机获得2单位非水元素
			var possible_elements = ["金", "木", "火", "土"]
			for i in range(2):
				var el = possible_elements[randi() % possible_elements.size()]
				match el:
					"金": GameManager.element_metal += 1
					"木": GameManager.element_wood += 1
					"火": GameManager.element_fire += 1
					"土": GameManager.element_earth += 1
				print("  [润泽反应] 随机获得元素: ", el, " +1")
				
		"熄灭":
			# 为目标赋予“虚弱”（造成伤害x0.75）2回合
			_apply_status_effect("weak", 1, 2)
			
		"泥沼":
			# 为目标赋予“减速”（获得护盾量x0.5）2回合
			_apply_status_effect("slow", 1, 2)
			
		"淬火":
			# 触发该反应的卡牌可以在本回合内再次“激活”
			reactivate_current_card = true
			print("  [淬火反应] 卡牌重新激活标记已设置！")
			
		"添柴":
			# 主控获得3点火元素
			GameManager.element_fire += 3
			print("  [添柴反应] 玩家获得 3 点火元素")
			
		"破土":
			# 无视目标护盾，直接造成5木元素伤害 (真实伤害)
			modifiers["true_damage"] = 5
			print("  [破土反应] 追加 5 点真实伤害！")
			
		"吸纳":
			# 从目标处偷取1点以太 (直接增加1点以太)
			GameManager.aether += 1
			print("  [吸纳反应] 玩家获得 1 点以太")
			
		"坚韧":
			# 主控获得“反震”（受击时回敬3伤）
			_apply_status_effect("reflect", 3, 2)
			
		"涌泉":
			# 激活后，立即补充2单位水元素
			GameManager.element_water += 2
			print("  [涌泉反应] 玩家获得 2 点水元素")
			
		"伐断":
			# 施加流血效果（动作时扣血），持续2回合
			_apply_status_effect("bleed", 5, 2)
			
		"合金":
			# 主控获得“合金”，提供1点减伤，直到本次对局结束
			player_damage_reduction += 1
			print("  [合金反应] 玩家永久获得 1 点伤害减免 (当前总减免: ", player_damage_reduction, ")")
			
		"过载":
			# 随机激活一个当前未激活的副槽卡牌 (动态扫描 CardSlot 节点)
			var tree = Engine.get_main_loop() as SceneTree
			if tree and tree.current_scene:
				var all_slots = []
				_find_card_slots_recursive(tree.current_scene, all_slots)
				var inactive_slots = []
				for slot in all_slots:
					if slot.current_state == CardSlot.SlotState.INACTIVE and slot.card_data != null and slot.is_sub_slot:
						inactive_slots.append(slot)
				if not inactive_slots.is_empty():
					var random_slot = inactive_slots[randi() % inactive_slots.size()]
					random_slot._activate_confirmed()
					print("  [过载反应] 随机激活了副槽卡牌: ", random_slot.card_data.card_name)
				else:
					print("  [过载反应] 未找到可激活的未激活副槽卡牌")
					
		"埋藏":
			# 下次在“车间”节点打造装备时，消耗减少2点金元素 (发送全局车间折扣信号)
			out_of_combat_reaction_triggered.emit("workshop_discount")
			print("  [埋藏反应] 触发全球车间折扣信号！")
			
		"阻截":
			# 禁锢目标，若其行动是攻击则推迟到下回合
			_apply_status_effect("stun_attack", 1, 1)
			
		"余烬":
			# 本回合每受到伤害一次，则返还主控1火元素
			_apply_status_effect("retaliate_generate_fire", 1, 1)
			
		"固本":
			# 恢复4点生命值
			GameManager.current_health = mini(GameManager.current_health + 4, GameManager.max_health)
			print("  [固本反应] 恢复 4 点生命值")
			
		_:
			printerr("  [未实现的元素反应]: ", reaction_name)
			
	return modifiers


# --- 战斗初始化 ---
func start_battle(enemy_res: EnemyData) -> void:
	current_enemy = enemy_res
	enemy_hp = enemy_res.max_hp
	enemy_shield = 0
	enemy_turn_counter = 0
	enemy_atk_buff = 0
	enemy_statuses = {}
	player_statuses = {}
	player_shield = 0
	
	# 初始化元素层级状态
	enemy_element = enemy_res.initial_element_attachment
	enemy_element_layers = enemy_res.initial_element_layers
	
	# 重置反应累计增益
	player_damage_reduction = 0
	reactivate_current_card = false
	
	has_activated_card_this_turn = false
	activated_card_prev_turn = false
	enemy_intent_override = ""
	
	print("战斗初始化成功！敌人: ", enemy_res.enemy_name, " HP: ", enemy_hp, " (初始附着: ", enemy_element, " 层数: ", enemy_element_layers, ")")
	stats_updated.emit(int(GameManager.current_health), int(player_shield), int(enemy_hp), int(enemy_shield))
	status_updated.emit("enemy", enemy_statuses)
	status_updated.emit("player", player_statuses)


# --- 结束回合 ---
func end_turn() -> void:
	print("--- 开始结算回合终止逻辑 ---")
	if not has_activated_card_this_turn:
		print("本回合未激活任何卡牌，触发【引气入体】！全基础元素 +5")
		GameManager.element_metal += 5
		GameManager.element_wood += 5
		GameManager.element_water += 5
		GameManager.element_fire += 5
		GameManager.element_earth += 5
		GameManager.update_player_stats() # 通知UI更新资源
	
	# 保存回合激活状态供下一回合 Condition Damage 判断，然后重置
	activated_card_prev_turn = has_activated_card_this_turn
	has_activated_card_this_turn = false
	
	# 1. 玩家护盾重置为 0
	player_shield = 0
	
	# 2. 结算敌人 DOT
	if enemy_hp > 0:
		if enemy_statuses.has("burn"):
			var burn_data = enemy_statuses["burn"]
			var burn_dmg = burn_data.get("amount", 4)
			enemy_hp = max(0, enemy_hp - burn_dmg)
			print("敌人受到 [burn] 伤害: ", burn_dmg, ", 剩余生命: ", enemy_hp)
		if enemy_statuses.has("bleed"):
			var bleed_data = enemy_statuses["bleed"]
			var bleed_dmg = bleed_data.get("amount", 5)
			enemy_hp = max(0, enemy_hp - bleed_dmg)
			print("敌人受到 [bleed] 伤害: ", bleed_dmg, ", 剩余生命: ", enemy_hp)
			
	# 检查结算敌人 DOT 后敌人是否死亡
	if enemy_hp <= 0:
		print("敌人被 DOT 击杀，战斗胜利！")
		stats_updated.emit(int(GameManager.current_health), int(player_shield), int(enemy_hp), int(enemy_shield))
		battle_ended.emit(true)
		return

	# 2.5. 结算玩家 DOT
	if GameManager.current_health > 0:
		if player_statuses.has("burn"):
			var burn_data = player_statuses["burn"]
			var burn_dmg = burn_data.get("amount", 4)
			GameManager.current_health = max(0, GameManager.current_health - burn_dmg)
			print("玩家受到 [burn] 伤害: ", burn_dmg, ", 剩余生命: ", GameManager.current_health)
		if player_statuses.has("bleed"):
			var bleed_data = player_statuses["bleed"]
			var bleed_dmg = bleed_data.get("amount", 5)
			GameManager.current_health = max(0, GameManager.current_health - bleed_dmg)
			print("玩家受到 [bleed] 伤害: ", bleed_dmg, ", 剩余生命: ", GameManager.current_health)

	# 检查结算玩家 DOT 后玩家是否死亡
	if GameManager.current_health <= 0:
		print("玩家被 DOT 击杀，战斗失败！")
		stats_updated.emit(int(GameManager.current_health), int(player_shield), int(enemy_hp), int(enemy_shield))
		battle_ended.emit(false)
		return
		
	# 3. 敌人行动
	_execute_enemy_intent()
	
	# 检查敌人行动后玩家是否死亡
	if GameManager.current_health <= 0:
		print("玩家生命归零，战斗失败！")
		stats_updated.emit(int(GameManager.current_health), int(player_shield), int(enemy_hp), int(enemy_shield))
		battle_ended.emit(false)
		return
		
	# 4. 回合计数前进
	enemy_turn_counter += 1
	
	# 5. 状态衰减
	_decay_statuses(enemy_statuses, "enemy")
	_decay_statuses(player_statuses, "player")
	
	# 6. 发送状态更新信号
	stats_updated.emit(int(GameManager.current_health), int(player_shield), int(enemy_hp), int(enemy_shield))


# --- 敌人行动意图执行 ---
func _execute_enemy_intent() -> void:
	if not current_enemy:
		return
		
	var turn_intent = ""
	if enemy_intent_override != "":
		turn_intent = enemy_intent_override
		enemy_intent_override = "" # Reset override
		print("敌人行动受到特殊效果干扰，意图被覆盖为: [", turn_intent, "]")
	else:
		var turn = enemy_turn_counter % 3
		match turn:
			0: turn_intent = "attack"
			1: turn_intent = "defend"
			2: turn_intent = "buff"

	match turn_intent:
		"attack":
			if enemy_statuses.has("stun_attack"):
				print("敌人处于 stun_attack 状态，跳过攻击意图！")
				return
				
			var dmg = current_enemy.intent_base_dmg + enemy_atk_buff
			if enemy_statuses.has("weak"):
				dmg = int(dmg * 0.75)
				
			print("敌人发动攻击！造成伤害: ", dmg)
			_damage_player(dmg)

			# --- 处理玩家的反震 (Reflect) ---
			if player_statuses.has("reflect") or player_statuses.has("反震"):
				var reflect_data = player_statuses.get("reflect", player_statuses.get("反震"))
				var reflect_dmg = reflect_data.get("amount", 0)
				if reflect_dmg > 0:
					print("玩家 [反震] 触发！对敌人造成反震伤害: ", reflect_dmg)
					take_damage(reflect_dmg, "以太")
				
		"defend":
			var shield_gain = 15
			if enemy_statuses.has("slow"):
				shield_gain = int(shield_gain * 0.5)
				
			enemy_shield += shield_gain
			print("敌人进行防御，获得护盾: ", shield_gain, ", 当前总护盾: ", enemy_shield)
			
		"buff":
			enemy_atk_buff += 3
			print("敌人获得攻击力加成！atk_buff: +3, 当前总加成: ", enemy_atk_buff)


# --- 目标/受击 API 实现 (BattleManager 扮演敌人角色) ---
func take_damage(amount: int, element: String = "") -> void:
	var actual_dmg = amount
	if enemy_statuses.has("frail"):
		actual_dmg = int(actual_dmg * 1.5)
		
	if enemy_shield >= actual_dmg:
		enemy_shield -= actual_dmg
	else:
		actual_dmg -= enemy_shield
		enemy_shield = 0
		enemy_hp = max(0, enemy_hp - actual_dmg)
		
	print("敌人受到伤害: ", amount, " (元素: ", element, "), 实际扣除生命: ", actual_dmg, ", 剩余生命: ", enemy_hp, ", 剩余护盾: ", enemy_shield)
	stats_updated.emit(int(GameManager.current_health), int(player_shield), int(enemy_hp), int(enemy_shield))
	
	if enemy_hp <= 0:
		print("敌人生命值归零，战斗胜利！")
		battle_ended.emit(true)

func get_status() -> String:
	return enemy_element

func set_status(element: String) -> void:
	enemy_element = element
	if enemy_element != "":
		enemy_element_layers = max(1, enemy_element_layers)
	else:
		enemy_element_layers = 0
	print("敌人附着元素更新为: ", enemy_element, " (", enemy_element_layers, " 层)")

func break_shield() -> void:
	enemy_shield = 0
	print("敌人的护盾已被强行破除！")
	stats_updated.emit(int(GameManager.current_health), int(player_shield), int(enemy_hp), int(enemy_shield))


# --- 内部状态衰减工具 ---
func _decay_statuses(statuses_dict: Dictionary, target_name: String) -> void:
	var keys_to_remove = []
	for key in statuses_dict.keys():
		var data = statuses_dict[key]
		if data is Dictionary and data.has("duration"):
			data["duration"] -= 1
			if data["duration"] <= 0:
				keys_to_remove.append(key)
		else:
			keys_to_remove.append(key)
			
	for key in keys_to_remove:
		statuses_dict.erase(key)
		
	status_updated.emit(target_name, statuses_dict)


# --- 内部工具 ---
# 在访问任何属性之前调用此函数，防止 "Invalid get index on Nil" 错误。
func _is_valid_card(card: CardData, slot_label: String) -> bool:
	if card == null:
		printerr("BattleManager: ", slot_label, " 卡牌资源为 null。",
				" 请检查 GameManager.active_deck_layout 中的 'main'/'subs' 是否正确赋值。")
		return false
	# 额外验证：资源是否完整（id 不为空）
	if card.id.is_empty():
		printerr("BattleManager: ", slot_label, " 卡牌资源 id 为空，",
				"可能是 .tres 文件未正确设置 id 字段。")
		return false
	return true
