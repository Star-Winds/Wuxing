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
