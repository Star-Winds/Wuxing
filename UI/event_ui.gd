extends BaseScreen

const EVENTS: Array[Dictionary] = [
	{
		title = "机缘奇遇 (Event)",
		description = "你发现了一尊废弃的八卦炉，炉心仍有微弱的火光跳动。炉灰中似乎掩埋着什么...\n\n(You find an abandoned alchemy furnace, a weak fire still flickers in the core. Something seems buried in the ashes...)",
		choices = [
			{text = "1. 吸收炉火 (Gain 8 Fire, Lose 10 HP)", effects = {"health": -10, "element_fire": 8}, disabled_when = "low_hp", disabled_threshold = 10},
			{text = "2. 仔细搜刮 (Gain 2 Aether)", effects = {"aether": 2}, disabled_when = ""},
			{text = "3. 默默离开 (Leave safely)", effects = {}, disabled_when = ""}
		]
	}
]

@onready var desc_label: RichTextLabel = $VBoxContainer/DescLabel
@onready var choices_container: VBoxContainer = $VBoxContainer/ChoicesContainer

func _ready() -> void:
	var event = EVENTS[0]
	set_scene_title(event.title)

	# 设置描述文本
	if desc_label:
		desc_label.text = event.description

	# 动态生成选项
	if choices_container:
		for child in choices_container.get_children():
			child.queue_free()

		for choice in event.choices:
			var is_disabled = false
			if choice.disabled_when == "low_hp" and GameManager.current_health <= choice.disabled_threshold:
				is_disabled = true
			_add_choice(choice.text, _make_event_callback(choice.effects), is_disabled)

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

func _make_event_callback(effects: Dictionary) -> Callable:
	return func():
		for key in effects:
			var value = effects[key]
			match key:
				"health": GameManager.current_health += value
				"element_metal": GameManager.element_metal += value
				"element_wood": GameManager.element_wood += value
				"element_water": GameManager.element_water += value
				"element_fire": GameManager.element_fire += value
				"element_earth": GameManager.element_earth += value
				"aether": GameManager.aether += value
				"gold": GameManager.gold += value
		return_to_map()

