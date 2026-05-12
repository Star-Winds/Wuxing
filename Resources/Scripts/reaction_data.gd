extends Resource
class_name ReactionData

@export var reaction_name: String = ""
@export var combination: Array[String] = [] # Length should be 2
@export_multiline var description: String = ""
@export var reaction_color: Color = Color.WHITE
@export var icon: Texture2D

func get_combo_key() -> String:
	if combination.size() < 2:
		return ""
	var temp = combination.duplicate()
	temp.sort()
	return temp[0] + "_" + temp[1]
