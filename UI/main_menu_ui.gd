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

	# 显示当前 Run 种子
	# 如果存在存档，显示继续按钮
	var vbox = $VBoxContainer
	if vbox and SaveManager.has_save(0):
		var continue_btn = Button.new()
		continue_btn.name = "ContinueButton"
		continue_btn.text = "继续游戏 (Continue)"
		continue_btn.custom_minimum_size = Vector2(300, 80)
		continue_btn.add_theme_font_size_override("font_size", 24)
		continue_btn.pressed.connect(_on_continue_pressed)
		vbox.add_child(continue_btn)
		# 放在 Start 按钮下方
		var start_idx = start_button.get_index()
		vbox.move_child(continue_btn, start_idx + 1)

	var seed_label = Label.new()
	seed_label.name = "SeedLabel"
	seed_label.text = "Seed: " + RNGService.get_seed_string()
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_label.add_theme_font_size_override("font_size", 14)
	seed_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	if vbox:
		vbox.add_child(seed_label)
		vbox.move_child(seed_label, vbox.get_child_count() - 1)  # 放在 Quit 按钮上方

func _on_start_pressed() -> void:
	# 1. 跳转到初始卡组选择界面
	var selection_scene = load("res://UI/initial_deck_selection_ui.tscn")
	if selection_scene:
		get_tree().change_scene_to_packed(selection_scene)
	else:
		printerr("Failed to load initial_deck_selection_ui.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_continue_pressed() -> void:
	SaveManager.load_game(0)