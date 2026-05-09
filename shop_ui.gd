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
	
	# Connect button signals
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
	
	# Optionally keep button availability updated based on gold (though once bought they remain disabled)
	# But we only disable them upon purchase as requested (can only buy once).
	# To make it user-friendly, we can also check if they can afford them, or just rely on the click check.
	_check_affordability()

func _check_affordability() -> void:
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
		print("Successfully purchased 5 Aether! (Current Gold: %d)" % GameManager.gold)
		buy_aether_button.disabled = true
		_update_ui()
	else:
		print("Not enough Gold to buy Aether!")

func _on_buy_elements_pressed() -> void:
	if GameManager.gold >= 40:
		GameManager.gold -= 40
		GameManager.element_metal += 2
		GameManager.element_wood += 2
		GameManager.element_water += 2
		GameManager.element_fire += 2
		GameManager.element_earth += 2
		print("Successfully purchased Element Pack! (Current Gold: %d)" % GameManager.gold)
		buy_elements_button.disabled = true
		_update_ui()
	else:
		print("Not enough Gold to buy Element Pack!")

func _on_buy_card_pressed() -> void:
	if GameManager.gold >= 30:
		GameManager.gold -= 30
		GameManager.backpack_cards.append("fire_law_001")
		print("Card fire_law_001 added to backpack! (Current Gold: %d)" % GameManager.gold)
		buy_card_button.disabled = true
		_update_ui()
	else:
		print("Not enough Gold to buy Card!")

func _leave_shop() -> void:
	print("Leaving shop.")
	GameManager.current_node_index += 1
	get_tree().change_scene_to_file("res://map_ui.tscn")
