class_name EquipmentEffect
extends Resource

## 效果类型:
##   "damage_bonus"         — 玩家造成伤害 +value
##   "damage_reduction"     — 玩家受到伤害 -value
##   "element_vulnerability" — 受到指定元素伤害 +value
##   "workshop_discount"    — 车间打造消耗 -value 金元素
@export var effect_type: String = ""
@export var value: int = 0
@export var element: String = ""
