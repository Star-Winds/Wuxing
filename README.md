# 五行 — 设计文档

> 一款基于五行生克的 Roguelike 卡牌构筑游戏（Godot 4.6）

---

## 一、世界观 & 核心循环

玩家扮演一名五行修士，在随机生成的世界地图上推进，经历战斗、休整、购物、事件和 BOSS 战，构筑卡组与五行反应体系，通关三个世界。

**核心循环：**

```
选法脉(15张初始牌) → 地图推节点 → 战斗(获得奖励) → 构筑卡组/反应/装备 → BOSS(获阵法) → 下一世界 → 通关
```

**游戏资源：**

| 资源 | 说明 | 初始值 |
|------|------|--------|
| 生命 (HP) | 归零则游戏结束 | 81 |
| 以太 (Aether) | 万能支付资源，可代替任何元素支付 | 81 |
| 元素 (金/木/水/火/土) | 支付卡牌费用、触发反应 | 0 |
| 金币 (Gold) | 在商店消费 | 150 |
| 装备 | 通过车间打造获得，被动生效 | 无 |
| 反应 | 战斗胜利 40% 几率掉落，装配后自动触发 | 20 种 |
| 阵法 | Boss 击败后获得，5 槽全激活时发动 | 1 种 |

---

## 二、五行体系

### 2.1 元素附着与反应（双向）

每张卡牌携带一种五行元素。打出卡牌时，为敌人附着对应元素（默认 1 层）。**敌人攻击时也可能对玩家附着元素**，触发双向反应。

**元素层数机制（敌我对称）：**

- 同元素叠加 → 增加层数
- 异元素碰撞 → 触发五行反应，层数减 1
- 层数归零 → 清除附着
- 多元素敌人：`initial_elements` 数组按序入队，一层消耗后自动出队下一元素

**玩家也拥有 `player_element` / `player_element_layers`**，敌人通过 `intent_elements` 对玩家附着元素。

### 2.2 20 种五行反应

反应已统一为 `CardData`（`is_reaction=true`），效果走 KeywordSlot 管线。玩家在反应界面自由装配/丢弃。

| combo | 反应名 | 效果 |
|-------|--------|------|
| 火+水 | 蒸腾 | 敌人灼烧 4 层，持续 2 回合 |
| 水+火 | 熄灭 | 敌人虚弱 1 层，持续 2 回合（伤害 ×0.75） |
| 火+土 | 烧制 | 敌人脆化 1 层 2 回合（受伤 ×1.5），玩家 +1 土 |
| 土+火 | 余烬 | 玩家每受击一次，返还 1 火 |
| 火+木 | 焚烬 | 本次伤害翻倍（×2.0） |
| 木+火 | 添柴 | 玩家 +3 火 |
| 火+金 | 熔炼 | 破除敌人护盾 |
| 金+火 | 过载 | 随机激活一个副槽 |
| 水+木 | 润泽 | 随机获得 2 单位非水元素 |
| 木+水 | 吸纳 | 获得 1 以太 |
| 水+土 | 泥沼 | 敌人减速 1 层，持续 2 回合（护盾量 ×0.5） |
| 土+水 | 阻截 | 禁锢敌人攻击 1 回合 |
| 水+金 | 淬火 | 本卡牌本回合可再次激活 |
| 金+水 | 涌泉 | +2 水元素 |
| 木+土 | 破土 | 追加 5 点伤害 |
| 土+木 | 固本 | 恢复 4 HP |
| 木+金 | 坚韧 | 玩家反震 3 层，持续 2 回合 |
| 金+木 | 伐断 | 敌人流血 5 层，持续 2 回合 |
| 金+土 | 合金 | 自身永久 +1 伤害减免 |
| 土+金 | 埋藏 | 下次车间打造 -2 金消耗 |

### 2.3 五行相生

当回合未激活任何卡牌时触发**引气入体**：全基础元素 +5，鼓励资源规划。

### 2.4 五行阵法

击败世界 BOSS 后获得（CardData，`is_formation=true`）。战斗中 5 个主槽全部激活后出现阵法按钮，点击释放。

---

## 三、战斗系统

### 3.1 槽位机制

玩家拥有 **5 行 × 3 槽**（1 主槽 + 2 副槽）的棋盘布局。

**状态机（4 状态）：**

```
INACTIVE → ACTIVATED → PLAYED → COOLDOWN → INACTIVE
```

