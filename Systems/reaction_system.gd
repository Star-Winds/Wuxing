class_name ReactionSystem
extends RefCounted

const RegenerateAllCards = preload("res://Data/RegenerateAllCards.gd")

var owned_reactions: Array[ReactionData] = []
## combo_key -> CardData (效果由 card_data.main_keywords 驱动)
var equipped_reactions: Dictionary = {}

signal reactions_updated
signal reaction_equipped(reaction: ReactionData)
signal reaction_discarded(reaction: ReactionData)

# 20 种反应的 combo --> CardData path 映射（与 RegenerateAllCards 中定义一致）
const REACTION_CARD_PATHS: Dictionary = {
	"火_水": "res://Resources/Cards/Reactions/reaction_fire_water.tres",
	"水_火": "res://Resources/Cards/Reactions/reaction_water_fire.tres",
	"火_土": "res://Resources/Cards/Reactions/reaction_fire_earth.tres",
	"土_火": "res://Resources/Cards/Reactions/reaction_earth_fire.tres",
	"火_木": "res://Resources/Cards/Reactions/reaction_fire_wood.tres",
	"木_火": "res://Resources/Cards/Reactions/reaction_wood_fire.tres",
	"火_金": "res://Resources/Cards/Reactions/reaction_fire_metal.tres",
	"金_火": "res://Resources/Cards/Reactions/reaction_metal_fire.tres",
	"水_木": "res://Resources/Cards/Reactions/reaction_water_wood.tres",
	"木_水": "res://Resources/Cards/Reactions/reaction_wood_water.tres",
	"水_土": "res://Resources/Cards/Reactions/reaction_water_earth.tres",
	"土_水": "res://Resources/Cards/Reactions/reaction_earth_water.tres",
	"水_金": "res://Resources/Cards/Reactions/reaction_water_metal.tres",
	"金_水": "res://Resources/Cards/Reactions/reaction_metal_water.tres",
	"木_土": "res://Resources/Cards/Reactions/reaction_wood_earth.tres",
	"土_木": "res://Resources/Cards/Reactions/reaction_earth_wood.tres",
	"木_金": "res://Resources/Cards/Reactions/reaction_wood_metal.tres",
	"金_木": "res://Resources/Cards/Reactions/reaction_metal_wood.tres",
	"金_土": "res://Resources/Cards/Reactions/reaction_metal_earth.tres",
	"土_金": "res://Resources/Cards/Reactions/reaction_earth_metal.tres",
}

func initialize_defaults() -> void:
	owned_reactions.clear()
	equipped_reactions.clear()

	for combo_key in REACTION_CARD_PATHS:
		var card_path: String = REACTION_CARD_PATHS[combo_key]
		var card_data: CardData

		if ResourceLoader.exists(card_path):
			card_data = load(card_path)
		else:
			# 降级：直接从 RegenerateAllCards 的内存定义构建卡牌
			card_data = _build_card_in_memory(combo_key)
			if card_data == null:
				printerr("[ReactionSystem] Cannot load or build reaction: ", combo_key)
				continue

		var reaction = ReactionData.new()
		reaction.reaction_name = card_data.card_name
		reaction.card_data = card_data
		var parts = combo_key.split("_")
		var combo_arr: Array[String] = []
		for p in parts:
			combo_arr.append(p)
		reaction.combination = combo_arr
		reaction.description = card_data.description
		# color from card element
		if card_data.element == "火": reaction.reaction_color = Color("#FF5252")
		elif card_data.element == "水": reaction.reaction_color = Color("#29B6F6")
		elif card_data.element == "木": reaction.reaction_color = Color("#66BB6A")
		elif card_data.element == "金": reaction.reaction_color = Color("#FFCA28")
		elif card_data.element == "土": reaction.reaction_color = Color("#8D6E63")
		else: reaction.reaction_color = Color("#FFFFFF")

		owned_reactions.append(reaction)

		if not equipped_reactions.has(combo_key):
			equipped_reactions[combo_key] = card_data


## 从 RegenerateAllCards 定义中构建内存卡牌（无需 .tres 文件）
var _fallback_cards: Dictionary = {}  # combo_key -> CardData (lazy init)

