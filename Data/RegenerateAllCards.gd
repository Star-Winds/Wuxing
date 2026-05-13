extends RefCounted

# ════════════════════════════════════════════════════════════════
#  全卡牌词条化生成器
#  一次性生成所有 74 张卡牌 + 所需词条 .tres 文件
#  运行前会清空 Resources/Cards/ 和 Resources/Keywords/
# ════════════════════════════════════════════════════════════════

const KEYWORD_DIR = "res://Resources/Keywords/"
const CARDS_DIR = "res://Resources/Cards/"

var _keyword_lookup: Dictionary = {}  # keyword_id → KeywordData

func run() -> void:
	print("==============================================")
	print("[全卡牌词条化生成器] 开始工作...")
	print("==============================================")

	# 1. 确保目录存在
	for d in [KEYWORD_DIR, CARDS_DIR + "Fire/", CARDS_DIR + "Earth/",
			CARDS_DIR + "Water/", CARDS_DIR + "Metal/", CARDS_DIR + "Wood/",
			CARDS_DIR + "Aether/"]:
		if not DirAccess.dir_exists_absolute(d):
			DirAccess.make_dir_recursive_absolute(d)

	# 2. 加载所有卡牌定义
	var cards: Array[Dictionary] = _define_all_cards()
	print("定义卡牌总数: ", cards.size())

	# 3. 收集所有需要的词条 → 生成 .tres 文件
	var keyword_count = _generate_all_keywords(cards)
	print("词条文件: ", keyword_count)

	# 4. 重新加载词条
	_reload_keywords()

	# 5. 生成卡牌 .tres 文件
	var success = 0
	for card in cards:
		if _generate_card(card):
			success += 1

	print("\n==============================================")
	print("[生成完毕] %d/%d 张卡牌, %d 个词条" % [success, cards.size(), keyword_count])
	print("==============================================")


# ════════════════════════════════════════════════════════════════
#  词条收集与生成
# ════════════════════════════════════════════════════════════════

func _generate_all_keywords(cards: Array[Dictionary]) -> int:
	var seen: Dictionary = {}  # keyword_id → entry dict
	for card in cards:
		for entry in card.get("main_kw", []):
			var kid = entry.get("id", "")
			if not kid.is_empty() and not seen.has(kid):
				seen[kid] = entry
		for entry in card.get("sub_kw", []):
			var kid = entry.get("id", "")
			if not kid.is_empty() and not seen.has(kid):
				seen[kid] = entry

	var count = 0
	for kid in seen:
		var entry = seen[kid]
		var effect = _build_effect(entry)
		if effect == null:
			continue

		var kw = KeywordData.new()
		kw.keyword_id = kid
		kw.display_name = entry.get("display", kid)
		kw.description = entry.get("desc", "")
		kw.effect = effect

		var err = ResourceSaver.save(kw, KEYWORD_DIR + kid + ".tres")
		if err == OK:
			count += 1
		else:
			printerr("词条保存失败: ", kid, " 错误码: ", err)

	return count


func _build_effect(entry: Dictionary) -> EffectBase:
	match entry.get("type", ""):
		"damage":
			var e = DamageEffect.new()
			e.value = entry.get("value", 0)
			return e
		"shield":
			var e = ShieldEffect.new()
			e.value = entry.get("value", 0)
			return e
		"damage_shield":
			var e = DamageAndShieldEffect.new()
			e.damage = entry.get("value", 0)
			e.shield = entry.get("value2", 0)
			return e
		"heal":
			var e = HealEffect.new()
			e.value = entry.get("value", 0)
			return e
		"status":
			var e = StatusEffect.new()
			e.status_id = entry.get("status_id", "")
			e.amount = entry.get("value", 0)
			e.duration = entry.get("duration", 0)
			e.apply_to_player = entry.get("to_player", false)
			return e
		"gen":
			var e = GenerateElementEffect.new()
			e.element_type = entry.get("element_type", "以太")
			e.amount = entry.get("value", 0)
			return e
		"cond_damage":
			var e = ConditionDamageEffect.new()
			e.base_damage = entry.get("value", 0)
			e.condition = entry.get("condition", "")
			e.bonus_per_condition = entry.get("bonus", 0)
			return e
		"action":
			var e = SpecialActionEffect.new()
			e.action_id = entry.get("action_id", "")
			return e
		_:
			return null


# ════════════════════════════════════════════════════════════════
#  卡牌生成
# ════════════════════════════════════════════════════════════════

func _reload_keywords() -> void:
	_keyword_lookup.clear()
	if not DirAccess.dir_exists_absolute(KEYWORD_DIR):
		return
	var dir = DirAccess.open(KEYWORD_DIR)
	dir.list_dir_begin()
	var f = dir.get_next()
	while f != "":
		if f.ends_with(".tres") or f.ends_with(".res"):
			var kw = load(KEYWORD_DIR + f)
			if kw is KeywordData and not kw.keyword_id.is_empty():
				_keyword_lookup[kw.keyword_id] = kw
		f = dir.get_next()


