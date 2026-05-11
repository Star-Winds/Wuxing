extends Control

@onready var desc_label: RichTextLabel = $VBoxContainer/DescLabel
@onready var choices_container: VBoxContainer = $VBoxContainer/ChoicesContainer

func _ready() -> void:
	GlobalHUD.set_scene_name("机缘奇遇 (Event)")
	var vbox = get_node_or_null("VBoxContainer")
	if vbox:
		vbox.offset_top = 100
	
	# 设置描述文本
	if desc_label:
		desc_label.text = "你发现了一尊废弃的八卦炉，炉心仍有微弱的火光跳动。炉灰中似乎掩埋着什么...\n\n(You find an abandoned alchemy furnace, a weak fire still flickers in the core. Something seems buried in the ashes...)"
		
	# 动态生成选项
	if choices_container:
		for child in choices_container.get_children():
			child.queue_free()
			
		_add_choice("1. 吸收炉火 (Gain 8 Fire, Lose 10 HP)", _on_absorb_selected, GameManager.current_health <= 10)
		_add_choice("2. 仔细搜刮 (Gain 2 Aether)", _on_scavenge_selected)
		_add_choice("3. 默默离开 (Leave safely)", _on_leave_selected)

# 辅助函数：快速添加按钮
func _add_choice(text: String, callback: Callable, is_disabled: bool = false) -> void:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(400, 50)
	if is_disabled:
		btn.disabled = true
		btn.text += " - [生命值不足]"
	else:
		btn.pressed.connect(callback)
	choices_container.add_child(btn)

func _on_absorb_selected() -> void:
	GameManager.current_health -= 10
	GameManager.element_fire += 8
	_leave_event()

func _on_scavenge_selected() -> void:
	GameManager.aether += 2
	_leave_event()

func _on_leave_selected() -> void:
	_leave_event()

# --- 核心修改部分 ---
func _leave_event() -> void:
	# 1. 仅仅递增节点索引（因为 Boss 之后才会重置，Event 不会是结束点）
	GameManager.current_node_index += 1
	
	# 2. 使用重构后的全局变量进行跳转
	# 确保你在 GameManager 的 Inspector 面板中已将 map_ui.tscn 拖入 map_scene 槽位
	GameManager.switch_to_scene(GameManager.map_scene)