extends Resource
class_name EnemyData

# 基础信息
@export_group("基础信息")
@export var id: String = ""
@export var enemy_name: String = ""
@export_enum("金", "木", "水", "火", "土", "以太") var element: String = "金"
@export var max_hp: int = 10
@export var intent_base_dmg: int = 0


# 初始携带元素（支持多元素敌人）
@export_group("初始元素")
@export var initial_elements: Array[String] = []


# 意图元素序列（按回合轮换属性攻击）
@export_group("意图元素")
@export var intent_elements: Array[String] = []


# 敌人词条
@export_group("敌人词条")
@export var enemy_keywords: Array[KeywordSlot] = []


var compiled_keywords: Array[KeywordData] = []


func compile_keywords() -> void:
	compiled_keywords.clear()
	for slot in enemy_keywords:
		if slot and slot.type != KeywordSlot.SlotType.无:
			var kw = slot.compile()
			if kw:
				compiled_keywords.append(kw)