func _generate_card(card: Dictionary) -> bool:
	var el_cn = card.get("el", "火")
	var el_en = _el_to_en(el_cn)
	var dir_path = CARDS_DIR + el_en + "/"
	var save_path = dir_path + card["id"].to_lower() + ".tres"

	var cd = CardData.new()
	cd.id = card["id"]
	cd.card_name = card["name"]
	cd.element = el_cn
	cd.element_attachment_layers = card.get("attach", 1)
	cd.description = card.get("desc", "")

	# 费用
	var cost = card.get("cost", {})
	cd.cost_metal = cost.get("金", 0)
	cd.cost_wood = cost.get("木", 0)
	cd.cost_water = cost.get("水", 0)
	cd.cost_fire = cost.get("火", 0)
	cd.cost_earth = cost.get("土", 0)
	cd.cost_aether = cost.get("以太", 0)

	# 词条引用
	cd.main_keywords = _resolve_keywords(card.get("main_kw", []))
	cd.sub_keywords = _resolve_keywords(card.get("sub_kw", []))

	# 旧字段向后兼容
	var main_parts: Array[String] = []
	for kw in cd.main_keywords:
		if kw and not kw.description.is_empty():
			main_parts.append(kw.description)
	cd.main_description = "\n".join(main_parts) if main_parts else card.get("desc", "")
	cd.main_value = cd.get_main_display_value()

	var sub_parts: Array[String] = []
	for kw in cd.sub_keywords:
		if kw and not kw.description.is_empty():
			sub_parts.append(kw.description)
	cd.sub_description = "\n".join(sub_parts) if sub_parts else ""
	cd.is_exhaust = card.get("is_exhaust", false)
	cd.single_use = card.get("single_use", false)

	var err = ResourceSaver.save(cd, save_path)
	if err == OK:
		print("  %s %s" % [card["id"], card["name"]])
		return true
	else:
		printerr("保存失败 %s 错误码: %d" % [card["id"], err])
		return false


func _resolve_keywords(entries: Array) -> Array[KeywordData]:
	var result: Array[KeywordData] = []
	for entry in entries:
		var kid = entry.get("id", "")
		if kid.is_empty():
			continue
		if _keyword_lookup.has(kid):
			result.append(_keyword_lookup[kid])
		else:
			printerr("  词条未找到: ", kid)
	return result


func _el_to_en(el: String) -> String:
	match el:
		"金": return "Metal"
		"木": return "Wood"
		"水": return "Water"
		"火": return "Fire"
		"土": return "Earth"
		"以太": return "Aether"
	return "Fire"


# ════════════════════════════════════════════════════════════════
#  全卡牌定义
# ════════════════════════════════════════════════════════════════

func _define_all_cards() -> Array[Dictionary]:
	return [
# ╔══════════════════════════════════════════════════════════════╗
# ║  火系 Fire_001~012 — 灼烧流派                                ║
# ╚══════════════════════════════════════════════════════════════╝

# ── 原始卡牌 Fire_001~006 ──
{
	"id": "Fire_001", "name": "火势", "el": "火", "cost": {"火": 3},
	"desc": "造成10点火元素伤害。若本牌上一回合已被激活，则伤害翻倍。",
	"main_kw": [
		{"id": "kw_cond_prev_turn_10_10", "type": "cond_damage",
		 "value": 10, "condition": "prev_turn_active", "bonus": 10,
		 "display": "蓄势10", "desc": "造成 10 点伤害。若上回合已激活，伤害+10"}
	],
	"sub_kw": []
},
{
	"id": "Fire_002", "name": "离火罩", "el": "火", "cost": {"火": 4},
	"desc": "每当你激活或打出一张卡牌，对敌方造成2点火伤。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_burn_1_1", "type": "status",
		 "status_id": "burn", "value": 1, "duration": 1,
		 "display": "灼烧1", "desc": "赋予 1 层灼烧"}
	]
},
{
	"id": "Fire_003", "name": "烛龙引", "el": "火", "cost": {"火": 2},
	"desc": "造成6点火伤。",
	"main_kw": [
		{"id": "kw_damage_6", "type": "damage", "value": 6,
		 "display": "伤害6", "desc": "造成 6 点伤害"}
	],
	"sub_kw": []
},
{
	"id": "Fire_004", "name": "焚天", "el": "火", "cost": {"火": 5},
	"desc": "造成8点火伤，先清除敌方护盾。",
	"main_kw": [
		{"id": "kw_damage_8", "type": "damage", "value": 8,
		 "display": "伤害8", "desc": "造成 8 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_action_shield_break", "type": "action",
		 "action_id": "shield_break",
		 "display": "破盾", "desc": "破除敌人护盾"}
	]
},
{
	"id": "Fire_005", "name": "死灰复燃", "el": "火", "cost": {"火": 0},
	"desc": "复制上一张火系卡牌效果50%。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_gen_fire_1", "type": "gen",
		 "value": 1, "element_type": "火",
		 "display": "生火1", "desc": "获得 1 点火元素"}
	]
},
{
	"id": "Fire_006", "name": "火攻", "el": "火", "cost": {"火": 2},
	"desc": "造成9火元素伤害。",
	"main_kw": [
		{"id": "kw_damage_9", "type": "damage", "value": 9,
		 "display": "伤害9", "desc": "造成 9 点伤害"}
	],
	"sub_kw": []
},

