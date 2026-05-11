extends Control

@onready var menu_button: Button = $VBoxContainer/MenuButton

func _ready() -> void:
	# 隐藏全局 HUD，因为胜利界面通常是全屏展示的
	GlobalHUD.visible = false
	menu_button.pressed.connect(_on_menu_pressed)

func _on_menu_pressed() -> void:
	# 1. 重置所有玩家数据、进度和地图索引
	GameManager.reset_run()
	
	# 2. 使用重构后的全局引用跳转回主菜单
	# 确保在 GameManager 的检查器中已为 main_menu_scene 赋值
	GameManager.switch_to_scene(GameManager.main_menu_scene)