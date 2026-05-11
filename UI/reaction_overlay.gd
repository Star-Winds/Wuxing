# res://UI/reaction_overlay.gd
extends Control

@onready var close_button: Button = %CloseButton
@onready var list_container: VBoxContainer = %ListContainer

# 保持色彩定义
const ELEMENT_COLORS = {
	"火": "#FF5252",
	"木": "#4CAF50",
	"水": "#2196F3",
	"金": "#FFC107",
	"土": "#A1887F",
	"以太": "#E040FB"
}

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	# 动态加载并填充反应条目
	_populate_reactions()

func _on_close_pressed() -> void:
	# 安全地清除 GlobalHUD 中的引用，防止悬挂指针
	if GlobalHUD.get("reaction_overlay_instance") == self:
		GlobalHUD.reaction_overlay_instance = null
	
	# 如果你是通过 GameManager.switch_to_scene 切换进来的，则需要切回上一个场景
	# 但通常 Overlay 是 add_child 进来的，所以 queue_free 是正确的
	queue_free()

# --- 数据加载优化 ---
func _load_json_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		printerr("错误: 反应数据库文件未找到: ", path)
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	
	if error == OK:
		return json.data
	else:
		printerr("JSON 解析错误: ", json.get_error_message())
		return {}

func _populate_reactions() -> void:
	# 清空现有列表
	for child in list_container.get_children():
		child.queue_free()
		
	# 注意：如果你的数据库路径未来也会变，建议也将其放入 GameManager 的 @export 中
	var db = _load_json_data("res://Databases/reaction_database.json")
	if db.is_empty():
		_show_error("无法加载反应数据库。")
		return
		
	var element_order = ["金", "木", "水", "火", "土"]
	
	for attacker in element_order:
		if not db.has(attacker): continue
			
		var attacker_color = ELEMENT_COLORS.get(attacker, "#FFFFFF")
		
		# 1. 创建章节标题
		var header = RichTextLabel.new()
		header.fit_content = true
		header.bbcode_enabled = true
		header.text = "[font_size=18][color=%s][b]● %s 属性触发的反应 :[/b][/color][/font_size]" % [attacker_color, attacker]
		list_container.add_child(header)
		
		# 2. 创建容器面板 (视觉优化)
		var panel = _create_styled_panel()
		var section_vbox = VBoxContainer.new()
		section_vbox.add_theme_constant_override("separation", 8)
		panel.add_child(section_vbox)
		list_container.add_child(panel)
		
		# 3. 填充具体反应
		var reactions = db[attacker]
		for defender in reactions.keys():
			var r_data = reactions[defender]
			var defender_color = ELEMENT_COLORS.get(defender, "#FFFFFF")
			var r_name = r_data.get("name", "未知")
			var r_desc = r_data.get("description", "无描述")
			
			var item = RichTextLabel.new()
			item.fit_content = true
			item.bbcode_enabled = true
			item.text = "   [color=%s][%s][/color] ➔ [color=%s][%s][/color]  [b][color=#FFEB3B]【%s】[/color][/b] : [color=#ECEFF1]%s[/color]" % [
				attacker_color, attacker, defender_color, defender, r_name, r_desc
			]
			section_vbox.add_child(item)
			
		# 4. 间距控制
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		list_container.add_child(spacer)

# --- 辅助样式方法 (保持代码整洁) ---

func _create_styled_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.6)
	style.set_corner_radius_all(6)
	style.content_margin_left = 15
	style.content_margin_top = 10
	style.content_margin_right = 15
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _show_error(msg: String) -> void:
	var err_label = Label.new()
	err_label.text = msg
	list_container.add_child(err_label)