| 状态 | 说明 |
|------|------|
| INACTIVE | 未激活，可点击弹出充能面板 |
| ACTIVATED | 已充能，点击进入瞄准模式 |
| PLAYED | 已释放（本回合已打出） |
| COOLDOWN | 冷却中，回合结束倒计时减 1，归零回到 INACTIVE |

### 3.2 充能支付

激活卡牌时弹出充能面板：

- 按卡牌所需元素类型显示 SpinBox
- 以太作为万能支付源
- 必须精确匹配总费用才能确认

**消耗回补：** 卡牌释放后，按实际消耗的每种元素回补 `max(1, spent / 2)`。消耗越多回补越多。

### 3.3 管道执行 (Pipeline)

卡牌释放后依次经历 5 个阶段：

```
PRE_HIT → AGGREGATION → REACTION_CHECK → EXECUTION → POST_HIT
```

| 阶段 | 执行内容 |
|------|----------|
| PRE_HIT | 特殊行动（破盾/过载/抽牌/撼地等）、休眠、共鸣 |
| AGGREGATION | 聚合伤害/护盾 + 动态加成（力量/活力/灼烧+3/流血+2） |
| REACTION_CHECK | 元素附着/碰撞检测，触发五行反应（反应走 Phase 分离执行） |
| EXECUTION | 护盾获得（敏捷加成）+ 伤害结算（脆弱×1.5→易伤×1+0.5×n→护盾吸收）→ 反震 |
| POST_HIT | 状态施加、元素产出、治疗 |

### 3.4 敌人系统

#### 数据架构

敌人使用 `EnemyData` 资源类（`.tres` 文件），支持词条驱动的战斗行为。

| 字段 | 类型 | 说明 |
|------|------|------|
| id / enemy_name | String | 标识与显示名 |
| element | enum | 五行属性 |
| max_hp | int | 最大生命值 |
| intent_base_dmg | int | 基础攻击伤害 |
| initial_elements | Array[String] | 初始附着元素队列（多元素依次出队） |
| intent_elements | Array[String] | 意图元素序列（按回合轮换对玩家附着） |
| enemy_keywords | Array[KeywordSlot] | 敌人词条数组 |

#### 意图系统（3 回合循环）

| 回合（%3） | 意图 | 效果 |
|------------|------|------|
| 0 | 攻击 | `intent_base_dmg + atk_buff` + 意图元素附着 + ON_ATTACK 词条 |
| 1 | 防御 | +15 护盾（减速时 7）+ ON_DEFEND 词条 |
| 2 | 增益 | `enemy_atk_buff += 3` |

可被 `敌意覆盖`（撼地）强制改为"防御"。

#### 敌人词条触发时机（7 种 TriggerTiming）

| 时机 | 枚举值 | 触发位置 |
|------|--------|----------|
| TURN_START | 1 | 回合开始时 |
| TURN_END | 2 | 回合结束时（DOT 结算后） |
| ON_ATTACK | 3 | 敌人攻击时 |
| ON_DEFEND | 4 | 敌人防御时 |
| ON_HURT | 5 | 敌人受到伤害后 |
| ON_DEATH | 6 | 敌人死亡时 |
| PASSIVE | 0 | 默认，不自动触发 |

#### 敌人阵容（18 个，3 世界 × 6）

详见 `docs/superpowers/specs/2026-05-15-cards-and-enemies-design.md` 第二节。

| 世界 | 主题 | 小怪/精英/Boss | 特点 |
|------|------|----------------|------|
| World 1 | 五行初现 | 6 个 | 纯单元素，基础教学 |
| World 2 | 元素交融 | 6 个 | 双元素混合，意图元素轮换 |
| World 3 | 五行归一 | 6 个 | 复合词条，Boss 带 18 词条 |

---

## 四、卡牌系统

### 4.1 卡牌数据 (CardData)

所有卡牌为 `.tres` 资源文件，共 **95 张**（74 标准 + 20 反应 + 1 阵法）。

#### 类型词条

| 字段 | 类型 | 说明 |
|------|------|------|
| id / card_name | String | 唯一标识与显示名 |
| element | enum(金木水火土以太) | 五行属性 |
| rarity | enum(凡/稀/珍) | 稀有度 |
| is_reaction | bool | 元素反应标记 |
| is_formation | bool | 五行阵法标记 |
| is_carry | bool | 携带：在 deck 中即生效（规划中） |
| is_embed | bool | 嵌入：在副槽即生效（规划中） |
| is_initiate | bool | 初动：在主槽即生效（规划中） |
| is_exhaust | bool | 消耗：打出后从牌组永久移除 |
| single_use | bool | 一次性：本场战斗仅可使用一次 |

