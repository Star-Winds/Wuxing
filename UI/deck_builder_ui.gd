extends Control

@onready var backpack_grid: GridContainer = %BackpackGrid
@onready var rows_container: VBoxContainer = %RowsContainer
@onready var save_button: Button = $VBoxContainer/HBoxContainer/SaveButton
@onready var cancel_button: Button = $VBoxContainer/HBoxContainer/CancelButton

var card_database: Dictionary = {}
var slots_map: Dictionary = {} # Maps row_idx -> {"main": main_slot_node, "subs": [sub_1_node, sub_2_node]}

func _ready() -> void:
	add_to_group("deck_builder_root")
	# 1. Load cards database
	card_database = _load_json_data("res://Databases/card_database.json")
	
	# 2. Build Equipped rows dynamically (Rows 1 to 5)
	_build_equipped_rows()
	
	# 3. Populate slots from GameManager.active_deck_layout
	_load_active_layout()
	
	# 4. Populate and display backpack cards
	update_backpack_view()
	
	# 5. Connect buttons
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Overlay & Combat awareness logic
	var is_overlay = (get_parent() != null and get_parent().name == "GlobalHUD")
	var is_combat = (get_tree().current_scene.name == "BattleUI" or (get_tree().current_scene.scene_file_path != "" and "battle" in get_tree().current_scene.scene_file_path))
	
	if is_overlay:
		# Inject dark background
		var dim_bg = ColorRect.new()
		dim_bg.color = Color(0, 0, 0, 0.95)
		dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dim_bg)
		move_child(dim_bg, 0)
		
		var main_container = get_node_or_null("VBoxContainer")
		if main_container:
			main_container.offset_top = 100
			
	if is_combat:
		var title_lbl = get_node_or_null("VBoxContainer/TitleLabel")
		if title_lbl:
			title_lbl.text = "卡组构筑 (战斗中 - 仅查看)"
			
		# Fully lock all drag & drop click nodes recursively in combat
		_disable_input_recursive(backpack_grid)
		_disable_input_recursive(rows_container)
		
		if save_button:
			save_button.text = "返回对局 (Return to Battle)"
		if cancel_button:
			cancel_button.hide()

func _disable_input_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if node is Button:
			node.disabled = true
	for child in node.get_children():
		_disable_input_recursive(child)

func _load_json_data(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null: return {}
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary:
		return parsed
	return {}

func _build_equipped_rows() -> void:
	# Clear existing children
	for child in rows_container.get_children():
		child.queue_free()
		
	slots_map.clear()
	
	for i in range(1, 6):
		var row_hbox = HBoxContainer.new()
		row_hbox.custom_minimum_size = Vector2(0, 100)
		row_hbox.add_theme_constant_override("separation", 15)
		
		# Row Title label
		var title_lbl = Label.new()
		title_lbl.text = "Row %d" % i
		title_lbl.custom_minimum_size = Vector2(70, 0)
		title_lbl.add_theme_font_size_override("font_size", 18)
		title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_hbox.add_child(title_lbl)
		
		# 1. Main Slot
		var main_slot = _create_slot_node("main", i, 0)
		row_hbox.add_child(main_slot)
		
		# 2. Sub Slot 1
		var sub_slot_1 = _create_slot_node("sub", i, 1)
		row_hbox.add_child(sub_slot_1)
		
		# 3. Sub Slot 2
		var sub_slot_2 = _create_slot_node("sub", i, 2)
		row_hbox.add_child(sub_slot_2)
		
		rows_container.add_child(row_hbox)
		
		slots_map[i] = {
			"main": main_slot,
			"subs": [sub_slot_1, sub_slot_2]
		}

func _create_slot_node(type: String, row_idx: int, sub_idx: int) -> PanelContainer:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(250, 90) if type == "main" else Vector2(180, 90)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Attach script
	slot.set_script(load("res://Components/deck_builder_slot.gd"))
	slot.slot_type = type
	slot.row_index = row_idx
	slot.sub_slot_index = sub_idx
	
	# Build layout inside slot
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	
	var name_lbl = Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_lbl)
	
	var stats_lbl = Label.new()
	stats_lbl.name = "StatsLabel"
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	vbox.add_child(stats_lbl)
	
	slot.add_child(vbox)
	
	# Set initial empty card
	slot.clear_slot()
	
	return slot

