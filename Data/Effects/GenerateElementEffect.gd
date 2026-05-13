class_name GenerateElementEffect
extends EffectBase

@export var element_type: String = "none"
@export var amount: int = 0

func _init():
	phase = Phase.POST_HIT

func execute(_context: Dictionary) -> Dictionary:
	if element_type == "none":
		return {}

	match element_type:
		"金": GameManager.element_metal += amount
		"木": GameManager.element_wood += amount
		"水": GameManager.element_water += amount
		"火": GameManager.element_fire += amount
		"土": GameManager.element_earth += amount
		"以太": GameManager.aether += amount
		_: printerr("  GenerateElementEffect: 未知 element_type: ", element_type)

	print("  [元素产出] 获得 ", element_type, " +", amount)
	return {}

func get_display_value() -> int:
	return amount
