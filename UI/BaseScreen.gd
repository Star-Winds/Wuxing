class_name BaseScreen
extends Control

## 设置场景标题（等效于 GlobalHUD.set_scene_name + vbox 偏移）。
func set_scene_title(title: String) -> void:
	GlobalHUD.set_scene_name(title)
	var vbox = get_node_or_null("VBoxContainer")
	if vbox:
		vbox.offset_top = 100


## 推进地图索引并返回大地图。
func return_to_map() -> void:
	GameManager.current_node_index += 1
	GameManager.switch_to_scene(GameManager.map_scene)


## 返回主菜单。
func go_to_main_menu() -> void:
	GameManager.switch_to_scene(GameManager.main_menu_scene)
