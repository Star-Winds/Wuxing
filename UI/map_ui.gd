extends Control

@onready var world_label: Label = $VBoxContainer/WorldLabel
@onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var nodes_container: HBoxContainer = $VBoxContainer/ScrollContainer/NodesContainer

func _ready() -> void:
	var is_overlay = (get_parent() != null and get_parent().name == "GlobalHUD")
	
	if not is_overlay:
		GlobalHUD.visible = true
		GlobalHUD.set_scene_name("大地图 (Overworld)")
		
	if is_overlay:
		var dim_bg = ColorRect.new()
		dim_bg.color = Color(0, 0, 0, 0.9) # 遮盖战斗场景的背景
		dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dim_bg)
		move_child(dim_bg, 0)
		
	# 设置世界标签
	if world_label:
		world_label.text = "World %d - Node %d/16" % [GameManager.current_world, GameManager.current_node_index + 1]
		
	# 动态生成地图节点
	if nodes_container:
		for child in nodes_container.get_children():
			child.queue_free()
			
		for i in range(GameManager.current_map_path.size()):
			var node_type = GameManager.current_map_path[i]
			var btn = Button.new()
			btn.text = "%d. %s" % [i + 1, node_type]
			btn.custom_minimum_size = Vector2(180, 80)
			
			if i == GameManager.current_node_index:
				btn.disabled = false
				btn.add_theme_color_override("font_color", Color("#FBC02D"))
				btn.add_theme_color_override("font_hover_color", Color("#FFF59D"))
				# 修改点：不再传递 node_type，直接连接到新逻辑
				btn.pressed.connect(_on_node_selected)
			else:
				btn.disabled = true
				if i < GameManager.current_node_index:
					btn.text += " (✓)"
					btn.add_theme_color_override("font_disabled_color", Color("#43A047"))
				else:
					btn.add_theme_color_override("font_disabled_color", Color("#555555"))
					
			nodes_container.add_child(btn)
			
	var vbox = get_node_or_null("VBoxContainer")
	if vbox:
		vbox.offset_top = 100
		
	if is_overlay:
		if nodes_container:
			for btn in nodes_container.get_children():
				if btn is Button:
					btn.disabled = true

# --- 核心修改部分 ---
func _on_node_selected() -> void:
	# 1. 打印当前节点信息用于调试
	var node_type = GameManager.current_map_path[GameManager.current_node_index]
	print("正在进入节点: ", node_type)
	
	# 2. 调用 GameManager 中重构好的自动化跳转逻辑
	# 该方法会自动判断 node_type 并跳转到对应的 battle_scene/shop_scene 等
	GameManager.enter_current_node()