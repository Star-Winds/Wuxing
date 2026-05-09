extends CanvasLayer

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

var map_overlay_instance: Node = null
var deck_overlay_instance: Node = null
var reaction_overlay_instance: Node = null

func _ready() -> void:
	visible = false # Starts hidden when the game boots
	settings_btn.pressed.connect(_on_settings_pressed)
	map_btn.pressed.connect(_on_map_peek_pressed)
	deck_btn.pressed.connect(_on_deck_peek_pressed)
	reaction_btn.pressed.connect(_on_reaction_peek_pressed)
	update_display()

func _process(_delta: float) -> void:
	update_display()

func update_display() -> void:
	# 1. Update HP & Shield (queries current scene for combat shield)
	var hp_text = "HP: %d/%d" % [GameManager.current_health, GameManager.max_health]
	var current_scene = get_tree().current_scene
	if current_scene and "player_shield" in current_scene:
		var shield = current_scene.player_shield
		if shield > 0:
			hp_text += " (+%d 护盾)" % shield
	hp_lbl.text = hp_text
	
	# 2. Update Elements & Gold
	aether_lbl.text = "以太: %d" % GameManager.aether
	metal_lbl.text = "金: %d" % GameManager.element_metal
	wood_lbl.text = "木: %d" % GameManager.element_wood
	water_lbl.text = "水: %d" % GameManager.element_water
	fire_lbl.text = "火: %d" % GameManager.element_fire
	earth_lbl.text = "土: %d" % GameManager.element_earth
	gold_lbl.text = "金币: %d" % GameManager.gold

func set_scene_name(scene_name: String) -> void:
	if scene_name_label:
		scene_name_label.text = "当前场景: " + scene_name
		
	# Automatically close map peek overlay when transitioning to a new room
	if map_overlay_instance != null:
		map_overlay_instance.queue_free()
		map_overlay_instance = null
		
	# Automatically close deck peek overlay when transitioning to a new room
	if deck_overlay_instance != null:
		deck_overlay_instance.queue_free()
		deck_overlay_instance = null

	# Automatically close reaction peek overlay when transitioning to a new room
	if reaction_overlay_instance != null:
		reaction_overlay_instance.queue_free()
		reaction_overlay_instance = null

func _on_map_peek_pressed() -> void:
	# If map is already open as peek, close it
	if map_overlay_instance != null:
		map_overlay_instance.queue_free()
		map_overlay_instance = null
		return
		
	# Prevent opening map peek if we are ACTUALLY on the real map screen
	var cur = get_tree().current_scene
	if cur.name == "MapUI" or (cur.scene_file_path != "" and "map_ui" in cur.scene_file_path):
		return 
		
	# Close other overlays if open
	if deck_overlay_instance != null:
		deck_overlay_instance.queue_free()
		deck_overlay_instance = null
	if reaction_overlay_instance != null:
		reaction_overlay_instance.queue_free()
		reaction_overlay_instance = null
		
	# Instantiate map as an overlay
	map_overlay_instance = load("res://map_ui.tscn").instantiate()
	add_child(map_overlay_instance)
	# Move it below the HUD elements but above the game
	move_child(map_overlay_instance, 0)

func _on_deck_peek_pressed() -> void:
	# If deck overlay is already open, close it
	if deck_overlay_instance != null:
		deck_overlay_instance.queue_free()
		deck_overlay_instance = null
		return
		
	# Prevent opening deck peek if we are ACTUALLY on the real deck builder scene
	var cur = get_tree().current_scene
	if cur.name == "DeckBuilderUI" or (cur.scene_file_path != "" and "deck_builder" in cur.scene_file_path):
		return 
		
	# Close other overlays if open
	if map_overlay_instance != null:
		map_overlay_instance.queue_free()
		map_overlay_instance = null
	if reaction_overlay_instance != null:
		reaction_overlay_instance.queue_free()
		reaction_overlay_instance = null
		
	# Instantiate deck builder as an overlay
	deck_overlay_instance = load("res://deck_builder_ui.tscn").instantiate()
	add_child(deck_overlay_instance)
	# Move it below the HUD elements but above the game
	move_child(deck_overlay_instance, 0)

func _on_reaction_peek_pressed() -> void:
	# If reaction overlay is already open, close it
	if reaction_overlay_instance != null:
		reaction_overlay_instance.queue_free()
		reaction_overlay_instance = null
		return
		
	# Close other overlays if open
	if map_overlay_instance != null:
		map_overlay_instance.queue_free()
		map_overlay_instance = null
	if deck_overlay_instance != null:
		deck_overlay_instance.queue_free()
		deck_overlay_instance = null
		
	# Instantiate reaction overlay as an overlay
	reaction_overlay_instance = load("res://UI/reaction_overlay.tscn").instantiate()
	add_child(reaction_overlay_instance)
	# Move it below the HUD elements but above the game
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
