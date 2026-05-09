extends Control

@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var menu_button: Button = $VBoxContainer/MenuButton

func _ready() -> void:
	stats_label.text = "Reached World: " + str(GameManager.current_world)
	menu_button.pressed.connect(_on_menu_pressed)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu_ui.tscn")
