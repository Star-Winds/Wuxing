@tool
extends EditorScript

# 生成 Keywords 词条资源
# 遍历所有卡牌 .tres，提取去重的 Effect，生成独立的 .tres 文件

const KEYWORD_DIR = "res://Resources/Keywords/"
const CARDS_DIR = "res://Resources/Cards/"

# 收集到的所有唯一 effect（按指纹去重）
var _effect_registry: Dictionary = {}  # fingerprint → {keyword_id, display_name, description, effect}

func _run() -> void:
	print("==============================================")
	print("[关键词提取] 扫描卡牌，提取唯一效果词条...")
	print("==============================================")

	# 确保目录存在
	if not DirAccess.dir_exists_absolute(KEYWORD_DIR):
		var err = DirAccess.make_dir_recursive_absolute(KEYWORD_DIR)
		if err != OK:
			printerr("创建 Keywords 目录失败: ", err)
			return

	# 第一阶段：扫描所有卡牌，收集 effect
	_scan_all_cards()
	print("\n共发现 ", _effect_registry.size(), " 个唯一词条")

	# 第二阶段：生成 KeywordData .tres 文件
	var count = _generate_keyword_files()
	print("\n==============================================")
	print("[生成完毕] 成功生成 ", count, "/", _effect_registry.size(), " 个词条 .tres 文件")
	print("==============================================")

func _scan_all_cards() -> void:
	var dir = DirAccess.open(CARDS_DIR)
	if not dir:
		printerr("无法打开卡牌目录: ", CARDS_DIR)
		return

	_scan_dir_recursive(dir, CARDS_DIR)

func _scan_dir_recursive(dir: DirAccess, path: String) -> void:
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				var sub_dir = DirAccess.open(path + file_name + "/")
				if sub_dir:
					_scan_dir_recursive(sub_dir, path + file_name + "/")
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var card_path = path + file_name
			_process_card(card_path)
		file_name = dir.get_next()

func _process_card(card_path: String) -> void:
	var card = load(card_path)
	if not card or not (card is CardData):
		return

	# 检查 main_effect（使用反射获取，避免旧版本没有字段）
	if card.has("main_effect") and card.main_effect != null:
		_register_effect(card.main_effect, "主")

	if card.has("sub_effect") and card.sub_effect != null:
		_register_effect(card.sub_effect, "副")

func _register_effect(effect: EffectBase, slot_label: String) -> void:
	var fp = _fingerprint(effect)
	if _effect_registry.has(fp):
		return  # 已存在，跳过

	var meta = _describe_effect(effect)
	_effect_registry[fp] = meta
	print("  [", slot_label, "] 注册词条: ", meta.display_name, " (", meta.keyword_id, ")")

