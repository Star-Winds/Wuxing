extends Control

# --- Battle Manager ---
@export var battle_manager: Node

# --- Resource Pool Data ---
var player_shield: int = 0

# --- Enemy Data ---
var enemy_name: String = ""
var enemy_element: String = ""
var enemy_max_hp: int = 0
var enemy_hp: int = 0
var enemy_shield: int = 0
var enemy_turn_counter: int = 0
var enemy_atk_buff: int = 0
var base_attack_damage: int = 0

# --- State Variables ---
var has_manually_activated: bool = false
var pending_activation_slot: CardSlot = null
var pending_play_slot: CardSlot = null
var card_database: Dictionary = {}
var is_game_over: bool = false
var element_colors: Dictionary = {}
var card_db: Dictionary = {}	
var player_statuses: Dictionary = {}
var enemy_statuses: Dictionary = {}

var array_db: Dictionary = {}
var is_array_activated: bool = false
var array_button: Button

# --- Node References ---
@onready var master_layout: VBoxContainer = $MasterLayout
@onready var end_turn_button: Button = $MasterLayout/PlayerStatusBar/MarginContainer/HBoxContainer/EndTurnButton
@onready var player_status_bar: PanelContainer = $MasterLayout/PlayerStatusBar
@onready var player_status_container: HBoxContainer = $MasterLayout/PlayerStatusBar/MarginContainer/HBoxContainer/PlayerStatusContainer
@onready var enemy_status_container: HBoxContainer = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity/VBoxContainer/StatusContainer

@onready var slots_container: VBoxContainer = $MasterLayout/MiddleArea/SlotsContainer
@onready var payment_panel: PanelContainer = $PaymentPanel
@onready var payment_title: Label = $PaymentPanel/VBoxContainer/TitleLabel
@onready var resource_sliders: VBoxContainer = $PaymentPanel/VBoxContainer/ResourceSliders
@onready var remaining_label: Label = $PaymentPanel/VBoxContainer/HBoxContainer/RemainingLabel
@onready var confirm_activation_button: Button = $PaymentPanel/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_activation_button: Button = $PaymentPanel/VBoxContainer/HBoxContainer/CancelButton

@onready var reserve_panel: PanelContainer = $ReservePanel
@onready var reserve_options: HBoxContainer = $ReservePanel/VBoxContainer/OptionsContainer
@onready var reserve_cancel_btn: Button = $ReservePanel/VBoxContainer/CancelButton

var reserve_cards: Array = ["wood_growth_001", "fire_attack_001", "earth_defense_001", "earth_rock_001", "wood_thorn_001", "water_torrent_001", "metal_knife_001", "fire_law_001"]
var current_replace_slot: CardSlot = null

@onready var enemy_entity: PanelContainer = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity
@onready var enemy_intent_label: Label = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity/VBoxContainer/IntentLabel
@onready var enemy_name_label: Label = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity/VBoxContainer/NameLabel
@onready var enemy_stats_label: Label = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity/VBoxContainer/EnemyStatsLabel

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

