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
		_:
			print("  [特殊效果] 未知 action_id: ", action_id)

	return {}

func get_display_value() -> int:
	return 0
