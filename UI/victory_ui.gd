extends BaseScreen

const CARD_DATA_CONST = preload("res://Data/Card_data.gd")

const GOLD_REWARD: int = 20
const ELEMENT_REWARD_COUNT: int = 5
const REACTION_DROP_CHANCE: float = 0.4
const CARD_OPTION_COUNT: int = 3

@onready var rewards_label: Label = $VBoxContainer/RewardsLabel
@onready var cards_container: HBoxContainer = $VBoxContainer/CardsContainer
@onready var skip_button: Button = $VBoxContainer/SkipButton

var pending_card_data: CardData = null
var pending_button: Button = null

var swap_overlay: Panel
var swap_grid: GridContainer

func _ready() -> void:
	_setup_swap_overlay()
	# 1. 授予基础奖励
	_grant_rewards()

	# 2. 加载卡牌并展示选项
	_display_card_options()

	# 3. 连接跳过/返回按钮
	skip_button.text = "返回地图 (Return to Map)"
	skip_button.pressed.connect(_return_to_map)

func _grant_rewards() -> void:
	GameManager.gold += GOLD_REWARD

	var elements = ["Metal", "Wood", "Water", "Fire", "Earth"]
	var counts = {"Metal": 0, "Wood": 0, "Water": 0, "Fire": 0, "Earth": 0}

	for i in range(ELEMENT_REWARD_COUNT):
		var chosen = elements[RNGService.randi() % elements.size()]
		match chosen:
			"Metal": GameManager.element_metal += 1
			"Wood": GameManager.element_wood += 1
			"Water": GameManager.element_water += 1
			"Fire": GameManager.element_fire += 1
			"Earth": GameManager.element_earth += 1
		counts[chosen] += 1

	var elem_strings = []
	if counts["Metal"] > 0: elem_strings.append("金 (Metal) +%d" % counts["Metal"])
	if counts["Wood"] > 0: elem_strings.append("木 (Wood) +%d" % counts["Wood"])
	if counts["Water"] > 0: elem_strings.append("水 (Water) +%d" % counts["Water"])
	if counts["Fire"] > 0: elem_strings.append("火 (Fire) +%d" % counts["Fire"])
	if counts["Earth"] > 0: elem_strings.append("土 (Earth) +%d" % counts["Earth"])

	var text_parts = ["获得: %d 金币 (Gold)" % GOLD_REWARD]
	text_parts.append_array(elem_strings)

	# 偶尔掉落五行反应秘籍
	var reaction_dropped: ReactionData = null
	if RNGService.randf() < REACTION_DROP_CHANCE:
		var keys = GameManager.reaction_system.REACTION_CARD_PATHS.keys()
		var combo_key = keys[RNGService.randi() % keys.size()]
		var card_path: String = GameManager.reaction_system.REACTION_CARD_PATHS[combo_key]
		var card_data: CardData = load(card_path)
		if card_data:
			reaction_dropped = ReactionData.new()
			reaction_dropped.reaction_name = card_data.card_name
			reaction_dropped.card_data = card_data
			var parts = combo_key.split("_")
			var combo_arr: Array[String] = []
			for p in parts:
				combo_arr.append(p)
			reaction_dropped.combination = combo_arr
			reaction_dropped.description = card_data.description
			# color from element
			if card_data.element == "火": reaction_dropped.reaction_color = Color("#FF5252")
			elif card_data.element == "水": reaction_dropped.reaction_color = Color("#29B6F6")
			elif card_data.element == "木": reaction_dropped.reaction_color = Color("#66BB6A")
			elif card_data.element == "金": reaction_dropped.reaction_color = Color("#FFCA28")
			elif card_data.element == "土": reaction_dropped.reaction_color = Color("#8D6E63")
			else: reaction_dropped.reaction_color = Color("#FFFFFF")

			GameManager.owned_reactions.append(reaction_dropped)
			text_parts.append("获得秘籍【%s】" % reaction_dropped.reaction_name)

	rewards_label.text = ", ".join(text_parts)

func _display_card_options() -> void:
	for child in cards_container.get_children():
		child.queue_free()

	var all_card_resources = ResourceManager.all_cards.values()
	if all_card_resources.is_empty():
		return

	RNGService.shuffle(all_card_resources)

	var selected_cards = []
	for i in range(min(CARD_OPTION_COUNT, all_card_resources.size())):
		selected_cards.append(all_card_resources[i])

	for card_data in selected_cards:
		var btn = Button.new()
		var c_name = card_data.card_name
		var c_elem = card_data.element
		btn.text = "%s\n[%s属性]" % [c_name, c_elem]
		btn.custom_minimum_size = Vector2(240, 200)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_card_reward_selected.bind(card_data, btn))
		cards_container.add_child(btn)

func _on_card_reward_selected(card_data: CardData, btn: Button) -> void:
	if GameManager.card_pool.size() < GameManager.MAX_DECK_SIZE:
		GameManager.card_pool.append(card_data)
		btn.disabled = true
		btn.text += "\n(已获取)"
	else:
		pending_card_data = card_data
		pending_button = btn
		_show_swap_menu()

func _return_to_map() -> void:
	return_to_map()

func _setup_swap_overlay() -> void:
	swap_overlay = Panel.new()
	swap_overlay.visible = false
	swap_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.96)
	style.set_border_width_all(4)
	style.border_color = Color(0.8, 0.2, 0.2, 0.8)
	style.set_corner_radius_all(12)
	swap_overlay.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 60; vbox.offset_top = 60; vbox.offset_right = -60; vbox.offset_bottom = -60
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	swap_overlay.add_child(vbox)

	var label = Label.new()
	label.text = "卡组已满！请选择一张卡牌丢弃以替换新卡"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(label)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	swap_grid = GridContainer.new()
	swap_grid.columns = 4
	swap_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swap_grid.add_theme_constant_override("h_separation", 15)
	swap_grid.add_theme_constant_override("v_separation", 15)
	scroll.add_child(swap_grid)

	var cancel_btn = Button.new()
	cancel_btn.text = "取消替换 (Cancel)"
	cancel_btn.custom_minimum_size = Vector2(200, 50)
	cancel_btn.pressed.connect(func(): swap_overlay.hide())
	vbox.add_child(cancel_btn)
	add_child(swap_overlay)

func _show_swap_menu() -> void:
	for child in swap_grid.get_children():
		child.queue_free()

	for i in range(GameManager.card_pool.size()):
		var card_data = GameManager.card_pool[i]
		var btn = Button.new()
		btn.text = "%s\n[%s属性]" % [card_data.card_name, card_data.element]
		btn.custom_minimum_size = Vector2(160, 90)
		btn.pressed.connect(_confirm_swap.bind(i))
		swap_grid.add_child(btn)
	swap_overlay.show()

func _confirm_swap(index: int) -> void:
	GameManager.card_pool.remove_at(index)
	GameManager.card_pool.append(pending_card_data)
	pending_button.disabled = true
	pending_button.text += "\n(已替换)"
	swap_overlay.hide()
