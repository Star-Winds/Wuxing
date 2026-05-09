# res://reaction_overlay.gd
extends Control

@onready var close_button: Button = %CloseButton
@onready var list_container: VBoxContainer = %ListContainer

const ELEMENT_COLORS = {
	"火": "#FF5252", # Red
	"木": "#4CAF50", # Green
	"水": "#2196F3", # Blue
	"金": "#FFC107", # Amber/Yellow
	"土": "#A1887F", # Warm Light Brown
	"以太": "#E040FB" # Magenta/Purple
}

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	
	# Dynamically load and populate reaction entries
	_populate_reactions()

func _on_close_pressed() -> void:
	# Safely clear reference from GlobalHUD before queue_free
	if GlobalHUD.reaction_overlay_instance == self:
		GlobalHUD.reaction_overlay_instance = null
	queue_free()

func _load_json_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		printerr("Reaction database file not found: ", path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var parse_err = json.parse(content)
	if parse_err == OK:
		return json.data
	else:
		printerr("JSON Parse Error in ", path, ": ", json.get_error_message())
		return {}

func _populate_reactions() -> void:
	# Clear existing children just in case
	for child in list_container.get_children():
		child.queue_free()
		
	var db = _load_json_data("res://reaction_database.json")
	if db.is_empty():
		var err_label = Label.new()
		err_label.text = "Failed to load reaction database."
		list_container.add_child(err_label)
		return
		
	# Iterate elements in traditional order
	var element_order = ["金", "木", "水", "火", "土"]
	
	for attacker in element_order:
		if not db.has(attacker):
			continue
			
		var attacker_color = ELEMENT_COLORS.get(attacker, "#FFFFFF")
		
		# Create Section Header
		var header_label = RichTextLabel.new()
		header_label.fit_content = true
		header_label.bbcode_enabled = true
		header_label.text = "[font_size=18][color=" + attacker_color + "][b]● " + attacker + " 属性作为主卡触发的反应 :[/b][/color][/font_size]"
		list_container.add_child(header_label)
		
		# Create Panel container for the section's reaction items
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.14, 0.6)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 15
		style.content_margin_top = 10
		style.content_margin_right = 15
		style.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", style)
		
		var section_vbox = VBoxContainer.new()
		section_vbox.add_theme_constant_override("separation", 8)
		panel.add_child(section_vbox)
		list_container.add_child(panel)
		
		# Populate reactions under this attacker element
		var reactions = db[attacker]
		for defender in reactions.keys():
			var r_data = reactions[defender]
			var defender_color = ELEMENT_COLORS.get(defender, "#FFFFFF")
			var r_name = r_data.get("name", "未知")
			var r_desc = r_data.get("description", "无描述")
			
			var item_label = RichTextLabel.new()
			item_label.fit_content = true
			item_label.bbcode_enabled = true
			
			# Build premium styled rich text string
			var text = "   [color=" + attacker_color + "][" + attacker + "][/color] ➔ [color=" + defender_color + "][" + defender + "][/color]  "
			text += "[b][color=#FFEB3B]【" + r_name + "】[/color][/b] : [color=#ECEFF1]" + r_desc + "[/color]"
			
			item_label.text = text
			section_vbox.add_child(item_label)
			
		# Add vertical spacing
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		list_container.add_child(spacer)
