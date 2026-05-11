extends Control

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var buy_aether_button: Button = $VBoxContainer/ButtonsContainer/BuyAetherButton
@onready var buy_elements_button: Button = $VBoxContainer/ButtonsContainer/BuyElementsButton
@onready var buy_card_button: Button = $VBoxContainer/ButtonsContainer/BuyCardButton
@onready var leave_button: Button = $VBoxContainer/ButtonsContainer/LeaveButton

func _ready() -> void:
	GlobalHUD.set_scene_name("奇珍异宝阁 (Shop)")
	var vbox = get_node_or_null("VBoxContainer")
	if vbox:
		vbox.offset_top = 100
	
	_update_ui()
	
	# 连接按钮信号
	buy_aether_button.pressed.connect(_on_buy_aether_pressed)
	buy_elements_button.pressed.connect(_on_buy_elements_pressed)
	buy_card_button.pressed.connect(_on_buy_card_pressed)
	leave_button.pressed.connect(_leave_shop)

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
	if GameManager.gold < 50 and not buy_aether_button.disabled:
		buy_aether_button.add_theme_color_override("font_color", Color("#888888"))
	if GameManager.gold < 40 and not buy_elements_button.disabled:
		buy_elements_button.add_theme_color_override("font_color", Color("#888888"))
	if GameManager.gold < 30 and not buy_card_button.disabled:
		buy_card_button.add_theme_color_override("font_color", Color("#888888"))

func _on_buy_aether_pressed() -> void:
	if GameManager.gold >= 50:
		GameManager.gold -= 50
		GameManager.aether += 5
		buy_aether_button.disabled = true
		_update_ui()

func _on_buy_elements_pressed() -> void:
	if GameManager.gold >= 40:
		GameManager.gold -= 40
		GameManager.element_metal += 2
		GameManager.element_wood += 2
		GameManager.element_water += 2
		GameManager.element_fire += 2
		GameManager.element_earth += 2
		buy_elements_button.disabled = true
		_update_ui()

func _on_buy_card_pressed() -> void:
	if GameManager.gold >= 30:
		GameManager.gold -= 30
		GameManager.backpack_cards.append("fire_law_001")
		buy_card_button.disabled = true
		_update_ui()

# --- 核心修改部分 ---
func _leave_shop() -> void:
	# 1. 推进地图索引
	GameManager.current_node_index += 1
	
	# 2. 调用重构后的全局场景切换逻辑
	# 确保 GameManager 的 map_scene 已在编辑器中赋值
	GameManager.switch_to_scene(GameManager.map_scene)