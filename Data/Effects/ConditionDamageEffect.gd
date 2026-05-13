class_name ConditionDamageEffect
extends EffectBase

@export var base_damage: int = 0
@export var condition: String = ""
@export var bonus_per_condition: int = 0

func _init():
	phase = Phase.AGGREGATION

func execute(context: Dictionary) -> Dictionary:
	var resolver: DamageResolver = context.get("damage_resolver")
	if not resolver:
		return {}

	var bonus = 0
	var sm: StatusManager = context.get("status_manager")

	match condition:
		"player_has_shield":
			if context.get("player_has_shield", false):
				bonus = bonus_per_condition

		"prev_turn_active":
			if context.get("prev_turn_active", false):
				bonus = bonus_per_condition

		"enemy_has_shield":
			if context.get("enemy_has_shield", false):
				bonus = bonus_per_condition

		"enemy_has_burn":
			if sm and sm.has("burn", "enemy"):
				bonus = bonus_per_condition

		"enemy_has_bleed":
			if sm and sm.has("bleed", "enemy"):
				bonus = bonus_per_condition

		"enemy_has_weak":
			if sm and sm.has("weak", "enemy"):
				bonus = bonus_per_condition

		"enemy_has_frail":
			if sm and sm.has("frail", "enemy"):
				bonus = bonus_per_condition

		"enemy_has_slow":
			if sm and sm.has("slow", "enemy"):
				bonus = bonus_per_condition

		"player_has_reflect":
			if sm and (sm.has("reflect", "player") or sm.has("反震", "player")):
				bonus = bonus_per_condition

		_:
			bonus = bonus_per_condition if condition == "" else 0

	resolver.add_damage(base_damage + bonus)
	return {}

func get_display_value() -> int:
	return base_damage
