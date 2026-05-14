class_name ActionQueue
extends Node

# ============================================================
#  动作队列系统 (Action Queue System)
#
#  核心设计:
#    - BaseAction: 抽象动作基类，携带 execute()/is_finished() 接口
#    - 自驱动循环: _process() 按序弹出动作执行，等待完成后前进
#    - 衍生动作: push_to_front() / insert_next() 支持反应/反伤等
#      被动效果立刻插入队列首部，在下一个排队的动作之前执行
# ============================================================


# ============================================================
#  Legacy 枚举 (向后兼容)
# ============================================================
enum ActionType {
	DAMAGE,        # 伤害数字浮动
	HEAL,          # 治疗数字浮动
	SHIELD_GAIN,   # 获得护盾
	SHIELD_BREAK,  # 护盾破碎
	HP_CHANGE,     # HP 数值更新 (直接设置文本)
	REACTION,      # 元素反应飘字
	STATUS_APPLY,  # 状态图标变更
}


# ============================================================
#  BaseAction — 抽象动作基类
#
#  所有动作 (伤害、治疗、反应、状态等) 均继承此类。
#  子类重写 execute() 启动动作逻辑，
#  通过 _finish() 标记完成并发射 finished 信号。
# ============================================================
class BaseAction extends RefCounted:
	var _on_finished: Callable
	var _done: bool = false

	func execute() -> void:
		pass

	func is_finished() -> bool:
		return _done

	func _finish() -> void:
		if not _done:
			_done = true
			_on_finished.call()

	func interrupt() -> void:
		if not _done:
			_done = true
			_on_finished.call()


# ============================================================
#  Action — Legacy 动作包装器
# ============================================================
class Action extends BaseAction:
	var type: ActionType
	var data: Dictionary = {}

	func _init(t: ActionType = ActionType.DAMAGE, d: Dictionary = {}) -> void:
		type = t
		data = d


# ============================================================
#  ActionQueue 主体
# ============================================================

@export var auto_process: bool = false

var _queue: Array[BaseAction] = []
var _current: BaseAction = null
var _waiting_external_finish: bool = false

signal action_queued(action: BaseAction, position: String)
signal action_started(action: BaseAction)
signal action_finished(action: BaseAction)
signal queue_emptied()


# ============================================================
#  入队方法
# ============================================================

func push_to_back(action: BaseAction) -> void:
	_queue.append(action)
	action_queued.emit(action, "back")


func push_to_front(actions: Array[BaseAction]) -> void:
	for i in range(actions.size() - 1, -1, -1):
		_queue.push_front(actions[i])
		action_queued.emit(actions[i], "front")


func insert_next(action: BaseAction) -> void:
	_queue.push_front(action)
	action_queued.emit(action, "next")


func enqueue(type: ActionType, data: Dictionary) -> void:
	push_to_back(Action.new(type, data))


# ============================================================
#  消费方法
# ============================================================

func peek() -> BaseAction:
	return _queue[0] if not _queue.is_empty() else null

func current() -> BaseAction:
	return _current

func consume() -> BaseAction:
	if _queue.is_empty():
		return null
	return _queue.pop_front()

func has_pending() -> bool:
	return not _queue.is_empty()

func clear() -> void:
	_queue.clear()
	_current = null
	_waiting_external_finish = false

func size() -> int:
	return _queue.size()

func total_size() -> int:
	var n = _queue.size()
	if _current != null:
		n += 1
	return n


# ============================================================
#  自驱动处理循环
# ============================================================

func _process(_delta: float) -> void:
	if not auto_process:
		return

	if _waiting_external_finish:
		return

	if _current != null:
		if _current.is_finished():
			var finished_action = _current
			_current = null
			action_finished.emit(finished_action)
		else:
			return

	if _queue.is_empty():
		if _current == null:
			queue_emptied.emit()
		return

	_current = _queue.pop_front()

	if _current is Action and _current.type != null:
		_waiting_external_finish = true
		action_started.emit(_current)
		return

	action_started.emit(_current)
	_current.execute()


func mark_current_finished() -> void:
	if _current != null and _waiting_external_finish:
		_waiting_external_finish = false
		var finished_action = _current
		_current = null
		if not finished_action.is_finished():
			finished_action._finish()
		action_finished.emit(finished_action)


# ============================================================
#  调试
# ============================================================

func _to_string() -> String:
	var parts: Array[String] = []
	parts.append("ActionQueue(size=%d, current=%s)" % [
		_queue.size(),
		_current.get("type") if _current is Action and _current.type != null else str(_current)
	])
	for i in range(_queue.size()):
		var a = _queue[i]
		if a is Action:
			parts.append("  [%d] Legacy(%d, %s)" % [i, a.type, a.data])
		else:
			parts.append("  [%d] %s" % [i, a])
	return "\n".join(parts)
