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
		dim_bg.color = Color(0, 0, 0, 0.9) # Very dark to cover the battle scene
		dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dim_bg)
		move_child(dim_bg, 0) # Put it at the very back of the map UI
		
	# Set world label text
	if world_label:
		world_label.text = "World %d - Node %d/16" % [GameManager.current_world, GameManager.current_node_index + 1]
		
	# Dynamically instantiate 16 Button nodes
	if nodes_container:
		# Clear existing children
		for child in nodes_container.get_children():
			child.queue_free()
			
		for i in range(GameManager.current_map_path.size()):
			var node_type = GameManager.current_map_path[i]
			var btn = Button.new()
			btn.text = "%d. %s" % [i + 1, node_type]
			btn.custom_minimum_size = Vector2(180, 80)
			
			# Disable all buttons except the current one
			if i == GameManager.current_node_index:
				btn.disabled = false
				# Highlight active node
				btn.add_theme_color_override("font_color", Color("#FBC02D"))
				btn.add_theme_color_override("font_hover_color", Color("#FFF59D"))
				btn.pressed.connect(_on_node_selected.bind(node_type))
			else:
				btn.disabled = true
				if i < GameManager.current_node_index:
					# Style completed nodes
					btn.text += " (✓)"
					btn.add_theme_color_override("font_disabled_color", Color("#43A047"))
				else:
					# Style locked nodes
					btn.add_theme_color_override("font_disabled_color", Color("#555555"))
					
			nodes_container.add_child(btn)
			
	# Apply universal padding so the HUD never covers the map title/content
	var vbox = get_node_or_null("VBoxContainer")
	if vbox:
		vbox.offset_top = 100
		
	# Check if we are running as a GlobalHUD map peek overlay
	if is_overlay:
		if nodes_container:
			for btn in nodes_container.get_children():
				if btn is Button:
					btn.disabled = true


func _on_node_selected(node_type: String) -> void:
	print("Entering node: ", node_type)
	if "车" in node_type or "Workshop" in node_type:
		get_tree().change_scene_to_file("res://UI/workshop_ui.tscn")
	elif "炮" in node_type or "Event" in node_type:
		get_tree().change_scene_to_file("res://UI/event_ui.tscn")
	elif "象" in node_type or "Rest" in node_type:
		get_tree().change_scene_to_file("res://UI/rest_ui.tscn")
	elif "马" in node_type or "Shop" in node_type:
		get_tree().change_scene_to_file("res://UI/shop_ui.tscn")
	else:
		get_tree().change_scene_to_file("res://UI/battle_ui.tscn")
