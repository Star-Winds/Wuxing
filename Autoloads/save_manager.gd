extends Node
## 存档管理器 — 游戏状态的持久化与恢复。
##
## 存档时机: 每次 scene 切换前自动存档到 slot 0。
## 读档时机: 主菜单 "Continue" 按钮。
## 格式: JSON，路径 user://save_<slot>.json

const SAVE_DIR := "user://"
const SAVE_PREFIX := "save_"
const SAVE_EXTENSION := ".json"


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(_save_path(slot))


func delete_save(slot: int = 0) -> void:
	var path = _save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func save_game(slot: int = 0) -> void:
	var data := {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"seed": RNGService.get_seed_string(),
		"rng_state": RNGService.get_state(),
		"current_scene": "",
		"persistent": _serialize_persistent(),
		"battle": null,
	}

	# 记录当前场景路径
	var tree := get_tree()
	if tree and tree.current_scene:
		data["current_scene"] = tree.current_scene.scene_file_path

	# 如果正在战斗中，捕获战斗状态
	if data["current_scene"] == "res://UI/battle_ui.tscn":
		data["battle"] = _serialize_battle(tree.current_scene)

	_write_json(data, slot)
	print("[SaveManager] 存档成功 slot=%d scene=%s" % [slot, data["current_scene"]])


func load_game(slot: int = 0) -> void:
	var data := _read_json(slot)
	if data.is_empty():
		printerr("[SaveManager] 读取存档失败 slot=%d" % slot)
		return

	# 1. 恢复 RNG 状态
	var seed_str: String = data.get("seed", "")
	if seed_str != "":
		RNGService.set_seed(seed_str)
		RNGService.set_state(data.get("rng_state", 0))

	# 2. 恢复持久状态
	_deserialize_persistent(data.get("persistent", {}))

	# 3. 设置战斗恢复数据 (供 battle_ui._ready() 检查)
	if data.has("battle") and data["battle"] != null:
		GameManager.restore_data = data["battle"]
	else:
		GameManager.restore_data = {}

	# 4. 标记加载中 (防止 switch_to_scene 的自动存档覆盖刚读的档)
	GameManager._is_loading = true

	# 5. 跳转到保存时的场景
	var scene_path: String = data.get("current_scene", "res://UI/map_ui.tscn")
	var scene_res := load(scene_path)
	if scene_res:
		get_tree().change_scene_to_packed(scene_res)
		# 非战斗场景在加载完成后复位 _is_loading 标记
		if scene_path != "res://UI/battle_ui.tscn":
			_reset_is_loading.call_deferred()
	else:
		printerr("[SaveManager] 无法加载场景: ", scene_path)


# -- 内部序列化 --

func _serialize_persistent() -> Dictionary:
	return {
		"game_manager": GameManager.to_dict(),
		"player_state": GameManager.player_state.to_dict(),
		"deck_manager": GameManager.deck_manager.to_dict(),
		"reaction_system": GameManager.reaction_system.to_dict(),
	}


func _deserialize_persistent(d: Dictionary) -> void:
	if d.is_empty(): return
	GameManager.from_dict(d.get("game_manager", {}))
	GameManager.player_state.from_dict(d.get("player_state", {}))
	GameManager.deck_manager.from_dict(d.get("deck_manager", {}))
	GameManager.reaction_system.from_dict(d.get("reaction_system", {}))


func _serialize_battle(scene: Node) -> Dictionary:
	var bm = scene.get_node_or_null("BattleManager")
	if not bm or not bm.has_method("to_dict"):
		return {}
	var d: Dictionary = bm.to_dict()
	# 附加 battle_ui 的主槽状态
	d["main_slot_states"] = scene.get_main_slot_states() if scene.has_method("get_main_slot_states") else []
	return d


# -- 文件 I/O --

func _save_path(slot: int) -> String:
	return SAVE_DIR + SAVE_PREFIX + str(slot) + SAVE_EXTENSION


func _write_json(data: Dictionary, slot: int) -> void:
	var file := FileAccess.open(_save_path(slot), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _read_json(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var file := FileAccess.open(_save_path(slot), FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		printerr("[SaveManager] JSON 解析错误: ", json.get_error_message())
		return {}
	return json.get_data()


func _reset_is_loading() -> void:
	GameManager._is_loading = false
