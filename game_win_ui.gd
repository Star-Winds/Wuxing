extends Control

@onready var menu_button: Button = $VBoxContainer/MenuButton

func _ready() -> void:
	GlobalHUD.visible = false
	menu_button.pressed.connect(_on_menu_pressed)

func _on_menu_pressed() -> void:
	GameManager.reset_run()
	get_tree().change_scene_to_file("res://main_menu_ui.tscn")
