class_name DamageEffect
extends EffectBase

@export var value: int = 0

func _init():
	phase = Phase.AGGREGATION

func execute(context: Dictionary) -> Dictionary:
	var resolver: DamageResolver = context.get("damage_resolver")
	if resolver:
		resolver.add_damage(value)
	return {}

func get_display_value() -> int:
	return value
