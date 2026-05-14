class_name ElementSystem
extends RefCounted

var enemy_element: String = ""
var enemy_element_layers: int = 0
var player_element: String = ""
var player_element_layers: int = 0
var enemy_element_queue: Array[String] = []


func attach(card_element: String, layers: int, target: String = "enemy") -> String:
	"""Attach element to enemy or player. Returns 'attach', 'stack', or the combo_key if a reaction triggers."""
	if card_element not in ["金", "木", "水", "火", "土"]:
		return "skip"

	if layers <= 0:
		return "skip"

	var current_element: String
	var current_layers: int

	if target == "player":
		current_element = player_element
		current_layers = player_element_layers
	else:
		current_element = enemy_element
		current_layers = enemy_element_layers

	if current_element == "" or current_layers <= 0:
		_set_element(target, card_element, layers)
		return "attach"

	if current_element == card_element:
		_add_layers(target, layers)
		return "stack"

	# Different element — reaction triggers
	_subtract_layers(target, 1)
	var el_arr = [card_element, current_element]
	el_arr.sort()
	var combo_key = el_arr[0] + "_" + el_arr[1]

	var remaining: int
	if target == "player":
		remaining = player_element_layers
	else:
		remaining = enemy_element_layers

	if remaining <= 0:
		if target == "enemy" and enemy_element_queue.size() > 0:
			var next_element = enemy_element_queue.pop_front()
			enemy_element = next_element
			enemy_element_layers = 1
			print("[ElementSystem] Next element in queue: ", next_element)
		else:
			_clear_element(target)

	return combo_key


func _set_element(target: String, el: String, layers: int) -> void:
	if target == "player":
		player_element = el
		player_element_layers = layers
	else:
		enemy_element = el
		enemy_element_layers = layers


func _add_layers(target: String, layers: int) -> void:
	if target == "player":
		player_element_layers += layers
	else:
		enemy_element_layers += layers


func _subtract_layers(target: String, layers: int) -> void:
	if target == "player":
		player_element_layers -= layers
	else:
		enemy_element_layers -= layers


func _clear_element(target: String) -> void:
	if target == "player":
		player_element = ""
		player_element_layers = 0
	else:
		enemy_element = ""
		enemy_element_layers = 0


func set_element(el: String) -> void:
	enemy_element = el
	if enemy_element != "":
		enemy_element_layers = max(1, enemy_element_layers)
	else:
		enemy_element_layers = 0


func set_enemy_queue(elements: Array[String]) -> void:
	"""Push all elements into the enemy queue. First element becomes current enemy_element with 1 layer."""
	enemy_element_queue.clear()
	if elements.is_empty():
		enemy_element = ""
		enemy_element_layers = 0
		return
	enemy_element = elements[0]
	enemy_element_layers = 1
	for i in range(1, elements.size()):
		enemy_element_queue.append(elements[i])


func reset() -> void:
	enemy_element = ""
	enemy_element_layers = 0
	player_element = ""
	player_element_layers = 0
	enemy_element_queue.clear()


func to_dict() -> Dictionary:
	return {
		"enemy_element": enemy_element,
		"enemy_element_layers": enemy_element_layers,
		"player_element": player_element,
		"player_element_layers": player_element_layers,
		"enemy_element_queue": enemy_element_queue.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	if d.is_empty(): return
	enemy_element = d.get("enemy_element", enemy_element)
	enemy_element_layers = d.get("enemy_element_layers", enemy_element_layers)
	player_element = d.get("player_element", player_element)
	player_element_layers = d.get("player_element_layers", player_element_layers)
	var queue_data = d.get("enemy_element_queue", [])
	if queue_data is Array:
		enemy_element_queue.clear()
		for item in queue_data:
			if item is String:
				enemy_element_queue.append(item)
