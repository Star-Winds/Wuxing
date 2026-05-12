# res://UI/reaction_overlay.gd
extends Control

@onready var close_button: Button = %CloseButton
@onready var list_container: VBoxContainer = %ListContainer

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
	# Connect style to close button
	_style_button(close_button, Color(0.2, 0.2, 0.25, 0.7), Color(0.3, 0.3, 0.35, 0.85), Color(0.4, 0.4, 0.45, 0.5))
	
	# Populate dynamic inventory view
	_populate_reactions()

func _on_close_pressed() -> void:
	if GlobalHUD.get("reaction_overlay_instance") == self:
		GlobalHUD.reaction_overlay_instance = null
	queue_free()

func _populate_reactions() -> void:
	for child in list_container.get_children():
		child.queue_free()
		
	if GameManager.owned_reactions.is_empty():
		var empty_panel = _create_styled_panel()
		var empty_lbl = Label.new()
		empty_lbl.text = "暂无拥有的五行反应。在战斗胜利后有几率获得反应秘籍！"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_panel.add_child(empty_lbl)
		list_container.add_child(empty_panel)
		return
		
	# Populate each owned reaction
	for reaction in GameManager.owned_reactions:
		if reaction == null:
			continue
		
		# Create Card Container
		var card = _create_reaction_card(reaction)
		list_container.add_child(card)
		
		# Root layout inside the card
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 20)
		card.add_child(hbox)
		
		# Left Column: Info
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 10)
		hbox.add_child(info_vbox)
		
		# Title HBox: Element Badges + Name
		var title_hbox = HBoxContainer.new()
		title_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		title_hbox.add_theme_constant_override("separation", 8)
		info_vbox.add_child(title_hbox)
		
		# Elements
		if reaction.combination.size() >= 2:
			var badge1 = _create_element_badge(reaction.combination[0])
			var badge2 = _create_element_badge(reaction.combination[1])
			title_hbox.add_child(badge1)
			
			var plus_lbl = Label.new()
			plus_lbl.text = "+"
			plus_lbl.add_theme_font_size_override("font_size", 14)
			plus_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			title_hbox.add_child(plus_lbl)
			
			title_hbox.add_child(badge2)
			
		var space_ctrl = Control.new()
		space_ctrl.custom_minimum_size = Vector2(10, 0)
		title_hbox.add_child(space_ctrl)
		
		# Reaction Name
		var name_lbl = Label.new()
		name_lbl.text = "【" + reaction.reaction_name + "】"
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", reaction.reaction_color)
		title_hbox.add_child(name_lbl)
		
		# Description
		var desc_lbl = Label.new()
		desc_lbl.text = reaction.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		info_vbox.add_child(desc_lbl)
		
		# Status Badge HBox
		var status_hbox = HBoxContainer.new()
		info_vbox.add_child(status_hbox)
		
		var combo_key = reaction.get_combo_key()
		var currently_equipped = GameManager.equipped_reactions.get(combo_key)
		var is_equipped = currently_equipped == reaction
		
		var status_badge = PanelContainer.new()
		var sb_style = StyleBoxFlat.new()
		sb_style.set_corner_radius_all(4)
		sb_style.content_margin_left = 10
		sb_style.content_margin_right = 10
		sb_style.content_margin_top = 3
		sb_style.content_margin_bottom = 3
		
		var sb_lbl = Label.new()
		sb_lbl.add_theme_font_size_override("font_size", 12)
		
		if is_equipped:
			sb_style.bg_color = Color(0.1, 0.4, 0.15, 0.3)
			sb_style.border_width_left = 1
			sb_style.border_width_top = 1
			sb_style.border_width_right = 1
			sb_style.border_width_bottom = 1
			sb_style.border_color = Color(0.2, 0.8, 0.3, 0.6)
			sb_lbl.text = "已装配 (Equipped)"
			sb_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		else:
			sb_style.bg_color = Color(0.2, 0.2, 0.25, 0.3)
			sb_style.border_width_left = 1
			sb_style.border_width_top = 1
			sb_style.border_width_right = 1
			sb_style.border_width_bottom = 1
			sb_style.border_color = Color(0.5, 0.5, 0.6, 0.4)
			
			if currently_equipped != null:
				sb_lbl.text = "未装配 - 槽位已被【" + currently_equipped.reaction_name + "】占用"
				sb_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
			else:
				sb_lbl.text = "闲置 (Available)"
				sb_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
				
		status_badge.add_theme_stylebox_override("panel", sb_style)
		status_badge.add_child(sb_lbl)
		status_hbox.add_child(status_badge)
		
		# Right Column: Action Buttons
		var btn_vbox = VBoxContainer.new()
		btn_vbox.custom_minimum_size = Vector2(130, 0)
		btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_vbox.add_theme_constant_override("separation", 10)
		hbox.add_child(btn_vbox)
		
		# Equip Button
		var equip_btn = Button.new()
		btn_vbox.add_child(equip_btn)
		
		if is_equipped:
			equip_btn.text = "已装配"
			equip_btn.disabled = true
			_style_button(equip_btn, Color(0.12, 0.16, 0.12, 0.5), Color(0.12, 0.16, 0.12, 0.5))
		else:
			if currently_equipped != null:
				equip_btn.text = "替换装配"
				_style_button(equip_btn, Color(0.8, 0.45, 0.1, 0.8), Color(0.9, 0.55, 0.15, 0.9))
			else:
				equip_btn.text = "装配"
				_style_button(equip_btn, Color(0.1, 0.6, 0.75, 0.8), Color(0.15, 0.7, 0.85, 0.9))
				
			equip_btn.pressed.connect(func():
				GameManager.equip_reaction(reaction)
				_populate_reactions()
			)
			
		# Discard Button
		var discard_btn = Button.new()
		discard_btn.text = "分解"
		btn_vbox.add_child(discard_btn)
		_style_button(discard_btn, Color(0.7, 0.15, 0.15, 0.7), Color(0.85, 0.2, 0.2, 0.85))
		discard_btn.pressed.connect(func():
			GameManager.discard_reaction(reaction)
			_populate_reactions()
		)