#### 消耗系统

| 字段 | 类型 | 说明 |
|------|------|------|
| cost_metal / cost_wood / cost_water / cost_fire / cost_earth / cost_aether | int | 各元素消耗量 |

### 4.2 词条槽位 (KeywordSlot)

卡牌效果通过 `KeywordSlot` 定义，Inspector 可视化编辑，运行时 `compile()` 编译为 `KeywordData`（含 `EffectBase` 子类实例）。

**三组槽位：**

| 槽位组 | 字段 | 说明 |
|--------|------|------|
| main_slots | Array[KeywordSlot] | 主槽词条（主要效果） |
| sub_slots | Array[KeywordSlot] | 副槽词条（辅助效果） |
| mechanic_slots | Array[KeywordSlot] | 机制词条（无法打出等） |

### 4.3 SlotType（14 种词条类型）

| SlotType | Effect 子类 | Phase | 配置字段 |
|----------|------------|-------|----------|
| 伤害 | DamageEffect | AGGREGATION | value |
| 护盾 | ShieldEffect | AGGREGATION | value |
| 治疗 | HealEffect | POST_HIT | value |
| 伤害护盾 | DamageAndShieldEffect | AGGREGATION | value, value2 |
| 施加状态 | StatusEffect | POST_HIT | status_id, value, duration, to_player |
| 生成元素 | GenerateElementEffect | POST_HIT | element_type, value |
| 条件伤害 | ConditionDamageEffect | AGGREGATION | value, condition, value2 |
| 行动 | SpecialActionEffect | PRE_HIT | action_id |
| 多次伤害 | MultiHitDamageEffect | AGGREGATION | value, value2 |
| 全体伤害 | AOEDamageEffect | AGGREGATION | value |
| 共鸣 | ResonanceEffect | PRE_HIT | condition |
| 休眠 | DormantEffect | PRE_HIT | value |
| 无法打出 | — | — | — |

### 4.4 StatusEffect（15 种状态）

| status_id | 显示名 | 目标 | 公式 |
|-----------|--------|------|------|
| burn | 灼烧 | 双向 | 回合结束 HP -= amount（默认 4） |
| bleed | 流血 | 双向 | 回合结束 HP -= amount（默认 5） |
| vulnerable | 易伤 | 敌人 | 受伤 × (1.0 + 0.5 × amount)，每层 +50% |
| weak | 虚弱 | 敌人 | 攻击 × max(0.25, 1.0 - 0.25 × amount) |
| frail | 脆化 | 敌人 | 受伤 × 1.5 |
| strength | 力量 | 玩家 | 攻击 +amount |
| vigor | 活力 | 玩家 | 攻击 +amount |
| dexterity | 敏捷 | 玩家 | 获得护盾 +amount |
| buffer | 缓冲 | 玩家 | 完全抵消一次 HP 损失 |
| ethereal | 虚化 | 玩家 | 本回合受伤 = 1 |
| damage_reduction | 合金 | 双向 | dmg = max(0, dmg - amount) |
| reflect | 反震 | 双向 | 受击反伤 amount（以太属性） |
| slow | 减速 | 敌人 | 护盾获得 = 7（原 15） |
| stun_attack | 阻截 | 敌人 | 跳过攻击 |
| retaliate_generate_fire | 余烬 | 玩家 | 受击 +1 火 |

### 4.5 ActionEffect（11 种特殊行动）

| action_id | 显示名 | 效果 |
|-----------|--------|------|
| overload | 过载 | 随机激活未激活副槽 |
| shield_break | 破盾 | 破除敌人护盾 |
| change_enemy_intent | 撼地 | 敌人下回合强制防御 |
| draw_card | 抽牌 | 从牌池随机抽入空副槽 |
| charge | 充能 | 随机激活卡槽，不冷却 |
| eject | 弹出 | 将槽位卡牌移回牌包 |
| collapse | 瓦解 | 冷却直到战斗结束 |
| reactivate | 淬火 | 本回合可再次激活此卡 |
| damage_multiplier | 翻倍 | 本次伤害 ×2.0 |
| random_element_2 | 润泽 | 随机获得 2 非水元素 |
| workshop_discount | 埋藏 | 下次车间消耗 -2 金 |

### 4.6 Condition（8 种条件触发）

