extends CanvasLayer

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var abandon_button: Button = $CenterContainer/VBoxContainer/AbandonButton

func _ready() -> void:
	hide()
	resume_button.pressed.connect(_on_resume_pressed)
	abandon_button.pressed.connect(_on_abandon_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	visible = not visible
	get_tree().paused = visible

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_abandon_pressed() -> void:
	get_tree().paused = false
	hide()
	GlobalHUD.visible = false
	GameManager.reset_run()
	get_tree().change_scene_to_file("res://main_menu_ui.tscn")
