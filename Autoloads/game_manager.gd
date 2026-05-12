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
var owned_reactions: Array[ReactionData] = []
var equipped_reactions: Dictionary = {} # Key: combo_key string (e.g. "火_水"), Value: ReactionData object
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
	owned_reactions.clear()
	equipped_reactions.clear()
	
	var default_list = [
		{"name": "蒸腾", "combo": ["火", "水"], "color": Color("#FF5252"), "desc": "提供烧伤效果，每回合按层数结算扣血"},
		{"name": "熄灭", "combo": ["水", "火"], "color": Color("#29B6F6"), "desc": "为目标赋予“虚弱”（造成伤害x0.75）2回合"},
		{"name": "烧制", "combo": ["火", "土"], "color": Color("#FF8A65"), "desc": "敌方获得脆化（受伤x1.5）2回合，主控获得1点土元素"},
		{"name": "余烬", "combo": ["土", "火"], "color": Color("#FF7043"), "desc": "本回合每受到伤害一次，则返还主控1火元素"},
		{"name": "焚烬", "combo": ["火", "木"], "color": Color("#FF3D00"), "desc": "本次火元素伤害翻倍"},
		{"name": "添柴", "combo": ["木", "火"], "color": Color("#66BB6A"), "desc": "主控获得3点火元素"},
		{"name": "熔炼", "combo": ["火", "金"], "color": Color("#FF7043"), "desc": "如果目标有护盾，则破除目标的护盾，再结算伤害"},
		{"name": "过载", "combo": ["金", "火"], "color": Color("#FF8F00"), "desc": "随机激活一个当前未激活的副槽卡牌"},
		{"name": "润泽", "combo": ["水", "木"], "color": Color("#4FC3F7"), "desc": "主控随机获得2单位非水元素"},
		{"name": "吸纳", "combo": ["木", "水"], "color": Color("#26A69A"), "desc": "从目标处偷取1点以太 (直接增加1点以太)"},
		{"name": "泥沼", "combo": ["水", "土"], "color": Color("#8D6E63"), "desc": "为目标赋予“减速”（获得护盾量x0.5）2回合"},
		{"name": "阻截", "combo": ["土", "水"], "color": Color("#8D6E63"), "desc": "禁锢目标，若其行动是攻击则推迟到下回合"},
		{"name": "淬火", "combo": ["水", "金"], "color": Color("#26C6DA"), "desc": "触发该反应的卡牌可以在本回合内再次“激活”"},
		{"name": "涌泉", "combo": ["金", "水"], "color": Color("#FFD54F"), "desc": "激活后，立即补充2单位水元素"},
		{"name": "破土", "combo": ["木", "土"], "color": Color("#8D6E63"), "desc": "无视目标护盾，直接造成5木元素伤害 (真实伤害)"},
		{"name": "固本", "combo": ["土", "木"], "color": Color("#81C784"), "desc": "恢复4点生命值"},
		{"name": "坚韧", "combo": ["木", "金"], "color": Color("#9CCC65"), "desc": "主控获得“反震”（受击时回敬3伤）"},
		{"name": "伐断", "combo": ["金", "木"], "color": Color("#A1887F"), "desc": "施加流血效果（动作时扣血），持续2回合"},
		{"name": "合金", "combo": ["金", "土"], "color": Color("#FFCA28"), "desc": "主控获得“合金”，提供1点减伤，直到本次对局结束"},
		{"name": "埋藏", "combo": ["土", "金"], "color": Color("#BCAAA4"), "desc": "下次在“车间”节点打造装备时，消耗减少2点金元素"}
	]
	
	for data in default_list:
		var reaction = ReactionData.new()
		reaction.reaction_name = data["name"]
		var combo_arr: Array[String] = []
		for elem in data["combo"]:
			combo_arr.append(elem)
		reaction.combination = combo_arr
		reaction.reaction_color = data["color"]
		reaction.description = data["desc"]
		owned_reactions.append(reaction)
		
		# Auto-equip the first reaction for each combination
		var key = reaction.get_combo_key()
		if not equipped_reactions.has(key):
			equipped_reactions[key] = reaction

func equip_reaction(reaction: ReactionData) -> void:
	if reaction == null: return
	var key = reaction.get_combo_key()
	if key == "": return
	equipped_reactions[key] = reaction
	print("Equipped reaction: ", reaction.reaction_name, " for ", key)

func discard_reaction(reaction: ReactionData) -> void:
	if reaction == null: return
	var key = reaction.get_combo_key()
	if key != "" and equipped_reactions.get(key) == reaction:
		equipped_reactions.erase(key)
		print("Unequipped reaction on discard: ", reaction.reaction_name)
	owned_reactions.erase(reaction)
	print("Discarded reaction: ", reaction.reaction_name)

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