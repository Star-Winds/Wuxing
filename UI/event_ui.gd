extends Control

@onready var desc_label: RichTextLabel = $VBoxContainer/DescLabel
@onready var choices_container: VBoxContainer = $VBoxContainer/ChoicesContainer

func _ready() -> void:
	GlobalHUD.set_scene_name("机缘奇遇 (Event)")
	var vbox = get_node_or_null("VBoxContainer")
	if vbox:
		vbox.offset_top = 100
	# Set description text
	if desc_label:
		desc_label.text = "你发现了一尊废弃的八卦炉，炉心仍有微弱的火光跳动。炉灰中似乎掩埋着什么...\n\n(You find an abandoned alchemy furnace, a weak fire still flickers in the core. Something seems buried in the ashes...)"
		
	# Populate choice buttons
	if choices_container:
		for child in choices_container.get_children():
			child.queue_free()
			
		# Choice 1: Absorption
		var btn_absorb = Button.new()
		btn_absorb.text = "1. 吸收炉火 (Gain 8 Fire, Lose 10 HP)"
		btn_absorb.custom_minimum_size = Vector2(400, 50)
		btn_absorb.theme_type_variation = "Button"
		if GameManager.current_health <= 10:
			btn_absorb.disabled = true
			btn_absorb.text += " - [生命值不足 (Insufficient HP)]"
		else:
			btn_absorb.pressed.connect(_on_absorb_selected)
		choices_container.add_child(btn_absorb)
		
		# Choice 2: Scavenge
		var btn_scavenge = Button.new()
		btn_scavenge.text = "2. 仔细搜刮 (Gain 2 Aether)"
		btn_scavenge.custom_minimum_size = Vector2(400, 50)
		btn_scavenge.pressed.connect(_on_scavenge_selected)
		choices_container.add_child(btn_scavenge)
		
		# Choice 3: Leave
		var btn_leave = Button.new()
		btn_leave.text = "3. 默默离开 (Leave safely)"
		btn_leave.custom_minimum_size = Vector2(400, 50)
		btn_leave.pressed.connect(_on_leave_selected)
		choices_container.add_child(btn_leave)

func _on_absorb_selected() -> void:
	if GameManager.current_health > 10:
		GameManager.current_health -= 10
		GameManager.element_fire += 8
		print("Successfully absorbed furnace fire! Gained 8 Fire, lost 10 HP.")
		_leave_event()

func _on_scavenge_selected() -> void:
	GameManager.aether += 2
	print("Successfully scavenged! Gained 2 Aether.")
	_leave_event()

func _on_leave_selected() -> void:
	print("Left safely.")
	_leave_event()

func _leave_event() -> void:
	GameManager.current_node_index += 1
	get_tree().change_scene_to_file("res://UI/map_ui.tscn")
