# res://Components/deck_builder_card.gd
extends Button

const CARD_DATA_CONST = preload("res://Data/Card_data.gd")

var card_data: CardData = null
var is_equipped: bool = false
var origin_slot = null

func set_card_data(data: CardData) -> void:
	if not data:
		push_error("DeckBuilderCard received null data!")
		return
	card_data = data
	custom_minimum_size = Vector2(170, 110)
	
	var element = card_data.element
	var color = Color(0.2, 0.2, 0.22, 1)
	match element:
		"火": color = Color(0.5, 0.2, 0.15, 1)
		"木": color = Color(0.15, 0.45, 0.2, 1)
		"水": color = Color(0.15, 0.25, 0.5, 1)
		"金": color = Color(0.5, 0.45, 0.15, 1)
		"土": color = Color(0.35, 0.25, 0.2, 1)
		"以太": color = Color(0.35, 0.15, 0.45, 1)
		
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_font_size_override("font_size", 15)
	
	var cost_str = _format_cost(card_data.get_total_cost())
	text = "%s\n[%s]\nCost: %s" % [
		card_data.card_name,
		element,
		cost_str
	]
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("normal", style)

func _format_cost(cost_dict: Dictionary) -> String:
	var result = []
	for key in cost_dict.keys():
		result.append(str(cost_dict[key]) + key)
	return ", ".join(result)

func _get_drag_data(_position: Vector2):
	var data = {
		"card_data": card_data,
		"origin_type": "backpack" if not is_equipped else "slot",
		"origin_node": self,
		"origin_slot": origin_slot
	}
	
	# Set drag visual preview
	var preview = Button.new()
	preview.text = text
	preview.custom_minimum_size = Vector2(160, 80)
	preview.add_theme_font_size_override("font_size", 12)
	set_drag_preview(preview)
	
	return data