func _create_reaction_card(reaction: ReactionData) -> PanelContainer:
	var card = PanelContainer.new()
	var combo_key = reaction.get_combo_key()
	var is_equipped = GameManager.equipped_reactions.get(combo_key) == reaction
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.8) # Sleek charcoal glassmorphism
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_top = 15
	style.content_margin_right = 20
	style.content_margin_bottom = 15
	
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	if is_equipped:
		style.border_color = reaction.reaction_color
		style.border_color.a = 0.6
	else:
		style.border_color = Color(0.2, 0.2, 0.25, 0.4)
		
	card.add_theme_stylebox_override("panel", style)
	return card

func _create_element_badge(element_name: String) -> PanelContainer:
	var badge = PanelContainer.new()
	var style = StyleBoxFlat.new()
	var hex_color = ELEMENT_COLORS.get(element_name, "#FFFFFF")
	style.bg_color = Color(hex_color)
	style.bg_color.a = 0.85
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = element_name
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(label)
	
	return badge

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

func _style_button(btn: Button, bg_color: Color, hover_color: Color, border_color: Color = Color.TRANSPARENT) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.set_corner_radius_all(6)
	style_normal.content_margin_left = 12
	style_normal.content_margin_right = 12
	style_normal.content_margin_top = 6
	style_normal.content_margin_bottom = 6
	if border_color != Color.TRANSPARENT:
		style_normal.border_width_left = 1
		style_normal.border_width_top = 1
		style_normal.border_width_right = 1
		style_normal.border_width_bottom = 1
		style_normal.border_color = border_color
		
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = hover_color
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = bg_color.darkened(0.2)
	
	var style_disabled = style_normal.duplicate()
	style_disabled.bg_color = bg_color.darkened(0.5)
	style_disabled.bg_color.a = 0.3
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("disabled", style_disabled)
	
	# Hover scaling animations
	btn.mouse_entered.connect(func():
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.1).set_trans(Tween.TRANS_SINE)
	)
	btn.mouse_exited.connect(func():
		var tween = btn.create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	)
	
	# Wait for layout to determine correct pivot offset, or assign standard center pivot
	btn.pivot_offset = Vector2(65, 18)