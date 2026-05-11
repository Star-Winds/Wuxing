extends Resource
class_name ReactionEffect

@export var combination: Array[String] = []
@export var reaction_name: String = ""
@export var description: String = ""
@export var effect: Dictionary = {}

func _init(p_combination: Array[String] = [], p_reaction_name: String = "", p_description: String = "", p_effect: Dictionary = {}):
	combination = p_combination
	reaction_name = p_reaction_name
	description = p_description
	effect = p_effect

func get_combination_key() -> String:
	if combination.size() != 2:
		return ""
	var sorted_comb = combination.duplicate()
	sorted_comb.sort()
	return sorted_comb[0] + "_" + sorted_comb[1]
