extends CanvasLayer

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var abandon_button: Button = $CenterContainer/VBoxContainer/AbandonButton

func _ready() -> void:
	hide()
	resume_button.pressed.connect(_on_resume_pressed)
	abandon_button.pressed.connect(_on_abandon_pressed)

	# Add "Save & Quit" button
	var save_quit_btn = Button.new()
	save_quit_btn.name = "SaveQuitButton"
	save_quit_btn.text = "存档并退出 (Save & Quit)"
	save_quit_btn.custom_minimum_size = Vector2(260, 60)
	save_quit_btn.pressed.connect(_on_save_quit_pressed)
	var vbox = $CenterContainer/VBoxContainer
	if vbox:
		vbox.add_child(save_quit_btn)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	visible = not visible
	get_tree().paused = visible

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_abandon_pressed() -> void:
	# 恢复场景树暂停状态
	get_tree().paused = false
	hide()
	
	# 隐藏全局 HUD
	GlobalHUD.visible = false
	
	# 重置游戏运行数据
	GameManager.reset_run()
	
	# --- 关键修改：使用 GameManager 里的场景引用进行跳转 ---
	# 这样即使你移动了 main_menu_ui.tscn 的位置，这里也不会失效
	GameManager.switch_to_scene(GameManager.main_menu_scene)

func _on_save_quit_pressed() -> void:
	SaveManager.save_game(0)
	get_tree().paused = false
	hide()
	GlobalHUD.visible = false
	GameManager.switch_to_scene(GameManager.main_menu_scene)
