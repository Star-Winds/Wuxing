# res://Components/deck_builder_backpack_zone.gd
extends ScrollContainer

func _can_drop_data(_position: Vector2, data) -> bool:
	return data is Dictionary and data.has("origin_type") and data["origin_type"] == "slot"

func _drop_data(_position: Vector2, data) -> void:
	var origin_slot = data["origin_slot"]
	if origin_slot != null:
		origin_slot.clear_slot()
	
	# Refresh views
	var ui_root = get_tree().get_first_node_in_group("deck_builder_root")
	if ui_root:
		if ui_root.has_method("update_backpack_view"):
			ui_root.update_backpack_view()
		elif ui_root.has_method("refresh_backpack_and_slots"):
			ui_root.refresh_backpack_and_slots()
