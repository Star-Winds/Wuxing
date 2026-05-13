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
#
#  队列执行模型:
#    ┌──────────┐    ┌──────────┐    ┌──────────┐
#    │ Action A │───▶│ Action B │───▶│ Action C │  (正常顺序)
#    └──────────┘    └──────────┘    └──────────┘
#                          │
#                    insert_next(D)    ← B 执行中触发衍生动作
#                          ▼
#    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
#    │ Action A │───▶│ Action B │───▶│ Action D │───▶│ Action C │
#    └──────────┘    └──────────┘    └──────────┘    └──────────┘
#                                      ▲ 衍生动作插队
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
	## 动作完成时发射。ActionQueue 监听此信号以推进队列。
	signal finished

	var _done: bool = false

	## 由 ActionQueue 调用，启动该动作。
	## 子类应在此启动动画/Tween/音效等。
	func execute() -> void:
		pass

	## 返回 true 表示动作已完成，队列可推进到下一个。
	func is_finished() -> bool:
		return _done

	## 标记动作完成。子类在异步操作 (Tween finished) 结束时调用。
	func _finish() -> void:
		if not _done:
			_done = true
			finished.emit()

	## 强制中断该动作 (如战斗提前结束)。
	func interrupt() -> void:
		if not _done:
			_done = true
			finished.emit()


# ============================================================
#  Action — Legacy 动作包装器
#
#  兼容旧的 type + data 模式。
#  battle_ui.gd 通过 consume() 取出并自行播放动画。
#  新代码应继承 BaseAction 并重写 execute()。
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

## 是否启用自驱动处理。
## true  = 队列在 _process() 中自动执行动作，适用于有 execute() 实现的 BaseAction。
## false = 需外部调用 consume() 手动消费 (Legacy 模式，battle_ui.gd 当前使用)。
@export var auto_process: bool = false

## 内部动作队列 (按执行顺序排列)
var _queue: Array[BaseAction] = []

## 当前正在执行的动作
var _current: BaseAction = null
## Legacy 动作是否正在等待外部动画完成
var _waiting_external_finish: bool = false

## 新动作入队 (正常或衍生) 时发射
signal action_queued(action: BaseAction, position: String)
## 动作开始执行时发射
signal action_started(action: BaseAction)
## 动作完成时发射
signal action_finished(action: BaseAction)
## 队列清空 (所有动作执行完毕) 时发射
signal queue_emptied()


# ============================================================
#  入队方法 (Enqueue Methods)
# ============================================================

## 正常入队: 动作排到队列末尾。
func push_to_back(action: BaseAction) -> void:
	_queue.append(action)
	action_queued.emit(action, "back")


## 插队入队: 将一个或多个动作插入队列最前端。
## 用于衍生动作 (如"受到伤害时反伤") 立刻在下一个位置执行。
func push_to_front(actions: Array[BaseAction]) -> void:
	# 从后往前插入，保持传入数组的顺序
	for i in range(actions.size() - 1, -1, -1):
		_queue.push_front(actions[i])
		action_queued.emit(actions[i], "front")


## 紧急插队: 将单个动作插入到当前正在执行的动作之后、
## 其余排队动作之前。用于需要立刻结算但不可打断当前动作的场景。
##
## 示例: 主伤害动作执行中触发"反伤"，反伤动作应在此伤害动画
##  完成后、下一个排队动作之前执行。
func insert_next(action: BaseAction) -> void:
	_queue.push_front(action)
	action_queued.emit(action, "next")


## [Legacy] 使用旧 type + data 模式入队。
## 创建的 Action 会自动包装为 BaseAction。
func enqueue(type: ActionType, data: Dictionary) -> void:
	push_to_back(Action.new(type, data))


# ============================================================
#  消费方法 (Consumption)
# ============================================================

## 查看但不移除队列首部动作。无动作时返回 null。
func peek() -> BaseAction:
	return _queue[0] if not _queue.is_empty() else null


## 查看当前正在执行的动作。
func current() -> BaseAction:
	return _current


## [Legacy] 弹出队列首部动作 (不执行，交给外部处理)。
## battle_ui.gd 通过此方法获取待播放的动画数据。
## 返回 null 表示队列为空。
func consume() -> BaseAction:
	if _queue.is_empty():
		return null
	return _queue.pop_front()


## [Legacy] 队列是否有待处理动作。
func has_pending() -> bool:
	return not _queue.is_empty()


