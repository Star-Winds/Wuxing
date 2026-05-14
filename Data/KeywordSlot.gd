extends Resource
class_name KeywordSlot

enum SlotType { 无, 伤害, 护盾, 治疗, 伤害护盾, 施加状态, 生成元素, 条件伤害, 行动, 多次伤害, 全体伤害, 共鸣, 休眠, 无法打出 }
enum TriggerTiming { PASSIVE, TURN_START, TURN_END, ON_ATTACK, ON_DEFEND, ON_HURT, ON_DEATH }

@export var type: SlotType = SlotType.无:
	set(v):
		type = v
		notify_property_list_changed()

# === 共用数值字段 ===
@export var value: int = 0
@export var value2: int = 0  # 伤害护盾的护盾 / 条件伤害的附加 / 多次伤害的次数
@export_enum("金","木","水","火","土","以太") var element_type: String = ""
@export_enum("burn","bleed","slow","reflect","damage_reduction","vulnerable","weak","strength","dexterity","vigor","buffer","ethereal","frail","stun_attack","retaliate_generate_fire") var status_id: String = ""
@export var duration: int = 0
@export var to_player: bool = false
@export_group("触发时机（敌人用）")
@export var trigger_timing: TriggerTiming = TriggerTiming.PASSIVE
@export_enum("prev_turn_active","enemy_has_burn","enemy_has_slow","enemy_has_bleed","enemy_has_shield","player_has_shield","any_card_activated","enemy_has_frail") var condition: String = ""
@export_enum("overload","shield_break","change_enemy_intent","draw_card","charge","eject","collapse","reactivate","damage_multiplier","random_element_2","workshop_discount") var action_id: String = ""

# === 显示覆盖（选填） ===
@export_group("显示覆盖（选填）")
@export var display_name_override: String = ""
@export var description_override: String = ""


func _validate_property(property: Dictionary):
	if type == SlotType.无:
		if property.name != "type":
			property.usage = PROPERTY_USAGE_NONE
		return

	var keep := false
	var groups := ["显示覆盖（选填）", "触发时机（敌人用）"]
	match type:
		SlotType.伤害:
			keep = property.name in ["type", "value"]
		SlotType.护盾:
			keep = property.name in ["type", "value"]
		SlotType.治疗:
			keep = property.name in ["type", "value"]
		SlotType.伤害护盾:
			keep = property.name in ["type", "value", "value2"]
		SlotType.施加状态:
			keep = property.name in ["type", "status_id", "value", "duration", "to_player"]
		SlotType.生成元素:
			keep = property.name in ["type", "element_type", "value"]
		SlotType.条件伤害:
			keep = property.name in ["type", "value", "condition", "value2"]
		SlotType.行动:
			keep = property.name in ["type", "action_id"]
		SlotType.多次伤害:
			keep = property.name in ["type", "value", "value2"]
		SlotType.全体伤害:
			keep = property.name in ["type", "value"]
		SlotType.共鸣:
			keep = property.name in ["type", "condition"]
		SlotType.休眠:
			keep = property.name in ["type", "value"]
		SlotType.无法打出:
			keep = property.name in ["type"]

	if not keep and property.name not in groups and property.name != "trigger_timing":
		property.usage = PROPERTY_USAGE_NONE


