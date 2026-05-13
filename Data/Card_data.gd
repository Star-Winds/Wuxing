extends Resource
class_name CardData

# 基础信息
@export_group("基础信息")
@export var id: String = ""
@export var card_name: String = ""
@export var icon: Texture2D
@export_enum("金", "木", "水", "火", "土", "以太") var element: String = "火"
@export var element_attachment_layers: int = 1
@export_multiline var description: String = ""

# 消耗系统：使用明确的变量而非 Dictionary，方便在编辑器中直接输入数值
@export_group("消耗 (Cost)")
@export var cost_metal: int = 0
@export var cost_wood: int = 0
@export var cost_water: int = 0
@export var cost_fire: int = 0
@export var cost_earth: int = 0
@export var cost_aether: int = 0

# ── 词条系统（Phase 3） ──
# 优先使用 keywords 数组；fallback 到 main_effect/sub_effect
@export_group("词条系统 (Keyword System)")
@export var main_keywords: Array[KeywordData] = []
@export var sub_keywords: Array[KeywordData] = []

# ── Effect 系统（Phase 2，向后兼容） ──
@export_group("效果系统 (Effect System, 旧)")
@export var main_effect: EffectBase
@export var sub_effect: EffectBase

# ── 旧字段（遗留，仅用于运行时兼容，新卡请勿使用） ──
var main_type: String = "damage"
var main_value: int = 0
var main_description: String = ""

var sub_type: String = "damage"
var sub_value: int = 0
var sub_element_type: String = "none"
var sub_description: String = ""

var status_id: String = ""
var status_amount: int = 0
var status_duration: int = 0
@export var is_exhaust: bool = false
@export var single_use: bool = false

# 辅助函数：方便 BattleManager 获取总消耗
func get_total_cost() -> Dictionary:
	var total = {}
	if cost_metal > 0: total["金"] = cost_metal
	if cost_wood > 0: total["木"] = cost_wood
	if cost_water > 0: total["水"] = cost_water
	if cost_fire > 0: total["火"] = cost_fire
	if cost_earth > 0: total["土"] = cost_earth
	if cost_aether > 0: total["以太"] = cost_aether
	return total

# ── 词条系统辅助方法 ──

# 返回主槽效果列表（优先词条->旧Effect->空）
func get_main_effects() -> Array:
	if not main_keywords.is_empty():
		var effects: Array = []
		for kw in main_keywords:
			if kw and kw.effect:
				effects.append(kw.effect)
		return effects
	if main_effect:
		return [main_effect]
	return []

# 返回副槽效果列表（优先词条->旧Effect->空）
func get_sub_effects() -> Array:
	if not sub_keywords.is_empty():
		var effects: Array = []
		for kw in sub_keywords:
			if kw and kw.effect:
				effects.append(kw.effect)
		return effects
	if sub_effect:
		return [sub_effect]
	return []

# 自动生成卡牌描述（组合词条显示名）
func get_auto_description(is_sub: bool = false) -> String:
	var kws = sub_keywords if is_sub else main_keywords
	var parts: Array[String] = []
	for kw in kws:
		if kw and not kw.description.is_empty():
			parts.append(kw.description)
	if parts.is_empty():
		var fallback = sub_description if is_sub else main_description
		return fallback if not fallback.is_empty() else ""
	return "\n".join(parts)

# Effect 系统辅助方法
func get_main_display_value() -> int:
	if main_effect:
		return main_effect.get_display_value()
	return main_value

func get_sub_display_value() -> int:
	if sub_effect:
		return sub_effect.get_display_value()
	return sub_value