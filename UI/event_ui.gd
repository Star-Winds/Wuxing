extends BaseScreen

@onready var desc_label: RichTextLabel = $VBoxContainer/DescLabel
@onready var choices_container: VBoxContainer = $VBoxContainer/ChoicesContainer

func _ready() -> void:
	set_scene_title("机缘奇遇 (Event)")
	
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
	return_to_map()

func _on_scavenge_selected() -> void:
	GameManager.aether += 2
	return_to_map()

func _on_leave_selected() -> void:
	return_to_map()