# ── 新卡牌 Fire_007~012 ──
{
	"id": "Fire_007", "name": "火花", "el": "火", "cost": {"火": 1},
	"desc": "造成4点火元素伤害。",
	"main_kw": [
		{"id": "kw_damage_4", "type": "damage", "value": 4,
		 "display": "伤害4", "desc": "造成 4 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_gen_fire_1", "type": "gen",
		 "value": 1, "element_type": "火",
		 "display": "生火1", "desc": "获得 1 点火元素"}
	]
},
{
	"id": "Fire_008", "name": "连珠火", "el": "火", "cost": {"火": 4},
	"desc": "造成6点火伤，然后重复1次。",
	"main_kw": [
		{"id": "kw_damage_6", "type": "damage", "value": 6,
		 "display": "伤害6", "desc": "造成 6 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_damage_3", "type": "damage", "value": 3,
		 "display": "伤害3", "desc": "造成 3 点伤害"}
	]
},
{
	"id": "Fire_009", "name": "纵火", "el": "火", "cost": {"火": 2},
	"desc": "赋予敌人灼烧3层，持续2回合。",
	"main_kw": [
		{"id": "kw_burn_3_2", "type": "status",
		 "status_id": "burn", "value": 3, "duration": 2,
		 "display": "灼烧3", "desc": "赋予灼烧 3 层，持续 2 回合"}
	],
	"sub_kw": [
		{"id": "kw_burn_1_1", "type": "status",
		 "status_id": "burn", "value": 1, "duration": 1,
		 "display": "灼烧1", "desc": "赋予 1 层灼烧"}
	]
},
{
	"id": "Fire_010", "name": "烈焰斩", "el": "火", "cost": {"火": 3},
	"desc": "造成5点火伤。若敌人有灼烧，伤害+2。",
	"main_kw": [
		{"id": "kw_cond_burn_5_2", "type": "cond_damage",
		 "value": 5, "condition": "enemy_has_burn", "bonus": 2,
		 "display": "烈焰斩", "desc": "造成 5 点伤害。若敌人有灼烧，伤害+2"}
	],
	"sub_kw": [
		{"id": "kw_damage_2", "type": "damage", "value": 2,
		 "display": "伤害2", "desc": "造成 2 点伤害"}
	]
},
{
	"id": "Fire_011", "name": "焚心", "el": "火", "cost": {"火": 5},
	"desc": "造成12点火伤。若敌人有灼烧，额外+5。",
	"main_kw": [
		{"id": "kw_cond_burn_12_5", "type": "cond_damage",
		 "value": 12, "condition": "enemy_has_burn", "bonus": 5,
		 "display": "焚心", "desc": "造成 12 点伤害。若敌人有灼烧，伤害+5"}
	],
	"sub_kw": [
		{"id": "kw_damage_5", "type": "damage", "value": 5,
		 "display": "伤害5", "desc": "造成 5 点伤害"}
	]
},
{
	"id": "Fire_012", "name": "不灭之火", "el": "火", "cost": {"火": 2},
	"desc": "赋予1层灼烧，持续延长。",
	"main_kw": [
		{"id": "kw_burn_1_1_b", "type": "status",
		 "status_id": "burn", "value": 1, "duration": 1,
		 "display": "灼烧续", "desc": "赋予 1 层灼烧"}
	],
	"sub_kw": [
		{"id": "kw_heal_3", "type": "heal", "value": 3,
		 "display": "治疗3", "desc": "回复 3 点生命"}
	]
},

# ╔══════════════════════════════════════════════════════════════╗
# ║  土系 Earth_007~017 — 护盾/反震流派                          ║
# ╚══════════════════════════════════════════════════════════════╝

# ── 原始卡牌 Earth_007~011 ──
{
	"id": "Earth_007", "name": "墙", "el": "土", "cost": {"土": 3},
	"desc": "获得10点护盾。",
	"main_kw": [
		{"id": "kw_shield_10", "type": "shield", "value": 10,
		 "display": "护盾10", "desc": "获得 10 点护盾"}
	],
	"sub_kw": []
},
{
	"id": "Earth_008", "name": "撼地", "el": "土", "cost": {"土": 4},
	"desc": "改变敌方意图。",
	"main_kw": [
		{"id": "kw_action_change_intent", "type": "action",
		 "action_id": "change_enemy_intent",
		 "display": "撼地", "desc": "强制改变敌方意图"}
	],
	"sub_kw": [
		{"id": "kw_shield_3", "type": "shield", "value": 3,
		 "display": "护盾3", "desc": "获得 3 点护盾"}
	]
},
{
	"id": "Earth_009", "name": "戌土甲", "el": "土", "cost": {"土": 3},
	"desc": "获得6点护盾，获得反震2持续2回合。",
	"main_kw": [
		{"id": "kw_reflect_2_2", "type": "status",
		 "status_id": "reflect", "value": 2, "duration": 2, "to_player": true,
		 "display": "反震2", "desc": "获得反震 2 层，持续 2 回合"}
	],
	"sub_kw": []
},
{
	"id": "Earth_010", "name": "厚德载物", "el": "土", "cost": {"土": 2},
	"desc": "本回合获得护盾量+50%。",
	"main_kw": [],
	"sub_kw": []
},
{
	"id": "Earth_011", "name": "泰山崩", "el": "土", "cost": {"土": 5},
	"desc": "消耗护盾造成伤害，每2点护盾造成3点土伤。",
	"main_kw": [
		{"id": "kw_cond_shield_0_3", "type": "cond_damage",
		 "value": 0, "condition": "player_has_shield", "bonus": 3,
		 "display": "崩山", "desc": "若持有护盾，伤害+3"}
	],
	"sub_kw": [
		{"id": "kw_cond_shield_0_3", "type": "cond_damage",
		 "value": 0, "condition": "player_has_shield", "bonus": 3,
		 "display": "崩山", "desc": "若持有护盾，伤害+3"}
	]
},

