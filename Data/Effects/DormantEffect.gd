class_name DormantEffect
extends EffectBase

@export var delay_turns: int = 1

func _init():
	phase = Phase.PRE_HIT

func execute(context: Dictionary) -> Dictionary:
	var bm: Node = context.get("battle_manager")
	if not bm:
		return {}
	print("  [休眠] 延迟 ", delay_turns, " 回合后生效")
	return {}

func get_display_value() -> int:
	return delay_turns
