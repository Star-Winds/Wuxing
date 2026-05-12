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
	# 1. 跳转到初始卡组选择界面
	var selection_scene = load("res://UI/initial_deck_selection_ui.tscn")
	if selection_scene:
		get_tree().change_scene_to_packed(selection_scene)
	else:
		printerr("Failed to load initial_deck_selection_ui.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()