# ── 新卡牌 Earth_012~017 ──
{
	"id": "Earth_012", "name": "碎石", "el": "土", "cost": {"土": 1},
	"desc": "获得4点护盾。",
	"main_kw": [
		{"id": "kw_shield_4", "type": "shield", "value": 4,
		 "display": "护盾4", "desc": "获得 4 点护盾"}
	],
	"sub_kw": [
		{"id": "kw_shield_1", "type": "shield", "value": 1,
		 "display": "护盾1", "desc": "获得 1 点护盾"}
	]
},
{
	"id": "Earth_013", "name": "岩刺", "el": "土", "cost": {"土": 2},
	"desc": "造成3点土伤，获得3点护盾。",
	"main_kw": [
		{"id": "kw_damage_shield_3_3", "type": "damage_shield",
		 "value": 3, "value2": 3,
		 "display": "伤盾3|3", "desc": "造成 3 点伤害，获得 3 点护盾"}
	],
	"sub_kw": [
		{"id": "kw_damage_2_b", "type": "damage", "value": 2,
		 "display": "伤害2", "desc": "造成 2 点伤害"}
	]
},
{
	"id": "Earth_014", "name": "垒土", "el": "土", "cost": {"土": 2},
	"desc": "获得6点护盾。",
	"main_kw": [
		{"id": "kw_shield_6", "type": "shield", "value": 6,
		 "display": "护盾6", "desc": "获得 6 点护盾"}
	],
	"sub_kw": [
		{"id": "kw_shield_3", "type": "shield", "value": 3,
		 "display": "护盾3", "desc": "获得 3 点护盾"}
	]
},
{
	"id": "Earth_015", "name": "以盾为矛", "el": "土", "cost": {"土": 4},
	"desc": "消耗护盾造成伤害。",
	"main_kw": [
		{"id": "kw_cond_shield_0_5", "type": "cond_damage",
		 "value": 0, "condition": "player_has_shield", "bonus": 5,
		 "display": "盾击", "desc": "若持有护盾，伤害+5"}
	],
	"sub_kw": [
		{"id": "kw_cond_shield_b_5_1", "type": "cond_damage",
		 "value": 5, "condition": "player_has_shield", "bonus": 1,
		 "display": "坚盾", "desc": "若持有护盾，基础5+1"}
	]
},
{
	"id": "Earth_016", "name": "不动如山", "el": "土", "cost": {"土": 5},
	"desc": "获得15点护盾。",
	"main_kw": [
		{"id": "kw_shield_15", "type": "shield", "value": 15,
		 "display": "护盾15", "desc": "获得 15 点护盾"}
	],
	"sub_kw": [
		{"id": "kw_shield_5", "type": "shield", "value": 5,
		 "display": "护盾5", "desc": "获得 5 点护盾"}
	]
},
{
	"id": "Earth_017", "name": "地脉涌动", "el": "土", "cost": {"土": 3},
	"desc": "获得8点护盾。",
	"main_kw": [
		{"id": "kw_shield_8", "type": "shield", "value": 8,
		 "display": "护盾8", "desc": "获得 8 点护盾"}
	],
	"sub_kw": [
		{"id": "kw_reflect_1_1", "type": "status",
		 "status_id": "reflect", "value": 1, "duration": 1, "to_player": true,
		 "display": "反震1", "desc": "获得反震 1 层"}
	]
},

# ╔══════════════════════════════════════════════════════════════╗
# ║  水系 Water_012~024 — 控制/元素转化                          ║
# ╚══════════════════════════════════════════════════════════════╝

# ── 原始卡牌 Water_012~017 ──
{
	"id": "Water_012", "name": "如水", "el": "水", "cost": {"水": 3},
	"desc": "本回合已释放卡牌可重新激活。",
	"main_kw": [],
	"sub_kw": []
},
{
	"id": "Water_013", "name": "甘霖", "el": "水", "cost": {"水": 10},
	"desc": "清除自身负面状态，回复生命。",
	"main_kw": [
		{"id": "kw_heal_2", "type": "heal", "value": 2,
		 "display": "治疗2", "desc": "回复 2 点生命"}
	],
	"sub_kw": []
},
{
	"id": "Water_014", "name": "困泽", "el": "水", "cost": {"水": 4},
	"desc": "减速敌人。对减速敌人伤害+4。",
	"main_kw": [
		{"id": "kw_slow_1_1", "type": "status",
		 "status_id": "slow", "value": 1, "duration": 1,
		 "display": "减速1", "desc": "赋予减速 1 层"}
	],
	"sub_kw": [
		{"id": "kw_cond_slow_4_1", "type": "cond_damage",
		 "value": 4, "condition": "enemy_has_slow", "bonus": 1,
		 "display": "泽伤", "desc": "若敌人减速，伤害+1"}
	]
},
{
	"id": "Water_015", "name": "调息术", "el": "水", "cost": {"水": 1},
	"desc": "以太转化为元素。",
	"main_kw": [],
	"sub_kw": []
},
{
	"id": "Water_016", "name": "水爆", "el": "水", "cost": {"水": 30},
	"desc": "造成52点水元素伤害。",
	"main_kw": [
		{"id": "kw_damage_52", "type": "damage", "value": 52,
		 "display": "伤害52", "desc": "造成 52 点伤害"}
	],
	"sub_kw": []
},
{
	"id": "Water_017", "name": "潮生诀", "el": "水", "cost": {"水": 3},
	"desc": "从卡包选牌替换主槽。",
	"main_kw": [],
	"sub_kw": []
},

