class_name EffectBase
extends Resource

enum Phase { PRE_HIT, AGGREGATION, POST_HIT }

@export var phase: Phase = Phase.AGGREGATION

func execute(_context: Dictionary) -> Dictionary:
	return {}

func get_display_value() -> int:
	return 0