| condition | 显示名 | 检查逻辑 |
|-----------|--------|----------|
| prev_turn_active | 上回合激活 | 上下文标志 |
| player_has_shield | 持有护盾 | 上下文标志 |
| enemy_has_shield | 敌人护盾 | 上下文标志 |
| enemy_has_burn | 敌人灼烧 | StatusManager 查询 |
| enemy_has_bleed | 敌人流血 | StatusManager 查询 |
| enemy_has_slow | 敌人减速 | StatusManager 查询 |
| enemy_has_frail | 敌人脆化 | StatusManager 查询 |
| any_card_activated | 任意激活 | 恒为 true |

### 4.7 牌组管理

| 规则 | 说明 |
|------|------|
| 起始牌组 | 选法脉后获得 15 张牌 |
| 牌组上限 | 30 张 (MAX_DECK_SIZE) |
| 获得卡牌 | 战斗胜利三选一、商店购买 |
| 牌组满时 | 弹出替换界面，选择一张丢弃再纳入新牌 |
| 布局管理 | 5 行主/副槽可在 DeckBuilder 中自由编排 |

### 4.8 装备系统

特定卡牌（"小刀制造""藤甲制造"）可在车间节点消耗后打造为装备（EquipmentData/EquipmentEffect 资源）：

- 消耗对应卡牌 + 元素资源 → 获得装备
- 装备显示在 GlobalHUD 上
- 通过 `acquired_equipment: Array[String]` 追踪
- 效果：小刀 `damage_bonus +3`、藤甲 `damage_reduction -4` / `fire_vulnerability +4`

---

## 五、战斗管道完整流程

### 5.1 玩家攻击 (`play_card()`)

```
PRE_HIT (Phase 0)
  └─ SpecialActionEffect, DormantEffect, ResonanceEffect

AGGREGATION (Phase 1)
  └─ DamageEffect, ShieldEffect, MultiHitDamageEffect,
     AOEDamageEffect, ConditionDamageEffect, DamageAndShieldEffect
  └─ 动态加成: strength(+flat), vigor(+flat)
     敌人 burn(+3), 敌人 bleed(+2)

REACTION_CHECK
  └─ element_system.attach(card_element, layers, "enemy")
  └─ combo_key → 查 equipped_reactions → _trigger_reaction()
     反应走 PRE_HIT → AGGREGATION → POST_HIT 三阶段

EXECUTION
  └─ 护盾: player_shield += total_shield (dexterity 加成)
  └─ 伤害: get_final_damage() → take_damage()
      equip_bonus → frail ×1.5 → vulnerable ×(1+0.5×amount)
      → damage_after_shield → enemy_hp -= hp_loss
  └─ 真实伤害: enemy_hp -= true_damage
  └─ 反震: 敌人 reflect → _damage_player(reflect_amount)

POST_HIT (Phase 2)
  └─ StatusEffect, GenerateElementEffect, HealEffect
```

### 5.2 敌人回合 (`end_turn()`)

```
TURN_START 敌人词条: _execute_enemy_slots(TURN_START)
玩家护盾清空: player_shield = 0

敌人 DOT: burn(amount|4), bleed(amount|5) → enemy_hp

TURN_END 敌人词条: _execute_enemy_slots(TURN_END)

玩家 DOT: burn(amount|4), bleed(amount|5) → player_hp

敌人意图 (_execute_enemy_intent):
  ├─ attack:
  │   ├─ stun_attack? → 跳过
  │   ├─ weak: dmg × max(0.25, 1-0.25×amount)
  │   ├─ intent_elements → element_system.attach("player")
  │   ├─ _damage_player(dmg):
  │   │   ├─ equip_reduction / equip_vulnerability
  │   │   ├─ ethereal: dmg=1
  │   │   ├─ buffer: hp_loss=0
  │   │   ├─ damage_reduction: max(0, dmg-amount)
  │   │   ├─ shield → hp_loss
  │   │   └─ retaliate_generate_fire: fire += 1
  │   ├─ ON_ATTACK 敌人词条
  │   └─ 玩家 reflect → take_damage on enemy
  ├─ defend:
  │   ├─ slow: shield_gain = 7 (else 15)
  │   └─ ON_DEFEND 敌人词条
  └─ buff:
       └─ enemy_atk_buff += 3

回合推进: enemy_turn_counter += 1
衰减: 所有 status duration - 1（≤0 移除）
TURN_START 词条（新一轮）
```

### 5.3 伤害公式

**玩家 → 敌人：**

```
actual = amount + equip_damage_bonus()
if frail: actual = floor(actual × 1.5)
if vulnerable: actual = floor(actual × (1.0 + 0.5 × vuln_amount))
result = damage_after_shield(actual, enemy_shield)
  hp_loss = max(0, actual - enemy_shield)
  shield = max(0, enemy_shield - actual)
enemy_hp -= hp_loss
→ ON_HURT 敌人词条
```

