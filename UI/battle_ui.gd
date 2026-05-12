extends Control

# --- 引用 ---
@export var battle_manager: Node
const CARD_DATA_CONST = preload("res://Resources/Scripts/Card_data.gd")

# --- 状态变量 ---
var is_game_over: bool = false
var player_statuses: Dictionary = {}
var enemy_statuses: Dictionary = {}

# --- 节点引用 ---
@onready var player_status_container: HBoxContainer = $MasterLayout/PlayerStatusBar/MarginContainer/HBoxContainer/PlayerStatusContainer
@onready var enemy_status_container: HBoxContainer = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity/VBoxContainer/StatusContainer
@onready var slot_rows: Array = [
	$MasterLayout/MiddleArea/SlotsContainer/SlotRow_1,
	$MasterLayout/MiddleArea/SlotsContainer/SlotRow_2,
	$MasterLayout/MiddleArea/SlotsContainer/SlotRow_3,
	$MasterLayout/MiddleArea/SlotsContainer/SlotRow_4,
	$MasterLayout/MiddleArea/SlotsContainer/SlotRow_5
]

# 元素颜色映射 (同步自 CardData 设计)
const ELEMENT_COLORS = {
	"金": Color("#FBC02D"),
	"木": Color("#43A047"),
	"水": Color("#1E88E5"),
	"火": Color("#E64A19"),
	"土": Color("#8D6E63"),
	"以太": Color("#9C27B0")
}

func _ready() -> void:
	# 监听来自 BattleManager 的所有信号
	if battle_manager:
		battle_manager.stats_updated.connect(_on_stats_updated)
		battle_manager.status_updated.connect(_on_status_updated)
		battle_manager.reaction_triggered.connect(_on_reaction_triggered)
		battle_manager.battle_ended.connect(_on_battle_ended)
	
	_initialize_slots()

# 初始化槽位并加载 GameManager 中的布局
func _initialize_slots() -> void:
	var layout = GameManager.active_deck_layout 
	
	for i in range(slot_rows.size()):
		var row_node = slot_rows[i]
		if not row_node:
			push_error("_initialize_slots: slot_rows[%d] is null!" % i)
			continue
			
		var row_num = i + 1
		var main_slot = row_node.get_node_or_null("MainSlot_" + str(row_num))
		var sub_slot_1 = row_node.get_node_or_null("SubSlot_" + str(row_num) + "_1")
		var sub_slot_2 = row_node.get_node_or_null("SubSlot_" + str(row_num) + "_2")
		
		if not main_slot:
			push_error("_initialize_slots: MainSlot_%d is missing!" % row_num)
			continue
		
		# --- 新增：绑定主槽点击信号，并用 bind 传递当前的行号 ---
		if not main_slot.activation_requested.is_connected(_on_main_slot_activated_proxy):
			main_slot.activation_requested.connect(_on_main_slot_activated_proxy.bind(i))
		
		if i < layout.size():
			var data = layout[i]
			var main_card = data.get("main")
			if main_card is CardData:
				main_slot.set_card(main_card)
			elif main_card is String and main_card != "":
				var card_res = ResourceManager.get_card_data(main_card)
				if card_res:
					main_slot.set_card(card_res)
			
			var subs = data.get("subs", [])
			if sub_slot_1 and subs.size() > 0:
				var s0 = subs[0]
				if s0 is CardData:
					sub_slot_1.set_card(s0)
				elif s0 is String and s0 != "":
					var card_res = ResourceManager.get_card_data(s0)
					if card_res:
						sub_slot_1.set_card(card_res)
			if sub_slot_2 and subs.size() > 1:
				var s1 = subs[1]
				if s1 is CardData:
					sub_slot_2.set_card(s1)
				elif s1 is String and s1 != "":
					var card_res = ResourceManager.get_card_data(s1)
					if card_res:
						sub_slot_2.set_card(card_res)

# --- 新增：配合信号传递的代理函数 ---
func _on_main_slot_activated_proxy(_slot: CardSlot, row_index: int) -> void:
	_on_main_slot_activated(row_index)

# --- 打牌交互逻辑 ---