# ── 新卡牌 Water_018~024 ──
{
	"id": "Water_018", "name": "水珠", "el": "水", "cost": {"水": 1},
	"desc": "造成3点水伤，获得1点水元素。",
	"main_kw": [
		{"id": "kw_damage_3_w", "type": "damage", "value": 3,
		 "display": "伤害3", "desc": "造成 3 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_gen_water_1", "type": "gen",
		 "value": 1, "element_type": "水",
		 "display": "生水1", "desc": "获得 1 点水元素"}
	]
},
{
	"id": "Water_019", "name": "霜刺", "el": "水", "cost": {"水": 2},
	"desc": "造成4点水伤。若敌人减速，伤害+6。",
	"main_kw": [
		{"id": "kw_cond_slow_4_6", "type": "cond_damage",
		 "value": 4, "condition": "enemy_has_slow", "bonus": 6,
		 "display": "霜刺", "desc": "造成 4 点伤害。若减速，伤害+6"}
	],
	"sub_kw": [
		{"id": "kw_slow_1_1", "type": "status",
		 "status_id": "slow", "value": 1, "duration": 1,
		 "display": "减速1", "desc": "赋予减速 1 层"}
	]
},
{
	"id": "Water_020", "name": "潮涌", "el": "水", "cost": {"水": 3},
	"desc": "造成6点水伤，获得水元素。",
	"main_kw": [
		{"id": "kw_damage_6_w", "type": "damage", "value": 6,
		 "display": "伤害6", "desc": "造成 6 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_gen_water_1", "type": "gen",
		 "value": 1, "element_type": "水",
		 "display": "生水1", "desc": "获得 1 点水元素"}
	]
},
{
	"id": "Water_021", "name": "镜湖", "el": "水", "cost": {"水": 2},
	"desc": "复制上一张卡牌效果。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_damage_3_w", "type": "damage", "value": 3,
		 "display": "伤害3", "desc": "造成 3 点伤害"}
	]
},
{
	"id": "Water_022", "name": "极寒", "el": "水", "cost": {"水": 4},
	"desc": "造成6点水伤，减速2。",
	"main_kw": [
		{"id": "kw_damage_6_w2", "type": "damage", "value": 6,
		 "display": "伤害6", "desc": "造成 6 点伤害"},
		{"id": "kw_slow_2_2", "type": "status",
		 "status_id": "slow", "value": 2, "duration": 2,
		 "display": "减速2", "desc": "赋予减速 2 层"}
	],
	"sub_kw": [
		{"id": "kw_cond_slow_4_4", "type": "cond_damage",
		 "value": 4, "condition": "enemy_has_slow", "bonus": 4,
		 "display": "霜伤", "desc": "若敌人减速，伤害+4"}
	]
},
{
	"id": "Water_023", "name": "润物无声", "el": "水", "cost": {"水": 2},
	"desc": "引气增益。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_heal_2", "type": "heal", "value": 2,
		 "display": "治疗2", "desc": "回复 2 点生命"}
	]
},
{
	"id": "Water_024", "name": "万流归宗", "el": "水", "cost": {"水": 6},
	"desc": "造成20点水伤。",
	"main_kw": [
		{"id": "kw_damage_20", "type": "damage", "value": 20,
		 "display": "伤害20", "desc": "造成 20 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_gen_water_3", "type": "gen",
		 "value": 3, "element_type": "水",
		 "display": "生水3", "desc": "获得 3 点水元素"}
	]
},

# ╔══════════════════════════════════════════════════════════════╗
# ║  金系 Metal_018~029 — 多重激活/穿透                           ║
# ╚══════════════════════════════════════════════════════════════╝

# ── 原始卡牌 Metal_018~022 ──
{
	"id": "Metal_018", "name": "针", "el": "金", "cost": {"金": 3},
	"desc": "随机激活一个副槽卡牌。",
	"main_kw": [
		{"id": "kw_action_overload", "type": "action",
		 "action_id": "overload",
		 "display": "过载", "desc": "触发一次过载"}
	],
	"sub_kw": [
		{"id": "kw_action_overload", "type": "action",
		 "action_id": "overload",
		 "display": "过载", "desc": "触发一次过载"}
	]
},
{
	"id": "Metal_019", "name": "金钟罩", "el": "金", "cost": {"金": 5},
	"desc": "获得合金3，持续2回合。",
	"main_kw": [
		{"id": "kw_damage_reduction_3_2", "type": "status",
		 "status_id": "damage_reduction", "value": 3, "duration": 2, "to_player": true,
		 "display": "合金3", "desc": "获得 3 层合金，持续 2 回合"}
	],
	"sub_kw": [
		{"id": "kw_damage_reduction_1_999", "type": "status",
		 "status_id": "damage_reduction", "value": 1, "duration": 999, "to_player": true,
		 "display": "合金1永续", "desc": "获得 1 层永久合金"}
	]
},
{
	"id": "Metal_020", "name": "养剑诀", "el": "金", "cost": {"金": 4},
	"desc": "金系卡牌伤害+2（本局）。",
	"main_kw": [],
	"sub_kw": []
},
{
	"id": "Metal_021", "name": "破甲符", "el": "金", "cost": {"金": 2},
	"desc": "造成5点金伤。若敌人护盾翻倍。",
	"main_kw": [
		{"id": "kw_cond_enemy_shield_5_5", "type": "cond_damage",
		 "value": 5, "condition": "enemy_has_shield", "bonus": 5,
		 "display": "破甲", "desc": "造成 5 点伤害。若敌人有护盾，伤害+5"}
	],
	"sub_kw": [
		{"id": "kw_damage_3", "type": "damage", "value": 3,
		 "display": "伤害3", "desc": "造成 3 点伤害"}
	]
},
{
	"id": "Metal_022", "name": "小刀制造", "el": "金", "cost": {"金": 3},
	"desc": "造成10点金伤。",
	"main_kw": [
		{"id": "kw_damage_10", "type": "damage", "value": 10,
		 "display": "伤害10", "desc": "造成 10 点伤害"}
	],
	"sub_kw": []
},

