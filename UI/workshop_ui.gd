# workshop_ui.gd
extends Control

@onready var resource_label: Label = $VBoxContainer/ResourceLabel
@onready var btn_craft_knife: Button = $VBoxContainer/HBoxContainer/PanelA/BtnCraftKnife
@onready var btn_craft_armor: Button = $VBoxContainer/HBoxContainer/PanelB/BtnCraftArmor

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
	
	_update_ui()
	
	btn_craft_knife.pressed.connect(_on_btn_craft_knife_pressed)
	btn_craft_armor.pressed.connect(_on_btn_craft_armor_pressed)
	
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

func _update_ui() -> void:
	if resource_label:
		resource_label.text = "当前 金: %d | 木: %d" % [GameManager.element_metal, GameManager.element_wood]
		
	# 更新按钮状态
	_update_craft_button(btn_craft_knife, "小刀")
	_update_craft_button(btn_craft_armor, "藤甲")

# 辅助函数：更新打造按钮样式
func _update_craft_button(btn: Button, item_name: String) -> void:
	if GameManager.acquired_equipment.has(item_name):
		btn.disabled = true
		btn.text = "已打造"
	else:
		btn.disabled = false
		btn.text = "打造"

func _on_btn_craft_knife_pressed() -> void:
	if GameManager.element_metal >= 17:
		GameManager.element_metal -= 17
		GameManager.acquired_equipment.append("小刀")
		_update_ui()
	else:
		_show_temp_error(btn_craft_knife, "金元素不足")

func _on_btn_craft_armor_pressed() -> void:
	if GameManager.element_metal >= 15 and GameManager.element_wood >= 2:
		GameManager.element_metal -= 15
		GameManager.element_wood -= 2
		GameManager.acquired_equipment.append("藤甲")
		_update_ui()
	else:
		_show_temp_error(btn_craft_armor, "资源不足")

# 辅助函数：展示临时错误文本
func _show_temp_error(btn: Button, msg: String) -> void:
	var old_text = btn.text
	btn.text = msg
	btn.disabled = true
	await get_tree().create_timer(1.0).timeout
	btn.text = old_text
	btn.disabled = false

# --- 核心修改部分 ---
func _on_btn_leave_pressed() -> void:
	# 1. 推进地图索引
	GameManager.current_node_index += 1
	
	# 2. 调用重构后的全局场景切换逻辑
	# 确保在 GameManager 检查器中已为 map_scene 变量赋值
	GameManager.switch_to_scene(GameManager.map_scene)