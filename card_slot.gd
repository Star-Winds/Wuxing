extends Control
class_name CardSlot

signal activation_requested(slot: CardSlot, cost_dict: Dictionary)

enum SlotState {
	INACTIVE,
	ACTIVATED,
	PLAYED
}

var current_state: SlotState = SlotState.INACTIVE
var cost_dict: Dictionary = {}

@export var is_sub_slot: bool = false

@onready var background: ColorRect = $Background
@onready var name_label: Label = $NameLabel
@onready var stats_label: Label = $StatsLabel
@onready var button: Button = $Button

var sub_slots: Array[CardSlot] = []

func _ready() -> void:
	if button:
		button.pressed.connect(_on_button_pressed)
		
	# Sub-slots are now siblings in the same HBoxContainer row
	if not is_sub_slot and get_parent() is HBoxContainer:
		for child in get_parent().get_children():
			if child is CardSlot and child != self:
				sub_slots.append(child)
				
	_update_visuals()

func _on_button_pressed() -> void:
	if is_sub_slot:
		return # Sub-slots cannot be clicked independently
		
	match current_state:
		SlotState.INACTIVE:
			activation_requested.emit(self, cost_dict)
		SlotState.ACTIVATED:
			var battle_ui = get_node_or_null("/root/BattleUI")
			if battle_ui:
				battle_ui.pending_play_slot = self
				print("Waiting for target...")
		SlotState.PLAYED:
			print("Card in cooldown.")

func _activate_confirmed() -> void:
	if not is_sub_slot:
		print(name + " activation confirmed. (Resources deducted)")
	current_state = SlotState.ACTIVATED
	_update_visuals()
	
	if not is_sub_slot:
		for sub_slot in sub_slots:
			sub_slot._activate_confirmed()

func _finalize_play() -> void:
	current_state = SlotState.PLAYED
	_update_visuals()
	
	if not is_sub_slot:
		for sub_slot in sub_slots:
			if sub_slot.current_state == SlotState.ACTIVATED:
				sub_slot._finalize_play()

func reset_turn() -> void:
	# Only reset if PLAYED. ACTIVATED stays across turns.
	if current_state == SlotState.PLAYED:
		current_state = SlotState.INACTIVE
		_update_visuals()

func _update_visuals() -> void:
	if not background: return
	
	var element_color: Color = Color(0.2, 0.2, 0.2)
	var card_id = get_meta("card_id", "")
	var battle_ui = get_node_or_null("/root/BattleUI")
	
	if battle_ui and card_id != "":
		var card_database = battle_ui.card_database
		if not card_database.has(card_id):
			print("ERROR: Card ID '", card_id, "' not found in database! Defaulting to visual fallback.")
			if name_label: name_label.text = "Missing Card"
			return
			
	if battle_ui and card_id != "" and battle_ui.card_database.has(card_id):
		var card_data = battle_ui.card_database[card_id]
		var element = card_data.get("element", "")
		if element != "" and battle_ui.element_colors.has(element):
			element_color = battle_ui.element_colors[element]
			
	match current_state:
		SlotState.INACTIVE:
			if card_id != "":
				background.color = Color(element_color, 0.2)
			else:
				background.color = Color(0.2, 0.2, 0.2)
			if name_label: name_label.modulate = Color(1, 1, 1)
		SlotState.ACTIVATED:
			background.color = element_color
			if name_label: name_label.modulate = Color(1, 1, 1)
		SlotState.PLAYED:
			background.color = Color(0.1, 0.1, 0.1)
			if name_label: name_label.modulate = Color(0.5, 0.5, 0.5)

func to_dict() -> Dictionary:
	var state_str: String = "INACTIVE"
	match current_state:
		SlotState.INACTIVE:
			state_str = "INACTIVE"
		SlotState.ACTIVATED:
			state_str = "ACTIVATED"
		SlotState.PLAYED:
			state_str = "PLAYED"
	
	var name_text: String = ""
	if name_label:
		name_text = name_label.text
		
	var sub_slots_array: Array = []
	for sub_slot in sub_slots:
		if sub_slot:
			sub_slots_array.append(sub_slot.to_dict())
			
	return {
		"card_id": get_meta("card_id", ""),
		"name": name_text,
		"is_sub_slot": is_sub_slot,
		"current_state": state_str,
		"sub_slots": sub_slots_array
	}
