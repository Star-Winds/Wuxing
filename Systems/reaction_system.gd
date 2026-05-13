class_name ReactionSystem
extends RefCounted

var owned_reactions: Array[ReactionData] = []
var equipped_reactions: Dictionary = {} # combo_key -> ReactionData

signal reactions_updated
signal reaction_equipped(reaction: ReactionData)
signal reaction_discarded(reaction: ReactionData)

func initialize_defaults() -> void:
	owned_reactions.clear()
	equipped_reactions.clear()

	var default_list = [
		{"name": "蒸腾", "combo": ["火", "水"], "color": Color("#FF5252"), "desc": "提供烧伤效果，每回合按层数结算扣血"},
		{"name": "熄灭", "combo": ["水", "火"], "color": Color("#29B6F6"), "desc": "为目标赋予“虚弱”（造成伤害x0.75）2回合"},
		{"name": "烧制", "combo": ["火", "土"], "color": Color("#FF8A65"), "desc": "敌方获得脆化（受伤x1.5）2回合，主控获得1点土元素"},
		{"name": "余烬", "combo": ["土", "火"], "color": Color("#FF7043"), "desc": "本回合每受到伤害一次，则返还主控1火元素"},
		{"name": "焚烬", "combo": ["火", "木"], "color": Color("#FF3D00"), "desc": "本次火元素伤害翻倍"},
		{"name": "添柴", "combo": ["木", "火"], "color": Color("#66BB6A"), "desc": "主控获得3点火元素"},
		{"name": "熔炼", "combo": ["火", "金"], "color": Color("#FF7043"), "desc": "如果目标有护盾，则破除目标的护盾，再结算伤害"},
		{"name": "过载", "combo": ["金", "火"], "color": Color("#FF8F00"), "desc": "随机激活一个当前未激活的副槽卡牌"},
		{"name": "润泽", "combo": ["水", "木"], "color": Color("#4FC3F7"), "desc": "主控随机获得2单位非水元素"},
		{"name": "吸纳", "combo": ["木", "水"], "color": Color("#26A69A"), "desc": "从目标处偷取1点以太 (直接增加1点以太)"},
		{"name": "泥沼", "combo": ["水", "土"], "color": Color("#8D6E63"), "desc": "为目标赋予“减速”（获得护盾量x0.5）2回合"},
		{"name": "阻截", "combo": ["土", "水"], "color": Color("#8D6E63"), "desc": "禁锢目标，若其行动是攻击则推迟到下回合"},
		{"name": "淬火", "combo": ["水", "金"], "color": Color("#26C6DA"), "desc": "触发该反应的卡牌可以在本回合内再次“激活”"},
		{"name": "涌泉", "combo": ["金", "水"], "color": Color("#FFD54F"), "desc": "激活后，立即补充2单位水元素"},
		{"name": "破土", "combo": ["木", "土"], "color": Color("#8D6E63"), "desc": "无视目标护盾，直接造成5木元素伤害 (真实伤害)"},
		{"name": "固本", "combo": ["土", "木"], "color": Color("#81C784"), "desc": "恢复4点生命值"},
		{"name": "坚韧", "combo": ["木", "金"], "color": Color("#9CCC65"), "desc": "主控获得“反震”（受击时回敬3伤）"},
		{"name": "伐断", "combo": ["金", "木"], "color": Color("#A1887F"), "desc": "施加流血效果（动作时扣血），持续2回合"},
		{"name": "合金", "combo": ["金", "土"], "color": Color("#FFCA28"), "desc": "主控获得“合金”，提供1点减伤，直到本次对局结束"},
		{"name": "埋藏", "combo": ["土", "金"], "color": Color("#BCAAA4"), "desc": "下次在“车间”节点打造装备时，消耗减少2点金元素"}
	]

	for data in default_list:
		var reaction = ReactionData.new()
		reaction.reaction_name = data["name"]
		var combo_arr: Array[String] = []
		for elem in data["combo"]:
			combo_arr.append(elem)
		reaction.combination = combo_arr
		reaction.reaction_color = data["color"]
		reaction.description = data["desc"]
		owned_reactions.append(reaction)

		var key = reaction.get_combo_key()
		if not equipped_reactions.has(key):
			equipped_reactions[key] = reaction

func equip_reaction(reaction: ReactionData) -> void:
	if reaction == null: return
	var key = reaction.get_combo_key()
	if key == "": return
	equipped_reactions[key] = reaction
	reaction_equipped.emit(reaction)
	reactions_updated.emit()
	print("Equipped reaction: ", reaction.reaction_name, " for ", key)

func discard_reaction(reaction: ReactionData) -> void:
	if reaction == null: return
	var key = reaction.get_combo_key()
	if key != "" and equipped_reactions.get(key) == reaction:
		equipped_reactions.erase(key)
		print("Unequipped reaction on discard: ", reaction.reaction_name)
	owned_reactions.erase(reaction)
	reaction_discarded.emit(reaction)
	reactions_updated.emit()
	print("Discarded reaction: ", reaction.reaction_name)

func get_equipped(combo_key: String) -> ReactionData:
	return equipped_reactions.get(combo_key)

func has_reaction(reaction_name: String) -> bool:
	for r in owned_reactions:
		if r.reaction_name == reaction_name:
			return true
	return false
