class_name StatusEffect
extends EffectBase

@export var status_id: String = ""
@export var amount: int = 0
@export var duration: int = 0
@export var apply_to_player: bool = false

func _init():
	phase = Phase.POST_HIT

func execute(context: Dictionary) -> Dictionary:
	if status_id == "":
		return {}

	var sm: StatusManager = context.get("status_manager")
	if not sm:
		return {}

	var target = "player" if apply_to_player else "enemy"
	sm.apply(status_id, amount, duration, target)
	if GameManager and GameManager.action_queue:
		GameManager.action_queue.enqueue(ActionQueue.ActionType.STATUS_APPLY, {"target": target, "statuses": sm.get_all(target)})
	return {}

func get_display_value() -> int:
	return amount
