class_name ActionQueue
extends Node

enum ActionType {
	DAMAGE,       # 伤害数字浮动
	HEAL,         # 治疗数字浮动
	SHIELD_GAIN,  # 获得护盾
	SHIELD_BREAK, # 护盾破碎
	HP_CHANGE,    # HP 数值更新（直接设置文本，不浮动）
	REACTION,     # 元素反应飘字
	STATUS_APPLY, # 状态图标变更
}

class Action:
	var type: ActionType
	var data: Dictionary

	func _init(t: ActionType, d: Dictionary):
		type = t
		data = d

var _queue: Array[Action] = []

func enqueue(type: ActionType, data: Dictionary) -> void:
	_queue.append(Action.new(type, data))

func consume() -> Action:
	if _queue.is_empty():
		return null
	return _queue.pop_front()

func has_pending() -> bool:
	return not _queue.is_empty()

func clear() -> void:
	_queue.clear()

func size() -> int:
	return _queue.size()
