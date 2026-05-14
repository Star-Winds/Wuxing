class_name ConditionDamageEffect
extends EffectBase

@export var base_damage: int = 0
@export var condition: String = ""
@export var bonus_per_condition: int = 0

func _init():
	phase = Phase.AGGREGATION

func _check_condition(context: Dictionary) -> bool:
	var sm: StatusManager = context.get("status_manager")
	match condition:
		"player_has_shield":
			return context.get("player_has_shield", false)
		"prev_turn_active":
			return context.get("prev_turn_active", false)
		"enemy_has_shield":
			return context.get("enemy_has_shield", false)
		"enemy_has_burn":
			return sm != null and sm.has("burn", "enemy")
		"enemy_has_bleed":
			return sm != null and sm.has("bleed", "enemy")
		"enemy_has_weak":
			return sm != null and sm.has("weak", "enemy")
		"enemy_has_frail":
			return sm != null and sm.has("frail", "enemy")
		"enemy_has_slow":
			return sm != null and sm.has("slow", "enemy")
		"player_has_reflect":
			return sm != null and (sm.has("reflect", "player") or sm.has("反震", "player"))
		_:
			return condition == ""

func execute(context: Dictionary) -> Dictionary:
	var resolver: DamageResolver = context.get("damage_resolver")
	if not resolver:
		return {}

	var bonus = bonus_per_condition if _check_condition(context) else 0
	resolver.add_damage(base_damage + bonus)
	return {}

func get_display_value() -> int:
	return base_damage
