@tool
extends EditorScript

func _run() -> void:
	print("==============================================")
	print("[开始生成] 自动生成 32 张卡牌资源 (带Effect系统)...")
	print("==============================================")

	var cards: Array[Dictionary] = [
		# --- 火系 (Fire) ---
		{
			"id": "Fire_001",
			"card_name": "火势",
			"element": "火",
			"cost_fire": 3,
			"main_type": "condition_damage",
			"main_value": 10,
			"main_description": "造成10点火元素伤害。若本牌上一回合已被激活，则伤害翻倍。",
			"sub_type": "buff",
			"sub_value": 50,
			"sub_description": "为主槽卡牌附加“蓄势”效果：若主槽卡牌上回合已被激活且未打出，本回合伤害+50％。",
			"status_id": "prev_turn_active",
			"status_amount": 10,
			"status_duration": 0
		},
		{
			"id": "Fire_002",
			"card_name": "离火罩",
			"element": "火",
			"cost_fire": 4,
			"main_type": "utility",
			"main_value": 2,
			"main_description": "本回合内，每当你激活或打出一张卡牌，对敌方造成2点火元素伤害。",
			"sub_type": "status_apply",
			"sub_value": 1,
			"sub_description": "主槽卡牌打出时，赋予敌方1层“烧伤”。",
			"status_id": "burn",
			"status_amount": 1,
			"status_duration": 1
		},
		{
			"id": "Fire_003",
			"card_name": "烛龙引",
			"element": "火",
			"cost_fire": 2,
			"main_type": "damage",
			"main_value": 6,
			"main_description": "造成6点火伤。若敌方处于“烧伤”状态，立即触发一次“烧伤”结算。",
			"sub_type": "buff",
			"sub_value": 3,
			"sub_description": "主槽卡牌对处于“烧伤”状态的敌人伤害+3。"
		},
		{
			"id": "Fire_004",
			"card_name": "焚天",
			"element": "火",
			"cost_fire": 5,
			"main_type": "damage",
			"main_value": 8,
			"main_description": "造成8点火伤。",
			"sub_type": "special_action",
			"sub_value": 0,
			"sub_description": "主槽卡牌会先清除敌方所有护盾，再结算伤害。",
			"status_id": "shield_break"
		},
		{
			"id": "Fire_005",
			"card_name": "死灰复燃",
			"element": "火",
			"cost_fire": 0,
			"main_type": "utility",
			"main_value": 50,
			"main_description": "仅可在本回合已打出至少1张火系卡牌后激活。复制上一张打出的火系卡牌效果的50％。",
			"sub_type": "generate_element",
			"sub_value": 1,
			"sub_element_type": "火",
			"sub_description": "主槽卡牌打出时，若本回合已打出过火系卡牌，返还1点火元素。"
		},
		{
			"id": "Fire_006",
			"card_name": "火攻",
			"element": "火",
			"cost_fire": 2,
			"main_type": "damage",
			"main_value": 9,
			"main_description": "造成9火元素伤害。",
			"sub_type": "buff",
			"sub_value": 2,
			"sub_description": "主槽卡牌的最终伤害增加2；"
		},

		# --- 土系 (Earth) ---
		{
			"id": "Earth_007",
			"card_name": "墙",
			"element": "土",
			"cost_earth": 3,
			"main_type": "shield",
			"main_value": 10,
			"main_description": "获得10点护盾。",
			"sub_type": "buff",
			"sub_value": 2,
			"sub_description": "主槽卡牌获得护盾时，额外+2护盾。"
		},
		{
			"id": "Earth_008",
			"card_name": "撼地",
			"element": "土",
			"cost_earth": 4,
			"main_type": "special_action",
			"main_value": 6,
			"main_description": "造成6点土伤，并强制改变敌方当前意图为“防守”。",
			"sub_type": "shield",
			"sub_value": 3,
			"sub_description": "主槽卡牌打出时，若敌方意图为“进攻”，获得3点护盾。",
			"status_id": "change_enemy_intent"
		},
		{
			"id": "Earth_009",
			"card_name": "戌土甲",
			"element": "土",
			"cost_earth": 3,
			"main_type": "status_apply",
			"main_value": 6,
			"main_description": "获得6点护盾，并获得“反震2”，持续2回合。",
			"sub_type": "buff",
			"sub_value": 2,
			"sub_description": "为主槽卡牌提供“若持有护盾，伤害+2”。",
			"status_id": "reflect",
			"status_amount": 2,
			"status_duration": 2
		},
		{
			"id": "Earth_010",
			"card_name": "厚德载物",
			"element": "土",
			"cost_earth": 2,
			"main_type": "utility",
			"main_value": 50,
			"main_description": "本回合内，你获得的所有护盾量+50％。",
			"sub_type": "buff",
			"sub_value": 1,
			"sub_description": "主槽卡牌打出时，若你持有护盾，格挡一次负面状态（每回合限一次）。"
		},
		{
			"id": "Earth_011",
			"card_name": "泰山崩",
			"element": "土",
			"cost_earth": 5,
			"main_type": "condition_damage",
			"main_value": 0,
			"main_description": "消耗你当前持有的所有护盾，每消耗2点护盾，造成3点土元素伤害。",
			"sub_type": "condition_damage",
			"sub_value": 0,
			"sub_description": "主槽卡牌造成伤害时，若你持有护盾，消耗2点护盾使伤害+3。",
			"status_id": "player_has_shield",
			"status_amount": 3
		},

		# --- 水系 (Water) ---
		{
			"id": "Water_012",
			"card_name": "如水",
			"element": "水",
			"cost_water": 3,
			"main_type": "utility",
			"main_value": 1,
			"main_description": "本回合内，所有已释放的卡牌可重新激活一次。",
			"sub_type": "utility",
			"sub_value": 1,
			"sub_description": "主槽卡牌每回合可以额外激活一次。"
		},
		{
			"id": "Water_013",
			"card_name": "甘霖",
			"element": "水",
			"cost_water": 10,
			"main_type": "heal",
			"main_value": 2,
			"main_description": "清除自身所有负面状态，每清除一种，回复2点生命。",
			"sub_type": "special_action",
			"sub_value": 1,
			"sub_description": "主槽卡牌打出时，清除敌方1层正面状态。"
		},
		{
			"id": "Water_014",
			"card_name": "困泽",
			"element": "水",
			"cost_water": 4,
			"main_type": "status_apply",
			"main_value": 0,
			"main_description": "敌方本回合无法行动，但你下回合只能激活至多3张卡牌。",
			"sub_type": "condition_damage",
			"sub_value": 4,
			"sub_description": "主槽卡牌对处于“减速”状态的敌人伤害+4。",
			"status_id": "slow",
			"status_amount": 1,
			"status_duration": 1
		},
		{
			"id": "Water_015",
			"card_name": "调息术",
			"element": "水",
			"cost_water": 1,
			"main_type": "utility",
			"main_value": 4,
			"main_description": "选择一种基础元素，将2点以太转化为4点该元素。",
			"sub_type": "utility",
			"sub_value": 1,
			"sub_description": "主槽卡牌如果使用以太激活，则消耗的以太减少1点（最低为1）。"
		},
		{
			"id": "Water_016",
			"card_name": "水爆",
			"element": "水",
			"cost_water": 30,
			"main_type": "damage",
			"main_value": 52,
			"main_description": "造成52点水元素伤害，你的卡牌包中每有一张非水元素的卡，该卡的消耗减少1点。",
			"sub_type": "utility",
			"sub_value": 1,
			"sub_description": "主槽卡牌如果是非水元素，消耗减少1点。"
		},
		{
			"id": "Water_017",
			"card_name": "潮生诀",
			"element": "水",
			"cost_water": 3,
			"main_type": "utility",
			"main_value": 1,
			"main_description": "从卡牌包里任意选择一张牌替换该主槽的位置。",
			"sub_type": "utility",
			"sub_value": 1,
			"sub_description": "主槽卡牌打出时，可以从卡牌包中任意选择一张牌替换该主槽的位置。"
		},

		# --- 金系 (Metal) ---
		{
			"id": "Metal_018",
			"card_name": "针",
			"element": "金",
			"cost_metal": 3,
			"main_type": "special_action",
			"main_value": 1,
			"main_description": "随机激活一个当前未激活的副槽卡牌，使其本回合可独立打出。",
			"sub_type": "special_action",
			"sub_value": 1,
			"sub_description": "主槽卡牌打出时，触发一次“火与金”元素反应。",
			"status_id": "overload"
		},
		{
			"id": "Metal_019",
			"card_name": "金钟罩",
			"element": "金",
			"cost_metal": 5,
			"main_type": "status_apply",
			"main_value": 0,
			"main_description": "获得“合金3”，持续2回合。",
			"sub_type": "status_apply",
			"sub_value": 1,
			"sub_description": "主槽卡牌获得“合金1”，持续到本局战斗结束（可叠加）。",
			"status_id": "alloy",
			"status_amount": 3,
			"status_duration": 2
		},
		{
			"id": "Metal_020",
			"card_name": "养剑诀",
			"element": "金",
			"cost_metal": 4,
			"main_type": "utility",
			"main_value": 2,
			"main_description": "本局战斗中，你所有已打出过的金系卡牌伤害+2。",
			"sub_type": "utility",
			"sub_value": 1,
			"sub_description": "主槽卡牌每被激活一次（无论是否打出），本次游戏该牌伤害永久+1。"
		},
		{
			"id": "Metal_021",
			"card_name": "破甲符",
			"element": "金",
			"cost_metal": 2,
			"main_type": "condition_damage",
			"main_value": 5,
			"main_description": "造成5点金伤。若敌方持有护盾，伤害翻倍。",
			"sub_type": "damage",
			"sub_value": 3,
			"sub_description": "主槽卡牌对护盾造成的伤害+3。",
			"status_id": "enemy_has_shield",
			"status_amount": 5
		},
		{
			"id": "Metal_022",
			"card_name": "小刀制造",
			"element": "金",
			"cost_metal": 3,
			"main_type": "damage",
			"main_value": 10,
			"main_description": "在车间花费17点金元素制造一把“小刀”装备，随后这张牌从你的卡牌包中移除。\n主槽效果：花费3金元素，对一名敌人造成5金属性伤害两次。",
			"sub_type": "buff",
			"sub_value": 3,
			"sub_description": "主槽卡牌的伤害+3。"
		},

		# --- 木系 (Wood) ---
		{
			"id": "Wood_023",
			"card_name": "逢春",
			"element": "木",
			"cost_wood": 3,
			"main_type": "heal",
			"main_value": 5,
			"main_description": "回复5点生命。",
			"sub_type": "heal",
			"sub_value": 1,
			"sub_description": "主槽卡牌打出时，回复1点生命。"
		},
		{
			"id": "Wood_024",
			"card_name": "缠绕",
			"element": "木",
			"cost_wood": 3,
			"main_type": "status_apply",
			"main_value": 4,
			"main_description": "造成4点木伤，赋予敌方“流血3”，持续2回合。",
			"sub_type": "condition_damage",
			"sub_value": 1,
			"sub_description": "主槽卡牌对处于“流血”状态的敌人，每层流血使伤害+1。",
			"status_id": "bleed",
			"status_amount": 3,
			"status_duration": 2
		},
		{
			"id": "Wood_025",
			"card_name": "纳元术",
			"element": "木",
			"cost_wood": 2,
			"main_type": "utility",
			"main_value": 3,
			"main_description": "下次你触发元素反应时，额外获得该反应涉及的一种元素3点。",
			"sub_type": "generate_element",
			"sub_value": 1,
			"sub_element_type": "木",
			"sub_description": "主槽卡牌触发元素反应时，你额外获得1点该主槽卡牌的元素。"
		},
		{
			"id": "Wood_026",
			"card_name": "荆棘",
			"element": "木",
			"cost_wood": 3,
			"main_type": "status_apply",
			"main_value": 0,
			"main_description": "获得“反震4”，持续2回合。若本牌已激活超过1回合未打出，反震+2。",
			"sub_type": "status_apply",
			"sub_value": 1,
			"sub_description": "主槽卡牌获得“反震1”。",
			"status_id": "reflect",
			"status_amount": 4,
			"status_duration": 2
		},
		{
			"id": "Wood_027",
			"card_name": "万物生",
			"element": "木",
			"cost_wood": 4,
			"main_type": "utility",
			"main_value": 1,
			"main_description": "本回合每激活一张卡牌，回复1点生命并随机获得1点基础元素。",
			"sub_type": "heal",
			"sub_value": 2,
			"sub_description": "主槽卡牌激活时，若你已激活3张以上卡牌，回复2点生命。"
		},

		# --- 以太 (Aether) ---
		{
			"id": "Aether_028",
			"card_name": "归元",
			"element": "以太",
			"cost_aether": 3,
			"main_type": "utility",
			"main_value": 50,
			"main_description": "返还本回合消耗的所有元素的一半。",
			"sub_type": "buff",
			"sub_value": 3,
			"sub_description": "主槽卡牌被激活时，若使用了至少1点以太，该卡牌本回合伤害+3。"
		},
		{
			"id": "Aether_029",
			"card_name": "五行轮转",
			"element": "以太",
			"cost_metal": 1,
			"cost_wood": 1,
			"cost_water": 1,
			"cost_fire": 1,
			"cost_earth": 1,
			"main_type": "damage",
			"main_value": 15,
			"main_description": "造成15点伤害，并触发一次你选择的元素反应。",
			"sub_type": "special_action",
			"sub_value": 1,
			"sub_description": "主槽卡牌打出时，额外触发一次随机元素反应。"
		},
		{
			"id": "Aether_030",
			"card_name": "流光",
			"element": "以太",
			"cost_aether": 5,
			"main_type": "utility",
			"main_value": 1,
			"main_description": "本回合内，所有“打出后不可再激活”的限制暂时取消。",
			"sub_type": "utility",
			"sub_value": 1,
			"sub_description": "主槽卡牌被激活时，可以额外被激活一次。"
		},
		{
			"id": "Aether_031",
			"card_name": "移形换位",
			"element": "以太",
			"cost_aether": 2,
			"main_type": "utility",
			"main_value": 3,
			"main_description": "从卡包随机展示3张牌，选择1张替换任意一个当前未激活的副槽卡牌。",
			"sub_type": "utility",
			"sub_value": 1,
			"sub_description": "主槽卡牌打出时，若本回合尚未激活此副槽所属主槽，可将此副槽卡牌与主槽卡牌互换位置。"
		},
		{
			"id": "Aether_032",
			"card_name": "混元归一",
			"element": "以太",
			"cost_aether": 8,
			"main_type": "damage",
			"main_value": 0,
			"main_description": "造成相当于本局战斗中你消耗的所有元素总量5％的伤害。",
			"sub_type": "generate_element",
			"sub_value": 20,
			"sub_element_type": "none",
			"sub_description": "主槽卡牌伤害的20％转化为随机元素返还。"
		}
	]

	var element_folders: Dictionary = {
		"金": "Metal",
		"木": "Wood",
		"水": "Water",
		"火": "Fire",
		"土": "Earth",
		"以太": "Aether"
	}

	var count: int = 0

	for card_dict in cards:
		var element_cn: String = card_dict["element"]
		var element_en: String = element_folders.get(element_cn, "Fire")
		var dir_path: String = "res://Resources/Cards/" + element_en + "/"

		# 确保目录存在
		if not DirAccess.dir_exists_absolute(dir_path):
			var err = DirAccess.make_dir_recursive_absolute(dir_path)
			if err != OK:
				printerr("创建目录失败: ", dir_path, " 错误码: ", err)
				continue

		var file_name: String = card_dict["id"].to_lower() + ".tres"
		var save_path: String = dir_path + file_name

		# 实例化 CardData 资源
		var card_data = preload("res://Data/Card_data.gd").new()

		# 基础信息
		card_data.id = card_dict.get("id", "")
		card_data.card_name = card_dict.get("card_name", "")
		card_data.element = card_dict.get("element", "火")
		card_data.element_attachment_layers = card_dict.get("element_attachment_layers", 1)
		card_data.description = card_dict.get("main_description", "")

		# 消耗 (Cost)
		card_data.cost_metal = card_dict.get("cost_metal", 0)
		card_data.cost_wood = card_dict.get("cost_wood", 0)
		card_data.cost_water = card_dict.get("cost_water", 0)
		card_data.cost_fire = card_dict.get("cost_fire", 0)
		card_data.cost_earth = card_dict.get("cost_earth", 0)
		card_data.cost_aether = card_dict.get("cost_aether", 0)

		# 旧字段（向后兼容）
		card_data.main_type = card_dict.get("main_type", "damage")
		card_data.main_value = card_dict.get("main_value", 0)
		card_data.main_description = card_dict.get("main_description", "")
		card_data.sub_type = card_dict.get("sub_type", "damage")
		card_data.sub_value = card_dict.get("sub_value", 0)
		card_data.sub_element_type = card_dict.get("sub_element_type", "none")
		card_data.sub_description = card_dict.get("sub_description", "")
		card_data.status_id = card_dict.get("status_id", "")
		card_data.status_amount = card_dict.get("status_amount", 0)
		card_data.status_duration = card_dict.get("status_duration", 0)
		card_data.is_exhaust = card_dict.get("is_exhaust", false)
		card_data.single_use = card_dict.get("single_use", false)

		# Effect 系统：生成主槽效果
		card_data.main_effect = _create_effect(
			card_dict.get("main_type", "damage"),
			card_dict.get("main_value", 0),
			card_dict.get("status_id", ""),
			card_dict.get("status_amount", 0),
			card_dict.get("status_duration", 0),
			"none"
		)

		# Effect 系统：生成副槽效果
		var sub_type = card_dict.get("sub_type", "damage")
		if sub_type == "generate_element":
			card_data.sub_effect = _create_effect(
				sub_type,
				card_dict.get("sub_value", 0),
				"", 0, 0,
				card_dict.get("sub_element_type", "none")
			)
		else:
			card_data.sub_effect = _create_effect(
				sub_type,
				card_dict.get("sub_value", 0),
				card_dict.get("status_id", ""),
				card_dict.get("status_amount", 0),
				card_dict.get("status_duration", 0),
				"none"
			)

		# 保存资源
		var save_err = ResourceSaver.save(card_data, save_path)
		if save_err == OK:
			print("成功保存卡牌资源: ", card_dict["card_name"], " -> ", save_path)
			count += 1
		else:
			printerr("保存卡牌资源失败: ", card_dict["card_name"], " 错误码: ", save_err)

	print("==============================================")
	print("[生成完毕] 成功生成了 ", count, "/", cards.size(), " 张卡牌 .tres 资源文件！")
	print("==============================================")


