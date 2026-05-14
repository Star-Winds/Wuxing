# res://Components/deck_builder_slot.gd
extends PanelContainer

const CARD_DATA_CONST = preload("res://Data/Card_data.gd")

var slot_type: String = "" # "main" or "sub"
var row_index: int = 0
var sub_slot_index: int = 0 # 1 or 2
var card_data: CardData = null

var current_card_id: String:
	get:
		return card_data.id if card_data else ""

@onready var name_label: Label = $VBox/NameLabel
@onready var stats_label: Label = $VBox/StatsLabel

# Store pending card values for when _ready() runs
var _pending_card_data: CardData = null
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
	if _pending_card_data:
		set_card(_pending_card_data)
	else:
		_update_display()

func set_card(new_card_data: CardData) -> void:
	card_data = new_card_data
	_pending_card_data = new_card_data
	
	if not _is_ready:
		return
		
	_update_display()

func _update_display() -> void:
	if card_data == null:
		if slot_type == "main":
			name_label.text = "[Empty Main Slot]"
		else:
			name_label.text = "[Empty Sub Slot %d]" % sub_slot_index
		stats_label.text = "Drag card here"
		self.self_modulate = Color(0.2, 0.2, 0.25, 0.8)
	else:
		name_label.text = card_data.card_name + " [" + card_data.element + "]"
		var auto_desc = card_data.get_auto_description(slot_type == "sub")
		if not auto_desc.is_empty():
			stats_label.text = auto_desc
		else:
			stats_label.text = card_data.description
		
		# Set aesthetic color according to element
		var color = Color(0.3, 0.3, 0.4, 1)
		match card_data.element:
			"火": color = Color(0.6, 0.2, 0.1, 1)
			"木": color = Color(0.15, 0.5, 0.15, 1)
			"水": color = Color(0.1, 0.3, 0.6, 1)
			"金": color = Color(0.6, 0.5, 0.1, 1)
			"土": color = Color(0.4, 0.3, 0.2, 1)
			"以太": color = Color(0.4, 0.15, 0.5, 1)
		self.self_modulate = color

func clear_slot() -> void:
	set_card(null)

func _get_drag_data(_position: Vector2) -> Variant:
	if card_data == null:
		return null # Empty slot, nothing to drag
		
	# Create a beautiful visual drag preview using card name
	var preview = Button.new()
	preview.text = name_label.text
	preview.custom_minimum_size = Vector2(160, 80)
	preview.add_theme_font_size_override("font_size", 12)
	set_drag_preview(preview)
	
	# Return the drag data packet
	return {
		"card_data": card_data,
		"origin_type": "slot",
		"origin_node": self,
		"origin_slot": self,
		"source_slot": self
	}

func _can_drop_data(_position: Vector2, data) -> bool:
	return data is Dictionary and data.has("card_data")

func _drop_data(_position: Vector2, data) -> void:
	var dropped_card_data = data["card_data"]
	var origin_type = data["origin_type"]
	var origin_slot = data["origin_slot"]
	
	# If card was dragged from another slot, clear that slot first
	if origin_type == "slot" and origin_slot != null:
		origin_slot.clear_slot()
		
	# Update this slot
	set_card(dropped_card_data)
	
	var ui_root = get_tree().get_first_node_in_group("deck_builder_root")
	if ui_root:
		# Refresh backpack
		if ui_root.has_method("update_backpack_view"):
			ui_root.update_backpack_view()
