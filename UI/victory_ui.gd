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
	# 1. Grant base rewards and update label
	_grant_rewards()
	
	# 2. Load cards and display options
	_display_card_options()
	
	# 3. Connect Skip button
	skip_button.text = "返回地图 (Return to Map)"
	skip_button.pressed.connect(_return_to_map)

func _grant_rewards() -> void:
	GameManager.gold += 20
	
	var elements = ["Metal", "Wood", "Water", "Fire", "Earth"]
	var gained_elements = []
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
		gained_elements.append(chosen)
		
	# Format the reward text nicely with localized/friendly element symbols
	var elem_strings = []
	if counts["Metal"] > 0: elem_strings.append("金 (Metal) +%d" % counts["Metal"])
	if counts["Wood"] > 0: elem_strings.append("木 (Wood) +%d" % counts["Wood"])
	if counts["Water"] > 0: elem_strings.append("水 (Water) +%d" % counts["Water"])
	if counts["Fire"] > 0: elem_strings.append("火 (Fire) +%d" % counts["Fire"])
	if counts["Earth"] > 0: elem_strings.append("土 (Earth) +%d" % counts["Earth"])
	
	var text_parts = ["获得: 20 金币 (Gold)"]
	text_parts.append_array(elem_strings)
	
	rewards_label.text = ", ".join(text_parts)
	print("Loot settlement granted: 20 gold and elements: ", gained_elements)

func _display_card_options() -> void:
	# Clear container
	for child in cards_container.get_children():
		child.queue_free()
		
	var card_db = _load_json_data("res://Databases/card_database.json")
	if card_db.is_empty():
		print("Error: Card database empty or could not be loaded!")
		return
		
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

func _format_cost(cost_dict: Dictionary) -> String:
	var result = []
	for key in cost_dict.keys():
		result.append(str(cost_dict[key]) + key)
	return ", ".join(result)

func _on_card_reward_selected(card_id: String, btn: Button) -> void:
	if GameManager.reserve_cards.size() < GameManager.MAX_DECK_SIZE:
		GameManager.reserve_cards.append(card_id)
		GameManager.backpack_cards.append(card_id)
		print("Loot: Card added to backpack/reserve: ", card_id)
		btn.disabled = true
		btn.text += "\n(已获取)"
	else:
		pending_card_id = card_id
		pending_button = btn
		_show_swap_menu()

func _return_to_map() -> void:
	GameManager.current_node_index += 1
	
	if GameManager.current_node_index >= 16:
		GameManager.active_five_elements_array = "base_array"
		GameManager.generate_new_world()
		print("Boss Defeated! Acquired Five Elements Array! Moving to World ", GameManager.current_world)
		
		if GameManager.current_world > 3:
			print("All 3 Worlds Completed! Transitioning to Game Victory Screen.")
			get_tree().change_scene_to_file("res://UI/game_win_ui.tscn")
			return
		
	get_tree().change_scene_to_file("res://UI/map_ui.tscn")

func _load_json_data(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		print("Error: File not found: ", file_path)
		return {}
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Error: Could not open file: ", file_path)
		return {}
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		return parsed
	else:
		print("Error: Parsed JSON is not a Dictionary: ", file_path)
		return {}

func _setup_swap_overlay() -> void:
	# Create Panel
	swap_overlay = Panel.new()
	swap_overlay.name = "SwapOverlay"
	swap_overlay.visible = false
	swap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Give it a beautiful glassmorphic flat panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.96)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.8, 0.2, 0.2, 0.8) # Red border for alert
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	swap_overlay.add_theme_stylebox_override("panel", style)
	
	# Create VBoxContainer
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.offset_left = 60
	vbox.offset_top = 60
	vbox.offset_right = -60
	vbox.offset_bottom = -60
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	swap_overlay.add_child(vbox)
	
	# Create Label
	var label = Label.new()
	label.text = "卡组已满！请选择一张卡牌丢弃以替换新卡"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(label)
	
	# Create ScrollContainer
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	# Create GridContainer
	swap_grid = GridContainer.new()
	swap_grid.columns = 4
	swap_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swap_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	swap_grid.add_theme_constant_override("h_separation", 15)
	swap_grid.add_theme_constant_override("v_separation", 15)
	scroll.add_child(swap_grid)
	
	# Cancel Button
	var cancel_btn = Button.new()
	cancel_btn.text = "取消替换 (Cancel)"
	cancel_btn.custom_minimum_size = Vector2(200, 50)
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_btn.pressed.connect(func(): swap_overlay.hide())
	vbox.add_child(cancel_btn)
	
	# Add to main node
	add_child(swap_overlay)

func _show_swap_menu() -> void:
	# Clear existing children in swap_grid
	for child in swap_grid.get_children():
		child.queue_free()
		
	var card_db = _load_json_data("res://Databases/card_database.json")
	
	for i in range(GameManager.reserve_cards.size()):
		var card_id = GameManager.reserve_cards[i]
		var card_data = card_db.get(card_id, {})
		var c_name = card_data.get("name", card_id)
		var c_elem = card_data.get("element", "无")
		
		var btn = Button.new()
		btn.text = "%s\n[%s属性]" % [c_name, c_elem]
		btn.custom_minimum_size = Vector2(160, 90)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_confirm_swap.bind(i))
		swap_grid.add_child(btn)
		
	swap_overlay.show()

func _confirm_swap(index: int) -> void:
	GameManager.reserve_cards.remove_at(index)
	GameManager.reserve_cards.append(pending_card_id)
	
	# Keep backpack cards synced
	GameManager.backpack_cards = GameManager.reserve_cards.duplicate()
	
	pending_button.disabled = true
	pending_button.text += "\n(已替换)"
	swap_overlay.hide()
	print("Swapped card at index " + str(index) + " for " + pending_card_id)