func _ready() -> void:
	GlobalHUD.set_scene_name("战斗 (Battle)")
	
	# Load Databases from JSON
	card_db = _load_json_data("res://Databases/card_database.json")
	array_db = _load_json_data("res://Databases/array_database.json")
	card_database = card_db
	
	# Dynamic encounter loading
	var node_type = ""
	if GameManager.current_node_index < GameManager.current_map_path.size():
		node_type = GameManager.current_map_path[GameManager.current_node_index]
	
	var category = "normal"
	if "Boss" in node_type or "将/帅" in node_type:
		category = "boss"
	elif "Elite" in node_type or "士" in node_type:
		category = "elite"
		
	var enemy_db = _load_json_data("res://Databases/enemy_database.json")
	if enemy_db.has(category):
		var enemies = enemy_db[category]
		if not enemies.is_empty():
			var chosen = enemies[randi() % enemies.size()]
			enemy_name = chosen.get("name", "Unknown")
			enemy_element = chosen.get("element", "木")
			enemy_max_hp = chosen.get("hp", 32)
			enemy_hp = enemy_max_hp
			base_attack_damage = chosen.get("intent_base_dmg", 8)
			print("Dynamic encounter loaded Category: ", category, " -> Enemy: ", enemy_name)

	element_colors = {
		"火": Color("#E64A19"),
		"木": Color("#43A047"),
		"水": Color("#1E88E5"),
		"金": Color("#FBC02D"),
		"土": Color("#8D6E63"),
		"以太": Color("#9C27B0")
	}
	
	# Connect local signals
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
	if confirm_activation_button:
		confirm_activation_button.pressed.connect(_on_confirm_payment)
	if cancel_activation_button:
		cancel_activation_button.pressed.connect(_on_cancel_payment)
	if reserve_cancel_btn:
		reserve_cancel_btn.pressed.connect(_on_reserve_cancel)
		
	# Setup card slots and connect signals
	_initialize_card_slots()
	
	if enemy_entity:
		var script = GDScript.new()
		script.source_code = "extends PanelContainer\nvar element: String = \"木\"\nvar hp: int = 32\nvar shield: int = 0\nvar max_hp: int = 32"
		script.reload()
		enemy_entity.set_script(script)
		enemy_entity.element = enemy_element
		enemy_entity.hp = enemy_hp
		enemy_entity.shield = enemy_shield
		enemy_entity.max_hp = enemy_max_hp

		var target_btn = Button.new()
		target_btn.name = "TargetButton"
		target_btn.flat = true
		enemy_entity.add_child(target_btn)
		target_btn.pressed.connect(_on_enemy_targeted)

	# Instantiate / Find Battle Manager
	if not battle_manager:
		battle_manager = get_node_or_null("BattleManager")
		if not battle_manager:
			var bm_script = load("res://Systems/battle_manager.gd")
			battle_manager = Node.new()
			battle_manager.name = "BattleManager"
			battle_manager.set_script(bm_script)
			add_child(battle_manager)
			
	# Connect Battle Manager Signals
	battle_manager.stats_updated.connect(_on_stats_updated)
	battle_manager.status_updated.connect(_on_status_updated)
	battle_manager.reaction_triggered.connect(_on_reaction_triggered)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.activate_random_subslot_requested.connect(_on_activate_random_subslot_requested)
	
	# Initialize Battle State in Manager (Safe to trigger signals now that enemy_entity is ready)
	battle_manager.initialize_battle(enemy_name, enemy_element, enemy_max_hp, base_attack_damage, card_db)
	
	# Setup array button
	array_button = Button.new()
	array_button.text = "阵法: 未就绪"
	array_button.disabled = true
	array_button.pressed.connect(_on_array_button_pressed)
	array_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	array_button.offset_left = 20
	array_button.offset_top = 105
	array_button.custom_minimum_size = Vector2(150, 40)
	add_child(array_button)
	
	enemy_turn_counter = battle_manager.enemy_turn_counter
	enemy_atk_buff = battle_manager.enemy_atk_buff
	
	_update_end_turn_button()
	_update_resource_ui()
	_update_enemy_ui()
	_update_enemy_intent()
	_update_status_displays()
	
	# Styling
	if player_status_bar:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.08, 0.1, 0.85)
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		player_status_bar.add_theme_stylebox_override("panel", style)
	
	# --- DEBUG INSTA-KILL BUTTON ---
	var debug_kill_btn = Button.new()
	debug_kill_btn.text = "🛠️ [测试] 一键秒杀"
	debug_kill_btn.add_theme_color_override("font_color", Color.RED)
	debug_kill_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_kill_btn.offset_left = -200
	debug_kill_btn.offset_top = 60
	debug_kill_btn.offset_right = -20
	debug_kill_btn.offset_bottom = 100
	debug_kill_btn.pressed.connect(_on_debug_instakill_pressed)
	add_child(debug_kill_btn)

