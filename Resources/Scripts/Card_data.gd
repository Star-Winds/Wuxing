extends Resource
class_name CardData

@export var id: String
@export var card_name: String
@export_enum("金", "木", "水", "火", "土", "以太") var element: String = "火"
@export var cost: Dictionary = {} # 例如 {"火": 2}

@export_group("主槽效果")
@export var main_type: String
@export var main_value: int
@export var main_description: String

@export_group("副槽效果")
@export var sub_type: String
@export var sub_value: int
@export var sub_description: String