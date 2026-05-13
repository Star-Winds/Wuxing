class_name DamageResolver
extends RefCounted

# ============================================================
#  伤害结算系统 (Damage Resolution System)
#
#  核心思想: 伤害从一个"基础数值"出发，依次经过多层修饰器
#  (Modifier) 的加工，最终得到实际对目标造成的伤害。
#
#  管道数据流 (Pipeline Data Flow):
#
#    base_amount (聚合阶段出口)
#       │
#       ▼
#    ┌─────────────────────────────┐
#    │ 1. 自身状态修正 (PRIORITY 100) │  ← 攻击方状态，如"虚弱"使伤害×0.75
#    └─────────────────────────────┘
#       │
#       ▼
#    ┌─────────────────────────────┐
#    │ 2. 敌方状态修正 (PRIORITY 200) │  ← 受击方状态，如"脆化"受伤×1.5、"灼烧"+3
#    └─────────────────────────────┘
#       │
#       ▼
#    ┌─────────────────────────────┐
#    │ 3. 反应修正   (PRIORITY 300) │  ← 五行反应，如"焚烬"×2.0、"破土"追加真实伤害
#    └─────────────────────────────┘
#       │
#       ▼
#    ┌─────────────────────────────┐
#    │ 4. 装备修正   (PRIORITY 400) │  ← 武器/遗物，如"小刀"最终伤害+3
#    └─────────────────────────────┘
#       │
#       ▼
#    ┌─────────────────────────────┐
#    │ 5. 倍率 & 真实伤害计算        │  ← damage_multiplier 与 true_damage
#    └─────────────────────────────┘
#       │
#       ▼
#    ┌─────────────────────────────┐
#    │ 6. 护盾吸收   (PRIORITY 500) │  ← 目标护盾抵扣部分伤害
#    └─────────────────────────────┘
#       │
#       ▼
#    final_amount / hp_loss (管道出口)
#
#  用法:
#    1. 聚合阶段: 仍使用 add_damage() / add_shield() 累加基础值
#    2. 结算前: 注册修饰器 register_modifier()
#    3. 结算: 调用 build_context() + resolve_damage()
#    4. 结算后: 清除临时修饰器 clear_modifiers_by_source()
# ============================================================


# ============================================================
#  DamageContext — 伤害上下文对象
#
#  封装一次伤害结算的完整数据，在管道的各阶段之间传递。
#  修饰器通过修改 ctx.final_amount 来影响最终伤害。
# ============================================================
class DamageContext extends RefCounted:
	## 伤害来源: "player" | "enemy"
	var source: String = ""
	## 伤害目标: "player" | "enemy"
	var target: String = ""
	## 管道入口值: 聚合阶段累加的原始伤害
	var base_amount: int = 0
	## 管道出口值: 经所有修饰器加工后的伤害
	var final_amount: int = 0
	## 元素类型: 金 / 木 / 水 / 火 / 土 / 以太
	var element_type: String = ""
	## 是否暴击
	var is_crit: bool = false
	## 通用标签: 修饰器间传递附加数据的载体
	## 例如 {"reaction_name": "焚烬", "ignore_shield": false}
	var tags: Dictionary = {}
	## 目标当前护盾值 (结算前由外部填入)
	var target_shield: int = 0
	## 护盾吸收的伤害量 (结算后回填)
	var shield_absorbed: int = 0
	## 最终扣除的生命值 (结算后回填)
	var hp_loss: int = 0
	## 真实伤害 (无视护盾，独立于 final_amount)
	var true_damage: int = 0
	## 伤害倍率 (所有修饰器执行完毕后统一乘算)
	var damage_multiplier: float = 1.0
	## 调试追踪: 按执行顺序记录应用了哪些修饰器
	var applied_modifiers: Array[String] = []

	func _init(p_source: String = "", p_target: String = "",
			p_base: int = 0, p_element: String = "") -> void:
		source = p_source
		target = p_target
		base_amount = p_base
		final_amount = p_base
		element_type = p_element


