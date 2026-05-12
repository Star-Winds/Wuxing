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

# 主槽逻辑：使用枚举代替 String 减少拼写错误
@export_group("主槽效果 (Main Slot)")
@export_enum("damage", "shield", "damage_and_shield", "heal", "utility", "status_apply", "special_action", "condition_damage") var main_type: String = "damage"
@export var main_value: int = 0
@export_multiline var main_description: String = ""

# 副槽逻辑
@export_group("副槽效果 (Sub Slot)")
@export_enum("damage", "shield", "generate_element", "buff", "debuff", "status_apply", "special_action", "condition_damage") var sub_type: String = "damage"
@export var sub_value: int = 0
@export_enum("金", "木", "水", "火", "土", "以太", "none") var sub_element_type: String = "none" # 专门用于产出元素的类型
@export_multiline var sub_description: String = ""

# 状态与特殊属性
@export_group("状态/特殊效果 (Status & Special)")
@export var status_id: String = ""
@export var status_amount: int = 0
@export var status_duration: int = 0
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