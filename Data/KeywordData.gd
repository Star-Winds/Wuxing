class_name KeywordData
extends Resource

# 词条分类 — 对应卡牌类型/通用机制/状态效果/行动描述
enum KeywordCategory { CARD_TYPE, MECHANIC, STATUS, ACTION }

# 词条唯一标识，如 "damage_6", "shield_10", "burn_3_2"
@export var keyword_id: String = ""

# 词条分类
@export var category: KeywordCategory = KeywordCategory.ACTION

# 显示名称，如 "伤害6", "护盾10", "灼烧3"
@export var display_name: String = ""

# 描述模板，如 "造成 {value} 点伤害"
@export_multiline var description: String = ""

# 关联的 Effect 对象，决定管线执行时的行为
@export var effect: EffectBase = null

func get_display_value() -> int:
	if effect:
		return effect.get_display_value()
	return 0