# --- Battle Manager Signal Listeners ---
func _on_stats_updated(player_hp: int, p_player_shield: int, p_enemy_hp: int, p_enemy_shield: int) -> void:
	player_shield = p_player_shield
	enemy_hp = p_enemy_hp
	enemy_shield = p_enemy_shield
	enemy_atk_buff = battle_manager.enemy_atk_buff
	
	if enemy_entity:
		enemy_entity.hp = enemy_hp
		enemy_entity.shield = enemy_shield

	_update_enemy_ui()
	_update_resource_ui()

func _on_status_updated(target: String, status_dict: Dictionary) -> void:
	if target == "player":
		player_statuses = status_dict
	elif target == "enemy":
		enemy_statuses = status_dict
	_update_status_displays()

func _on_reaction_triggered(reaction_name: String, reaction_color: Color) -> void:
	_spawn_floating_text(reaction_name + "!", reaction_color)

func _on_battle_ended(is_victory: bool) -> void:
	is_game_over = true
	if is_victory:
		_trigger_victory()
	else:
		_trigger_game_over()

func _on_activate_random_subslot_requested() -> void:
	_activate_random_subslot()

# --- Interface Logic ---
func _initialize_card_slots() -> void:
	var slots_data = GameManager.active_deck_layout
	
	for data in slots_data:
		var row = slots_container.get_node_or_null(data["row"])
		if not row: continue
		
		var main_idx = data["row"].right(1)
		var main_slot = row.get_node_or_null("MainSlot_" + main_idx)
		if main_slot and card_database.has(data["main"]):
			var c_data = card_database[data["main"]]
			main_slot.set_meta("card_id", data["main"])
			main_slot.name_label.text = c_data.get("name", "Unknown Card")
			
			var cost_dict = c_data.get("cost", {})
			var stat_text = "Cost: " + _format_cost(cost_dict)
			
			var main_slot_data = c_data.get("main_slot", {})
			if main_slot_data is Dictionary:
				var m_type = main_slot_data.get("type", "")
				var m_val = main_slot_data.get("value", 0)
				if m_type == "damage":
					stat_text += " | Dmg: " + str(m_val)
				elif m_type == "shield":
					stat_text += " | Shd: " + str(m_val)
					
			main_slot.stats_label.text = stat_text
			main_slot.cost_dict = cost_dict.duplicate()
			main_slot._update_visuals()
			
		for i in range(data["subs"].size()):
			var sub_slot = row.get_node_or_null("SubSlot_" + main_idx + "_" + str(i+1))
			var sub_id = data["subs"][i]
			if sub_slot and card_database.has(sub_id):
				var c_data = card_database[sub_id]
				sub_slot.set_meta("card_id", sub_id)
				sub_slot.name_label.text = "Sub: " + c_data.get("name", "Unknown Card")
				
				var sub_slot_data = c_data.get("sub_slot", {})
				var sub_val = 0
				if sub_slot_data is Dictionary:
					sub_val = sub_slot_data.get("value", 0)
					
				sub_slot.stats_label.text = "Buff: +" + str(sub_val)
				sub_slot._update_visuals()

	for row in slots_container.get_children():
		if row is HBoxContainer:
			for slot in row.get_children():
				if slot is CardSlot and not slot.is_sub_slot:
					slot.activation_requested.connect(_on_slot_activation_requested)
					
					var replace_btn = Button.new()
					replace_btn.text = "Swap"
					replace_btn.add_theme_font_size_override("font_size", 11)
					replace_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
					replace_btn.offset_left = -45
					replace_btn.offset_bottom = 22
					replace_btn.pressed.connect(_on_replace_button_pressed.bind(slot))
					slot.add_child(replace_btn)

func _format_cost(cost_dict: Dictionary) -> String:
	var result = []
	for key in cost_dict.keys():
		result.append(str(cost_dict[key]) + key)
	return ", ".join(result)

func _update_resource_ui() -> void:
	pass

func _update_end_turn_button() -> void:
	if has_manually_activated:
		end_turn_button.text = "结束回合 (End Turn)"
	else:
		end_turn_button.text = "引气入体 (End Turn)"

var current_card_cost_dict: Dictionary = {}
var current_card_total_cost: int = 0
var allocated_amounts: Dictionary = {}
var element_spinboxes: Dictionary = {}

