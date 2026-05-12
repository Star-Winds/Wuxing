extends Control

const CARD_DATA_CONST = preload("res://Resources/Scripts/Card_data.gd")

@onready var backpack_grid: GridContainer = %BackpackGrid
@onready var rows_container: VBoxContainer = %RowsContainer
@onready var save_button: Button = $VBoxContainer/HBoxContainer/SaveButton
@onready var cancel_button: Button = $VBoxContainer/HBoxContainer/CancelButton

var slots_map: Dictionary = {} # Maps row_idx -> {"main": main_slot_node, "subs": [sub_1_node, sub_2_node]}

func _ready() -> void:
	add_to_group("deck_builder_root")
	
	# 1. Build Equipped rows dynamically (Rows 1 to 5)
	_build_equipped_rows()
	
	# 2. Populate slots from GameManager.active_deck_layout
	_load_active_layout()
	
	# 3. Populate and display backpack cards
	update_backpack_view()
	
	# 4. Connect buttons
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
		var main_card = data.get("main")
		if main_card is CardData:
			row_slots["main"].set_card(main_card)
		elif main_card is String and main_card != "":
			# Backward compatibility fallback
			var card_res = ResourceManager.get_card_data(main_card)
			if card_res:
				row_slots["main"].set_card(card_res)
			
		# Load sub slots
		var subs = data.get("subs", [])
		for j in range(min(subs.size(), 2)):
			var sub_card = subs[j]
			if sub_card is CardData:
				row_slots["subs"][j].set_card(sub_card)
			elif sub_card is String and sub_card != "":
				# Backward compatibility fallback
				var card_res = ResourceManager.get_card_data(sub_card)
				if card_res:
					row_slots["subs"][j].set_card(card_res)

func update_backpack_view() -> void:
	# 1. Clear backpack grid
	for child in backpack_grid.get_children():
		child.queue_free()
		
	# 2. Collect all equipped card references
	var equipped_cards: Array[CardData] = []
	for row_idx in slots_map.keys():
		var row_slots = slots_map[row_idx]
		if row_slots["main"].card_data != null:
			equipped_cards.append(row_slots["main"].card_data)
		for sub_slot in row_slots["subs"]:
			if sub_slot.card_data != null:
				equipped_cards.append(sub_slot.card_data)
				
	# 3. Calculate remaining available cards in backpack
	var available_cards: Array[CardData] = []
	var temp_equipped = equipped_cards.duplicate()
	for card in GameManager.backpack_cards:
		if card == null:
			continue
		if card is CardData:
			var idx = temp_equipped.find(card)
			if idx == -1:
				available_cards.append(card)
			else:
				temp_equipped.remove_at(idx)
		elif card is String and card != "":
			# Fallback if backpack contains String IDs
			var card_res = ResourceManager.get_card_data(card)
			if card_res:
				var idx = temp_equipped.find(card_res)
				if idx == -1:
					available_cards.append(card_res)
				else:
					temp_equipped.remove_at(idx)
			
	# 4. Create draggable card buttons for available cards
	for card_data_obj in available_cards:
		if card_data_obj == null:
			continue
			
		var card_btn = Button.new()
		card_btn.set_script(load("res://Components/deck_builder_card.gd"))
		card_btn.set_card_data(card_data_obj)
		card_btn.is_equipped = false
		card_btn.origin_slot = null
		
		backpack_grid.add_child(card_btn)

func _format_cost(cost_dict: Dictionary) -> String:
	var result = []
	for key in cost_dict.keys():
		result.append(str(cost_dict[key]) + key)
	return ", ".join(result)

func get_card_name(card_id: String) -> String:
	var card = ResourceManager.get_card_data(card_id)
	return card.card_name if card else card_id

func _on_save_pressed() -> void:
	var is_overlay = (get_parent() != null and get_parent().name == "GlobalHUD")
	var is_combat = (get_tree().current_scene.name == "BattleUI" or (get_tree().current_scene.scene_file_path != "" and "battle" in get_tree().current_scene.scene_file_path))
	
	if not is_combat:
		var new_layout: Array[Dictionary] = []
		for i in range(1, 6):
			var row_name = "SlotRow_" + str(i)
			var main_card = slots_map[i]["main"].card_data
			var sub1_card = slots_map[i]["subs"][0].card_data
			var sub2_card = slots_map[i]["subs"][1].card_data
			
			# Save row layout structure
			new_layout.append({
				"row": row_name,
				"main": main_card,
				"subs": [sub1_card, sub2_card]
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
