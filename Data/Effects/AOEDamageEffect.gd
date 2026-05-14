class_name AOEDamageEffect
extends EffectBase

@export var damage: int = 0

func _init():
	phase = Phase.AGGREGATION

func execute(context: Dictionary) -> Dictionary:
	var resolver: DamageResolver = context.get("damage_resolver")
	if resolver:
		resolver.add_damage(damage)
	return {}

func get_display_value() -> int:
	return damage
