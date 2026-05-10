extends Control

@onready var resource_label: Label = $VBoxContainer/ResourceLabel
@onready var btn_craft_knife: Button = $VBoxContainer/HBoxContainer/PanelA/BtnCraftKnife
@onready var btn_craft_armor: Button = $VBoxContainer/HBoxContainer/PanelB/BtnCraftArmor

func _ready() -> void:
	GlobalHUD.set_scene_name("造化炼坊 (Workshop)")
	
	var vbox = get_node_or_null("VBoxContainer")
	if vbox:
		vbox.offset_top = 100
		
		# Prevent duplicates if the scene file already contains these nodes
		var existing_btn = vbox.get_node_or_null("BtnLeave")
		if existing_btn:
			existing_btn.queue_free()
		var existing_spacer = vbox.get_node_or_null("Spacer")
		if existing_spacer:
			existing_spacer.queue_free()
		var existing_b_spacer = vbox.get_node_or_null("BottomSpacer")
		if existing_b_spacer:
			existing_b_spacer.queue_free()
			
		# 1. Use Godot's native layout engine to push the crafting UI upwards
		# Create a massive invisible spacer at the bottom of the VBox
		var bottom_spacer = Control.new()
		bottom_spacer.name = "BottomSpacer"
		bottom_spacer.custom_minimum_size = Vector2(0, 180) # Reserve 180 pixels at the bottom
		bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(bottom_spacer)
	
	_update_ui()
	
	btn_craft_knife.pressed.connect(_on_btn_craft_knife_pressed)
	btn_craft_armor.pressed.connect(_on_btn_craft_armor_pressed)
	
	# 2. Create the top-level CanvasLayer
	var emergency_layer = CanvasLayer.new()
	emergency_layer.layer = 128
	add_child(emergency_layer)
	
	# 3. Create the Leave Button
	var leave_btn = Button.new()
	leave_btn.text = "【返回地图】离开车间"
	leave_btn.name = "ForceLeaveBtn"
	leave_btn.add_theme_font_size_override("font_size", 24)
	leave_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 1. Add to the layer first
	emergency_layer.add_child(leave_btn)
	
	# 2. Force the button size to ensure math is accurate
	var btn_width = 300
	var btn_height = 80
	leave_btn.custom_minimum_size = Vector2(btn_width, btn_height)
	leave_btn.size = Vector2(btn_width, btn_height)
	
	# 3. Wait exactly one frame to ensure the Viewport layout is fully initialized by the engine
	await get_tree().process_frame
	
	# 4. Get the true screen resolution dynamically
	var screen_size = get_viewport_rect().size
	
	# 5. Calculate Center-X and Bottom-Y math manually
	var target_x = (screen_size.x - btn_width) / 2.0
	var target_y = screen_size.y - btn_height - 40.0 # 40 pixels padding from the bottom edge
	
	# 6. Apply absolute position
	leave_btn.position = Vector2(target_x, target_y)
	
	# 7. Connect progression logic
	leave_btn.pressed.connect(_on_btn_leave_pressed)

func _update_ui() -> void:
	if resource_label:
		resource_label.text = "当前 金: %d | 木: %d" % [GameManager.element_metal, GameManager.element_wood]
		
	# Update buttons depending on purchase state
	if GameManager.acquired_equipment.has("小刀"):
		btn_craft_knife.disabled = true
		btn_craft_knife.text = "已打造"
	else:
		btn_craft_knife.disabled = false
		btn_craft_knife.text = "打造"
		
	if GameManager.acquired_equipment.has("藤甲"):
		btn_craft_armor.disabled = true
		btn_craft_armor.text = "已打造"
	else:
		btn_craft_armor.disabled = false
		btn_craft_armor.text = "打造"

func _on_btn_craft_knife_pressed() -> void:
	if GameManager.element_metal >= 17:
		GameManager.element_metal -= 17
		GameManager.acquired_equipment.append("小刀")
		print("Crafted 小刀 (Knife)!")
		_update_ui()
	else:
		btn_craft_knife.text = "金元素不足"
		btn_craft_knife.disabled = true
		await get_tree().create_timer(1.0).timeout
		if not GameManager.acquired_equipment.has("小刀"):
			btn_craft_knife.text = "打造"
			btn_craft_knife.disabled = false

func _on_btn_craft_armor_pressed() -> void:
	if GameManager.element_metal >= 15 and GameManager.element_wood >= 2:
		GameManager.element_metal -= 15
		GameManager.element_wood -= 2
		GameManager.acquired_equipment.append("藤甲")
		print("Crafted 藤甲 (Armor)!")
		_update_ui()
	else:
		btn_craft_armor.text = "资源不足"
		btn_craft_armor.disabled = true
		await get_tree().create_timer(1.0).timeout
		if not GameManager.acquired_equipment.has("藤甲"):
			btn_craft_armor.text = "打造"
			btn_craft_armor.disabled = false

func _on_btn_leave_pressed() -> void:
	GameManager.current_node_index += 1
	get_tree().change_scene_to_file("res://UI/map_ui.tscn")
