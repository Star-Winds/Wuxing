extends Control

@onready var rewards_label: Label = $VBoxContainer/RewardsLabel
@onready var cards_container: HBoxContainer = $VBoxContainer/CardsContainer
@onready var skip_button: Button = $VBoxContainer/SkipButton

var pending_card_id: String = ""
var pending_button: Button = null

var swap_overlay: Panel
var swap_grid: GridContainer

func _ready() -> void:
	_setup_swap_overlay()
	# 1. 授予基础奖励
	_grant_rewards()
	
	# 2. 加载卡牌并展示选项
	_display_card_options()
	
	# 3. 连接跳过/返回按钮
	skip_button.text = "返回地图 (Return to Map)"
	skip_button.pressed.connect(_return_to_map)

func _grant_rewards() -> void:
	GameManager.gold += 20
	
	var elements = ["Metal", "Wood", "Water", "Fire", "Earth"]
	var counts = {"Metal": 0, "Wood": 0, "Water": 0, "Fire": 0, "Earth": 0}
	
	for i in range(5):
		var chosen = elements[randi() % elements.size()]
		match chosen:
			"Metal": GameManager.element_metal += 1
			"Wood": GameManager.element_wood += 1
			"Water": GameManager.element_water += 1
			"Fire": GameManager.element_fire += 1
			"Earth": GameManager.element_earth += 1
		counts[chosen] += 1
		
	var elem_strings = []
	if counts["Metal"] > 0: elem_strings.append("金 (Metal) +%d" % counts["Metal"])
	if counts["Wood"] > 0: elem_strings.append("木 (Wood) +%d" % counts["Wood"])
	if counts["Water"] > 0: elem_strings.append("水 (Water) +%d" % counts["Water"])
	if counts["Fire"] > 0: elem_strings.append("火 (Fire) +%d" % counts["Fire"])
	if counts["Earth"] > 0: elem_strings.append("土 (Earth) +%d" % counts["Earth"])
	
	var text_parts = ["获得: 20 金币 (Gold)"]
	text_parts.append_array(elem_strings)
	
	rewards_label.text = ", ".join(text_parts)

func _display_card_options() -> void:
	for child in cards_container.get_children():
		child.queue_free()
		
	var card_db = _load_json_data("res://Databases/card_database.json")
	if card_db.is_empty(): return
		
	var card_ids = card_db.keys()
	card_ids.shuffle()
	
	var selected_ids = []
	for i in range(min(3, card_ids.size())):
		selected_ids.append(card_ids[i])
		
	for card_id in selected_ids:
		var card_data = card_db[card_id]
		var btn = Button.new()
		var c_name = card_data.get("name", "Unknown Card")
		var c_elem = card_data.get("element", "无")
		btn.text = "%s\n[%s属性]" % [c_name, c_elem]
		btn.custom_minimum_size = Vector2(240, 200)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_card_reward_selected.bind(card_id, btn))
		cards_container.add_child(btn)

func _on_card_reward_selected(card_id: String, btn: Button) -> void:
	if GameManager.reserve_cards.size() < GameManager.MAX_DECK_SIZE:
		GameManager.reserve_cards.append(card_id)
		GameManager.backpack_cards.append(card_id)
		btn.disabled = true
		btn.text += "\n(已获取)"
	else:
		pending_card_id = card_id
		pending_button = btn
		_show_swap_menu()

# --- 核心修改部分 ---
func _return_to_map() -> void:
	# 1. 增加节点索引
	GameManager.current_node_index += 1
	
	# 2. 判断是否完成世界 (假设 16 是 Boss 后的索引)
	if GameManager.current_node_index >= 16:
		GameManager.active_five_elements_array = "base_array"
		GameManager.generate_new_world()
		
		# 判断是否通关全三章
		if GameManager.current_world > 3:
			# 使用重构后的变量跳转至游戏胜利大结局
			GameManager.switch_to_scene(GameManager.game_win_scene)
			return
	
	# 3. 使用重构后的变量跳转回大地图
	GameManager.switch_to_scene(GameManager.map_scene)

# --- 数据加载与覆盖层逻辑 (保持不变) ---

func _load_json_data(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path): return {}
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	var parsed = JSON.parse_string(content)
	return parsed if parsed is Dictionary else {}

func _setup_swap_overlay() -> void:
	swap_overlay = Panel.new()
	swap_overlay.visible = false
	swap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.96)
	
	# 替换这一行：分别设置四个边的宽度
	style.set_border_width_all(4) 
	
	# 或者如果你想手动指定每一个边：
	# style.border_width_left = 4
	# style.border_width_top = 4
	# style.border_width_right = 4
	# style.border_width_bottom = 4
	
	style.border_color = Color(0.8, 0.2, 0.2, 0.8)
	style.set_corner_radius_all(12)
	swap_overlay.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 60; vbox.offset_top = 60; vbox.offset_right = -60; vbox.offset_bottom = -60
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	swap_overlay.add_child(vbox)
	
	var label = Label.new()
	label.text = "卡组已满！请选择一张卡牌丢弃以替换新卡"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(label)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	swap_grid = GridContainer.new()
	swap_grid.columns = 4
	swap_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swap_grid.add_theme_constant_override("h_separation", 15)
	swap_grid.add_theme_constant_override("v_separation", 15)
	scroll.add_child(swap_grid)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "取消替换 (Cancel)"
	cancel_btn.custom_minimum_size = Vector2(200, 50)
	cancel_btn.pressed.connect(func(): swap_overlay.hide())
	vbox.add_child(cancel_btn)
	add_child(swap_overlay)

func _show_swap_menu() -> void:
	for child in swap_grid.get_children():
		child.queue_free()
	var card_db = _load_json_data("res://Databases/card_database.json")
	for i in range(GameManager.reserve_cards.size()):
		var card_id = GameManager.reserve_cards[i]
		var card_data = card_db.get(card_id, {})
		var btn = Button.new()
		btn.text = "%s\n[%s属性]" % [card_data.get("name", card_id), card_data.get("element", "无")]
		btn.custom_minimum_size = Vector2(160, 90)
		btn.pressed.connect(_confirm_swap.bind(i))
		swap_grid.add_child(btn)
	swap_overlay.show()

func _confirm_swap(index: int) -> void:
	GameManager.reserve_cards.remove_at(index)
	GameManager.reserve_cards.append(pending_card_id)
	GameManager.backpack_cards = GameManager.reserve_cards.duplicate()
	pending_button.disabled = true
	pending_button.text += "\n(已替换)"
	swap_overlay.hide()
