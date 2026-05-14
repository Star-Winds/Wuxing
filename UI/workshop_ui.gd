extends BaseScreen

@export var recipes: Array[EquipmentData] = []

@onready var resource_label: Label = $VBoxContainer/ResourceLabel
@onready var recipes_container: VBoxContainer = $VBoxContainer/RecipesContainer


func _ready() -> void:
	set_scene_title("造化炼坊 (Workshop)")

	if recipes_container:
		_build_recipe_ui()

	_create_leave_button()


func _build_recipe_ui() -> void:
	for child in recipes_container.get_children():
		child.queue_free()

	for eq in recipes:
		if not eq is EquipmentData:
			continue
		var panel = _create_recipe_panel(eq)
		recipes_container.add_child(panel)


func _create_recipe_panel(eq: EquipmentData) -> Panel:
	var panel = Panel.new()
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = eq.equipment_name
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color("#FFD54F"))
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = eq.description
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.modulate = Color(0.85, 0.85, 0.85)
	vbox.add_child(desc_lbl)

	var cost_effective = _effective_metal_cost(eq)
	var cost_lbl = Label.new()
	if GameManager.workshop_discount_amount > 0 and cost_effective < eq.cost_metal:
		cost_lbl.text = "材料：%d 金（已折扣） | %d 木" % [cost_effective, eq.cost_wood]
	else:
		cost_lbl.text = "材料：%d 金 | %d 木" % [eq.cost_metal, eq.cost_wood]
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(cost_lbl)

	var btn = Button.new()
	btn.text = "打造"
	btn.custom_minimum_size = Vector2(200, 40)
	vbox.add_child(btn)

	_update_button_state(btn, eq)
	btn.pressed.connect(_on_craft_pressed.bind(eq, btn))

	return panel


func _update_button_state(btn: Button, eq: EquipmentData) -> void:
	var already_owned = _is_equipment_owned(eq)
	var has_card = _has_crafting_card(eq.required_card_id)
	var cost_effective = _effective_metal_cost(eq)
	var discount_active = GameManager.workshop_discount_amount > 0 and cost_effective < eq.cost_metal
	var enough_resources = (
		GameManager.element_metal >= cost_effective
		and GameManager.element_wood >= eq.cost_wood
	)

	if already_owned:
		btn.disabled = true
		btn.text = "已打造"
		return

	if not has_card:
		btn.disabled = true
		btn.text = "缺失材料"
		return

	if not enough_resources:
		btn.disabled = true
		btn.text = "资源不足"
	else:
		btn.disabled = false
		btn.text = "打造（折扣中）" if discount_active else "打造"


func _is_equipment_owned(eq: EquipmentData) -> bool:
	for owned in GameManager.acquired_equipment:
		if owned is EquipmentData and owned.equipment_id == eq.equipment_id:
			return true
	return false


func _has_crafting_card(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	for card in GameManager.card_pool:
		if card is CardData and card.id == card_id:
			return true
	return false


func _remove_crafting_card(card_id: String) -> void:
	for i in range(GameManager.card_pool.size()):
		var card = GameManager.card_pool[i]
		if card is CardData and card.id == card_id:
			GameManager.card_pool.remove_at(i)
			print("车间：消耗了制造卡牌 ", card.card_name)
			return


func _effective_metal_cost(eq: EquipmentData) -> int:
	return max(0, eq.cost_metal - GameManager.workshop_discount_amount)


func _on_craft_pressed(eq: EquipmentData, btn: Button) -> void:
	if _is_equipment_owned(eq):
		return
	if not _has_crafting_card(eq.required_card_id):
		return

	var cost_effective = _effective_metal_cost(eq)
	if GameManager.element_metal < cost_effective or GameManager.element_wood < eq.cost_wood:
		return

	GameManager.element_metal -= cost_effective
	GameManager.element_wood -= eq.cost_wood
	_remove_crafting_card(eq.required_card_id)
	GameManager.acquired_equipment.append(eq)

	var consumed = GameManager.workshop_discount_amount
	if consumed > 0 and cost_effective < eq.cost_metal:
		GameManager.workshop_discount_amount = 0
		print("车间：使用了埋藏折扣，节省 %d 金" % consumed)

	print("车间：成功打造 [", eq.equipment_name, "]！")
	_update_button_state(btn, eq)


func _create_leave_button() -> void:
	var emergency_layer = CanvasLayer.new()
	emergency_layer.layer = 128
	add_child(emergency_layer)

	var leave_btn = Button.new()
	leave_btn.text = "【返回地图】离开车间"
	leave_btn.name = "ForceLeaveBtn"
	leave_btn.add_theme_font_size_override("font_size", 24)
	emergency_layer.add_child(leave_btn)

	var btn_width = 300
	var btn_height = 80
	leave_btn.custom_minimum_size = Vector2(btn_width, btn_height)

	await get_tree().process_frame
	var screen_size = get_viewport_rect().size
	leave_btn.position = Vector2((screen_size.x - btn_width) / 2.0, screen_size.y - btn_height - 40.0)

	leave_btn.pressed.connect(_on_btn_leave_pressed)


func _on_btn_leave_pressed() -> void:
	return_to_map()