func _on_slot_activation_requested(slot: CardSlot, cost: Dictionary) -> void:
	pending_activation_slot = slot
	current_card_cost_dict = cost.duplicate()
	
	if current_card_cost_dict.is_empty():
		current_card_cost_dict = {"Aether": 2}
		
	current_card_total_cost = 0
	for element in current_card_cost_dict.keys():
		current_card_total_cost += current_card_cost_dict[element]
		
	var card_name = slot.name_label.text
	payment_title.text = "Allocate Resources for " + card_name
	
	for child in resource_sliders.get_children():
		child.queue_free()
		
	allocated_amounts.clear()
	element_spinboxes.clear()
	
	for element in current_card_cost_dict.keys():
		if element == "Aether": continue
		_create_allocation_row(element, min(_get_element_current(element), current_card_cost_dict[element]))
		
	_create_allocation_row("Aether", GameManager.aether)
	
	_update_payment_calculation()
	payment_panel.show()

func _get_element_current(element: String) -> int:
	match element:
		"火": return GameManager.element_fire
		"土": return GameManager.element_earth
		"金": return GameManager.element_metal
		"木": return GameManager.element_wood
		"水": return GameManager.element_water
	return 0

func _create_allocation_row(element: String, max_val: int) -> void:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = element + ":"
	label.custom_minimum_size = Vector2(80, 0)
	
	var spinbox = SpinBox.new()
	spinbox.min_value = 0
	spinbox.max_value = max_val
	spinbox.value = 0
	spinbox.value_changed.connect(_on_allocation_changed)
	
	hbox.add_child(label)
	hbox.add_child(spinbox)
	resource_sliders.add_child(hbox)
	
	element_spinboxes[element] = spinbox
	allocated_amounts[element] = 0

func _on_allocation_changed(_value: float) -> void:
	_update_payment_calculation()

func _update_payment_calculation() -> void:
	var total_allocated = 0
	for element in element_spinboxes.keys():
		var val = int(element_spinboxes[element].value)
		allocated_amounts[element] = val
		total_allocated += val
		
	var remaining = current_card_total_cost - total_allocated
	remaining_label.text = "Remaining Cost: %d" % remaining
	
	if total_allocated == current_card_total_cost:
		confirm_activation_button.disabled = false
	else:
		confirm_activation_button.disabled = true

func _on_confirm_payment() -> void:
	for element in allocated_amounts.keys():
		var amount = allocated_amounts[element]
		if amount > 0:
			match element:
				"火": GameManager.element_fire -= amount
				"土": GameManager.element_earth -= amount
				"金": GameManager.element_metal -= amount
				"木": GameManager.element_wood -= amount
				"水": GameManager.element_water -= amount
				"Aether": GameManager.aether -= amount
				
	_update_resource_ui()
	
	if pending_activation_slot:
		pending_activation_slot._activate_confirmed()
		has_manually_activated = true
		_update_end_turn_button()
		check_five_elements_array()
		
	payment_panel.hide()
	pending_activation_slot = null

func _on_cancel_payment() -> void:
	payment_panel.hide()
	pending_activation_slot = null

func _on_enemy_targeted(card_id: String = "", enemy_node: Node = null) -> void:
	if is_game_over: return
	
	if card_id == "":
		if pending_play_slot != null:
			card_id = pending_play_slot.get_meta("card_id", "")
			
	if enemy_node == null:
		enemy_node = enemy_entity
		
	if pending_play_slot != null or card_id != "":
		if card_id == "" or not card_db.has(card_id):
			print("ERROR: Attempted to execute an invalid card ID: ", card_id)
			if pending_play_slot:
				pending_play_slot._finalize_play()
				pending_play_slot = null
			return
			
		# Gather active sub slots to pass to manager
		var active_sub_ids = []
		if pending_play_slot:
			for sub_slot in pending_play_slot.sub_slots:
				if sub_slot.current_state == CardSlot.SlotState.ACTIVATED:
					var sub_id = sub_slot.get_meta("card_id", "")
					if sub_id != "":
						active_sub_ids.append(sub_id)

		# Execute on Battle Manager
		battle_manager.play_card(card_id, active_sub_ids, enemy_node)
		
		# UI Reset & reactivation
		if pending_play_slot:
			var slot_to_finalize = pending_play_slot
			slot_to_finalize._finalize_play()
			pending_play_slot = null
			
			if battle_manager.should_reactivate:
				slot_to_finalize.current_state = CardSlot.SlotState.INACTIVE
				slot_to_finalize._update_visuals()
				for sub_slot in slot_to_finalize.sub_slots:
					sub_slot.current_state = CardSlot.SlotState.INACTIVE
					sub_slot._update_visuals()
				print("淬火! Card reset to INACTIVE for repayment.")

		_update_resource_ui()
		_update_enemy_ui()

