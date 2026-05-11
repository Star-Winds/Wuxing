extends Control

@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var menu_button: Button = $VBoxContainer/MenuButton

func _ready() -> void:
	# 记录玩家战绩：到达了第几个世界
	stats_label.text = "Reached World: " + str(GameManager.current_world)
	menu_button.pressed.connect(_on_menu_pressed)

func _on_menu_pressed() -> void:
	# --- 核心修改部分 ---
	
	# 1. 使用重构后的全局引用跳转回主菜单
	# 确保你在 GameManager 的 Inspector 中已将 main_menu_ui.tscn 拖入 main_menu_scene 槽位
	GameManager.switch_to_scene(GameManager.main_menu_scene)
	
	# 2. (可选) 如果你希望返回主菜单后立即重置所有内存数据，可以在这里调用
	# GameManager.reset_run()