func _load_active_layout() -> void:
	var active_layout = GameManager.active_deck_layout
	for data in active_layout:
		var row_name = data.get("row", "")
		if row_name == "": continue
		var row_idx = int(row_name.right(1))
		if not slots_map.has(row_idx): continue
		
		var row_slots = slots_map[row_idx]
		
		# Load main slot
		var main_id = data.get("main", "")
		if main_id != "" and card_database.has(main_id):
			var card_data = card_database[main_id]
			row_slots["main"].set_card(
				main_id,
				card_data.get("name", main_id),
				card_data.get("element", ""),
				card_data.get("main_slot", {}).get("description", "")
			)
			
		# Load sub slots
		var subs = data.get("subs", [])
		for j in range(min(subs.size(), 2)):
			var sub_id = subs[j]
			if sub_id != "" and card_database.has(sub_id):
				var card_data = card_database[sub_id]
				row_slots["subs"][j].set_card(
					sub_id,
					card_data.get("name", sub_id),
					card_data.get("element", ""),
					card_data.get("sub_slot", {}).get("description", "")
				)

func update_backpack_view() -> void:
	# 1. Clear backpack grid
	for child in backpack_grid.get_children():
		child.queue_free()
		
	# 2. Collect all equipped card IDs
	var equipped_ids = []
	for row_idx in slots_map.keys():
		var row_slots = slots_map[row_idx]
		if row_slots["main"].current_card_id != "":
			equipped_ids.append(row_slots["main"].current_card_id)
		for sub_slot in row_slots["subs"]:
			if sub_slot.current_card_id != "":
				equipped_ids.append(sub_slot.current_card_id)
				
	# 3. Calculate remaining available cards in backpack
	var available_cards = GameManager.backpack_cards.duplicate()
	for eq_id in equipped_ids:
		if available_cards.has(eq_id):
			available_cards.erase(eq_id)
			
	# 4. Create draggable card buttons for available cards
	for card_id in available_cards:
		if not card_database.has(card_id): continue
		
		var card_data = card_database[card_id]
		var card_btn = Button.new()
		card_btn.custom_minimum_size = Vector2(170, 110)
		
		# Style button base color according to element
		var element = card_data.get("element", "")
		var color = Color(0.2, 0.2, 0.22, 1)
		match element:
			"火": color = Color(0.5, 0.2, 0.15, 1)
			"木": color = Color(0.15, 0.45, 0.2, 1)
			"水": color = Color(0.15, 0.25, 0.5, 1)
			"金": color = Color(0.5, 0.45, 0.15, 1)
			"土": color = Color(0.35, 0.25, 0.2, 1)
			"以太": color = Color(0.35, 0.15, 0.45, 1)
			
		card_btn.add_theme_color_override("font_color", Color.WHITE)
		card_btn.add_theme_font_size_override("font_size", 15)
		
		var cost_str = _format_cost(card_data.get("cost", {}))
		card_btn.text = "%s\n[%s]\nCost: %s" % [
			card_data.get("name", card_id),
			element,
			cost_str
		]
		
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		card_btn.add_theme_stylebox_override("normal", style)
		
		# Set drag-and-drop helper script
		card_btn.set_script(load("res://Components/deck_builder_card.gd"))
		card_btn.card_id = card_id
		card_btn.card_name = card_data.get("name", card_id)
		card_btn.is_equipped = false
		card_btn.origin_slot = null
		
		backpack_grid.add_child(card_btn)

func _format_cost(cost_dict: Dictionary) -> String:
	var result = []
	for key in cost_dict.keys():
		result.append(str(cost_dict[key]) + key)
	return ", ".join(result)

func get_card_name(card_id: String) -> String:
	return card_database.get(card_id, {}).get("name", card_id)

func _on_save_pressed() -> void:
	var is_overlay = (get_parent() != null and get_parent().name == "GlobalHUD")
	var is_combat = (get_tree().current_scene.name == "BattleUI" or (get_tree().current_scene.scene_file_path != "" and "battle" in get_tree().current_scene.scene_file_path))
	
	if not is_combat:
		var new_layout: Array[Dictionary] = []
		for i in range(1, 6):
			var row_name = "SlotRow_" + str(i)
			var main_id = slots_map[i]["main"].current_card_id
			var sub1_id = slots_map[i]["subs"][0].current_card_id
			var sub2_id = slots_map[i]["subs"][1].current_card_id
			
			# Save row layout structure
			new_layout.append({
				"row": row_name,
				"main": main_id,
				"subs": [sub1_id, sub2_id]
			})
			
		GameManager.active_deck_layout.clear()
		GameManager.active_deck_layout.assign(new_layout)
		print("Deck layout successfully saved!")
		
	if is_overlay:
		queue_free()
	else:
		get_tree().change_scene_to_file("res://UI/map_ui.tscn")

func _on_cancel_pressed() -> void:
	print("Cancel deck editing.")
	var is_overlay = (get_parent() != null and get_parent().name == "GlobalHUD")
	if is_overlay:
		queue_free()
	else:
		get_tree().change_scene_to_file("res://UI/map_ui.tscn")