# ── 新卡牌 Metal_023~029 ──
{
	"id": "Metal_023", "name": "铁刺", "el": "金", "cost": {"金": 1},
	"desc": "造成4点金伤。",
	"main_kw": [
		{"id": "kw_damage_4", "type": "damage", "value": 4,
		 "display": "伤害4", "desc": "造成 4 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_damage_1", "type": "damage", "value": 1,
		 "display": "伤害1", "desc": "造成 1 点伤害"}
	]
},
{
	"id": "Metal_024", "name": "破盾锥", "el": "金", "cost": {"金": 2},
	"desc": "破除敌人护盾。",
	"main_kw": [
		{"id": "kw_action_shield_break", "type": "action",
		 "action_id": "shield_break",
		 "display": "破盾", "desc": "破除敌人护盾"}
	],
	"sub_kw": [
		{"id": "kw_damage_3", "type": "damage", "value": 3,
		 "display": "伤害3", "desc": "造成 3 点伤害"}
	]
},
{
	"id": "Metal_025", "name": "连环击", "el": "金", "cost": {"金": 3},
	"desc": "造成9点金伤。",
	"main_kw": [
		{"id": "kw_damage_9", "type": "damage", "value": 9,
		 "display": "伤害9", "desc": "造成 9 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_damage_2", "type": "damage", "value": 2,
		 "display": "伤害2", "desc": "造成 2 点伤害"}
	]
},
{
	"id": "Metal_026", "name": "共鸣", "el": "金", "cost": {"金": 2},
	"desc": "辅助效果。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_gen_metal_1", "type": "gen",
		 "value": 1, "element_type": "金",
		 "display": "生金1", "desc": "获得 1 点金元素"}
	]
},
{
	"id": "Metal_027", "name": "万剑诀", "el": "金", "cost": {"金": 5},
	"desc": "造成4点伤害，重复多次。",
	"main_kw": [
		{"id": "kw_damage_4", "type": "damage", "value": 4,
		 "display": "伤害4", "desc": "造成 4 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_damage_2", "type": "damage", "value": 2,
		 "display": "伤害2", "desc": "造成 2 点伤害"}
	]
},
{
	"id": "Metal_028", "name": "锋锐", "el": "金", "cost": {"金": 1},
	"desc": "buff: 下张卡伤害+6。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_damage_2", "type": "damage", "value": 2,
		 "display": "伤害2", "desc": "造成 2 点伤害"}
	]
},
{
	"id": "Metal_029", "name": "金精", "el": "金", "cost": {"金": 4},
	"desc": "永久合金+护盾。",
	"main_kw": [
		{"id": "kw_damage_reduction_1_999", "type": "status",
		 "status_id": "damage_reduction", "value": 1, "duration": 999, "to_player": true,
		 "display": "合金1永续", "desc": "获得 1 层永久合金"}
	],
	"sub_kw": [
		{"id": "kw_shield_4", "type": "shield", "value": 4,
		 "display": "护盾4", "desc": "获得 4 点护盾"}
	]
},

# ╔══════════════════════════════════════════════════════════════╗
# ║  木系 Wood_023~035 — 恢复/流血流派                           ║
# ╚══════════════════════════════════════════════════════════════╝

