extends BaseScreen

const SHOP_ITEMS: Array[Dictionary] = [
	{
		name = "Buy Aether",
		cost = 50,
		desc = "Payment Element: 以太Aether +5",
		rewards = {"aether": 5}
	},
	{
		name = "Buy Elements",
		cost = 40,
		desc = "Payment Element: 五行各五行各+2",
		rewards = {"element_metal": 2, "element_wood": 2, "element_water": 2, "element_fire": 2, "element_earth": 2}
	},
	{
		name = "Buy Card",
		cost = 30,
		desc = "Payment Card: 随机卡牌",
		rewards = {"card": 1}
	}
]

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var buy_aether_button: Button = $VBoxContainer/ButtonsContainer/BuyAetherButton
@onready var buy_elements_button: Button = $VBoxContainer/ButtonsContainer/BuyElementsButton
@onready var buy_card_button: Button = $VBoxContainer/ButtonsContainer/BuyCardButton
@onready var leave_button: Button = $VBoxContainer/ButtonsContainer/LeaveButton

var _pending_shop_card: CardData = null
var _swap_overlay: Panel
var _swap_grid: GridContainer

func _ready() -> void:
	set_scene_title("奇珍异宝阁 (Shop)")

	_setup_shop_swap_overlay()
	_update_ui()

	# 连接按钮信号
	buy_aether_button.pressed.connect(_on_buy_aether_pressed)
	buy_elements_button.pressed.connect(_on_buy_elements_pressed)
	buy_card_button.pressed.connect(_on_buy_card_pressed)
	leave_button.pressed.connect(_leave_shop)

func _setup_shop_swap_overlay() -> void:
	_swap_overlay = Panel.new()
	_swap_overlay.visible = false
	_swap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.96)
	style.set_border_width_all(4)
	style.border_color = Color(0.8, 0.2, 0.2, 0.8)
	style.set_corner_radius_all(12)
	_swap_overlay.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 60; vbox.offset_top = 60; vbox.offset_right = -60; vbox.offset_bottom = -60
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_swap_overlay.add_child(vbox)

	var label = Label.new()
	label.text = "牌包已满！请选择一张卡牌丢弃以替换新卡"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(label)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_swap_grid = GridContainer.new()
	_swap_grid.columns = 4
	_swap_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_swap_grid.add_theme_constant_override("h_separation", 15)
	_swap_grid.add_theme_constant_override("v_separation", 15)
	scroll.add_child(_swap_grid)

	var cancel_btn = Button.new()
	cancel_btn.text = "取消购买 (Cancel)"
	cancel_btn.custom_minimum_size = Vector2(200, 50)
	cancel_btn.pressed.connect(func(): _swap_overlay.hide())
	vbox.add_child(cancel_btn)
	add_child(_swap_overlay)

func _update_ui() -> void:
	if status_label:
		status_label.text = "Current Gold: %d | Current Aether: %d\nElements: Metal: %d | Wood: %d | Water: %d | Fire: %d | Earth: %d" % [
			GameManager.gold,
			GameManager.aether,
			GameManager.element_metal,
			GameManager.element_wood,
			GameManager.element_water,
			GameManager.element_fire,
			GameManager.element_earth
		]

	_check_affordability()

func _check_affordability() -> void:
	# 若余额不足且按钮尚未因购买被禁用，则置灰文字
	if GameManager.gold < SHOP_ITEMS[0].cost and not buy_aether_button.disabled:
		buy_aether_button.add_theme_color_override("font_color", Color("#888888"))
	if GameManager.gold < SHOP_ITEMS[1].cost and not buy_elements_button.disabled:
		buy_elements_button.add_theme_color_override("font_color", Color("#888888"))
	if GameManager.gold < SHOP_ITEMS[2].cost and not buy_card_button.disabled:
		buy_card_button.add_theme_color_override("font_color", Color("#888888"))

func _on_buy_aether_pressed() -> void:
	var item = SHOP_ITEMS[0]
	if GameManager.gold >= item.cost:
		GameManager.gold -= item.cost
		GameManager.aether += item.rewards["aether"]
		buy_aether_button.disabled = true
		_update_ui()

func _on_buy_elements_pressed() -> void:
	var item = SHOP_ITEMS[1]
	if GameManager.gold >= item.cost:
		GameManager.gold -= item.cost
		GameManager.element_metal += item.rewards["element_metal"]
		GameManager.element_wood += item.rewards["element_wood"]
		GameManager.element_water += item.rewards["element_water"]
		GameManager.element_fire += item.rewards["element_fire"]
		GameManager.element_earth += item.rewards["element_earth"]
		buy_elements_button.disabled = true
		_update_ui()

func _on_buy_card_pressed() -> void:
	var item = SHOP_ITEMS[2]
	if GameManager.gold >= item.cost:
		var card_res = ResourceManager.get_card_data("fire_law_001")
		if not card_res:
			var all_keys = ResourceManager.all_cards.keys()
			if not all_keys.is_empty():
				card_res = ResourceManager.all_cards[all_keys[0]]
		if not card_res:
			return

		if GameManager.card_pool.size() < DeckManager.MAX_DECK_SIZE:
			# 牌包未满，直接添加
			GameManager.gold -= item.cost
			GameManager.card_pool.append(card_res)
			buy_card_button.disabled = true
			_update_ui()
		else:
			# 牌包已满，弹出替换界面
			_pending_shop_card = card_res
			_show_buy_swap_menu()

func _show_buy_swap_menu() -> void:
	for child in _swap_grid.get_children():
		child.queue_free()

	for i in range(GameManager.card_pool.size()):
		var card_data = GameManager.card_pool[i]
		var btn = Button.new()
		btn.text = "%s\n[%s]" % [card_data.card_name, card_data.element]
		btn.custom_minimum_size = Vector2(160, 90)
		btn.pressed.connect(_confirm_shop_swap.bind(i))
		_swap_grid.add_child(btn)

	_swap_overlay.show()

func _confirm_shop_swap(index: int) -> void:
	GameManager.gold -= SHOP_ITEMS[2].cost
	GameManager.card_pool.remove_at(index)
	GameManager.card_pool.append(_pending_shop_card)
	buy_card_button.disabled = true
	_swap_overlay.hide()
	_update_ui()

# --- 核心修改部分 ---
func _leave_shop() -> void:
	return_to_map()
