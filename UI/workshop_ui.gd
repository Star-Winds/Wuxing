# workshop_ui.gd
extends Control

var _recipes = {
	"knife": {
		"equipment_name": "小刀",
		"required_card_id": "Metal_022",
		"required_card_name": "小刀制造",
		"cost_metal": 17,
		"cost_wood": 0,
		"description": "所有卡牌最终伤害 +3"
	},
	"armor": {
		"equipment_name": "藤甲",
		"required_card_id": "Wood_028",
		"required_card_name": "藤甲制造",
		"cost_metal": 15,
		"cost_wood": 2,
		"description": "抵挡 4 点伤害（火属性弱点 +4 点）"
	}
}

@onready var resource_label: Label = $VBoxContainer/ResourceLabel
@onready var btn_craft_knife: Button = $VBoxContainer/HBoxContainer/PanelA/BtnCraftKnife
@onready var btn_craft_armor: Button = $VBoxContainer/HBoxContainer/PanelB/BtnCraftArmor
@onready var panel_a: Node = $VBoxContainer/HBoxContainer/PanelA
@onready var panel_b: Node = $VBoxContainer/HBoxContainer/PanelB
var label_knife_req: Label
var label_armor_req: Label

func _ready() -> void:
	GlobalHUD.set_scene_name("造化炼坊 (Workshop)")

	var vbox = get_node_or_null("VBoxContainer")
	if vbox:
		vbox.offset_top = 100

		# 清理旧的冗余节点
		for node_name in ["BtnLeave", "Spacer", "BottomSpacer"]:
			var node = vbox.get_node_or_null(node_name)
			if node: node.queue_free()

		# 创建底部占位空间
		var bottom_spacer = Control.new()
		bottom_spacer.name = "BottomSpacer"
		bottom_spacer.custom_minimum_size = Vector2(0, 180)
		bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(bottom_spacer)

	# Create requirement labels if not in scene
	label_knife_req = panel_a.get_node_or_null("RequirementLabel") if panel_a else null
	if not label_knife_req:
		label_knife_req = _create_requirement_label(panel_a) if panel_a else null
	label_armor_req = panel_b.get_node_or_null("RequirementLabel") if panel_b else null
	if not label_armor_req:
		label_armor_req = _create_requirement_label(panel_b) if panel_b else null

	_update_ui()

	btn_craft_knife.pressed.connect(_on_btn_craft_pressed.bind("knife"))
	btn_craft_armor.pressed.connect(_on_btn_craft_pressed.bind("armor"))

	# 创建悬浮层用于放置离开按钮
	var emergency_layer = CanvasLayer.new()
	emergency_layer.layer = 128
	add_child(emergency_layer)

	var leave_btn = Button.new()
	leave_btn.text = "【返回地图】离开车间"
	leave_btn.name = "ForceLeaveBtn"
	leave_btn.add_theme_font_size_override("font_size", 24)
	emergency_layer.add_child(leave_btn)

	# 按钮布局数学计算
	var btn_width = 300
	var btn_height = 80
	leave_btn.custom_minimum_size = Vector2(btn_width, btn_height)

	await get_tree().process_frame
	var screen_size = get_viewport_rect().size
	leave_btn.position = Vector2((screen_size.x - btn_width) / 2.0, screen_size.y - btn_height - 40.0)

	# 连接重构后的离开逻辑
	leave_btn.pressed.connect(_on_btn_leave_pressed)


func _create_requirement_label(parent: Node) -> Label:
	var lbl = Label.new()
	lbl.name = "RequirementLabel"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(0.7, 0.7, 0.7)
	parent.add_child(lbl)
	return lbl


func _has_crafting_card(card_id: String) -> bool:
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


func _update_ui() -> void:
	if resource_label:
		resource_label.text = "当前 金: %d | 木: %d" % [GameManager.element_metal, GameManager.element_wood]

	_update_craft_button("knife", btn_craft_knife, label_knife_req)
	_update_craft_button("armor", btn_craft_armor, label_armor_req)


func _update_craft_button(recipe_key: String, btn: Button, req_label: Label) -> void:
	var recipe = _recipes[recipe_key]
	var equip_name = recipe["equipment_name"]
	var has_card = _has_crafting_card(recipe["required_card_id"])
	var already_owned = GameManager.acquired_equipment.has(equip_name)
	var enough_resources = (GameManager.element_metal >= recipe["cost_metal"]
		and GameManager.element_wood >= recipe["cost_wood"])

	if already_owned:
		btn.disabled = true
		btn.text = "已打造"
		req_label.text = ""
		return

	if not has_card:
		btn.disabled = true
		btn.text = "缺失材料"
		req_label.text = "需要卡牌：" + recipe["required_card_name"]
		return

	# Has the card
	req_label.text = "材料：%d 金 | %d 木" % [recipe["cost_metal"], recipe["cost_wood"]]

	if not enough_resources:
		btn.disabled = true
		btn.text = "资源不足"
	else:
		btn.disabled = false
		btn.text = "打造"


func _on_btn_craft_pressed(recipe_key: String) -> void:
	var recipe = _recipes[recipe_key]
	var equip_name = recipe["equipment_name"]

	# Double-check
	if GameManager.acquired_equipment.has(equip_name):
		return
	if not _has_crafting_card(recipe["required_card_id"]):
		return
	if GameManager.element_metal < recipe["cost_metal"] or GameManager.element_wood < recipe["cost_wood"]:
		return

	# Deduct resources
	GameManager.element_metal -= recipe["cost_metal"]
	GameManager.element_wood -= recipe["cost_wood"]

	# Remove the crafting card from pool
	_remove_crafting_card(recipe["required_card_id"])

	# Grant equipment
	GameManager.acquired_equipment.append(equip_name)

	print("车间：成功打造 [", equip_name, "]！")
	_update_ui()


func _on_btn_leave_pressed() -> void:
	GameManager.current_node_index += 1
	GameManager.switch_to_scene(GameManager.map_scene)