func check_five_elements_array() -> void:
	if GameManager.active_five_elements_array == "" or is_array_activated: return
	
	var active_count = 0
	for row in slots_container.get_children():
		if row is HBoxContainer:
			for slot in row.get_children():
				if slot is CardSlot and not slot.is_sub_slot:
					if slot.current_state == CardSlot.SlotState.ACTIVATED:
						active_count += 1
						
	if active_count == 5:
		is_array_activated = true
		array_button.disabled = false
		var array_id = GameManager.active_five_elements_array
		if array_db.has(array_id):
			var array_name = array_db[array_id]["name"]
			array_button.text = array_name + " (点击释放)"
			_spawn_floating_text("阵法充能完毕！", Color.GOLD)

func _on_array_button_pressed() -> void:
	if not is_array_activated: return
	
	is_array_activated = false
	array_button.disabled = true
	array_button.text = "阵法: 消耗中/未就绪"
	
	var array_id = GameManager.active_five_elements_array
	if array_db.has(array_id):
		var effects = array_db[array_id].get("effects", [])
		battle_manager.execute_array_effects(effects)
			
	_spawn_floating_text("阵法发动！", Color.CYAN)

func _activate_random_subslot() -> void:
	var inactive_subs = []
	for row in slots_container.get_children():
		if row is HBoxContainer:
			for slot in row.get_children():
				if slot is CardSlot and slot.is_sub_slot and slot.current_state == CardSlot.SlotState.INACTIVE:
					inactive_subs.append(slot)
	if inactive_subs.size() > 0:
		var chosen = inactive_subs[randi() % inactive_subs.size()]
		chosen.current_state = CardSlot.SlotState.ACTIVATED
		chosen._update_visuals()
		print("过载! Activated sub-slot: ", chosen.name)

func _spawn_floating_text(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	
	add_child(label)
	
	if enemy_entity:
		var target_pos = enemy_entity.global_position + Vector2(enemy_entity.size.x / 2 - 50, -30)
		target_pos += Vector2(randf_range(-20, 20), randf_range(-10, 10))
		label.global_position = target_pos
	else:
		label.global_position = Vector2(800, 100)
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -60), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", Color(color, 0.0), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(label.queue_free)

func _on_replace_button_pressed(slot_node: CardSlot) -> void:
	if reserve_cards.is_empty():
		print("Reserve deck is empty!")
		return
		
	current_replace_slot = slot_node
	
	var pool = reserve_cards.duplicate()
	pool.shuffle()
	
	var options = []
	for i in range(min(3, pool.size())):
		options.append(pool[i])
		
	for child in reserve_options.get_children():
		child.queue_free()
		
	for card_id in options:
		if not card_database.has(card_id):
			print("CRITICAL: Swap failed. ID '", card_id, "' not found")
			continue
			
		var btn = Button.new()
		var card_data = card_database[card_id]
		btn.text = card_data["name"] + "\nCost: " + _format_cost(card_data["cost"])
		btn.custom_minimum_size = Vector2(140, 180)
		btn.pressed.connect(_on_reserve_option_selected.bind(card_id))
		reserve_options.add_child(btn)
		
	reserve_panel.show()

