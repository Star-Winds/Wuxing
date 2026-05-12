extends Control
class_name CardSlot

# --- 新增引用，解决启动解析报错 ---
const CARD_DATA_CONST = preload("res://Resources/Scripts/Card_data.gd")

# --- 信号 ---
signal activation_requested(slot: CardSlot)

# --- 枚举 ---
enum SlotState { INACTIVE, ACTIVATED, PLAYED }

# --- 变量 ---
var current_state: SlotState = SlotState.INACTIVE
var card_data: CardData = null 

@export var is_sub_slot: bool = false
var sub_slots: Array[CardSlot] = []

# --- 节点引用 (使用可选链或安全检查) ---
@onready var background: ColorRect = get_node_or_null("Background")
@onready var name_label: Label = get_node_or_null("NameLabel")
@onready var stats_label: Label = get_node_or_null("StatsLabel")
@onready var button: Button = get_node_or_null("Button")

func _ready() -> void:
	if button:
		button.pressed.connect(_on_button_pressed)
	
	# 安全检查父节点
	var parent = get_parent()
	if parent and parent is HBoxContainer and not is_sub_slot:
		for child in parent.get_children():
			if child is CardSlot and child != self:
				sub_slots.append(child)
				
	_update_visuals()

# --- 外部设置接口 ---
func set_card(new_card_data: CardData) -> void:
	card_data = new_card_data
	
	# 保险 1：如果节点还没 Ready，绝对不操作 UI 节点
	if not is_node_ready():
		await ready
	
	# 保险 2：再次检查节点是否在树中
	if not is_inside_tree(): return

	if card_data:
		if name_label: name_label.text = card_data.card_name
		if stats_label:
			stats_label.text = str(card_data.sub_value) if is_sub_slot else str(card_data.main_value)
	else:
		if name_label: name_label.text = ""
		if stats_label: stats_label.text = ""
	
	_update_visuals()

# --- 视觉更新逻辑 ---
func _update_visuals() -> void:
	# 保险 3：终极拦截，如果关键节点不存在，直接停止
	if background == null or not is_inside_tree():
		return
	
	var element_color: Color = Color(0.2, 0.2, 0.2)
	
	# 检查 CardData 和引用是否存在
	if card_data:
		# 优先尝试从 GameManager 获取颜色，或者通过 find_child 寻找
		var battle_ui = get_tree().root.find_child("BattleUI", true, false)
		if battle_ui and "ELEMENT_COLORS" in battle_ui:
			element_color = battle_ui.ELEMENT_COLORS.get(card_data.element, element_color)
		elif "ELEMENT_COLORS" in GameManager: # 备选方案
			element_color = GameManager.ELEMENT_COLORS.get(card_data.element, element_color)
			
	match current_state:
		SlotState.INACTIVE:
			background.color = Color(element_color, 0.2)
		SlotState.ACTIVATED:
			background.color = element_color
		SlotState.PLAYED:
			background.color = Color(0.05, 0.05, 0.05)

# --- 其余逻辑 ---
func _on_button_pressed() -> void:
	if is_sub_slot or not card_data: return
	if current_state == SlotState.INACTIVE:
		activation_requested.emit(self)
	elif current_state == SlotState.ACTIVATED:
		var battle_ui = get_tree().root.find_child("BattleUI", true, false)
		if battle_ui: battle_ui.set("pending_play_slot", self)

func _activate_confirmed():
	current_state = SlotState.ACTIVATED
	_update_visuals()
	if not is_sub_slot:
		for s in sub_slots: s._activate_confirmed()

func _finalize_play():
	current_state = SlotState.PLAYED
	_update_visuals()
	if not is_sub_slot:
		for s in sub_slots: s._finalize_play()

func reset_turn() -> void:
	if current_state == SlotState.PLAYED:
		current_state = SlotState.INACTIVE
		_update_visuals()