## 编译本槽位为一个 KeywordData 实例（含 Effect）
func compile() -> KeywordData:
	if type == SlotType.无:
		return null

	var kw = KeywordData.new()
	var display := ""
	var desc := ""

	match type:
		SlotType.伤害:
			kw.keyword_id = "kw_damage_%d" % value
			display = "伤害%d" % value
			desc = "造成 %d 点伤害" % value
			kw.category = KeywordData.KeywordCategory.ACTION
			var e = DamageEffect.new()
			e.value = value
			kw.effect = e

		SlotType.护盾:
			kw.keyword_id = "kw_shield_%d" % value
			display = "护盾%d" % value
			desc = "获得 %d 点护盾" % value
			kw.category = KeywordData.KeywordCategory.ACTION
			var e = ShieldEffect.new()
			e.value = value
			kw.effect = e

		SlotType.治疗:
			kw.keyword_id = "kw_heal_%d" % value
			display = "治疗%d" % value
			desc = "恢复 %d 点生命" % value
			kw.category = KeywordData.KeywordCategory.ACTION
			var e = HealEffect.new()
			e.value = value
			kw.effect = e

		SlotType.伤害护盾:
			kw.keyword_id = "kw_ds_%d_%d" % [value, value2]
			display = "伤害%d+护盾%d" % [value, value2]
			desc = "造成 %d 点伤害并获得 %d 点护盾" % [value, value2]
			kw.category = KeywordData.KeywordCategory.ACTION
			var e = DamageAndShieldEffect.new()
			e.damage = value
			e.shield = value2
			kw.effect = e

		SlotType.施加状态:
			var sid = status_id if not status_id.is_empty() else "unknown"
			kw.keyword_id = "kw_status_%s_%d_%d" % [sid, value, duration]
			display = _status_display(sid, value)
			desc = _status_desc(sid, value, duration, to_player)
			kw.category = KeywordData.KeywordCategory.STATUS
			var e = StatusEffect.new()
			e.status_id = sid
			e.amount = value
			e.duration = duration
			e.apply_to_player = to_player
			kw.effect = e

		SlotType.生成元素:
			var el = element_type if not element_type.is_empty() else "以太"
			kw.keyword_id = "kw_gen_%s_%d" % [el, value]
			display = "生%s%d" % [el, value]
			desc = "获得 %d 单位%s" % [value, el]
			kw.category = KeywordData.KeywordCategory.ACTION
			var e = GenerateElementEffect.new()
			e.element_type = el
			e.amount = value
			kw.effect = e

		SlotType.条件伤害:
			kw.keyword_id = "kw_cond_%s_%d_%d" % [condition, value, value2]
			display = "蓄势%d" % value
			desc = "造成 %d 点伤害（触发 %s +%d）" % [value, _cond_display(condition), value2]
			kw.category = KeywordData.KeywordCategory.ACTION
			var e = ConditionDamageEffect.new()
			e.base_damage = value
			e.condition = condition
			e.bonus_per_condition = value2
			kw.effect = e

		SlotType.行动:
			var aid = action_id if not action_id.is_empty() else "unknown"
			kw.keyword_id = "kw_action_%s" % aid
			display = _action_display(aid)
			desc = _action_desc(aid)
			kw.category = KeywordData.KeywordCategory.MECHANIC
			var e = SpecialActionEffect.new()
			e.action_id = aid
			kw.effect = e

		SlotType.多次伤害:
			kw.keyword_id = "kw_multihit_%d_%d" % [value, value2]
			display = "伤害%dx%d" % [value, value2]
			desc = "造成 %d 点伤害，重复 %d 次" % [value, value2]
			kw.category = KeywordData.KeywordCategory.ACTION
			var e = MultiHitDamageEffect.new()
			e.damage = value
			e.hits = value2
			kw.effect = e

		SlotType.全体伤害:
			kw.keyword_id = "kw_aoe_%d" % value
			display = "全体%d" % value
			desc = "对所有敌人造成 %d 点伤害" % value
			kw.category = KeywordData.KeywordCategory.ACTION
			var e = AOEDamageEffect.new()
			e.damage = value
			kw.effect = e

		SlotType.共鸣:
			kw.keyword_id = "kw_resonance_%s" % condition
			display = "共鸣"
			desc = "任意其他卡牌激活时，此卡牌视为激活"
			kw.category = KeywordData.KeywordCategory.MECHANIC
			var e = ResonanceEffect.new()
			e.trigger_condition = condition
			kw.effect = e

		SlotType.休眠:
			kw.keyword_id = "kw_dormant_%d" % value
			display = "休眠%d" % value
			desc = "激活后延迟 %d 回合生效" % value
			kw.category = KeywordData.KeywordCategory.MECHANIC
			var e = DormantEffect.new()
			e.delay_turns = value
			kw.effect = e

		SlotType.无法打出:
			kw.keyword_id = "kw_cannot_play"
			display = "无法打出"
			desc = "此卡牌无法被打出"
			kw.category = KeywordData.KeywordCategory.MECHANIC

	if not display_name_override.is_empty():
		display = display_name_override
	if not description_override.is_empty():
		desc = description_override

	kw.display_name = display
	kw.description = desc
	return kw


# ── 辅助显示 ──

static func _status_display(sid: String, amount: int) -> String:
	match sid:
		"burn": return "灼烧%d" % amount
		"bleed": return "流血%d" % amount
		"slow": return "减速%d" % amount
		"reflect": return "反震%d" % amount
		"damage_reduction": return "合金%d" % amount
		"vulnerable": return "易伤%d" % amount
		"weak": return "虚弱%d" % amount
		"strength": return "力量%d" % amount
		"dexterity": return "敏捷%d" % amount
		"vigor": return "活力%d" % amount
		"buffer": return "缓冲%d" % amount
		"ethereal": return "虚化"
		"frail": return "脆化%d" % amount
		"stun_attack": return "阻截"
		"retaliate_generate_fire": return "余烬"
	return "%s%d" % [sid, amount]

static func _status_desc(sid: String, amount: int, dur: int, to_self: bool) -> String:
	var who = "自身" if to_self else "敌人"
	var sname = _status_display(sid, amount)
	if sid == "ethereal" or sid == "stun_attack" or sid == "retaliate_generate_fire":
		return "赋予 %s %s，持续 %d 回合" % [who, sname, dur]
	return "赋予 %s %d 层%s，持续 %d 回合" % [who, amount, sname, dur]

static func _cond_display(c: String) -> String:
	match c:
		"prev_turn_active": return "上回合激活"
		"enemy_has_burn": return "敌人灼烧"
		"enemy_has_slow": return "敌人减速"
		"enemy_has_bleed": return "敌人流血"
		"enemy_has_shield": return "敌人护盾"
		"player_has_shield": return "持有护盾"
		"any_card_activated": return "任意激活"
		"enemy_has_frail": return "敌人脆化"
	return c

static func _action_display(aid: String) -> String:
	match aid:
		"overload": return "过载"
		"shield_break": return "破盾"
		"change_enemy_intent": return "撼地"
		"draw_card": return "抽牌"
		"charge": return "充能"
		"eject": return "弹出"
		"collapse": return "瓦解"
		"reactivate": return "淬火"
		"damage_multiplier": return "翻倍"
		"random_element_2": return "润泽"
		"workshop_discount": return "埋藏"
	return aid

static func _action_desc(aid: String) -> String:
	match aid:
		"overload": return "触发一次过载"
		"shield_break": return "破除敌人护盾"
		"change_enemy_intent": return "强制改变敌方意图"
		"draw_card": return "从牌组随机抽卡3选1，置入主槽并激活"
		"charge": return "立即激活目标卡牌，此次激活不进入冷却"
		"eject": return "将该槽位中的牌移回手牌包，槽位变空"
		"collapse": return "卡牌打出后冷却直到战斗结束"
		"reactivate": return "本回合内可再次激活当前卡牌"
		"damage_multiplier": return "本次伤害翻倍 (x2.0)"
		"random_element_2": return "随机获得2单位非水元素"
		"workshop_discount": return "下次车间打造消耗-2金元素"
	return aid
