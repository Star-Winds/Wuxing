extends Resource
class_name EnemyData

# 基础信息
@export_group("基础信息")
@export var id: String = ""
@export var enemy_name: String = ""
@export_enum("金", "木", "水", "火", "土", "以太") var element: String = "金"
@export var max_hp: int = 10
@export var intent_base_dmg: int = 0
@export var initial_element_attachment: String = ""
@export var initial_element_layers: int = 0

