extends Node

# 引用 CardData 类，确保类型检查
const CARD_DATA_CONST = preload("res://Resources/Scripts/Card_data.gd")

# --- 信号（供 BattleUI 监听）---
signal stats_updated(p_hp: int, p_shield: int, e_hp: int, e_shield: int)
signal status_updated(target: String, status_dict: Dictionary)
signal reaction_triggered(reaction_name: String, reaction_color: Color)
signal battle_ended(is_victory: bool)

# --- 核心打牌逻辑 ---
# main_card : 主槽 CardData 资源（已通过 is_valid() 校验）
# sub_cards  : 副槽 CardData 资源数组
# target     : 技能目标节点（通常是敌人节点）
func play_card(main_card: CardData, sub_cards: Array, target: Node = null) -> void:
	# 1. 安全校验主槽
	if not _is_valid_card(main_card, "主槽"):
		return

	print("打出卡牌: ", main_card.card_name)

	# 2. 处理主槽效果（使用 main_type / main_value）
	_apply_card_effect(main_card, main_card.main_type, main_card.main_value, target, main_card.element)

	# 3. 处理副槽效果
	for sub_card in sub_cards:
		if sub_card is CardData:
			if not _is_valid_card(sub_card, "副槽"):
				continue
			_apply_card_effect(sub_card, sub_card.sub_type, sub_card.sub_value, target, sub_card.element)

	# 4. 五行反应判定（使用主槽元素）
	_check_elemental_reaction(main_card.element, target)

	# 5. 通知 GameManager 广播玩家状态（Autoload 直接访问，无需 @onready）
	GameManager.update_player_stats()


# --- 通用效果处理 ---
# effect_type 对应 CardData 中的 main_type / sub_type 枚举值（String）
func _apply_card_effect(
		card_res: CardData,
		effect_type: String,
		value: int,
		target: Node,
		element: String) -> void:

	match effect_type:
		"damage":
			if target and target.has_method("take_damage"):
				target.take_damage(value, element)
			else:
				printerr("_apply_card_effect: 目标无效或缺少 take_damage 方法。卡牌: ", card_res.card_name)

		"shield":
			GameManager.aether += value   # 示例：护盾加到 GameManager，按需修改

		"damage_and_shield":
			if target and target.has_method("take_damage"):
				target.take_damage(value, element)
			GameManager.aether += value   # 同时获得护盾（如有独立护盾变量请修改）

		"heal":
			GameManager.current_health = mini(
				GameManager.current_health + value,
				GameManager.max_health
			)

		"generate_element":
			# sub_element_type 决定产出哪种元素
			match card_res.sub_element_type:
				"金": GameManager.element_metal += value
				"木": GameManager.element_wood  += value
				"水": GameManager.element_water += value
				"火": GameManager.element_fire  += value
				"土": GameManager.element_earth += value
				"以太": GameManager.aether      += value
				_: printerr("generate_element: 未知的 sub_element_type: ", card_res.sub_element_type)

		"buff", "debuff", "utility", "buff_main", "buff_player", "buff_status", \
		"buff_global", "passive_global", "cost_reduction", "global_buff":
			# TODO: 按需实现增益/减益/特殊效果
			print("特殊效果占位: ", effect_type, " 值=", value, " 来自: ", card_res.card_name)

		_:
			printerr("_apply_card_effect: 未知的 effect_type '", effect_type,
					"'（卡牌: ", card_res.card_name, "）。请检查 Card_data.gd 枚举定义。")


# --- 五行反应判定 ---
func _check_elemental_reaction(current_element: String, target: Node) -> void:
	if not target:
		return
	if not target.has_method("get_status"):
		return

	var target_status: String = target.get_status()

	# 五行相生相克反应表（按需补全）
	var reaction_table: Dictionary = {
		"火_金": ["熔炼",  Color(1.0, 0.5, 0.0)],
		"水_木": ["润泽",  Color(0.2, 0.8, 1.0)],
		"木_土": ["培育",  Color(0.4, 0.9, 0.3)],
		"土_水": ["泥泞",  Color(0.6, 0.5, 0.2)],
		"金_木": ["砍伐",  Color(0.9, 0.9, 0.1)],
	}

	var key = current_element + "_" + target_status
	if reaction_table.has(key):
		var entry = reaction_table[key]
		_trigger_reaction(entry[0], entry[1], target)

	# 附着元素更新
	if target.has_method("set_status"):
		target.set_status(current_element)


func _trigger_reaction(reaction_name: String, reaction_color: Color, target: Node) -> void:
	print("触发反应: ", reaction_name)
	reaction_triggered.emit(reaction_name, reaction_color)

	match reaction_name:
		"熔炼":
			if target.has_method("break_shield"):
				target.break_shield()
		"润泽":
			GameManager.aether += 2
		# TODO: 添加其他反应效果


# --- 结束回合 ---
func end_turn() -> void:
	# TODO: 敌人行动、元素回复等逻辑
	print("回合结束")


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