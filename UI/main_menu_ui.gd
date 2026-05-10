extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	GlobalHUD.visible = false
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	GameManager.reset_run()
	get_tree().change_scene_to_file("res://UI/map_ui.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
