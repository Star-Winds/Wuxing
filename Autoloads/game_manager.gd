extends Node

# --- 资源注册表 (Scene Registry) ---
# 在编辑器中将对应的 .tscn 文件拖入以下变量位
@export_group("场景资源管理")
@export var main_menu_scene: PackedScene
@export var map_scene: PackedScene
@export var battle_scene: PackedScene
@export var shop_scene: PackedScene
@export var rest_scene: PackedScene
@export var event_scene: PackedScene
@export var workshop_scene: PackedScene
@export var victory_scene: PackedScene
@export var game_over_scene: PackedScene
@export var game_win_scene: PackedScene
@export var deck_builder_scene: PackedScene
@export var reaction_overlay_scene: PackedScene
const MAX_DECK_SIZE = 15

# 持久化玩家资源数据
var max_health: int = 81
var current_health: int = 81
var aether: int = 81
var gold: int = 150
var element_metal: int = 0
var element_wood: int = 0
var element_water: int = 0
var element_fire: int = 0
var element_earth: int = 0

# 进度与配置数据
var backpack_cards: Array[String] = [] 
var reserve_cards: Array[String] = [] 
var active_deck_layout: Array[Dictionary] = [] 
var acquired_equipment: Array[String] = [] 
var active_five_elements_array: String = "" 

# 地图进度变量
var current_world: int = 1
var current_node_index: int = 0
const NODE_TYPES = ["兵 (Battle)", "象 (Rest)", "马 (Shop)", "炮 (Event)", "兵 (Battle)", "士 (Elite)", "车 (Workshop)", "将/帅 (Boss)"]
var current_map_path: Array[String] = []

# --- 通用场景切换逻辑 ---
func switch_to_scene(target_scene: PackedScene) -> void:
	if target_scene:
		get_tree().change_scene_to_packed(target_scene)
	else:
		printerr("错误: 尝试跳转的场景资源未在 GameManager 中赋值！")

# 针对地图节点类型的自动跳转逻辑
func enter_current_node() -> void:
	var node_type = current_map_path[current_node_index]
	if "Battle" in node_type or "Elite" in node_type or "Boss" in node_type:
		switch_to_scene(battle_scene)
	elif "Rest" in node_type:
		switch_to_scene(rest_scene)
	elif "Shop" in node_type:
		switch_to_scene(shop_scene)
	elif "Event" in node_type:
		switch_to_scene(event_scene)
	elif "Workshop" in node_type:
		switch_to_scene(workshop_scene)

# --- 原有逻辑保持 ---
func generate_new_world() -> void:
	if not current_map_path.is_empty():
		current_world += 1
		
	current_node_index = 0
	current_map_path.clear()
	
	for i in range(15):
		var random_type = NODE_TYPES[randi() % 7]
		current_map_path.append(random_type)
	current_map_path.append("将/帅 (Boss)")

func reset_run() -> void:
	max_health = 81
	current_health = 81
	aether = 81
	gold = 150
	# ... 初始化元素数据 ...
	
	backpack_cards = [
		"fire_attack_001", "fire_attack_001", "earth_defense_001",
		"earth_rock_001", "wood_thorn_001", "earth_defense_001",
		"water_torrent_001", "water_torrent_001", "earth_defense_001",
		"metal_knife_001", "wood_growth_001", "fire_law_001"
	]
	
	active_deck_layout = [
		{"row": "SlotRow_1", "main": "fire_attack_001", "subs": ["fire_attack_001", "earth_defense_001"]},
		{"row": "SlotRow_2", "main": "earth_rock_001", "subs": ["wood_thorn_001", "earth_defense_001"]},
		{"row": "SlotRow_3", "main": "water_torrent_001", "subs": ["water_torrent_001", "earth_defense_001"]}
	]
	
	current_world = 1
	generate_new_world()

var equipped_reactions: Dictionary = {}

func _ready() -> void:
	_initialize_default_reactions()

func _initialize_default_reactions() -> void:
	equipped_reactions.clear()
	var file = FileAccess.open("res://Databases/reaction_database.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var db = JSON.parse_string(content)
		if db is Dictionary:
			var elements = ["火", "水", "木", "金", "土"]
			for i in range(elements.size()):
				for j in range(i + 1, elements.size()):
					var e1 = elements[i]
					var e2 = elements[j]
					
					var sorted_elements = [e1, e2]
					sorted_elements.sort()
					var key = sorted_elements[0] + "_" + sorted_elements[1]
					
					# Default logic: Use alphabetically first element attacking second element
					if db.has(sorted_elements[0]) and db[sorted_elements[0]].has(sorted_elements[1]):
						var reaction_data = db[sorted_elements[0]][sorted_elements[1]]
						var new_reaction = ReactionEffect.new()
						var comb_typed: Array[String] = []
						comb_typed.append(sorted_elements[0])
						comb_typed.append(sorted_elements[1])
						new_reaction.combination = comb_typed
						new_reaction.reaction_name = reaction_data.get("name", "")
						new_reaction.description = reaction_data.get("description", "")
						new_reaction.effect = reaction_data.duplicate()
						
						equipped_reactions[key] = new_reaction

func learn_new_reaction(new_reaction_res: ReactionEffect) -> void:
	var key = new_reaction_res.get_combination_key()
	if key != "":
		equipped_reactions[key] = new_reaction_res