# ── 原始卡牌 Wood_023~028 ──
{
	"id": "Wood_023", "name": "逢春", "el": "木", "cost": {"木": 3},
	"desc": "回复5点生命。",
	"main_kw": [
		{"id": "kw_heal_5", "type": "heal", "value": 5,
		 "display": "治疗5", "desc": "回复 5 点生命"}
	],
	"sub_kw": [
		{"id": "kw_heal_1", "type": "heal", "value": 1,
		 "display": "治疗1", "desc": "回复 1 点生命"}
	]
},
{
	"id": "Wood_024", "name": "缠绕", "el": "木", "cost": {"木": 3},
	"desc": "造成4点木伤，赋予流血3持续2回合。",
	"main_kw": [
		{"id": "kw_damage_4", "type": "damage", "value": 4,
		 "display": "伤害4", "desc": "造成 4 点伤害"},
		{"id": "kw_bleed_3_2", "type": "status",
		 "status_id": "bleed", "value": 3, "duration": 2,
		 "display": "流血3", "desc": "赋予流血 3 层，持续 2 回合"}
	],
	"sub_kw": [
		{"id": "kw_cond_bleed_1_1", "type": "cond_damage",
		 "value": 1, "condition": "enemy_has_bleed", "bonus": 1,
		 "display": "藤刺", "desc": "若敌人流血，伤害+1"}
	]
},
{
	"id": "Wood_025", "name": "纳元术", "el": "木", "cost": {"木": 2},
	"desc": "下次元素反应额外获得元素。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_gen_wood_1", "type": "gen",
		 "value": 1, "element_type": "木",
		 "display": "生木1", "desc": "获得 1 点木元素"}
	]
},
{
	"id": "Wood_026", "name": "荆棘", "el": "木", "cost": {"木": 3},
	"desc": "获得反震4持续2回合。",
	"main_kw": [
		{"id": "kw_reflect_4_2", "type": "status",
		 "status_id": "reflect", "value": 4, "duration": 2, "to_player": true,
		 "display": "反震4", "desc": "获得反震 4 层，持续 2 回合"}
	],
	"sub_kw": [
		{"id": "kw_reflect_1_1", "type": "status",
		 "status_id": "reflect", "value": 1, "duration": 1, "to_player": true,
		 "display": "反震1", "desc": "获得反震 1 层"}
	]
},
{
	"id": "Wood_027", "name": "万物生", "el": "木", "cost": {"木": 4},
	"desc": "每激活一张卡牌回复1点生命。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_heal_2", "type": "heal", "value": 2,
		 "display": "治疗2", "desc": "回复 2 点生命"}
	]
},
{
	"id": "Wood_028", "name": "守护者", "el": "木", "cost": {"木": 2},
	"desc": "辅助防御。",
	"main_kw": [],
	"sub_kw": []
},

# ── 新卡牌 Wood_029~035 ──
{
	"id": "Wood_029", "name": "叶刃", "el": "木", "cost": {"木": 1},
	"desc": "造成3点木伤，回复2点生命。",
	"main_kw": [
		{"id": "kw_damage_3_wood", "type": "damage", "value": 3,
		 "display": "伤害3", "desc": "造成 3 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_heal_1", "type": "heal", "value": 1,
		 "display": "治疗1", "desc": "回复 1 点生命"}
	]
},
{
	"id": "Wood_030", "name": "草木萌发", "el": "木", "cost": {"木": 2},
	"desc": "回复5点生命。",
	"main_kw": [
		{"id": "kw_heal_5", "type": "heal", "value": 5,
		 "display": "治疗5", "desc": "回复 5 点生命"}
	],
	"sub_kw": [
		{"id": "kw_heal_2", "type": "heal", "value": 2,
		 "display": "治疗2", "desc": "回复 2 点生命"}
	]
},
{
	"id": "Wood_031", "name": "毒藤", "el": "木", "cost": {"木": 2},
	"desc": "赋予流血3层，持续2回合。",
	"main_kw": [
		{"id": "kw_bleed_3_2", "type": "status",
		 "status_id": "bleed", "value": 3, "duration": 2,
		 "display": "流血3", "desc": "赋予流血 3 层，持续 2 回合"}
	],
	"sub_kw": [
		{"id": "kw_bleed_1_1", "type": "status",
		 "status_id": "bleed", "value": 1, "duration": 1,
		 "display": "流血1", "desc": "赋予 1 层流血"}
	]
},
{
	"id": "Wood_032", "name": "嗜血藤", "el": "木", "cost": {"木": 3},
	"desc": "造成5点木伤。流血时+5。",
	"main_kw": [
		{"id": "kw_cond_bleed_5_5", "type": "cond_damage",
		 "value": 5, "condition": "enemy_has_bleed", "bonus": 5,
		 "display": "嗜血", "desc": "造成 5 点伤害。若敌人流血，伤害+5"}
	],
	"sub_kw": [
		{"id": "kw_heal_3", "type": "heal", "value": 3,
		 "display": "治疗3", "desc": "回复 3 点生命"}
	]
},
{
	"id": "Wood_033", "name": "生命汲取", "el": "木", "cost": {"木": 4},
	"desc": "造成8点木伤，回复等量生命。",
	"main_kw": [
		{"id": "kw_damage_8", "type": "damage", "value": 8,
		 "display": "伤害8", "desc": "造成 8 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_heal_4", "type": "heal", "value": 4,
		 "display": "治疗4", "desc": "回复 4 点生命"}
	]
},
{
	"id": "Wood_034", "name": "枯木逢春", "el": "木", "cost": {"木": 1},
	"desc": "治疗效果+50%。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_heal_2", "type": "heal", "value": 2,
		 "display": "治疗2", "desc": "回复 2 点生命"}
	]
},
{
	"id": "Wood_035", "name": "腐生", "el": "木", "cost": {"木": 5},
	"desc": "造成10点木伤。流血时追加。",
	"main_kw": [
		{"id": "kw_damage_10", "type": "damage", "value": 10,
		 "display": "伤害10", "desc": "造成 10 点伤害"},
		{"id": "kw_cond_bleed_0_8", "type": "cond_damage",
		 "value": 0, "condition": "enemy_has_bleed", "bonus": 8,
		 "display": "腐化", "desc": "若敌人流血，伤害+8"}
	],
	"sub_kw": [
		{"id": "kw_damage_4_wd", "type": "damage", "value": 4,
		 "display": "伤害4", "desc": "造成 4 点伤害"}
	]
},

