extends Node

const MAX_DECK_SIZE = 15

# Persistent player resource pool data
var max_health: int = 81
var current_health: int = 81
var aether: int = 81
var gold: int = 150
var element_metal: int = 0
var element_wood: int = 0
var element_water: int = 0
var element_fire: int = 0
var element_earth: int = 0

# Persistent progression & configuration data
var backpack_cards: Array[String] = [] # up to 30 cards
var reserve_cards: Array[String] = [] # tracking for deck reserves
var active_deck_layout: Array[Dictionary] = [] # configuration of main slots and sub-slots
var acquired_equipment: Array[String] = [] # permanent buffs, e.g. "小刀"
var active_five_elements_array: String = "" # ID of the current boss-dropped array, empty by default

# Map progression tracking variables
var current_world: int = 1
var current_node_index: int = 0
const NODE_TYPES = ["兵 (Battle)", "象 (Rest)", "马 (Shop)", "炮 (Event)", "兵 (Battle)", "士 (Elite)", "车 (Workshop)", "将/帅 (Boss)"]
var current_map_path: Array[String] = []

func _ready() -> void:
	# Populate starting backpack cards if empty
	if backpack_cards.is_empty():
		backpack_cards = [
			"fire_attack_001", "fire_attack_001", "earth_defense_001",
			"earth_rock_001", "wood_thorn_001", "earth_defense_001",
			"water_torrent_001", "water_torrent_001", "earth_defense_001",
			"metal_knife_001", "wood_growth_001", "fire_law_001"
		]
	if reserve_cards.is_empty():
		reserve_cards = backpack_cards.duplicate()

	# Populate default starter deck layout from battle_ui's initial setup
	if active_deck_layout.is_empty():
		active_deck_layout = [
			{"row": "SlotRow_1", "main": "fire_attack_001", "subs": ["fire_attack_001", "earth_defense_001"]},
			{"row": "SlotRow_2", "main": "earth_rock_001", "subs": ["wood_thorn_001", "earth_defense_001"]},
			{"row": "SlotRow_3", "main": "water_torrent_001", "subs": ["water_torrent_001", "earth_defense_001"]}
		]
		
	# Populate map path with 16 nodes
	if current_map_path.is_empty():
		generate_new_world()

func generate_new_world() -> void:
	if not current_map_path.is_empty():
		current_world += 1
		
	current_node_index = 0
	current_map_path.clear()
	
	for i in range(15):
		# Randomly pick from non-Boss types (indices 0 to 6)
		var random_type = NODE_TYPES[randi() % 7]
		current_map_path.append(random_type)
	# Ensure 16th is always "将/帅 (Boss)"
	current_map_path.append("将/帅 (Boss)")

func reset_run() -> void:
	max_health = 81
	current_health = 81
	aether = 81
	gold = 150
	element_metal = 0
	element_wood = 0
	element_water = 0
	element_fire = 0
	element_earth = 0
	
	backpack_cards = [
		"fire_attack_001", "fire_attack_001", "earth_defense_001",
		"earth_rock_001", "wood_thorn_001", "earth_defense_001",
		"water_torrent_001", "water_torrent_001", "earth_defense_001",
		"metal_knife_001", "wood_growth_001", "fire_law_001"
	]
	reserve_cards.clear()
	
	active_deck_layout = [
		{"row": "SlotRow_1", "main": "fire_attack_001", "subs": ["fire_attack_001", "earth_defense_001"]},
		{"row": "SlotRow_2", "main": "earth_rock_001", "subs": ["wood_thorn_001", "earth_defense_001"]},
		{"row": "SlotRow_3", "main": "water_torrent_001", "subs": ["water_torrent_001", "earth_defense_001"]}
	]
	
	acquired_equipment.clear()
	active_five_elements_array = ""
	
	current_world = 1
	current_map_path.clear()
	generate_new_world()
