extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	# 确保进入主菜单时隐藏战斗/地图通用的 HUD
	GlobalHUD.visible = false
	
	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	if not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	# 1. 初始化游戏数据（重置血量、金钱、生成第一层地图等）
	GameManager.reset_run()
	
	# 2. 使用重构后的全局变量跳转到地图场景
	# 确保在 GameManager 的 Inspector 中已将 map_ui.tscn 拖入 map_scene 槽位
	GameManager.switch_to_scene(GameManager.map_scene)

func _on_quit_pressed() -> void:
	get_tree().quit()