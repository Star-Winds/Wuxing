class_name PlayerState
extends RefCounted

# 玩家属性
var max_health: int = 81
var current_health: int = 81
var aether: int = 81
var gold: int = 150

# 元素资源（逐步用 Dictionary 替代独立变量）
var elements: Dictionary = {
	"金": 0, "木": 0, "水": 0, "火": 0, "土": 0
}

# 独立变量保持向后兼容（内部通过 elements 读写）
var element_metal: int:
	get: return elements["金"]
	set(v): elements["金"] = v

var element_wood: int:
	get: return elements["木"]
	set(v): elements["木"] = v

var element_water: int:
	get: return elements["水"]
	set(v): elements["水"] = v

var element_fire: int:
	get: return elements["火"]
	set(v): elements["火"] = v

var element_earth: int:
	get: return elements["土"]
	set(v): elements["土"] = v

# 装备
var acquired_equipment: Array[String] = []

func reset_run() -> void:
	current_health = max_health
	aether = 81
	gold = 150
	for el in elements.keys():
		elements[el] = 0
	acquired_equipment.clear()

func get_element(element: String) -> int:
	return elements.get(element, 0)

func add_element(element: String, amount: int) -> void:
	if elements.has(element):
		elements[element] += amount

func spend_element(element: String, amount: int) -> bool:
	if elements.get(element, 0) >= amount:
		elements[element] -= amount
		return true
	return false

func has_elements(costs: Dictionary) -> bool:
	for el in costs.keys():
		var available = aether if el == "以太" else elements.get(el, 0)
		if available < costs[el]:
			return false
	return true


func to_dict() -> Dictionary:
	return {
		"max_health": max_health,
		"current_health": current_health,
		"aether": aether,
		"gold": gold,
		"elements": elements.duplicate(),
		"acquired_equipment": acquired_equipment.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	if d.is_empty(): return
	max_health = d.get("max_health", max_health)
	current_health = d.get("current_health", current_health)
	aether = d.get("aether", aether)
	gold = d.get("gold", gold)
	if d.has("elements"): elements = d["elements"]
	if d.has("acquired_equipment"): acquired_equipment = d["acquired_equipment"]