# ============================================================
#  DamageModifier — 伤害修饰器
#
#  每个修饰器代表一条可修改伤害的规则。
#  来源可以是: 自身状态、敌方状态、五行反应、装备/遗物。
# ============================================================
class DamageModifier extends RefCounted:
	## 唯一标识，如 "status:weak:enemy"、"reaction:焚烬"、"equip:dagger"
	var id: String = ""
	## 执行优先级，数值越小越先执行 (参见 PRIORITY_* 常量)
	var priority: int = 0
	## 可读来源描述
	var source_name: String = ""
	## 修饰函数: func(ctx: DamageContext) -> void
	var _apply: Callable

	func apply(ctx: DamageContext) -> void:
		if _apply.is_valid():
			_apply.call(ctx)


# ============================================================
#  修饰器优先级常量
#
#  管道按 priority 升序执行修饰器，保证:
#    自身状态 → 敌方状态 → 反应 → 装备 → 护盾
# ============================================================
## 攻击方自身状态修正 (虚弱、减速等)
const PRIORITY_SELF_STATUS := 100
## 受击方状态修正 (脆化、灼烧、流血等)
const PRIORITY_ENEMY_STATUS := 200
## 五行反应修正 (焚烬、破土、熔炼等)
const PRIORITY_REACTION := 300
## 装备 / 遗物修正
const PRIORITY_EQUIPMENT := 400
## 护盾吸收 — 始终最后执行
const PRIORITY_SHIELD := 500


# ============================================================
#  修饰器注册表
# ============================================================
var _modifiers: Array[DamageModifier] = []

# ============================================================
#  向后兼容字段 (Legacy API)
#  新代码推荐使用 build_context() + resolve_damage() 管道
# ============================================================
var total_damage: int = 0
var total_shield: int = 0
var damage_multiplier: float = 1.0
var true_damage: int = 0


# ============================================================
#  修饰器管理 (Modifier Registry)
# ============================================================

## 注册一个伤害修饰器。同一 id 的修饰器会被覆盖。
func register_modifier(mod: DamageModifier) -> void:
	# 如果已存在同 id 的修饰器，移除旧的
	for i in range(_modifiers.size()):
		if _modifiers[i].id == mod.id:
			_modifiers.remove_at(i)
			break
	_modifiers.append(mod)


## 按 id 移除一个修饰器。
func unregister_modifier(id: String) -> void:
	for i in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[i].id == id:
			_modifiers.remove_at(i)


## 清除所有修饰器。
func clear_all_modifiers() -> void:
	_modifiers.clear()


## 按 id 前缀清除修饰器。用于批量清理某一来源的临时修饰器。
## 例如 clear_modifiers_by_source("reaction:") 清除所有反应修饰器。
func clear_modifiers_by_source(source_prefix: String) -> void:
	var to_remove: Array[int] = []
	for i in range(_modifiers.size()):
		if _modifiers[i].id.begins_with(source_prefix):
			to_remove.append(i)
	# 从后往前删，避免索引偏移
	for i in range(to_remove.size() - 1, -1, -1):
		_modifiers.remove_at(to_remove[i])


## 获取当前所有已注册修饰器的 id 列表 (调试用)。
func get_registered_modifier_ids() -> Array[String]:
	var ids: Array[String] = []
	for mod in _modifiers:
		ids.append(mod.id)
	return ids


# ============================================================
#  核心管道 (Core Pipeline)
# ============================================================

## 快捷工厂: 创建一个 DamageContext 并从 total_damage 填充 base_amount。
func build_context(source: String, target: String,
		element_type: String = "") -> DamageContext:
	var ctx = DamageContext.new(source, target, total_damage, element_type)
	ctx.damage_multiplier = damage_multiplier
	ctx.true_damage = true_damage
	return ctx


