extends Control

# --- 引用 ---
@export var battle_manager: Node
const CARD_DATA_CONST = preload("res://Resources/Scripts/Card_data.gd")

# --- 支付面板节点引用 ---
@onready var payment_panel: PanelContainer = $PaymentPanel
@onready var payment_title: Label = $PaymentPanel/VBoxContainer/TitleLabel
@onready var resource_sliders: VBoxContainer = $PaymentPanel/VBoxContainer/ResourceSliders
@onready var remaining_label: Label = $PaymentPanel/VBoxContainer/HBoxContainer/RemainingLabel
@onready var confirm_activation_button: Button = $PaymentPanel/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_activation_button: Button = $PaymentPanel/VBoxContainer/HBoxContainer/CancelButton

# --- 支付面板状态变量 ---
var pending_main_card: CardData
var pending_sub_cards: Array = []
var current_card_total_cost: int = 0
var allocated_amounts: Dictionary = {}
var element_spinboxes: Dictionary = {}

# --- 状态变量 ---
var is_game_over: bool = false
var player_statuses: Dictionary = {}
var enemy_statuses: Dictionary = {}
var pending_slot: CardSlot = null # 用于记住当前正在操作的槽位
var is_targeting: bool = false
var target_pending_slot: CardSlot = null

# 玩家护盾，用于 GlobalHUD 显示
var player_shield: int:
	get:
		if battle_manager:
			return battle_manager.player_shield
		return 0

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
	# --- 新增/补回：自动寻找或实例化 BattleManager 的逻辑 ---
	if not battle_manager:
		battle_manager = get_node_or_null("BattleManager")
		if not battle_manager:
			var bm_script = preload("res://Systems/battle_manager.gd")
			battle_manager = Node.new()
			battle_manager.name = "BattleManager"
			battle_manager.set_script(bm_script)
			add_child(battle_manager)
	# --------------------------------------------------
	var enemy_entity = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity
	if enemy_entity:
		# 确保 Control 节点不会鼠标穿透
		enemy_entity.mouse_filter = Control.MOUSE_FILTER_STOP 
		if not enemy_entity.gui_input.is_connected(_on_enemy_entity_gui_input):
			enemy_entity.gui_input.connect(_on_enemy_entity_gui_input)
			
	# 监听来自 BattleManager 的所有信号
	if battle_manager:
		battle_manager.stats_updated.connect(_on_stats_updated)
		battle_manager.status_updated.connect(_on_status_updated)
		battle_manager.reaction_triggered.connect(_on_reaction_triggered)
		battle_manager.battle_ended.connect(_on_battle_ended)
	
	# 连接支付面板按钮
	if confirm_activation_button:
		confirm_activation_button.pressed.connect(_on_confirm_payment)
	if cancel_activation_button:
		cancel_activation_button.pressed.connect(_on_cancel_payment)
		
	# 默认隐藏支付面板
	if payment_panel:
		payment_panel.hide()
		
	_initialize_slots()
	
	# 连接回合结束按钮
	var end_turn_btn = %EndTurnButton
	if end_turn_btn:
		if not end_turn_btn.pressed.is_connected(_on_end_turn_pressed):
			end_turn_btn.pressed.connect(_on_end_turn_pressed)
			
	# step 4: Load default test enemy for testing purposes
	var test_enemy = load("res://Resources/Enemies/snake_wood.tres")
	if test_enemy and battle_manager:
		battle_manager.start_battle(test_enemy)

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
# --- 自由支付与打牌交互逻辑 ---

func _on_main_slot_activated(row_index: int) -> void:
	if is_game_over: return
	
	var row_node = slot_rows[row_index]
	if not row_node: return
		
	var row_num = row_index + 1
	var main_slot = row_node.get_node_or_null("MainSlot_" + str(row_num))
	if not main_slot or not main_slot.card_data:
		print("此槽位没有卡牌！")
		return
		
	# 根据卡牌当前状态执行不同逻辑 (解耦与冷却)
	match main_slot.current_state:
		CardSlot.SlotState.INACTIVE:
			# 1. 未激活：唤起支付面板
			pending_slot = main_slot
			# 收集副槽资源 (为了后续打出做准备，也可在 play 时再收集)
			var sub_cards: Array = []
			var sub_slot_1 = row_node.get_node_or_null("SubSlot_" + str(row_num) + "_1")
			var sub_slot_2 = row_node.get_node_or_null("SubSlot_" + str(row_num) + "_2")
			if sub_slot_1 and sub_slot_1.card_data: sub_cards.append(sub_slot_1.card_data)
			if sub_slot_2 and sub_slot_2.card_data: sub_cards.append(sub_slot_2.card_data)
			pending_sub_cards = sub_cards
			
			_show_payment_panel(main_slot.card_data)
			
		CardSlot.SlotState.ACTIVATED:
			# 【核心修改：第二次点击不直接打出，而是进入瞄准模式】
			if not is_targeting:
				is_targeting = true
				target_pending_slot = main_slot
				print("卡牌已就绪，请点击敌人释放！(右键可取消)")
				# TODO: 这里后续可以加一个鼠标变准星的视觉效果
			else:
				# 如果已经在瞄准状态又点了一下该卡牌，视为取消瞄准
				is_targeting = false
				target_pending_slot = null
				print("取消瞄准")
			
		CardSlot.SlotState.PLAYED:
			# 3. 冷却中
			print("此卡牌本回合已释放，处于冷却中！")