func _on_reserve_option_selected(card_id: String) -> void:
	if GameManager.aether < 5:
		print("Not enough Aether to swap! Need 5.")
		return
		
	GameManager.aether -= 5
	_update_resource_ui()
	
	var old_card_id = current_replace_slot.get_meta("card_id", "")
	if old_card_id != "":
		reserve_cards.append(old_card_id)
		
	reserve_cards.erase(card_id)
	
	if not card_database.has(card_id):
		print("CRITICAL: Swap failed. ID '", card_id, "' not found")
		return
		
	current_replace_slot.set_meta("card_id", card_id)
	var card_data = card_database[card_id]
	current_replace_slot.name_label.text = card_data["name"]
	var stat_text = "Cost: " + _format_cost(card_data["cost"])
	if card_data["main_slot"]["type"] == "damage":
		stat_text += " | Dmg: " + str(card_data["main_slot"]["value"])
	elif card_data["main_slot"]["type"] == "shield":
		stat_text += " | Shd: " + str(card_data["main_slot"]["value"])
	current_replace_slot.stats_label.text = stat_text
	current_replace_slot.cost_dict = card_data["cost"].duplicate()
	current_replace_slot._update_visuals()
	
	reserve_panel.hide()
	current_replace_slot = null

func _on_reserve_cancel() -> void:
	reserve_panel.hide()
	current_replace_slot = null

func _on_end_turn_pressed() -> void:
	if is_game_over: return
	print("=== END TURN ===")
	
	if not has_manually_activated:
		GameManager.element_metal += 5
		GameManager.element_wood += 5
		GameManager.element_water += 5
		GameManager.element_fire += 5
		GameManager.element_earth += 5
		print("Yin Qi Ru Ti activated! Rewarded 5 elements.")
		
	battle_manager.end_turn()
	
	enemy_turn_counter = battle_manager.enemy_turn_counter
	enemy_atk_buff = battle_manager.enemy_atk_buff
	
	_update_enemy_intent()
	
	for row in slots_container.get_children():
		if row is HBoxContainer:
			for slot in row.get_children():
				if slot is CardSlot:
					slot.reset_turn()
					
	has_manually_activated = false
	_update_end_turn_button()
	_update_resource_ui()
	_update_status_displays()
	print("New turn started.")
	print(export_state_to_json())

func _update_enemy_ui() -> void:
	enemy_name_label.text = "%s (%s)" % [enemy_name, enemy_element]
	enemy_stats_label.text = "HP: %d/%d | Shield: %d" % [enemy_hp, enemy_max_hp, enemy_shield]
	
	if element_colors.has(enemy_element):
		var color = element_colors[enemy_element]
		enemy_name_label.modulate = color
		if enemy_entity:
			enemy_entity.self_modulate = color

func _trigger_game_over() -> void:
	print("GAME OVER")
	is_game_over = true
	GameManager.current_health = 0
	_update_resource_ui()
	
	if has_node("/root/GlobalHUD"):
		GlobalHUD.close_all_overlays()
	
	GameManager.switch_to_scene(GameManager.game_over_scene)

func _trigger_victory() -> void:
	print("VICTORY! Enemy Defeated.")
	is_game_over = true
	var target_btn = enemy_entity.get_node_or_null("TargetButton") if enemy_entity else null
	if target_btn:
		target_btn.disabled = true
		
	var loot_btn = Button.new()
	loot_btn.text = "收集战利品 (Collect Loot)"
	loot_btn.custom_minimum_size = Vector2(250, 60)
	loot_btn.add_theme_font_size_override("font_size", 20)
	
	loot_btn.set_anchors_preset(Control.PRESET_CENTER)
	loot_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loot_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	loot_btn.offset_left = -125
	loot_btn.offset_right = 125
	loot_btn.offset_top = -30
	loot_btn.offset_bottom = 30
	
	add_child(loot_btn)
	loot_btn.pressed.connect(_go_to_loot)

func _go_to_loot() -> void:
	if has_node("/root/GlobalHUD"):
		GlobalHUD.close_all_overlays()
	GameManager.switch_to_scene(GameManager.victory_scene)