## 伤害结算管道 — 主入口。
##
## 数据在管道中的流动:
##   1. ctx.final_amount 初始化为 ctx.base_amount
##   2. 修饰器按 priority 升序排列
##   3. 依次调用每个修饰器的 apply(ctx)，允许它修改 ctx.final_amount
##   4. 应用 ctx.damage_multiplier (倍率)
##   5. ctx.true_damage 独立于 final_amount，直接参与结算
##   6. 护盾吸收: target_shield 优先抵扣 final_amount
##   7. 剩余伤害写入 ctx.hp_loss
##
## 返回值字段:
##   final_damage: int  — 修饰后的总伤害 (未扣护盾)
##   shield_absorbed: int — 护盾吸收量
##   hp_loss: int         — 实际扣除生命值
##   true_damage: int     — 真实伤害 (无视护盾)
func resolve_damage(ctx: DamageContext) -> Dictionary:
	# ── 步骤 1: 初始化出口值为入口值 ──
	ctx.final_amount = ctx.base_amount

	# ── 步骤 2: 按优先级排序修饰器 ──
	var sorted = _modifiers.duplicate()
	sorted.sort_custom(func(a, b): return a.priority < b.priority)

	# ── 步骤 3: 依次执行修饰器 ──
	# 每个修饰器可能执行的操作:
	#   - 修改 ctx.final_amount (乘算/加算)
	#   - 修改 ctx.true_damage (反应追加真实伤害)
	#   - 修改 ctx.damage_multiplier (反应倍率)
	#   - 修改 ctx.tags (标记特殊行为，如破盾)
	for mod in sorted:
		mod.apply(ctx)
		ctx.applied_modifiers.append(mod.id)

	# ── 步骤 4: 应用伤害倍率 ──
	# 倍率在修饰器之后统一乘算，确保加算修正(如灼烧+3)不受倍率影响
	ctx.final_amount = int(ceil(float(ctx.final_amount) * ctx.damage_multiplier))

	# ── 步骤 5: 护盾吸收 ──
	# 护盾优先抵扣 final_amount，真实伤害独立结算、不受护盾影响
	if ctx.target_shield > 0 and ctx.final_amount > 0:
		if ctx.tags.get("ignore_shield", false):
			# 特殊标记: 跳过护盾 (如"熔炼"反应的破盾效果)
			ctx.shield_absorbed = 0
			ctx.hp_loss = ctx.final_amount
		elif ctx.target_shield >= ctx.final_amount:
			ctx.shield_absorbed = ctx.final_amount
			ctx.hp_loss = 0
		else:
			ctx.shield_absorbed = ctx.target_shield
			ctx.hp_loss = ctx.final_amount - ctx.target_shield
	else:
		ctx.shield_absorbed = 0
		ctx.hp_loss = ctx.final_amount

	return {
		"final_damage": ctx.final_amount,
		"shield_absorbed": ctx.shield_absorbed,
		"hp_loss": ctx.hp_loss,
		"true_damage": ctx.true_damage,
	}


# ============================================================
#  Legacy API (向后兼容)
#  以下方法保持与旧代码的兼容，新代码应优先使用管道。
# ============================================================

## 重置聚合值与倍率 (每次打牌前调用)。
func reset() -> void:
	total_damage = 0
	total_shield = 0
	damage_multiplier = 1.0
	true_damage = 0


## 累加基础伤害 (聚合阶段由 Effect 调用)。
func add_damage(amount: int) -> void:
	total_damage += amount


## 累加护盾值 (聚合阶段由 Effect 调用)。
func add_shield(amount: int) -> void:
	total_shield += amount


## [Legacy] 返回基础伤害 * 倍率。新代码请用 resolve_damage()。
func get_final_damage() -> int:
	return int(total_damage * damage_multiplier)


## 将累加的护盾应用到玩家护盾上。
func apply_shield_to_player(player_shield: int) -> int:
	return player_shield + total_shield


## [Legacy] 计算伤害经过目标护盾抵扣后的结果。
## 返回 {hp_loss, shield_remaining}。
func damage_after_shield(amount: int, enemy_shield: int) -> Dictionary:
	var dmg = amount
	var shield = enemy_shield
	if shield >= dmg:
		shield -= dmg
		return {"hp_loss": 0, "shield_remaining": shield}
	else:
		dmg -= shield
		shield = 0
		return {"hp_loss": dmg, "shield_remaining": shield}


## [Legacy] 计算玩家受到的伤害，考虑伤害减免与护盾。
## 返回 {hp_loss, shield_remaining, damage_reduced}。
func damage_player(amount: int, player_shield: int,
		player_damage_reduction: int) -> Dictionary:
	# 步骤 1: 伤害减免 (来自"合金"反应等)
	var dmg = max(0, amount - player_damage_reduction)
	if dmg <= 0:
		return {
			"hp_loss": 0,
			"shield_remaining": player_shield,
			"damage_reduced": amount,
		}
	# 步骤 2: 护盾抵扣
	if player_shield >= dmg:
		return {
			"hp_loss": 0,
			"shield_remaining": player_shield - dmg,
			"damage_reduced": 0,
		}
	else:
		var remainder = dmg - player_shield
		return {
			"hp_loss": remainder,
			"shield_remaining": 0,
			"damage_reduced": 0,
		}
