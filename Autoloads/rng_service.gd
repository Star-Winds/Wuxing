extends Node
## 集中式 RNG 服务 — 所有游戏逻辑随机调用必须经此服务。
##
## 目的:
##   - 种子管理: 生成/设置/显示种子，支持 Run 复现与分享
##   - 状态持久: get_state()/set_state() 供存档系统保存 RNG 位置
##   - 确定性: 同种子 + 同操作序列 = 同结果
##
## 视觉随机 (伤害数字飘动位置等) 不经过此服务，继续使用内置 randf_range()。

var _rng: RandomNumberGenerator
var _seed_string: String = ""


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	generate_seed()


## 用当前系统时间生成一个新种子。仅在首次启动时调用。
func generate_seed() -> String:
	_seed_string = str(Time.get_unix_time_from_system())
	_rng.seed = hash(_seed_string)
	print("[RNGService] 种子已生成: ", _seed_string)
	return _seed_string


## 手动设置种子 (用于输入种子重玩)。
func set_seed(seed_str: String) -> void:
	_seed_string = seed_str
	_rng.seed = hash(seed_str)
	print("[RNGService] 种子已设置: ", _seed_string)


func get_seed_string() -> String:
	return _seed_string


# -- 游戏逻辑随机方法 (禁止直接使用全局 randi/randf) --

func randi() -> int:
	return _rng.randi()


func randf() -> float:
	return _rng.randf()


func randi_range(from_val: int, to_val: int) -> int:
	return _rng.randi_range(from_val, to_val)


func randf_range(from_val: float, to_val: float) -> float:
	return _rng.randf_range(from_val, to_val)


## Fisher-Yates 洗牌。Godot 4.x 的 RandomNumberGenerator 没有原生 shuffle()。
func shuffle(arr: Array) -> void:
	var n = arr.size()
	for i in range(n - 1, 0, -1):
		var j = _rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# -- 存档钩子 --

## 返回 RNG 内部状态 (整数)，供存档保存。
func get_state() -> int:
	return _rng.get_state()


## 从存档恢复 RNG 内部状态。
func set_state(state: int) -> void:
	_rng.set_state(state)
