class_name ElementSystem
extends RefCounted

var enemy_element: String = ""
var enemy_element_layers: int = 0


func attach(card_element: String, layers: int) -> String:
	"""Attach element to enemy. Returns 'attach', 'stack', or the combo_key if a reaction triggers."""
	if card_element not in ["金", "木", "水", "火", "土"]:
		return "skip"

	if layers <= 0:
		return "skip"

	if enemy_element == "" or enemy_element_layers <= 0:
		enemy_element = card_element
		enemy_element_layers = layers
		return "attach"

	if enemy_element == card_element:
		enemy_element_layers += layers
		return "stack"

	# Different element — reaction triggers
	enemy_element_layers -= 1
	var el_arr = [card_element, enemy_element]
	el_arr.sort()
	var combo_key = el_arr[0] + "_" + el_arr[1]

	if enemy_element_layers <= 0:
		enemy_element = ""

	return combo_key


func set_element(el: String) -> void:
	enemy_element = el
	if enemy_element != "":
		enemy_element_layers = max(1, enemy_element_layers)
	else:
		enemy_element_layers = 0


func reset() -> void:
	enemy_element = ""
	enemy_element_layers = 0


func to_dict() -> Dictionary:
	return {
		"enemy_element": enemy_element,
		"enemy_element_layers": enemy_element_layers,
	}


func from_dict(d: Dictionary) -> void:
	if d.is_empty(): return
	enemy_element = d.get("enemy_element", enemy_element)
	enemy_element_layers = d.get("enemy_element_layers", enemy_element_layers)
