class_name ShieldEffect
extends EffectBase

@export var value: int = 0

func _init():
	phase = Phase.AGGREGATION

func execute(context: Dictionary) -> Dictionary:
	var resolver: DamageResolver = context.get("damage_resolver")
	if resolver:
		resolver.add_shield(value)
	return {}

func get_display_value() -> int:
	return value
