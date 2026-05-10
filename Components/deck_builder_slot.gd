# res://Components/deck_builder_slot.gd
extends PanelContainer

var slot_type: String = "" # "main" or "sub"
var row_index: int = 0
var sub_slot_index: int = 0 # 1 or 2
var current_card_id: String = ""

@onready var name_label: Label = $VBox/NameLabel
@onready var stats_label: Label = $VBox/StatsLabel

# Store pending card values for when _ready() runs
var _pending_card_id: String = ""
var _pending_name: String = ""
var _pending_element: String = ""
var _pending_desc: String = ""
var _is_ready: bool = false

func _ready() -> void:
	_is_ready = true
	# Add a stylebox override to make background coloring visible
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1) # Modulate will color this
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)
	
	# Apply any card information that was set before _ready
	set_card(_pending_card_id, _pending_name, _pending_element, _pending_desc)

func set_card(card_id: String, c_name: String, element: String, desc: String) -> void:
	current_card_id = card_id
	_pending_card_id = card_id
	_pending_name = c_name
	_pending_element = element
	_pending_desc = desc
	
	if not _is_ready:
		return
		
	if card_id == "":
		if slot_type == "main":
			name_label.text = "[Empty Main Slot]"
		else:
			name_label.text = "[Empty Sub Slot %d]" % sub_slot_index
		stats_label.text = "Drag card here"
		self.self_modulate = Color(0.2, 0.2, 0.25, 0.8)
	else:
		name_label.text = c_name + " [" + element + "]"
		stats_label.text = desc
		
		# Set aesthetic color according to element
		var color = Color(0.3, 0.3, 0.4, 1)
		match element:
			"火": color = Color(0.6, 0.2, 0.1, 1)
			"木": color = Color(0.15, 0.5, 0.15, 1)
			"水": color = Color(0.1, 0.3, 0.6, 1)
			"金": color = Color(0.6, 0.5, 0.1, 1)
			"土": color = Color(0.4, 0.3, 0.2, 1)
			"以太": color = Color(0.4, 0.15, 0.5, 1)
		self.self_modulate = color

func clear_slot() -> void:
	set_card("", "", "", "")

func _get_drag_data(_position: Vector2) -> Variant:
	if current_card_id == "":
		return null # Empty slot, nothing to drag
		
	# Create a beautiful visual drag preview using card name
	var preview = Button.new()
	preview.text = name_label.text
	preview.custom_minimum_size = Vector2(160, 80)
	preview.add_theme_font_size_override("font_size", 12)
	set_drag_preview(preview)
	
	# Return the drag data packet
	return {
		"card_id": current_card_id,
		"origin_type": "slot",
		"origin_node": self,
		"origin_slot": self,
		"source_slot": self
	}

func _can_drop_data(_position: Vector2, data) -> bool:
	return data is Dictionary and data.has("card_id")

func _drop_data(_position: Vector2, data) -> void:
	var dropped_card_id = data["card_id"]
	var origin_type = data["origin_type"]
	var origin_slot = data["origin_slot"]
	
	# If card was dragged from another slot, clear that slot first
	if origin_type == "slot" and origin_slot != null:
		origin_slot.clear_slot()
		
	# Update this slot
	var ui_root = get_tree().get_first_node_in_group("deck_builder_root")
	if ui_root:
		var card_data = ui_root.card_database.get(dropped_card_id, {})
		var c_name = card_data.get("name", dropped_card_id)
		var c_elem = card_data.get("element", "")
		var c_desc = ""
		if slot_type == "main":
			c_desc = card_data.get("main_slot", {}).get("description", "")
		else:
			c_desc = card_data.get("sub_slot", {}).get("description", "")
			
		set_card(dropped_card_id, c_name, c_elem, c_desc)
		
		# Refresh backpack
		if ui_root.has_method("update_backpack_view"):
			ui_root.update_backpack_view()