# 根据类型创建对应的 Effect 子资源
func _create_effect(type: String, value: int, status_id: String, status_amount: int,
		status_duration: int, element_type: String) -> EffectBase:

	match type:
		"damage":
			var e = DamageEffect.new()
			e.value = value
			return e

		"shield":
			var e = ShieldEffect.new()
			e.value = value
			return e

		"damage_and_shield":
			var e = DamageAndShieldEffect.new()
			e.damage = value
			e.shield = value
			return e

		"condition_damage":
			var e = ConditionDamageEffect.new()
			e.base_damage = value
			e.condition = status_id
			e.bonus_per_condition = status_amount
			return e

		"heal":
			var e = HealEffect.new()
			e.value = value
			return e

		"status_apply":
			var e = StatusEffect.new()
			e.status_id = status_id
			e.amount = status_amount
			e.duration = status_duration
			# Apply to enemy by default (reflect/反震 goes to player)
			e.apply_to_player = (status_id == "reflect" or status_id == "反震" or status_id == "retaliate_generate_fire" or status_id == "余烬")
			return e

		"generate_element":
			var e = GenerateElementEffect.new()
			e.element_type = element_type
			e.amount = value
			return e

		"special_action":
			var e = SpecialActionEffect.new()
			e.action_id = status_id
			return e

		_:
			# "utility", "buff", "debuff" 等无直接执行效果的类型
			return null