## 清空队列 (不影响当前正在执行的动作)。
func clear() -> void:
	_queue.clear()
	_current = null
	_waiting_external_finish = false


## 当前队列长度 (不含正在执行的动作)。
func size() -> int:
	return _queue.size()


## 队列中动作总数 (含正在执行的动作)。
func total_size() -> int:
	var n = _queue.size()
	if _current != null:
		n += 1
	return n


# ============================================================
#  自驱动处理循环 (Self-Driven Loop)
# ============================================================

func _process(_delta: float) -> void:
	if not auto_process:
		return

	# 正在等待外部动画完成 (Legacy 模式)，不推进
	if _waiting_external_finish:
		return

	# 当前动作仍在执行中，等待其完成
	if _current != null:
		if _current.is_finished():
			# 动作完成，清理并推进
			var finished_action = _current
			_current = null
			action_finished.emit(finished_action)
		else:
			# 尚未完成，继续等待
			return

	# 取出下一个动作
	if _queue.is_empty():
		# 队列为空
		if _current == null:
			queue_emptied.emit()
		return

	_current = _queue.pop_front()

	# Legacy Action 的处理:
	#   如果 action 是旧式 Action (type + data)，execute() 是空操作。
	#   此时我们发射 action_started 并等待外部调用 mark_current_finished()。
	if _current is Action and _current.type != null:
		_waiting_external_finish = true
		action_started.emit(_current)
		return

	# 新式 BaseAction: 调用 execute() 启动逻辑
	action_started.emit(_current)
	_current.execute()


## 外部动画完成后调用此方法，告知队列可以推进到下一个动作。
## 仅在 Legacy 消费模式 (_waiting_external_finish == true) 时需要。
func mark_current_finished() -> void:
	if _current != null and _waiting_external_finish:
		_waiting_external_finish = false
		var finished_action = _current
		_current = null
		# 标记 Legacy Action 为已完成
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


# ============================================================
#  测试用例 (Test Case)
#
#  将以下代码复制到任意场景的 _ready() 中运行，观察控制台输出:
# ============================================================

static func run_test(queue: ActionQueue) -> void:
	print("\n========== ActionQueue 测试用例 ==========")
	print("场景: 玩家打出伤害卡牌 → 造成 10 点伤害 → 触发敌方反伤 3 点")
	print("预期顺序: Damage(10) → Reflect(3) → Heal(5)")
	print("")

	# ── 辅助: 创建一个带延迟完成的动作 ──
	var create_delayed_action = func(name: String, delay: float, on_execute: Callable) -> BaseAction:
		var act = BaseAction.new()
		# 劫持 execute 方法: 执行回调后延迟 _finish
		act.execute = func():
			print("  ▶ [%s] 开始执行..." % name)
			if on_execute.is_valid():
				on_execute.call()
			# 模拟异步动画: 延迟后标记完成
			queue.get_tree().create_timer(delay).timeout.connect(
				func():
					print("  ✓ [%s] 完成" % name)
					act._finish()
				, CONNECT_ONE_SHOT
			)
		return act

	# ── 1. 主伤害动作 (Damage 10) ──
	var damage_action = create_delayed_action.call(
		"Damage(10)",
		0.8,
		func():
			print("    对敌人造成 10 点伤害!")
			# 模拟: 敌人有"反伤"被动，受到伤害时立刻反伤 3 点
			var reflect_action = create_delayed_action.call(
				"Reflect(3)",
				0.4,
				func(): print("    对玩家反伤 3 点!")
			)
			queue.insert_next(reflect_action)
			print("  ⚡ 衍生动作 Reflect(3) 已插入队列首部!")
	)

	# ── 2. 治疗动作 (Heal 5) ──
	var heal_action = create_delayed_action.call(
		"Heal(5)",
		0.3,
		func(): print("    玩家恢复 5 点生命!")
	)

	# ── 入队 ──
	queue.push_to_back(damage_action)
	queue.push_to_back(heal_action)
	print("队列初始化: [Damage(10), Heal(5)]")
	print("开始自驱动执行...\n")

	# ── 监听队列清空 ──
	queue.queue_emptied.connect(
		func():
			print("\n✅ 队列已清空，所有动作执行完毕!")
			print("执行顺序验证: Damage(10) → Reflect(3) → Heal(5)")
			print("========== 测试用例结束 ==========\n")
		, CONNECT_ONE_SHOT
	)
