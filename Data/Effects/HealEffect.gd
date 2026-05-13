class_name HealEffect
extends EffectBase

@export var value: int = 0

func _init():
	phase = Phase.POST_HIT

func execute(_context: Dictionary) -> Dictionary:
	GameManager.current_health = mini(
		GameManager.current_health + value,
		GameManager.max_health
	)
	print("  [治疗效果] 玩家恢复 ", value, " 点生命值")
	return {}

func get_display_value() -> int:
	return value