func _fingerprint(effect: EffectBase) -> String:
	var parts = []
	parts.append(effect.get_script().get_global_name())  # e.g. "DamageEffect"

	# 收集所有 exported 属性
	var props = effect.get_property_list()
	for p in props:
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var name = p.name
			var value = effect.get(name)
			parts.append(str(name, "="", str(value)))

	return ",".join(parts)

func _describe_effect(effect: EffectBase) -> Dictionary:
	var script_name = effect.get_script().get_global_name()
	var result = {
		"keyword_id": "",
		"display_name": "",
		"description": "",
		"effect": effect
	}

	match script_name:
		"DamageEffect":
			var v = effect.get("value")
			result.keyword_id = "kw_damage_%d" % v
			result.display_name = "伤害%d" % v
			result.description = "造成 %d 点伤害" % v

		"ShieldEffect":
			var v = effect.get("value")
			result.keyword_id = "kw_shield_%d" % v
			result.display_name = "护盾%d" % v
			result.description = "获得 %d 点护盾" % v

		"HealEffect":
			var v = effect.get("value")
			result.keyword_id = "kw_heal_%d" % v
			result.display_name = "治疗%d" % v
			result.description = "回复 %d 点生命" % v

		"DamageAndShieldEffect":
			var d = effect.get("damage")
			var s = effect.get("shield")
			result.keyword_id = "kw_damage_shield_%d_%d" % [d, s]
			result.display_name = "伤盾%d|%d" % [d, s]
			result.description = "造成 %d 点伤害，获得 %d 点护盾" % [d, s]

		"StatusEffect":
			var sid = effect.get("status_id")
			var amt = effect.get("amount")
			var dur = effect.get("duration")
			var to_player = effect.get("apply_to_player")
			result.keyword_id = "kw_%s_%d_%d" % [sid, amt, dur]
			var status_name = _status_display(sid)
			if to_player:
				result.display_name = "自%s%d" % [status_name, amt]
				result.description = "获得 %s %d 层，持续 %d 回合" % [status_name, amt, dur]
			else:
				result.display_name = "%s%d" % [status_name, amt]
				result.description = "赋予 %s %d 层，持续 %d 回合" % [status_name, amt, dur]

		"GenerateElementEffect":
			var el = effect.get("element_type")
			var amt = effect.get("amount")
			result.keyword_id = "kw_gen_%s_%d" % [el, amt]
			result.display_name = "生成%s" % el
			result.description = "获得 %d 点 %s" % [amt, el]

		"ConditionDamageEffect":
			var base = effect.get("base_damage")
			var cond = effect.get("condition")
			var bonus = effect.get("bonus_per_condition")
			result.keyword_id = "kw_cond_%s_%d_%d" % [cond, base, bonus]
			result.display_name = "条件伤%d" % (base + bonus)
			var cond_desc = _condition_display(cond)
			result.description = "造成 %d 点伤害。若%s，伤害+%d" % [base, cond_desc, bonus]

		"SpecialActionEffect":
			var act = effect.get("action_id")
			result.keyword_id = "kw_action_%s" % act
			result.display_name = "特殊: %s" % act
			result.description = "触发特殊效果: %s" % act

		_:
			# Fallback for unknown effect types
			result.keyword_id = "kw_unknown_%s" % script_name.to_lower()
			result.display_name = script_name
			result.description = "未知效果: %s" % script_name

	return result

func _status_display(sid: String) -> String:
	match sid:
		"burn": return "灼烧"
		"bleed": return "流血"
		"weak": return "虚弱"
		"frail": return "脆化"
		"slow": return "减速"
		"reflect": return "反震"
		"stun_attack": return "震慑"
		"damage_reduction": return "合金"
		"retaliate_generate_fire": return "余烬"
		_: return sid

func _condition_display(cond: String) -> String:
	match cond:
		"player_has_shield": return "持有护盾"
		"prev_turn_active": return "上一回合已激活"
		"enemy_has_shield": return "敌人有护盾"
		"enemy_has_burn": return "敌人有灼烧"
		"enemy_has_bleed": return "敌人有流血"
		"enemy_has_weak": return "敌人虚弱"
		"enemy_has_frail": return "敌人脆化"
		"enemy_has_slow": return "敌人减速"
		"player_has_reflect": return "持有反震"
		_: return cond

func _generate_keyword_files() -> int:
	var count = 0
	for fp in _effect_registry:
		var meta = _effect_registry[fp]
		var file_path = KEYWORD_DIR + meta.keyword_id + ".tres"

		# 创建 KeywordData 资源
		var kw = KeywordData.new()
		kw.keyword_id = meta.keyword_id
		kw.display_name = meta.display_name
		kw.description = meta.description
		kw.effect = meta.effect  # 直接引用原 effect 对象（会深度拷贝）

		var save_err = ResourceSaver.save(kw, file_path)
		if save_err == OK:
			print("  保存词条: ", meta.keyword_id, ".tres")
			count += 1
		else:
			printerr("  保存失败: ", meta.keyword_id, " 错误码: ", save_err)

	return count
