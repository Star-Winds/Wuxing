class_name ResonanceEffect
extends EffectBase

@export var trigger_condition: String = "any_card_activated"

func _init():
	phase = Phase.PRE_HIT

func execute(context: Dictionary) -> Dictionary:
	var bm: Node = context.get("battle_manager")
	if not bm:
		return {}
	print("  [共鸣] 检测条件: ", trigger_condition, " — 被动监听中")
	return {}

func get_display_value() -> int:
	return 0
