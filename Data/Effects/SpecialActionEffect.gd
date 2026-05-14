class_name SpecialActionEffect
extends EffectBase

@export var action_id: String = ""

func _init():
	phase = Phase.PRE_HIT

func execute(context: Dictionary) -> Dictionary:
	var bm: Node = context.get("battle_manager")
	var target: Node = context.get("target")
	if not bm:
		return {}

	match action_id:
		"shield_break":
			print("  [特殊效果] 触发强力破盾！")
			if target and target.has_method("break_shield"):
				target.break_shield()
			else:
				bm.break_shield()
		"change_enemy_intent":
			bm.enemy_intent_override = "defend"
			print("  [特殊效果] 改变敌人意图为 [DEFEND]")
		"overload":
			bm.overload_random_sub_slot()
		"draw_card":
			bm.draw_card_from_pool()
		"charge":
			bm.charge_random_slot()
		"eject":
			bm.eject_card_from_slot()
		"collapse":
			bm.collapse_card()
		"reactivate":
			bm.reactivate_current_card = true
			print("  [特殊效果] 淬火 — 卡牌可再次激活！")
		"damage_multiplier":
			var dr = context.get("damage_resolver")
			if dr:
				dr.damage_multiplier = 2.0
				print("  [特殊效果] 伤害翻倍 (x2.0)！")
		"random_element_2":
			bm._grant_random_elements(2)
		"workshop_discount":
			GameManager.workshop_discount_amount += 2
			print("  [特殊效果] 埋藏 — 车间折扣 +2")
		_:
			print("  [特殊效果] 未知 action_id: ", action_id)

	return {}

func get_display_value() -> int:
	return 0