**敌人 → 玩家：**

```
modified = max(1, amount - equip_damage_reduction + equip_element_vulnerability)
if ethereal: modified = 1
result = damage_player(modified, player_shield, player_damage_reduction)
  dmg = max(0, modified - player_damage_reduction)
  hp_loss = max(0, dmg - player_shield)
if buffer: hp_loss = 0
player_hp -= hp_loss
if retaliate_generate_fire: fire += 1
```

---

## 六、地图 & 流程

### 6.1 节点类型

| 节点 | 说明 |
|------|------|
| 兵 (Battle) | 普通战斗（加载世界对应 Minion 敌人） |
| 士 (Elite) | 精英战斗（加载世界对应 Elite 敌人） |
| 象 (Rest) | 恢复 30 HP 或随机获得 10 元素 |
| 马 (Shop) | 购买/替换卡牌 |
| 炮 (Event) | 随机事件（数据驱动） |
| 车 (Workshop) | 打造装备 |
| 将/帅 (Boss) | 世界 Boss（第 16 节点固定） |

每世界生成 15 个随机节点 + 1 个固定 Boss（共 16 节点）。

### 6.2 世界推进

```
Boss 战胜 → BossRewardScene（展示阵法）→ current_world +1
→ 生成新世界 → 地图开始
```

- 第 3 世界 Boss 后通关 game_win_scene
- 每世界阵法唯一
- 敌人从 `Resources/Enemies/World_{n}/{Minion|Elite|Boss}/` 随机加载

### 6.3 场景列表

| 场景 | 说明 |
|------|------|
| MainMenu | 主菜单 |
| InitialDeckSelection | 选法脉（火+水 / 土+木 / 混沌） |
| Map | 世界地图 |
| Battle | 战斗主场景 |
| Victory | 战斗胜利奖励（20 金币 + 元素 + 卡牌三选一 + 40% 反应掉落） |
| BossReward | Boss 阵法展示 |
| Shop | 商店 |
| Rest | 休整 |
| Workshop | 装备打造 |
| Event | 随机事件 |
| DeckBuilder | 卡组编排悬浮层 |
| ReactionOverlay | 反应管理悬浮层 |
| GameOver | 游戏结束 |
| GameWin | 通关 |

---

## 七、数据流 & 模块架构

```
ResourceManager (自动扫描 .tres)
    ↓
CardData / EnemyData / ReactionData (资源文件)
    ↓
GameManager (全局单例) → 持有子模块:
    ├── PlayerState (玩家属性)
    ├── DeckManager (卡池 + 布局)
    ├── ReactionSystem (反应拥有 + 装配)
    ├── active_formation: CardData (阵法)
    └── SaveManager / RNGService
    ↓
BattleManager (战斗实例) → 持有子模块:
    ├── ElementSystem (双向元素附着)
    ├── StatusManager (状态管理)
    └── DamageResolver (伤害聚合)
    ↓
UI 层 (battle_ui / victory_ui / shop_ui / etc.)
    └── GlobalHUD (常驻顶栏，signal 驱动)
```

### 关键设计决策

- **Resource 架构**：卡牌、敌人均为 `.tres` 资源，编辑器可视化编辑
- **KeywordSlot 系统**：14 种词条类型 → `compile()` → Effect 管线，数据驱动
- **反应/阵法统一**：底层均为 `CardData` + `KeywordSlot`，告别硬编码 match
- **双向元素**：`element_system` 支持 `player`/`enemy` 两侧附着
- **敌人词条**：7 种 `TriggerTiming` 驱动 AI 行为
- **信号驱动 UI**：EventBus → HUD 自动刷新，无 `_process` 轮询
- **子系统解耦**：ElementSystem / StatusManager / DamageResolver 独立可测
- **存档系统**：SaveManager 持久化全局状态，RNGService 种子存档

---

## 八、系统基础设施

| 系统 | 说明 |
|------|------|
| RNGService | 基于种子的随机数（存档可复现） |
| SaveManager | 全局状态序列化/反序列化 |
| EventBus | 全局信号总线（解耦模块通信） |
| ActionQueue | 动画序列队列（signal 驱动，非轮询） |
| BaseScreen | UI 基类（场景标题 + 返回地图逻辑） |

---

## 九、调试

战斗中按 **Ctrl+K** 一键秒杀当前敌人，方便测试流程。
