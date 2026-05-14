class_name MultiHitDamageEffect
extends EffectBase

@export var damage: int = 0
@export var hits: int = 1

func _init():
	phase = Phase.AGGREGATION

func execute(context: Dictionary) -> Dictionary:
	var resolver: DamageResolver = context.get("damage_resolver")
	if resolver:
		for i in range(hits):
			resolver.add_damage(damage)
	return {}

func get_display_value() -> int:
	return damage * hits
