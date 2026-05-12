extends Node

const CARD_DATA_CONST = preload("res://Resources/Scripts/Card_data.gd")

# --- 场景资源管理 ---
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

# --- 数据仓库 ---
var all_cards: Dictionary:
	get:
		if ResourceManager:
			return ResourceManager.all_cards
		return {}
var equipped_reactions: Dictionary = {}
var MAX_DECK_SIZE: int = 15

# --- 玩家持久化数据 ---
var max_health: int = 81
var current_health: int = 81
var aether: int = 81
var gold: int = 150
var element_metal: int = 0
var element_wood: int = 0
var element_water: int = 0
var element_fire: int = 0
var element_earth: int = 0

# --- 卡组数据结构重构 ---
# 现在我们存储 CardData 实例，而不是 String ID
var backpack_cards: Array[CardData] = [] 
var reserve_cards: Array[CardData] = [] 
var active_deck_layout: Array[Dictionary] = [] # 内部存储：{"main": CardData, "subs": [CardData, CardData]}

var acquired_equipment: Array[String] = [] 
var active_five_elements_array: String = "" 

# --- 地图进度 ---
const NODE_TYPES = ["兵 (Battle)", "象 (Rest)", "马 (Shop)", "炮 (Event)", "兵 (Battle)", "士 (Elite)", "车 (Workshop)", "将/帅 (Boss)"]
var current_world: int = 1
var current_node_index: int = 0
var current_map_path: Array[String] = []

func _ready() -> void:
	_initialize_default_reactions() # 2. 初始化反应系统
	# Convert string references on boot if any exist (e.g. legacy/editor placeholders)
	_convert_string_references_to_resources()
	# reset_run() # 如果需要开始即初始化，取消注释

# --- 逻辑重构：初始化新战局 ---
func reset_run() -> void:
	current_health = max_health
	aether = 81
	gold = 150
	# ... 重置元素 ...
	
	# 从加载好的资源库中通过 ID 引用
	# IMPORTANT: IDs here must match the 'id' field inside each .tres file exactly.
	backpack_cards.clear()
	var starting_ids: Array[String] = ["Fire_A_001", "Fire_A_001", "Earth_D_001"]
	for card_id in starting_ids:
		if all_cards.has(card_id):
			backpack_cards.append(all_cards[card_id])
		else:
			printerr("reset_run: 起始卡牌 ID '" + card_id + "' 未在 all_cards 中找到。请检查 .tres 文件的 id 字段。")
	
	# 初始化卡槽布局 (使用 CardData 对象)
	# 使用辅助函数安全获取，避免 null 传入布局
	active_deck_layout = [
		{
			"row": "SlotRow_1",
			"main": _safe_get_card("Fire_A_001"),
			"subs": [_safe_get_card("Fire_A_001"), _safe_get_card("Earth_D_001")]
		}
	]
	
	current_world = 1
	generate_new_world()

# --- 原有场景切换与反应逻辑 (保持并微调) ---
func _initialize_default_reactions() -> void:
	# ... (保持原有的 JSON 加载逻辑，因为反应目前还是 JSON 驱动)
	# 注意：如果未来反应也改为 .tres，可以参考上面的扫描逻辑
	pass

func switch_to_scene(target_scene: PackedScene) -> void:
	if target_scene: get_tree().change_scene_to_packed(target_scene)

func generate_new_world() -> void:
	current_node_index = 0
	current_map_path.clear()
	for i in range(15):
		current_map_path.append(NODE_TYPES[randi() % 7])
	current_map_path.append("将/帅 (Boss)")

func enter_current_node() -> void:
	var node_type = current_map_path[current_node_index]
	if "Battle" in node_type or "Elite" in node_type or "Boss" in node_type:
		switch_to_scene(battle_scene)
	elif "Rest" in node_type: switch_to_scene(rest_scene)
	elif "Shop" in node_type: switch_to_scene(shop_scene)
	elif "Event" in node_type: switch_to_scene(event_scene)
	elif "Workshop" in node_type: switch_to_scene(workshop_scene)

# --- 辅助函数：安全获取卡牌资源 ---
# 用此函数替代直接调用 all_cards.get()，防止静默 null 进入布局数组。
func _safe_get_card(card_id: String) -> CardData:
	if ResourceManager:
		return ResourceManager.get_card_data(card_id)
	return null

func get_card_data(card_id: String) -> CardData:
	return _safe_get_card(card_id)

func _convert_string_references_to_resources() -> void:
	# Ensure ResourceManager is fully initialized and cards are loaded first
	if ResourceManager and ResourceManager.all_cards.is_empty():
		ResourceManager.load_all_card_resources()

	# Convert backpack_cards
	var converted_backpack: Array[CardData] = []
	var untyped_backpack: Array = backpack_cards
	for item in untyped_backpack:
		if item is CardData:
			converted_backpack.append(item)
		elif item is String and item != "":
			var card_res = get_card_data(item)
			if card_res:
				converted_backpack.append(card_res)
			else:
				push_error("Failed to convert backpack card ID to resource: " + item)
	backpack_cards = converted_backpack

	# Convert reserve_cards
	var converted_reserve: Array[CardData] = []
	var untyped_reserve: Array = reserve_cards
	for item in untyped_reserve:
		if item is CardData:
			converted_reserve.append(item)
		elif item is String and item != "":
			var card_res = get_card_data(item)
			if card_res:
				converted_reserve.append(card_res)
			else:
				push_error("Failed to convert reserve card ID to resource: " + item)
	reserve_cards = converted_reserve

	# Convert active_deck_layout
	for row_data in active_deck_layout:
		var main_card = row_data.get("main")
		if main_card is String and main_card != "":
			var card_res = get_card_data(main_card)
			if card_res:
				row_data["main"] = card_res
			else:
				push_error("Failed to convert active layout main card ID to resource: " + main_card)
		
		var subs = row_data.get("subs", [])
		for j in range(subs.size()):
			var sub_card = subs[j]
			if sub_card is String and sub_card != "":
				var card_res = get_card_data(sub_card)
				if card_res:
					subs[j] = card_res
				else:
					push_error("Failed to convert active layout sub card ID to resource: " + sub_card)

# --- 供 BattleManager 调用的玩家状态广播 ---
func update_player_stats() -> void:
	# 如有信号或 UI 节点需要同步，在此扩展。
	pass