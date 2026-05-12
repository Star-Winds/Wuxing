extends Control

# UI References
@onready var water_fire_btn: Button = $CenterContainer/VBoxContainer/ArchetypesContainer/WaterFireCard/SelectButton
@onready var earth_wood_btn: Button = $CenterContainer/VBoxContainer/ArchetypesContainer/EarthWoodCard/SelectButton
@onready var chaos_btn: Button = $CenterContainer/VBoxContainer/ArchetypesContainer/ChaosCard/SelectButton

# All loaded card resources categorized by element
var card_pools: Dictionary = {
	"金": [],
	"木": [],
	"水": [],
	"火": [],
	"土": [],
	"以太": []
}

func _ready() -> void:
	# Hide global HUD during deck selection
	if has_node("/root/GlobalHUD"):
		get_node("/root/GlobalHUD").visible = false
		
	# Connect buttons safely
	if water_fire_btn and not water_fire_btn.pressed.is_connected(_on_water_fire_selected):
		water_fire_btn.pressed.connect(_on_water_fire_selected)
	if earth_wood_btn and not earth_wood_btn.pressed.is_connected(_on_earth_wood_selected):
		earth_wood_btn.pressed.connect(_on_earth_wood_selected)
	if chaos_btn and not chaos_btn.pressed.is_connected(_on_chaos_selected):
		chaos_btn.pressed.connect(_on_chaos_selected)
	
	# Load all cards by element
	load_cards_by_element()

func load_cards_by_element() -> void:
	# Scan recursively starting from the base cards directory
	_scan_cards_recursive("res://Resources/Cards/")
	
	var debug_str = "InitialDeckSelection: Loaded pools -> "
	for el in card_pools:
		debug_str += "%s: %d cards | " % [el, card_pools[el].size()]
	print(debug_str)

func _scan_cards_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		printerr("InitialDeckSelection: Cannot open directory: ", path)
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				_scan_cards_recursive(path + file_name + "/")
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var card = load(path + file_name)
			if card is CardData:
				var element = card.element
				if card_pools.has(element):
					card_pools[element].append(card)
				else:
					card_pools[element] = [card]
		file_name = dir.get_next()

func _generate_deck(elements: Array) -> Array[CardData]:
	var candidate_pool: Array[CardData] = []
	for el in elements:
		if card_pools.has(el):
			for card in card_pools[el]:
				candidate_pool.append(card)
				
	var selected_deck: Array[CardData] = []
	if candidate_pool.is_empty():
		printerr("InitialDeckSelection: Candidate pool is empty for elements: ", elements)
		# Fallback to loading any cards from GameManager or ResourceManager
		if GameManager and not GameManager.all_cards.is_empty():
			for card_id in GameManager.all_cards:
				candidate_pool.append(GameManager.all_cards[card_id])
				
	if candidate_pool.is_empty():
		push_error("Critical Error: No card data found anywhere!")
		return selected_deck
		
	for i in range(15):
		var rand_idx = randi() % candidate_pool.size()
		selected_deck.append(candidate_pool[rand_idx])
		
	return selected_deck

func _finalize_selection(selected_deck: Array[CardData]) -> void:
	if selected_deck.is_empty():
		push_error("Error: Selected deck is empty!")
		return
		
	# 1. Reset run to prepare new game statistics (health, gold, first world)
	GameManager.reset_run()
	
	# 2. Overwrite the default backpack with our 15 selected cards
	GameManager.backpack_cards.clear()
	for card in selected_deck:
		GameManager.backpack_cards.append(card)
		
	# 3. Safely initialize active deck layout using the first 3 cards from selected archetype
	# This ensures combat pipeline doesn't throw null reference exceptions on start
	if selected_deck.size() >= 3:
		GameManager.active_deck_layout = [
			{
				"row": "SlotRow_1",
				"main": selected_deck[0],
				"subs": [selected_deck[1], selected_deck[2]]
			}
		]
	else:
		# Fallback if deck is too small
		GameManager.active_deck_layout = [
			{
				"row": "SlotRow_1",
				"main": selected_deck[0],
				"subs": []
			}
		]
	
	print("InitialDeckSelection: Backpack cards successfully populated! Size: ", GameManager.backpack_cards.size())
	
	# 4. Transition to the Map UI
	GameManager.switch_to_scene(GameManager.map_scene)

func _on_water_fire_selected() -> void:
	print("InitialDeckSelection: Selected Water & Fire path.")
	var deck = _generate_deck(["水", "火"])
	_finalize_selection(deck)

func _on_earth_wood_selected() -> void:
	print("InitialDeckSelection: Selected Earth & Wood path.")
	var deck = _generate_deck(["土", "木"])
	_finalize_selection(deck)

func _on_chaos_selected() -> void:
	print("InitialDeckSelection: Selected Path of Chaos.")
	var deck = _generate_deck(["金", "木", "水", "火", "土", "以太"])
	_finalize_selection(deck)
