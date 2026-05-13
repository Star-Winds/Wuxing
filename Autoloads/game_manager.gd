extends Node

const CARD_DATA_CONST = preload("res://Data/Card_data.gd")

# --- 子模块 ---
var player_state: PlayerState
var deck_manager: DeckManager
var reaction_system: ReactionSystem
var action_queue: ActionQueue

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
@export var boss_reward_scene: PackedScene = preload("res://UI/boss_reward_ui.tscn")

# ============================================================
#  向后兼容代理属性
#  新代码应直接使用子模块，旧代码通过此代理逐步迁移
# ============================================================

# --- 玩家状态代理 ---
var max_health: int:
	get: return player_state.max_health if player_state else 81
	set(v):
		if player_state: player_state.max_health = v

var current_health: int:
	get: return player_state.current_health if player_state else 81
	set(v):
		if player_state: player_state.current_health = v

var aether: int:
	get: return player_state.aether if player_state else 81
	set(v):
		if player_state: player_state.aether = v

var gold: int:
	get: return player_state.gold if player_state else 150
	set(v):
		if player_state: player_state.gold = v

var element_metal: int:
	get: return player_state.element_metal if player_state else 0
	set(v):
		if player_state: player_state.element_metal = v

var element_wood: int:
	get: return player_state.element_wood if player_state else 0
	set(v):
		if player_state: player_state.element_wood = v

var element_water: int:
	get: return player_state.element_water if player_state else 0
	set(v):
		if player_state: player_state.element_water = v

var element_fire: int:
	get: return player_state.element_fire if player_state else 0
	set(v):
		if player_state: player_state.element_fire = v

var element_earth: int:
	get: return player_state.element_earth if player_state else 0
	set(v):
		if player_state: player_state.element_earth = v

var acquired_equipment: Array[String]:
	get: return player_state.acquired_equipment if player_state else ([] as Array[String])
	set(v):
		if player_state: player_state.acquired_equipment = v

# --- 卡组代理 ---
var card_pool: Array[CardData]:
	get: return deck_manager.card_pool if deck_manager else []
	set(v):
		if deck_manager: deck_manager.card_pool = v

var active_deck_layout: Array[Dictionary]:
	get: return deck_manager.active_deck_layout if deck_manager else []
	set(v):
		if deck_manager: deck_manager.active_deck_layout = v

var MAX_DECK_SIZE: int:
	get: return DeckManager.MAX_DECK_SIZE

# --- 反应系统代理 ---
var owned_reactions: Array[ReactionData]:
	get: return reaction_system.owned_reactions if reaction_system else []
	set(v):
		if reaction_system: reaction_system.owned_reactions = v

var equipped_reactions: Dictionary:
	get: return reaction_system.equipped_reactions if reaction_system else {}
	set(v):
		if reaction_system: reaction_system.equipped_reactions = v

# --- 五行阵法（Boss 掉落，World 1 后获得）---
var active_formation: FormationData = null
var has_formation: bool:
	get: return active_formation != null

# --- 数据仓库 ---
var all_cards: Dictionary:
	get:
		if ResourceManager:
			return ResourceManager.all_cards
		return {}

# --- 地图进度 ---
const NODE_TYPES = ["兵 (Battle)", "象 (Rest)", "马 (Shop)", "炮 (Event)", "兵 (Battle)", "士 (Elite)", "车 (Workshop)", "将/帅 (Boss)"]
var current_world: int = 1
var current_node_index: int = 0
var current_map_path: Array[String] = []


func _ready() -> void:
	# 初始化子模块
	player_state = PlayerState.new()
	deck_manager = DeckManager.new()
	reaction_system = ReactionSystem.new()

	reaction_system.initialize_defaults()
	action_queue = ActionQueue.new()
	add_child(action_queue)

	# 从编辑器/旧存档兼容 String 引用
	_convert_string_references_to_resources()


# ============================================================
#  新战局初始化
# ============================================================
func reset_run() -> void:
	player_state.reset_run()
	deck_manager.reset_run(["Fire_001", "Fire_001", "Earth_007"])

	deck_manager.active_deck_layout = [
		{
			"row": "SlotRow_1",
			"main": _safe_get_card("Fire_001"),
			"subs": [_safe_get_card("Fire_001"), _safe_get_card("Earth_007")]
		}
	]

	current_world = 1
	generate_new_world()


# ============================================================
#  场景切换
# ============================================================
func switch_to_scene(target_scene: PackedScene) -> void:
	if target_scene:
		get_tree().change_scene_to_packed(target_scene)


# ============================================================
#  世界地图
# ============================================================
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
	elif "Rest" in node_type:
		switch_to_scene(rest_scene)
	elif "Shop" in node_type:
		switch_to_scene(shop_scene)
	elif "Event" in node_type:
		switch_to_scene(event_scene)
	elif "Workshop" in node_type:
		switch_to_scene(workshop_scene)


# ============================================================
#  反应系统代理（新代码可直接访问 reaction_system）
# ============================================================
func equip_reaction(reaction: ReactionData) -> void:
	reaction_system.equip_reaction(reaction)

func discard_reaction(reaction: ReactionData) -> void:
	reaction_system.discard_reaction(reaction)


# ============================================================
#  辅助函数
# ============================================================
func _safe_get_card(card_id: String) -> CardData:
	if ResourceManager:
		return ResourceManager.get_card_data(card_id)
	return null

func get_card_data(card_id: String) -> CardData:
	return _safe_get_card(card_id)

func _convert_string_references_to_resources() -> void:
	if ResourceManager and ResourceManager.all_cards.is_empty():
		ResourceManager.load_all_card_resources()

	# Convert card_pool (was previously split into backpack_cards/reserve_cards)
	var converted: Array[CardData] = []
	var untyped: Array = deck_manager.card_pool
	for item in untyped:
		if item is CardData:
			converted.append(item)
		elif item is String and item != "":
			var card_res = get_card_data(item)
			if card_res:
				converted.append(card_res)
			else:
				push_error("Failed to convert card ID to resource: " + item)
	deck_manager.card_pool = converted

	# Convert active_deck_layout
	for row_data in deck_manager.active_deck_layout:
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

func update_player_stats() -> void:
	pass
