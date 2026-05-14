class_name EquipmentData
extends Resource

@export var equipment_id: String = ""
@export var equipment_name: String = ""
@export_multiline var description: String = ""
@export var effects: Array[EquipmentEffect] = []
@export var icon: Texture2D

# Workshop crafting cost
@export var required_card_id: String = ""
@export var cost_metal: int = 0
@export var cost_wood: int = 0
