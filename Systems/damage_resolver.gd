class_name DamageResolver
extends RefCounted

# Aggregated values for a single card play
var total_damage: int = 0
var total_shield: int = 0
var damage_multiplier: float = 1.0
var true_damage: int = 0


func reset() -> void:
	total_damage = 0
	total_shield = 0
	damage_multiplier = 1.0
	true_damage = 0


func add_damage(amount: int) -> void:
	total_damage += amount


func add_shield(amount: int) -> void:
	total_shield += amount


func get_final_damage() -> int:
	return int(total_damage * damage_multiplier)


func apply_shield_to_player(player_shield: int) -> int:
	return player_shield + total_shield


func damage_after_shield(amount: int, enemy_shield: int) -> Dictionary:
	"""Returns {hp_loss, shield_remaining} after shield absorbs damage."""
	var dmg = amount
	var shield = enemy_shield
	if shield >= dmg:
		shield -= dmg
		return {"hp_loss": 0, "shield_remaining": shield}
	else:
		dmg -= shield
		shield = 0
		return {"hp_loss": dmg, "shield_remaining": shield}


func damage_player(amount: int, player_shield: int, player_damage_reduction: int) -> Dictionary:
	"""Returns {hp_loss, shield_remaining, damage_reduced}."""
	var dmg = max(0, amount - player_damage_reduction)
	if dmg <= 0:
		return {"hp_loss": 0, "shield_remaining": player_shield, "damage_reduced": amount}

	if player_shield >= dmg:
		return {"hp_loss": 0, "shield_remaining": player_shield - dmg, "damage_reduced": 0}
	else:
		var remainder = dmg - player_shield
		return {"hp_loss": remainder, "shield_remaining": 0, "damage_reduced": 0}
