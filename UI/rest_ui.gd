extends Control

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var heal_button: Button = $VBoxContainer/HBoxContainer/HealButton
@onready var nature_button: Button = $VBoxContainer/HBoxContainer/NatureButton
@onready var leave_button: Button = $VBoxContainer/HBoxContainer/LeaveButton

func _ready() -> void:
	GlobalHUD.set_scene_name("聚气歇息 (Rest)")
	var vbox = get_node_or_null("VBoxContainer")
	if vbox:
		vbox.offset_top = 100
	_update_ui()
	
	heal_button.pressed.connect(_on_heal_selected)
	nature_button.pressed.connect(_on_nature_selected)
	leave_button.pressed.connect(_on_leave_selected)

func _update_ui() -> void:
	if status_label:
		status_label.text = "Current HP: %d / %d | Wood Element: %d" % [GameManager.current_health, GameManager.max_health, GameManager.element_wood]

func _on_heal_selected() -> void:
	var heal_amount = 30
	GameManager.current_health = min(GameManager.max_health, GameManager.current_health + heal_amount)
	print("Healed for %d HP! (Current HP: %d/%d)" % [heal_amount, GameManager.current_health, GameManager.max_health])
	_leave_rest()

func _on_nature_selected() -> void:
	var elements = ["Metal", "Wood", "Water", "Fire", "Earth"]
	var gained_counts = {
		"Metal": 0,
		"Wood": 0,
		"Water": 0,
		"Fire": 0,
		"Earth": 0
	}
	for i in range(10):
		var choice = elements[randi() % elements.size()]
		gained_counts[choice] += 1
		
	GameManager.element_metal += gained_counts["Metal"]
	GameManager.element_wood += gained_counts["Wood"]
	GameManager.element_water += gained_counts["Water"]
	GameManager.element_fire += gained_counts["Fire"]
	GameManager.element_earth += gained_counts["Earth"]
	
	print("Gained elements: Metal +%d, Wood +%d, Water +%d, Fire +%d, Earth +%d" % [
		gained_counts["Metal"], gained_counts["Wood"], gained_counts["Water"], gained_counts["Fire"], gained_counts["Earth"]
	])
	_leave_rest()

func _on_leave_selected() -> void:
	print("Left campfire safely.")
	_leave_rest()

func _leave_rest() -> void:
	GameManager.current_node_index += 1
	get_tree().change_scene_to_file("res://UI/map_ui.tscn")
