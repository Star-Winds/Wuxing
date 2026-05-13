extends Node
## 全局事件总线
##
## 用法: 在任何脚本中通过 EventBus.<signal_name>.emit(...) 发送信号，
## 通过 EventBus.<signal_name>.connect(...) 订阅信号。
##
## *重要*: 在 项目设置 > 自动加载 中注册此脚本，名称为 "EventBus"。

# ============================================================
#  卡牌领域 (Card Domain)
# ============================================================

## 玩家选中了一张卡牌（鼠标悬停/点击），未涉及消耗或激活。
signal card_hovered(card_data: CardData, slot_index: int, slot_type: String)

## 卡牌支付面板完成确认，卡牌变为 ACTIVATED 状态。
signal card_activated(card_data: CardData, slot_index: int, cost: Dictionary)

## 卡牌正式打出（已瞄准目标并执行 play_card 管道）。
signal card_played(card_data: CardData, sub_cards: Array, target: Node)

## 卡牌进入冷却 (PLAYED) 状态。
signal card_played_out(card_data: CardData, slot_index: int)

## 卡牌因淬火等效果被重新激活。
signal card_reactivated(card_data: CardData, slot_index: int)


# ============================================================
#  战斗生命周期 (Battle Lifecycle)
# ============================================================

## 战斗初始化完成（所有子系统就绪、敌人数据加载完毕）。
signal battle_started(enemy_data: Resource, enemy_hp: int, enemy_shield: int)

## 回合正式开始（初始化/敌人行动/状态衰减完毕后）。
signal turn_started(turn_number: int)

## 回合结束（玩家主动点击结束回合）。
signal turn_ended(turn_number: int)

## 战斗胜利（敌人 HP ≤ 0）。
signal battle_won()

## 战斗失败（玩家 HP ≤ 0）。
signal battle_lost()

## 五行阵法就绪状态变更。
signal formation_readiness_changed(is_ready: bool)

## 五行阵法已发动。
signal formation_activated(formation_name: String)


# ============================================================
#  战斗数值 (Battle Numeric)
# ============================================================

## 任意单位受到伤害时触发。
signal damage_taken(target: String, amount: int, element: String, hp_remaining: int)

## 任意单位获得护盾时触发。
signal shield_gained(target: String, amount: int, shield_total: int)

## 玩家获得/产生元素时触发。
signal element_generated(element: String, amount: int, source: String)

## 五行元素反应被触发时触发。
signal reaction_triggered(reaction_name: String, combo_key: String)

## 状态效果更新时触发（燃烧/流血/脆弱等）。
signal status_applied(target: String, status_id: String, duration: int, amount: int)

## 玩家生命值变化（直接的生命值变更，非伤害流程）。
signal player_hp_changed(old_hp: int, new_hp: int, max_hp: int)

## 玩家以太数量变化。
signal aether_changed(old_amount: int, new_amount: int)


# ============================================================
#  便捷触发方法 (可选，方便从强类型约束的上下文调用)
# ============================================================

func emit_card_activated(card: CardData, slot_index: int, cost: Dictionary) -> void:
	card_activated.emit(card, slot_index, cost)


func emit_card_played(card: CardData, subs: Array, target: Node) -> void:
	card_played.emit(card, subs, target)


func emit_card_played_out(card: CardData, slot_index: int) -> void:
	card_played_out.emit(card, slot_index)


func emit_battle_started(enemy: Resource, hp: int, shield: int) -> void:
	battle_started.emit(enemy, hp, shield)


func emit_turn_started(turn: int) -> void:
	turn_started.emit(turn)


func emit_turn_ended(turn: int) -> void:
	turn_ended.emit(turn)


func emit_battle_won() -> void:
	battle_won.emit()


func emit_battle_lost() -> void:
	battle_lost.emit()


func emit_damage_taken(target: String, amount: int, element: String, hp_remaining: int) -> void:
	damage_taken.emit(target, amount, element, hp_remaining)


func emit_shield_gained(target: String, amount: int, shield_total: int) -> void:
	shield_gained.emit(target, amount, shield_total)


func emit_reaction_triggered(name: String, combo: String) -> void:
	reaction_triggered.emit(name, combo)


func emit_status_applied(target: String, status_id: String, duration: int, amount: int) -> void:
	status_applied.emit(target, status_id, duration, amount)


func emit_player_hp_changed(old_hp: int, new_hp: int, max_hp: int) -> void:
	player_hp_changed.emit(old_hp, new_hp, max_hp)


func emit_aether_changed(old: int, new: int) -> void:
	aether_changed.emit(old, new)