func _show_payment_panel(card: CardData) -> void:
	pending_main_card = card
	payment_title.text = "为 [" + card.card_name + "] 分配灵气"
	var costs = card.get_total_cost()
	
	current_card_total_cost = 0
	for v in costs.values():
		current_card_total_cost += v
		
	# 如果卡牌消耗为 0，直接打出，无需支付
	if current_card_total_cost <= 0:
		_execute_pending_card()
		return
		
	# 清空旧的滑块
	for child in resource_sliders.get_children():
		child.queue_free()
		
	allocated_amounts.clear()
	element_spinboxes.clear()
	
	# 检查玩家是否拥有任何可以支付的资源（任意所需元素或以太）
	var has_any_resource = false
	for el in costs.keys():
		if _get_element_current(el) > 0:
			has_any_resource = true
	if _get_element_current("以太") > 0:
		has_any_resource = true
		
	if not has_any_resource:
		print("你没有任何元素或以太可以支付！")
		pending_main_card = null
		return
		
	# 1. 针对卡牌明确要求的每个非以太元素创建 SpinBox
	for el in costs.keys():
		if el == "以太":
			continue
		var required_amount = costs[el]
		var stash_amount = _get_element_current(el)
		_create_specific_element_row(el, required_amount, stash_amount)
		
	# 2. 总是生成一个用于 Aether (以太) 的 HSlider 作为万能替代
	var stash_aether = _get_element_current("以太")
	_create_aether_row(stash_aether)
	
	_update_payment_calculation()
	payment_panel.show()

func _get_element_current(element: String) -> int:
	match element:
		"金": return GameManager.element_metal
		"木": return GameManager.element_wood
		"水": return GameManager.element_water
		"火": return GameManager.element_fire
		"土": return GameManager.element_earth
		"以太": return GameManager.aether
	return 0

