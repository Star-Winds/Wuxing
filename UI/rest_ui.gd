extends Control

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var heal_button: Button = $VBoxContainer/HBoxContainer/HealButton
@onready var nature_button: Button = $VBoxContainer/HBoxContainer/NatureButton
@onready var leave_button: Button = $VBoxContainer/HBoxContainer/LeaveButton

func _ready() -> void:
	GlobalHUD.set_scene_name("聚气歇息 (Rest)")
	var vbox = get_node_or_null("VBoxContainer")
	if vbox:
		vbox.offset_top = 100
	_update_ui()
	
	heal_button.pressed.connect(_on_heal_selected)
	nature_button.pressed.connect(_on_nature_selected)
	leave_button.pressed.connect(_on_leave_selected)
	# Add "Save & Quit" button
	var hbox = heal_button.get_parent()
	if hbox:
		var save_quit_btn = Button.new()
		save_quit_btn.name = "SaveQuitButton"
		save_quit_btn.text = "存档并退出 (Save & Quit)"
		save_quit_btn.custom_minimum_size = Vector2(200, 60)
		save_quit_btn.pressed.connect(_on_save_quit_pressed)
		hbox.add_child(save_quit_btn)

func _update_ui() -> void:
	if status_label:
		status_label.text = "Current HP: %d / %d | Wood Element: %d" % [GameManager.current_health, GameManager.max_health, GameManager.element_wood]

func _on_heal_selected() -> void:
	var heal_amount = 30
	GameManager.current_health = min(GameManager.max_health, GameManager.current_health + heal_amount)
	# 调用 GlobalHUD 更新顶部显示（如果有此方法）
	_leave_rest()

func _on_nature_selected() -> void:
	# 优化：直接循环增加
	for i in range(10):
		var choice = RNGService.randi() % 5
		match choice:
			0: GameManager.element_metal += 1
			1: GameManager.element_wood += 1
			2: GameManager.element_water += 1
			3: GameManager.element_fire += 1
			4: GameManager.element_earth += 1
	
	_leave_rest()

func _on_leave_selected() -> void:
	_leave_rest()

# --- 核心修改部分 ---
func _leave_rest() -> void:
	# 1. 推进地图索引
	GameManager.current_node_index += 1
	
	# 2. 使用重构后的全局引用跳转回地图
	# 确保在 GameManager 的 Inspector 中已将 map_ui.tscn 拖入 map_scene 槽位
	GameManager.switch_to_scene(GameManager.map_scene)

func _on_save_quit_pressed() -> void:
	SaveManager.save_game(0)
	GameManager.switch_to_scene(GameManager.main_menu_scene)
