extends Resource
class_name CardData

# ════════════════════════════════════════════════════════════════
#  卡牌类型词条 — 定义卡牌的"是什么"
# ════════════════════════════════════════════════════════════════

@export_group("卡牌类型")

# 元素属性
@export_enum("金", "木", "水", "火", "土", "以太") var element: String = "火"
@export var element_attachment_layers: int = 1

# 稀有度：凡(常见)、稀(少见)、珍(最少见)
@export_enum("凡", "稀", "珍") var rarity: String = "凡"

# 类型标签
@export var is_formation: bool = false    # 五行阵法
@export var is_reaction: bool = false     # 元素反应
@export var is_carry: bool = false        # 携带：在 deck 中即生效
@export var is_embed: bool = false        # 嵌入：在副槽即生效
@export var is_initiate: bool = false     # 初动：在主槽即生效

# 卡牌生命周期
@export var is_exhaust: bool = false      # 消耗：打出后从牌组移除
@export var single_use: bool = false      # 一次性：本场战斗仅可使用一次

# 基础信息
@export_group("基础信息")
@export var id: String = ""
@export var card_name: String = ""
@export var icon: Texture2D
@export_multiline var description: String = ""

# ════════════════════════════════════════════════════════════════
#  消耗系统
# ════════════════════════════════════════════════════════════════

@export_group("消耗")
@export var cost_metal: int = 0
@export var cost_wood: int = 0
@export var cost_water: int = 0
@export var cost_fire: int = 0
@export var cost_earth: int = 0
@export var cost_aether: int = 0

# ════════════════════════════════════════════════════════════════
#  词条槽位 — 在 Inspector 中编辑，运行时编译为 KeywordData
# ════════════════════════════════════════════════════════════════

@export_group("词条槽位")
@export var main_slots: Array[KeywordSlot] = []
@export var sub_slots: Array[KeywordSlot] = []
@export var mechanic_slots: Array[KeywordSlot] = []

# ════════════════════════════════════════════════════════════════
#  编译后的运行态词条（不导出，由 compile_slots() 生成）
# ════════════════════════════════════════════════════════════════

var main_keywords: Array[KeywordData] = []
var sub_keywords: Array[KeywordData] = []
var mechanic_keywords: Array[KeywordData] = []
var _needs_compile: bool = true


# ════════════════════════════════════════════════════════════════
#  编译系统
# ════════════════════════════════════════════════════════════════

## 将 main_slots/sub_slots/mechanic_slots 编译为 KeywordData 数组
func compile_slots() -> void:
	main_keywords = _compile_list(main_slots)
	sub_keywords = _compile_list(sub_slots)
	mechanic_keywords = _compile_list(mechanic_slots)
	_needs_compile = false

static func _compile_list(slots: Array[KeywordSlot]) -> Array[KeywordData]:
	var result: Array[KeywordData] = []
	for slot in slots:
		if slot and slot.type != KeywordSlot.SlotType.无:
			var kw = slot.compile()
			if kw:
				result.append(kw)
	return result

func _ensure_compiled() -> void:
	if _needs_compile:
		compile_slots()


# ════════════════════════════════════════════════════════════════
#  辅助方法（自动编译后访问）
# ════════════════════════════════════════════════════════════════

func get_total_cost() -> Dictionary:
	var total = {}
	if cost_metal > 0: total["金"] = cost_metal
	if cost_wood > 0: total["木"] = cost_wood
	if cost_water > 0: total["水"] = cost_water
	if cost_fire > 0: total["火"] = cost_fire
	if cost_earth > 0: total["土"] = cost_earth
	if cost_aether > 0: total["以太"] = cost_aether
	return total

## 返回主槽行动效果列表
func get_main_effects() -> Array:
	_ensure_compiled()
	var effects: Array = []
	for kw in main_keywords:
		if kw and kw.effect:
			effects.append(kw.effect)
	return effects

## 返回副槽行动效果列表
func get_sub_effects() -> Array:
	_ensure_compiled()
	var effects: Array = []
	for kw in sub_keywords:
		if kw and kw.effect:
			effects.append(kw.effect)
	return effects

## 返回所有词条（供遍历用）
func get_all_keywords() -> Array[KeywordData]:
	_ensure_compiled()
	return main_keywords + sub_keywords + mechanic_keywords

## 获取指定分类的词条列表
func get_keywords_by_category(cat: int) -> Array[KeywordData]:
	_ensure_compiled()
	var result: Array[KeywordData] = []
	for kw in main_keywords + sub_keywords + mechanic_keywords:
		if kw and kw.category == cat:
			result.append(kw)
	return result

## 检查是否携带指定机制词条
func has_mechanic(mechanic_id: String) -> bool:
	_ensure_compiled()
	for kw in mechanic_keywords:
		if kw and kw.keyword_id == mechanic_id:
			return true
	return false

## 自动生成卡牌描述
func get_auto_description(is_sub: bool = false) -> String:
	_ensure_compiled()
	var kws = sub_keywords if is_sub else main_keywords
	var parts: Array[String] = []
	for kw in kws:
		if kw and not kw.description.is_empty():
			parts.append(kw.description)
	for kw in mechanic_keywords:
		if kw and not kw.description.is_empty():
			parts.append(kw.description)
	return "\n".join(parts)

func get_main_display_value() -> int:
	_ensure_compiled()
	for kw in main_keywords:
		if kw and kw.effect:
			return kw.effect.get_display_value()
	return 0

func get_sub_display_value() -> int:
	_ensure_compiled()
	for kw in sub_keywords:
		if kw and kw.effect:
			return kw.effect.get_display_value()
	return 0