func _update_enemy_intent() -> void:
	var intent_type = enemy_turn_counter % 3
	match intent_type:
		0:
			enemy_intent_label.text = "意图: 攻击 (%d 伤害)" % (base_attack_damage + enemy_atk_buff)
		1:
			enemy_intent_label.text = "意图: 防御 (15 护盾)"
		2:
			enemy_intent_label.text = "意图: 强化 (+3 攻击力)"

func export_state_to_json() -> String:
	var player_status = {
		"hp": GameManager.current_health,
		"max_hp": GameManager.max_health,
		"shield": player_shield,
		"elements": {
			"aether": GameManager.aether,
			"element_metal": GameManager.element_metal,
			"element_wood": GameManager.element_wood,
			"element_water": GameManager.element_water,
			"element_fire": GameManager.element_fire,
			"element_earth": GameManager.element_earth
		}
	}
	
	var deck_system: Array = []
	for row in slots_container.get_children():
		if row is HBoxContainer:
			for slot in row.get_children():
				if slot is CardSlot and not slot.is_sub_slot:
					deck_system.append(slot.to_dict())
					
	var combat_state = {
		"enemy_name": enemy_name,
		"enemy_element": enemy_element,
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"enemy_shield": enemy_shield,
		"player_statuses": player_statuses,
		"enemy_statuses": enemy_statuses
	}
	
	var state_dict = {
		"player_status": player_status,
		"deck_system": deck_system,
		"combat_state": combat_state
	}
	
	return JSON.stringify(state_dict, "\t")

# --- Visual Status Effect System ---
const STATUS_INFO = {
	"burn": {"name": "烧伤", "emoji": "🔥", "color": Color(0.95, 0.3, 0.2)},
	"frail": {"name": "脆化", "emoji": "☠️", "color": Color(0.8, 0.2, 0.8)},
	"weak": {"name": "虚弱", "emoji": "💤", "color": Color(0.5, 0.5, 0.7)},
	"slow": {"name": "减速", "emoji": "🐌", "color": Color(0.6, 0.4, 0.2)},
	"bleed": {"name": "流血", "emoji": "🩸", "color": Color(0.8, 0.1, 0.1)},
	"stun_attack": {"name": "禁锢", "emoji": "🕸️", "color": Color(0.4, 0.8, 0.9)},
	
	"thorns": {"name": "反震", "emoji": "🌵", "color": Color(0.3, 0.8, 0.3)},
	"damage_reduction": {"name": "合金", "emoji": "🛡️", "color": Color(0.9, 0.8, 0.2)},
	"retaliate_generate": {"name": "余烬", "emoji": "🌋", "color": Color(0.9, 0.5, 0.1)}
}

func _update_status_displays() -> void:
	if not enemy_status_container or not player_status_container:
		return
		
	for child in enemy_status_container.get_children():
		child.queue_free()
	for child in player_status_container.get_children():
		child.queue_free()
		
	for status_id in enemy_statuses.keys():
		var data = enemy_statuses[status_id]
		if data is Dictionary:
			_create_status_badge(status_id, data, enemy_status_container)
			
	for status_id in player_statuses.keys():
		var data = player_statuses[status_id]
		if data is Dictionary:
			_create_status_badge(status_id, data, player_status_container)

func _create_status_badge(status_id: String, status_data: Dictionary, container: HBoxContainer) -> void:
	var info = STATUS_INFO.get(status_id, {"name": status_id.capitalize(), "emoji": "✨", "color": Color(0.5, 0.5, 0.5)})
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = info["color"]
	style.bg_color.a = 0.22
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = info["color"]
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_top = 4
	style.content_margin_right = 8
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	var duration = status_data.get("duration", 1)
	var dur_text = ""
	if duration != -1:
		dur_text = " x%d" % duration
		
	label.text = info["emoji"] + " " + info["name"] + dur_text
	label.add_theme_color_override("font_color", info["color"].lightened(0.25))
	label.add_theme_font_size_override("font_size", 12)
	
	panel.add_child(label)
	container.add_child(panel)

func _on_debug_instakill_pressed() -> void:
	if is_game_over: 
		return
	print("DEBUG: Insta-kill triggered!")
	battle_manager.enemy_hp = 0
	battle_manager.emit_stats()
	battle_manager._trigger_victory()