func _build_card_in_memory(combo_key: String) -> CardData:
	if _fallback_cards.is_empty():
		var gen = RegenerateAllCards.new()
		var cards: Array = gen._define_all_cards()
		for entry in cards:
			var cid: String = entry.get("id", "")
			if cid.begins_with("Reaction_"):
				# Derive combo_key from id: Reaction_Fire_Water -> 火_水
				var parts = cid.trim_prefix("Reaction_").split("_")
				if parts.size() >= 2:
					var ek = parts[0] + "_" + parts[1]
					var elems = {
						"Fire": "火", "Earth": "土", "Water": "水",
						"Metal": "金", "Wood": "木"
					}
					var e1 = elems.get(parts[0], parts[0])
					var e2 = elems.get(parts[1], parts[1])
					ek = e1 + "_" + e2

					var cd = CardData.new()
					cd.id = cid
					cd.card_name = entry["name"]
					cd.element = entry["el"]
					cd.is_reaction = true
					cd.description = entry.get("desc", "")
					cd.main_slots = RegenerateAllCards._build_card_slots(entry.get("main_kw", []))
					cd.compile_slots()
					_fallback_cards[ek] = cd
	return _fallback_cards.get(combo_key)

func equip_reaction(reaction: ReactionData) -> void:
	if reaction == null: return
	var key = reaction.get_combo_key()
	if key == "": return
	equipped_reactions[key] = reaction.card_data
	reaction_equipped.emit(reaction)
	reactions_updated.emit()
	print("Equipped reaction: ", reaction.reaction_name, " for ", key)

func discard_reaction(reaction: ReactionData) -> void:
	if reaction == null: return
	var key = reaction.get_combo_key()
	if key != "" and equipped_reactions.get(key) == reaction.card_data:
		equipped_reactions.erase(key)
		print("Unequipped reaction on discard: ", reaction.reaction_name)
	owned_reactions.erase(reaction)
	reaction_discarded.emit(reaction)
	reactions_updated.emit()
	print("Discarded reaction: ", reaction.reaction_name)

## 返回装备的 CardData（效果由 card_data.main_keywords 驱动）
func get_equipped(combo_key: String) -> CardData:
	return equipped_reactions.get(combo_key)

func has_reaction(reaction_name: String) -> bool:
	for r in owned_reactions:
		if r.reaction_name == reaction_name:
			return true
	return false


func to_dict() -> Dictionary:
	var owned_data: Array = []
	for r in owned_reactions:
		owned_data.append({
			"name": r.reaction_name,
			"combo": r.combination.duplicate(),
			"color_hex": "#%02x%02x%02x" % [
				int(clampf(r.reaction_color.r, 0.0, 1.0) * 255),
				int(clampf(r.reaction_color.g, 0.0, 1.0) * 255),
				int(clampf(r.reaction_color.b, 0.0, 1.0) * 255),
			],
			"desc": r.description,
		})

	var equipped_data: Dictionary = {}
	for key in equipped_reactions:
		var card: CardData = equipped_reactions[key]
		if card:
			equipped_data[key] = card.id

	return {
		"owned_reactions": owned_data,
		"equipped_reactions": equipped_data,
	}


func from_dict(d: Dictionary) -> void:
	if d.is_empty(): return

	owned_reactions.clear()
	var owned_data: Array = d.get("owned_reactions", [])
	for item in owned_data:
		var r := ReactionData.new()
		r.reaction_name = item.get("name", "")
		var combo_arr: Array[String] = []
		for elem in item.get("combo", []):
			combo_arr.append(elem)
		r.combination = combo_arr
		var hex: String = item.get("color_hex", "#FFFFFF")
		r.reaction_color = Color(hex)
		r.description = item.get("desc", "")
		# Try to reassociate card_data by loading from path
		var key = r.get_combo_key()
		if REACTION_CARD_PATHS.has(key) and ResourceLoader.exists(REACTION_CARD_PATHS[key]):
			r.card_data = load(REACTION_CARD_PATHS[key])
		owned_reactions.append(r)

	equipped_reactions.clear()
	var equipped_data: Dictionary = d.get("equipped_reactions", {})
	for key in equipped_data:
		var card_id: String = equipped_data[key]
		# Find card_data from owned reactions
		for r in owned_reactions:
			if r.card_data and r.card_data.id == card_id:
				equipped_reactions[key] = r.card_data
				break
		# Fallback: try direct load
		if not equipped_reactions.has(key) and REACTION_CARD_PATHS.has(key):
			if ResourceLoader.exists(REACTION_CARD_PATHS[key]):
				equipped_reactions[key] = load(REACTION_CARD_PATHS[key])
