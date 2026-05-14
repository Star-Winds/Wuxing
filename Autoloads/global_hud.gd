extends CanvasLayer

# --- 资源注册表 ---
# 在 GlobalHUD.tscn 的检查器中拖入对应的场景文件
@export_group("悬浮层资源")
@export var map_ui_scene: PackedScene
@export var deck_builder_scene: PackedScene
@export var reaction_overlay_scene: PackedScene

@onready var hp_lbl: Label = %HPLabel
@onready var aether_lbl: Label = %AetherLabel
@onready var metal_lbl: Label = %MetalLabel
@onready var wood_lbl: Label = %WoodLabel
@onready var water_lbl: Label = %WaterLabel
@onready var fire_lbl: Label = %FireLabel
@onready var earth_lbl: Label = %EarthLabel
@onready var gold_lbl: Label = %GoldLabel
@onready var scene_name_label: Label = %SceneNameLabel
@onready var deck_btn: Button = %DeckButton
@onready var map_btn: Button = %MapButton
@onready var settings_btn: Button = %SettingsButton
@onready var reaction_btn: Button = %ReactionButton
@onready var equipment_row: HBoxContainer = %EquipmentRow
@onready var equipment_label: Label = %EquipmentLabel

var map_overlay_instance: Node = null
var deck_overlay_instance: Node = null
var reaction_overlay_instance: Node = null

func _ready() -> void:
	visible = false
	settings_btn.pressed.connect(_on_settings_pressed)
	map_btn.pressed.connect(_on_map_peek_pressed)
	deck_btn.pressed.connect(_on_deck_peek_pressed)
	reaction_btn.pressed.connect(_on_reaction_peek_pressed)

	# Connect update_display to EventBus signals (avoids polling _process every frame)
	EventBus.damage_taken.connect(_on_event_relay)
	EventBus.player_hp_changed.connect(_on_event_relay)
	EventBus.aether_changed.connect(_on_event_relay)
	EventBus.element_generated.connect(_on_event_relay)

	update_display()

func _on_event_relay(_a = null, _b = null, _c = null, _d = null) -> void:
	## Relay for any EventBus signal that should trigger a HUD refresh.
	## Uses default args to accommodate varying signal signatures.
	update_display()

func update_display() -> void:
	var hp_text = "HP: %d/%d" % [GameManager.current_health, GameManager.max_health]
	var current_scene = get_tree().current_scene
	if current_scene and "player_shield" in current_scene:
		var shield = current_scene.player_shield
		if shield > 0:
			hp_text += " (+%d 护盾)" % shield
	hp_lbl.text = hp_text
	
	aether_lbl.text = "以太: %d" % GameManager.aether
	metal_lbl.text = "金: %d" % GameManager.element_metal
	wood_lbl.text = "木: %d" % GameManager.element_wood
	water_lbl.text = "水: %d" % GameManager.element_water
	fire_lbl.text = "火: %d" % GameManager.element_fire
	earth_lbl.text = "土: %d" % GameManager.element_earth
	gold_lbl.text = "金币: %d" % GameManager.gold

	# Update equipment display
	var equip_list: Array[EquipmentData] = GameManager.acquired_equipment
	if equip_list.is_empty():
		equipment_row.visible = false
	else:
		var names: Array[String] = []
		for eq in equip_list:
			names.append(eq.equipment_name)
		equipment_label.text = "装备: " + " | ".join(names)
		equipment_row.visible = true

func set_scene_name(scene_name: String) -> void:
	if scene_name_label:
		scene_name_label.text = "当前场景: " + scene_name
	close_all_overlays()

func _on_map_peek_pressed() -> void:
	if map_overlay_instance != null:
		map_overlay_instance.queue_free()
		map_overlay_instance = null
		return
		
	# 使用资源引用进行判断，避免字符串比对
	var cur = get_tree().current_scene
	if cur.scene_file_path == map_ui_scene.resource_path:
		return 
		
	close_all_overlays()
	
	# 使用实例化方法，彻底废弃 load()
	if map_ui_scene:
		map_overlay_instance = map_ui_scene.instantiate()
		add_child(map_overlay_instance)
		move_child(map_overlay_instance, 0)

func _on_deck_peek_pressed() -> void:
	if deck_overlay_instance != null:
		deck_overlay_instance.queue_free()
		deck_overlay_instance = null
		return
		
	var cur = get_tree().current_scene
	if cur.scene_file_path == deck_builder_scene.resource_path:
		return 
		
	close_all_overlays()
	
	if deck_builder_scene:
		deck_overlay_instance = deck_builder_scene.instantiate()
		add_child(deck_overlay_instance)
		move_child(deck_overlay_instance, 0)

func _on_reaction_peek_pressed() -> void:
	if reaction_overlay_instance != null:
		reaction_overlay_instance.queue_free()
		reaction_overlay_instance = null
		return
		
	close_all_overlays()
	
	if reaction_overlay_scene:
		reaction_overlay_instance = reaction_overlay_scene.instantiate()
		add_child(reaction_overlay_instance)
		move_child(reaction_overlay_instance, 0)

func _on_settings_pressed() -> void:
	PauseOverlay.toggle_pause()

func close_all_overlays() -> void:
	if map_overlay_instance != null:
		map_overlay_instance.queue_free()
		map_overlay_instance = null
	if deck_overlay_instance != null:
		deck_overlay_instance.queue_free()
		deck_overlay_instance = null
	if reaction_overlay_instance != null:
		reaction_overlay_instance.queue_free()
		reaction_overlay_instance = null