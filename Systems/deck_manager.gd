class_name DeckManager
extends RefCounted

const MAX_DECK_SIZE: int = 30

var card_pool: Array[CardData] = []

# 卡槽布局：[{"row": "SlotRow_1", "main": CardData, "subs": [CardData, CardData]}]
var active_deck_layout: Array[Dictionary] = []

signal layout_changed
signal pool_updated

func reset_run(starting_card_ids: Array[String]) -> void:
	card_pool.clear()
	active_deck_layout.clear()

	for card_id in starting_card_ids:
		var card = _lookup_card(card_id)
		if card:
			card_pool.append(card)
		else:
			printerr("DeckManager: 起始卡牌 ID '" + card_id + "' 未找到。")

func _lookup_card(card_id: String) -> CardData:
	if ResourceManager:
		return ResourceManager.get_card_data(card_id)
	return null

func get_card(card_id: String) -> CardData:
	return _lookup_card(card_id)

func add_card_to_pool(card: CardData) -> bool:
	if card_pool.size() >= MAX_DECK_SIZE:
		return false
	card_pool.append(card)
	pool_updated.emit()
	return true

func remove_card_from_pool(index: int) -> void:
	if index >= 0 and index < card_pool.size():
		card_pool.remove_at(index)
		pool_updated.emit()

func set_layout(layout: Array[Dictionary]) -> void:
	active_deck_layout = layout
	layout_changed.emit()

func get_main_card(row_index: int) -> CardData:
	if row_index < active_deck_layout.size():
		var data = active_deck_layout[row_index]
		var main = data.get("main")
		if main is CardData:
			return main
		if main is String and main != "":
			return _lookup_card(main)
	return null

func get_sub_cards(row_index: int) -> Array:
	if row_index < active_deck_layout.size():
		return active_deck_layout[row_index].get("subs", [])
	return []

func save_layout_from_slots(slots_map: Dictionary) -> Array[Dictionary]:
	var new_layout: Array[Dictionary] = []
	for i in range(1, 6):
		if not slots_map.has(i):
			continue
		new_layout.append({
			"row": "SlotRow_" + str(i),
			"main": slots_map[i]["main"].card_data,
			"subs": [slots_map[i]["subs"][0].card_data, slots_map[i]["subs"][1].card_data]
		})
	return new_layout


func to_dict() -> Dictionary:
	var pool_ids: Array[String] = []
	for card in card_pool:
		if card and not card.id.is_empty():
			pool_ids.append(card.id)

	var layout_data: Array = []
	for row in active_deck_layout:
		var row_dict := {
			"row": row.get("row", ""),
			"main": "",
			"subs": [],
		}
		var main_card = row.get("main")
		if main_card is CardData:
			row_dict["main"] = main_card.id
		elif main_card is String:
			row_dict["main"] = main_card
		var subs = row.get("subs", [])
		for sub in subs:
			if sub is CardData:
				row_dict["subs"].append(sub.id)
			elif sub is String:
				row_dict["subs"].append(sub)
		layout_data.append(row_dict)

	return {"card_pool": pool_ids, "active_deck_layout": layout_data}


func from_dict(d: Dictionary) -> void:
	if d.is_empty(): return

	card_pool.clear()
	var pool_ids: Array = d.get("card_pool", [])
	for card_id in pool_ids:
		var card := _lookup_card(card_id)
		if card:
			card_pool.append(card)
		else:
			printerr("DeckManager.from_dict: card not found: ", card_id)

	active_deck_layout.clear()
	var layout_data: Array = d.get("active_deck_layout", [])
	for row_dict in layout_data:
		var new_row := {
			"row": row_dict.get("row", ""),
			"main": null,
			"subs": [],
		}
		var main_id: String = row_dict.get("main", "")
		if main_id != "":
			new_row["main"] = _lookup_card(main_id)
		var sub_ids: Array = row_dict.get("subs", [])
		for sub_id in sub_ids:
			var sub_card := _lookup_card(sub_id)
			if sub_card:
				new_row["subs"].append(sub_card)
		active_deck_layout.append(new_row)