# ╔══════════════════════════════════════════════════════════════╗
# ║  以太系 Aether_028~040 — 反应/通用                           ║
# ╚══════════════════════════════════════════════════════════════╝

# ── 原始卡牌 Aether_028~032 ──
{
	"id": "Aether_028", "name": "归元", "el": "以太", "cost": {"以太": 3},
	"desc": "返还本回合消耗元素的一半。",
	"main_kw": [],
	"sub_kw": []
},
{
	"id": "Aether_029", "name": "五行轮转", "el": "以太",
	"cost": {"金": 1, "木": 1, "水": 1, "火": 1, "土": 1},
	"desc": "造成15点伤害，触发元素反应。",
	"main_kw": [
		{"id": "kw_damage_15", "type": "damage", "value": 15,
		 "display": "伤害15", "desc": "造成 15 点伤害"}
	],
	"sub_kw": []
},
{
	"id": "Aether_030", "name": "流光", "el": "以太", "cost": {"以太": 5},
		"desc": "取消「打出后不可再激活」限制。",
	"main_kw": [],
	"sub_kw": []
},
{
	"id": "Aether_031", "name": "移形换位", "el": "以太", "cost": {"以太": 2},
	"desc": "从卡包选牌替换副槽。",
	"main_kw": [],
	"sub_kw": []
},
{
	"id": "Aether_032", "name": "混元归一", "el": "以太", "cost": {"以太": 8},
	"desc": "造成消耗总量5%的伤害。",
	"main_kw": [
		{"id": "kw_damage_0", "type": "damage", "value": 0,
		 "display": "混元", "desc": "造成累积消耗5%的伤害"}
	],
	"sub_kw": [
		{"id": "kw_gen_aether_20", "type": "gen",
		 "value": 20, "element_type": "以太",
		 "display": "生以太20", "desc": "获得 20 点以太"}
	]
},

# ── 新卡牌 Aether_033~040 ──
{
	"id": "Aether_033", "name": "星火", "el": "以太", "cost": {"以太": 1},
	"desc": "获得2点以太。",
	"main_kw": [
		{"id": "kw_gen_aether_2", "type": "gen",
		 "value": 2, "element_type": "以太",
		 "display": "生以太2", "desc": "获得 2 点以太"}
	],
	"sub_kw": [
		{"id": "kw_gen_aether_1", "type": "gen",
		 "value": 1, "element_type": "以太",
		 "display": "生以太1", "desc": "获得 1 点以太"}
	]
},
{
	"id": "Aether_034", "name": "调和", "el": "以太", "cost": {"以太": 2},
	"desc": "元素转化。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_gen_aether_2", "type": "gen",
		 "value": 2, "element_type": "以太",
		 "display": "生以太2", "desc": "获得 2 点以太"}
	]
},
{
	"id": "Aether_035", "name": "虚无", "el": "以太", "cost": {"以太": 3},
	"desc": "造成10点伤害。",
	"main_kw": [
		{"id": "kw_damage_10", "type": "damage", "value": 10,
		 "display": "伤害10", "desc": "造成 10 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_damage_3", "type": "damage", "value": 3,
		 "display": "伤害3", "desc": "造成 3 点伤害"}
	]
},
{
	"id": "Aether_036", "name": "灵气萦绕", "el": "以太", "cost": {"以太": 1},
	"desc": "引气增益。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_gen_aether_2", "type": "gen",
		 "value": 2, "element_type": "以太",
		 "display": "生以太2", "desc": "获得 2 点以太"}
	]
},
{
	"id": "Aether_037", "name": "感应", "el": "以太", "cost": {"以太": 2},
	"desc": "反应增益。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_gen_aether_3", "type": "gen",
		 "value": 3, "element_type": "以太",
		 "display": "生以太3", "desc": "获得 3 点以太"}
	]
},
{
	"id": "Aether_038", "name": "混沌种", "el": "以太", "cost": {"以太": 4},
	"desc": "造成10点伤害，获得以太。",
	"main_kw": [
		{"id": "kw_damage_10", "type": "damage", "value": 10,
		 "display": "伤害10", "desc": "造成 10 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_gen_aether_2", "type": "gen",
		 "value": 2, "element_type": "以太",
		 "display": "生以太2", "desc": "获得 2 点以太"}
	]
},
{
	"id": "Aether_039", "name": "返璞归真", "el": "以太", "cost": {"以太": 7},
	"desc": "重置冷却。",
	"main_kw": [],
	"sub_kw": [
		{"id": "kw_heal_5", "type": "heal", "value": 5,
		 "display": "治疗5", "desc": "回复 5 点生命"}
	]
},
{
	"id": "Aether_040", "name": "五行流转", "el": "以太",
	"cost": {"金": 2, "木": 2, "水": 2, "火": 2, "土": 2},
	"desc": "造成20点五行伤害。",
	"main_kw": [
		{"id": "kw_damage_20", "type": "damage", "value": 20,
		 "display": "伤害20", "desc": "造成 20 点伤害"}
	],
	"sub_kw": [
		{"id": "kw_gen_aether_3", "type": "gen",
		 "value": 3, "element_type": "以太",
		 "display": "生以太3", "desc": "获得 3 点以太"}
	]
},

# ═══════════════════════════════════════════
#  末尾哨兵（不要删除此行）
# ═══════════════════════════════════════════
	]