# 当点击主槽发动按钮时调用
func _on_main_slot_activated(row_index: int) -> void:
	if is_game_over: return
	
	var row_node = slot_rows[row_index]
	if not row_node:
		push_error("_on_main_slot_activated: row_node at index %d is null!" % row_index)
		return
		
	var row_num = row_index + 1
	var main_slot = row_node.get_node_or_null("MainSlot_" + str(row_num))
	if not main_slot:
		push_error("_on_main_slot_activated: MainSlot_%d is missing!" % row_num)
		return
		
	var main_card: CardData = main_slot.card_data
	
	if not main_card:
		print("此槽位没有卡牌！")
		return
		
	# 收集副槽资源
	var sub_cards: Array[CardData] = []
	var sub_slot_1 = row_node.get_node_or_null("SubSlot_" + str(row_num) + "_1")
	var sub_slot_2 = row_node.get_node_or_null("SubSlot_" + str(row_num) + "_2")
	
	var s1 = sub_slot_1.card_data if sub_slot_1 else null
	var s2 = sub_slot_2.card_data if sub_slot_2 else null
	if s1: sub_cards.append(s1)
	if s2: sub_cards.append(s2)
	
	# 检查玩家以太/元素消耗
	if _can_afford_card(main_card):
		_deduct_costs(main_card)
		# 核心：直接向 BattleManager 传递 CardData 对象
		battle_manager.play_card(main_card, sub_cards)
	else:
		print("资源不足！")

func _can_afford_card(card: CardData) -> bool:
	var costs = card.get_total_cost()
	# 校验 GameManager 中的元素资源是否足够
	return (GameManager.element_fire >= costs.get("火", 0) and 
			GameManager.element_water >= costs.get("水", 0) and
			GameManager.element_metal >= costs.get("金", 0) and
			GameManager.element_wood >= costs.get("木", 0) and
			GameManager.element_earth >= costs.get("土", 0) and
			GameManager.aether >= costs.get("以太", 0))

func _deduct_costs(card: CardData) -> void:
	var costs = card.get_total_cost()
	GameManager.element_fire -= costs.get("火", 0)
	GameManager.element_water -= costs.get("水", 0)
	GameManager.element_metal -= costs.get("金", 0)
	GameManager.element_wood -= costs.get("木", 0)
	GameManager.element_earth -= costs.get("土", 0)
	GameManager.aether -= costs.get("以太", 0)

# --- 信号回调 (UI 更新) ---

func _on_stats_updated(_p_hp, _p_shd, e_hp, e_shd) -> void:
	# 更新血条、护盾 UI 的逻辑
	$MasterLayout/EnemyCenter/EnemyHPBar.value = e_hp
	$MasterLayout/EnemyCenter/EnemyShieldLabel.text = "护盾: " + str(e_shd)
	# 玩家部分同理...

func _on_reaction_triggered(reaction_name: String, reaction_color: Color) -> void:
	# 显示五行反应特效
	var overlay = GameManager.reaction_overlay_scene.instantiate()
	add_child(overlay)
	overlay.show_reaction(reaction_name, reaction_color)

func _on_battle_ended(is_victory: bool) -> void:
	is_game_over = true
	if is_victory:
		GameManager.switch_to_scene(GameManager.victory_scene)
	else:
		GameManager.switch_to_scene(GameManager.game_over_scene)

func _on_end_turn_pressed() -> void:
	if not is_game_over:
		battle_manager.end_turn()

# 处理状态图标更新（如：虚弱、流血、焚烬等）
func _on_status_updated(target: String, status_dict: Dictionary) -> void:
	if target == "player":
		player_statuses = status_dict
		_update_status_display(player_status_container, player_statuses)
	else:
		enemy_statuses = status_dict
		_update_status_display(enemy_status_container, enemy_statuses)

# 具体的图标刷新逻辑
func _update_status_display(container: HBoxContainer, statuses: Dictionary) -> void:
	# 先清空旧图标
	for child in container.get_children():
		child.queue_free()
	
	# 根据状态字典创建新图标
	for status_id in statuses.keys():
		var data = statuses[status_id]
		if data is Dictionary:
			var label = Label.new()
			# 这里可以根据 status_id 配不同的文字或颜色
			label.text = "[" + status_id + ":" + str(data.get("duration", 0)) + "]"
			container.add_child(label)
