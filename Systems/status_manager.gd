class_name StatusManager
extends RefCounted

var enemy_statuses: Dictionary = {}
var player_statuses: Dictionary = {}


func apply(status_id: String, amount: int, duration: int, target: String) -> Dictionary:
	var dict = _dict_for(target)
	var dur = duration if duration > 0 else 1
	var amt = amount if amount > 0 else 1
	dict[status_id] = {"duration": dur, "amount": amt}
	return dict.duplicate()


func decay(target: String) -> void:
	var dict = _dict_for(target)
	var to_remove: Array[String] = []
	for key in dict.keys():
		var data = dict[key]
		if data is Dictionary and data.has("duration"):
			data["duration"] -= 1
			if data["duration"] <= 0:
				to_remove.append(key)
		else:
			to_remove.append(key)
	for key in to_remove:
		dict.erase(key)


func has(status_id: String, target: String) -> bool:
	return _dict_for(target).has(status_id)


func get_data(status_id: String, target: String) -> Dictionary:
	return _dict_for(target).get(status_id, {})


func get_all(target: String) -> Dictionary:
	return _dict_for(target).duplicate()


func pop_damage(status_id: String, target: String) -> int:
	var data = get_data(status_id, target)
	return data.get("amount", 0)


func reset() -> void:
	enemy_statuses.clear()
	player_statuses.clear()


func _dict_for(target: String) -> Dictionary:
	return player_statuses if target == "player" else enemy_statuses
