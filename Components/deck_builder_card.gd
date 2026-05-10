# res://Components/deck_builder_card.gd
extends Button

var card_id: String = ""
var card_name: String = ""
var is_equipped: bool = false
var origin_slot = null

func _get_drag_data(_position: Vector2):
	var data = {
		"card_id": card_id,
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