func _create_specific_element_row(element: String, required: int, stash: int) -> void:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = element + ":"
	label.custom_minimum_size = Vector2(80, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 应用色彩
	if ELEMENT_COLORS.has(element):
		label.modulate = ELEMENT_COLORS[element]
	
	var spinbox = SpinBox.new()
	spinbox.min_value = 0
	spinbox.max_value = min(stash, required)
	spinbox.value = 0
	spinbox.value_changed.connect(_on_allocation_changed)
	
	var info_label = Label.new()
	info_label.text = "（需 %d / 持有 %d）" % [required, stash]
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_label.modulate = Color(0.7, 0.7, 0.7) # 灰色辅助说明文字
	
	hbox.add_child(label)
	hbox.add_child(spinbox)
	hbox.add_child(info_label)
	resource_sliders.add_child(hbox)
	
	element_spinboxes[element] = spinbox
	allocated_amounts[element] = 0

func _create_aether_row(stash_aether: int) -> void:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = "以太 (万能):"
	label.custom_minimum_size = Vector2(80, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	if ELEMENT_COLORS.has("以太"):
		label.modulate = ELEMENT_COLORS["以太"]
	
	var slider = HSlider.new()
	slider.min_value = 0
	var max_val = min(stash_aether, current_card_total_cost)
	slider.max_value = max_val
	slider.value = 0
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var val_label = Label.new()
	val_label.text = "0 / " + str(max_val)
	val_label.custom_minimum_size = Vector2(50, 0)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	slider.value_changed.connect(func(val: float):
		val_label.text = str(int(val)) + " / " + str(max_val)
		_on_allocation_changed(val)
	)
	
	hbox.add_child(label)
	hbox.add_child(slider)
	hbox.add_child(val_label)
	resource_sliders.add_child(hbox)
	
	element_spinboxes["以太"] = slider
	allocated_amounts["以太"] = 0

func _on_allocation_changed(_value: float) -> void:
	_update_payment_calculation()

func _update_payment_calculation() -> void:
	var total_allocated = 0
	for element in element_spinboxes.keys():
		var val = int(element_spinboxes[element].value)
		allocated_amounts[element] = val
		total_allocated += val
		
	var remaining = current_card_total_cost - total_allocated
	remaining_label.text = "剩余需支付: %d" % remaining
	
	# 只有当分配的资源总量恰好等于卡牌总 Cost 时，才允许确认
	confirm_activation_button.disabled = (total_allocated != current_card_total_cost)

func _on_confirm_payment() -> void:
	# 扣除对应数量的资源 (此部分逻辑待用提示词重构，暂不修改原有扣除代码)
	for element in allocated_amounts.keys():
		var amount = allocated_amounts[element]
		if amount > 0:
			match element:
				"金": GameManager.element_metal -= amount
				"木": GameManager.element_wood -= amount
				"水": GameManager.element_water -= amount
				"火": GameManager.element_fire -= amount
				"土": GameManager.element_earth -= amount
				"以太": GameManager.aether -= amount
				
	payment_panel.hide()
	GameManager.update_player_stats() 
	
	# 【核心修改：支付确认后，变更槽位状态为 ACTIVATED】
	if pending_slot:
		pending_slot._activate_confirmed()
		if battle_manager:
			battle_manager.has_activated_card_this_turn = true
		print("卡牌已激活，再次点击即可释放！")
		
func _on_cancel_payment() -> void:
	payment_panel.hide()
	pending_main_card = null
	pending_sub_cards.clear()

func _execute_pending_card() -> void:
	if pending_main_card and battle_manager:
		battle_manager.play_card(pending_main_card, pending_sub_cards, battle_manager)
		
	pending_main_card = null
	pending_sub_cards.clear()

# --- 信号回调 (UI 更新) ---

func _on_stats_updated(_p_hp, _p_shd, e_hp, e_shd) -> void:
	# 更新敌人状态 UI
	if battle_manager and battle_manager.current_enemy:
		var name_lbl = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity/VBoxContainer/NameLabel
		if name_lbl:
			name_lbl.text = battle_manager.current_enemy.enemy_name + " (" + battle_manager.current_enemy.element + ")"
		
		var stats_lbl = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity/VBoxContainer/EnemyStatsLabel
		if stats_lbl:
			stats_lbl.text = "HP: %d/%d | Shield: %d" % [e_hp, battle_manager.current_enemy.max_hp, e_shd]
			
	_update_enemy_intent()

func _update_enemy_intent() -> void:
	if not battle_manager or not battle_manager.current_enemy:
		return
		
	var intent_lbl = $MasterLayout/MiddleArea/EnemyCenter/EnemyEntity/VBoxContainer/IntentLabel
	if not intent_lbl:
		return
		
	var turn = battle_manager.enemy_turn_counter % 3
	var dmg = battle_manager.current_enemy.intent_base_dmg + battle_manager.enemy_atk_buff
	if battle_manager.enemy_statuses.has("weak"):
		dmg = int(dmg * 0.75)
		
	match turn:
		0:
			if battle_manager.enemy_statuses.has("stun_attack"):
				intent_lbl.text = "Intent: Stunned (Skip Attack)"
			else:
				intent_lbl.text = "Intent: Attack " + str(dmg)
		1:
			var shield_gain = 15
			if battle_manager.enemy_statuses.has("slow"):
				shield_gain = int(shield_gain * 0.5)
			intent_lbl.text = "Intent: Defend " + str(shield_gain)
		2:
			intent_lbl.text = "Intent: Buff (+3 Atk)"

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
		# 【新增：重置所有卡槽状态为 INACTIVE】
		for row in slot_rows:
			for child in row.get_children():
				if child is CardSlot:
					child.reset_turn()

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

# 监听敌人 UI 的鼠标事件
func _on_enemy_entity_gui_input(event: InputEvent) -> void:
	if is_targeting and target_pending_slot:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("已锁定目标，释放卡牌！")
			is_targeting = false
			
			# 当前本地版本中 battle_manager 实现了 take_damage 等接口，充当了敌人实体
			var target = battle_manager 
			_play_activated_card(target_pending_slot, target)
			
			# 清空瞄准缓存
			target_pending_slot = null

# 监听全局鼠标右键，用于取消瞄准
func _unhandled_input(event: InputEvent) -> void:
	if is_targeting and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		print("右键取消目标选择")
		is_targeting = false
		target_pending_slot = null

# 带目标的释放函数 (注意：这个函数需要替换掉你之前那个不带 target 参数的老版本)
func _play_activated_card(slot: CardSlot, target: Node) -> void:
	if slot and slot.card_data and battle_manager:
		# 获取副槽
		var parent_row = slot.get_parent()
		var sub_cards = []
		for child in parent_row.get_children():
			if child is CardSlot and child.is_sub_slot and child.card_data:
				sub_cards.append(child.card_data)
				
		# 打出卡牌并指定目标
		battle_manager.play_card(slot.card_data, sub_cards, target)
		
		# 释放后进入冷却或由于淬火反应而重新激活
		if battle_manager.get("reactivate_current_card"):
			print("淬火触发：卡牌已重新激活！")
			slot.current_state = CardSlot.SlotState.ACTIVATED
			slot._update_visuals()
			# 重置 battle_manager 里的标志位
			battle_manager.reactivate_current_card = false
		else:
			slot._finalize_play()
			
		pending_slot = null
