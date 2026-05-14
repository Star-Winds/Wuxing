# 五行卡牌与敌人设计文档

> 生成日期：2026-05-15 | 分支：v2-dev

---

## 一、卡牌数据（74 张标准卡 + 20 张反应卡 + 1 张阵法卡）

### 火系（12 张）

| ID | 名称 | 稀有度 | 消耗 | 描述 | 主槽 | 副槽 |
|----|------|--------|------|------|------|------|
| Fire_001 | 火势 | 凡 | 火3 | 造成10点火元素伤害。若本牌上一回合已被激活，则伤害翻倍。 | 条件伤害10（上回合激活+10） | — |
| Fire_002 | 离火罩 | 凡 | 火4 | 每当你激活或打出一张卡牌，对敌方造成2点火伤。 | — | 灼烧1（1回合） |
| Fire_003 | 烛龙引 | 凡 | 火2 | 造成6点火伤。 | 伤害6 | — |
| Fire_004 | 焚天 | 凡 | 火5 | 造成8点火伤，先清除敌方护盾。 | 伤害8 | 行动：破盾 |
| Fire_005 | 死灰复燃 | 凡 | 火0 | 复制上一张火系卡牌效果50%。 | — | 生火1 |
| Fire_006 | 火攻 | 凡 | 火2 | 造成9火元素伤害。 | 伤害9 | — |
| Fire_007 | 火花 | 凡 | 火1 | 造成4点火元素伤害。 | 伤害4 | 生火1 |
| Fire_008 | 连珠火 | 凡 | 火4 | 造成6点火伤，然后重复1次。 | 伤害6 | 伤害3 |
| Fire_009 | 纵火 | 凡 | 火2 | 赋予敌人灼烧3层，持续2回合。 | 灼烧3（2回合） | 灼烧1（1回合） |
| Fire_010 | 烈焰斩 | 凡 | 火3 | 造成5点火伤。若敌人有灼烧，伤害+2。 | 条件伤害5（敌人灼烧+2） | 伤害2 |
| Fire_011 | 焚心 | 凡 | 火5 | 造成12点火伤。若敌人有灼烧，额外+5。 | 条件伤害12（敌人灼烧+5） | 伤害5 |
| Fire_012 | 不灭之火 | 凡 | 火2 | 赋予1层灼烧，持续延长。 | 灼烧1（1回合） | 治疗3 |

### 土系（11 张）

| ID | 名称 | 稀有度 | 消耗 | 描述 | 主槽 | 副槽 |
|----|------|--------|------|------|------|------|
| Earth_007 | 墙 | 凡 | 土3 | 获得10点护盾。 | 护盾10 | — |
| Earth_008 | 撼地 | 凡 | 土4 | 改变敌方意图。 | 行动：撼地 | 护盾3 |
| Earth_009 | 戌土甲 | 凡 | 土3 | 获得6点护盾，获得反震2持续2回合。 | 反震2（2回合，自身） | — |
| Earth_010 | 厚德载物 | 凡 | 土2 | 本回合获得护盾量+50%。 | — | — |
| Earth_011 | 泰山崩 | 凡 | 土5 | 消耗护盾造成伤害，每2点护盾造成3点土伤。 | 条件伤害0（持有护盾+3） | 条件伤害0（持有护盾+3） |
| Earth_012 | 碎石 | 凡 | 土1 | 获得4点护盾。 | 护盾4 | 护盾1 |
| Earth_013 | 岩刺 | 凡 | 土2 | 造成3点土伤，获得3点护盾。 | 伤害3+护盾3 | 伤害2 |
| Earth_014 | 垒土 | 凡 | 土2 | 获得6点护盾。 | 护盾6 | 护盾3 |
| Earth_015 | 以盾为矛 | 凡 | 土4 | 消耗护盾造成伤害。 | 条件伤害0（持有护盾+5） | 条件伤害5（持有护盾+1） |
| Earth_016 | 不动如山 | 凡 | 土5 | 获得15点护盾。 | 护盾15 | 护盾5 |
| Earth_017 | 地脉涌动 | 凡 | 土3 | 获得8点护盾。 | 护盾8 | 反震1（1回合，自身） |

### 水系（13 张）

| ID | 名称 | 稀有度 | 消耗 | 描述 | 主槽 | 副槽 |
|----|------|--------|------|------|------|------|
| Water_012 | 如水 | 凡 | 水3 | 本回合已释放卡牌可重新激活。 | — | — |
| Water_013 | 甘霖 | 凡 | 水10 | 清除自身负面状态，回复生命。 | 治疗2 | — |
| Water_014 | 困泽 | 凡 | 水4 | 减速敌人。对减速敌人伤害+4。 | 减速1（1回合） | 条件伤害4（敌人减速+1） |
| Water_015 | 调息术 | 凡 | 水1 | 以太转化为元素。 | — | — |
| Water_016 | 水爆 | 凡 | 水30 | 造成52点水元素伤害。 | 伤害52 | — |
| Water_017 | 潮生诀 | 凡 | 水3 | 从卡包选牌替换主槽。 | — | — |
| Water_018 | 水珠 | 凡 | 水1 | 造成3点水伤，获得1点水元素。 | 伤害3 | 生水1 |
| Water_019 | 霜刺 | 凡 | 水2 | 造成4点水伤。若敌人减速，伤害+6。 | 条件伤害4（敌人减速+6） | 减速1（1回合） |
| Water_020 | 潮涌 | 凡 | 水3 | 造成6点水伤，获得水元素。 | 伤害6 | 生水1 |
| Water_021 | 镜湖 | 凡 | 水2 | 复制上一张卡牌效果。 | — | 伤害3 |
| Water_022 | 极寒 | 凡 | 水4 | 造成6点水伤，减速2。 | 伤害6，减速2（2回合） | 条件伤害4（敌人减速+4） |
| Water_023 | 润物无声 | 凡 | 水2 | 引气增益。 | — | 治疗2 |
| Water_024 | 万流归宗 | 凡 | 水6 | 造成20点水伤。 | 伤害20 | 生水3 |

### 金系（12 张）

| ID | 名称 | 稀有度 | 消耗 | 描述 | 主槽 | 副槽 |
|----|------|--------|------|------|------|------|
| Metal_018 | 针 | 凡 | 金3 | 随机激活一个副槽卡牌。 | 行动：过载 | 行动：过载 |
| Metal_019 | 金钟罩 | 凡 | 金5 | 获得合金3，持续2回合。 | 合金3（2回合，自身） | 合金1（999回合，自身） |
| Metal_020 | 养剑诀 | 凡 | 金4 | 金系卡牌伤害+2（本局）。 | — | — |
| Metal_021 | 破甲符 | 凡 | 金2 | 造成5点金伤。若敌人护盾翻倍。 | 条件伤害5（敌人护盾+5） | 伤害3 |
| Metal_022 | 小刀制造 | 凡 | 金3 | 造成10点金伤。 | 伤害10 | — |
| Metal_023 | 铁刺 | 凡 | 金1 | 造成4点金伤。 | 伤害4 | 伤害1 |
| Metal_024 | 破盾锥 | 凡 | 金2 | 破除敌人护盾。 | 行动：破盾 | 伤害3 |
| Metal_025 | 连环击 | 凡 | 金3 | 造成9点金伤。 | 伤害9 | 伤害2 |
| Metal_026 | 共鸣 | 凡 | 金2 | 辅助效果。 | — | 生金1 |
| Metal_027 | 万剑诀 | 凡 | 金5 | 造成4点伤害，重复多次。 | 伤害4 | 伤害2 |
| Metal_028 | 锋锐 | 凡 | 金1 | buff: 下张卡伤害+6。 | — | 伤害2 |
| Metal_029 | 金精 | 凡 | 金4 | 永久合金+护盾。 | 合金1（999回合，自身） | 护盾4 |

### 木系（13 张）

| ID | 名称 | 稀有度 | 消耗 | 描述 | 主槽 | 副槽 |
|----|------|--------|------|------|------|------|
| Wood_023 | 逢春 | 凡 | 木3 | 回复5点生命。 | 治疗5 | 治疗1 |
| Wood_024 | 缠绕 | 凡 | 木3 | 造成4点木伤，赋予流血3持续2回合。 | 伤害4，流血3（2回合） | 条件伤害1（敌人流血+1） |
| Wood_025 | 纳元术 | 凡 | 木2 | 下次元素反应额外获得元素。 | — | 生木1 |
| Wood_026 | 荆棘 | 凡 | 木3 | 获得反震4持续2回合。 | 反震4（2回合，自身） | 反震1（1回合，自身） |
| Wood_027 | 万物生 | 凡 | 木4 | 每激活一张卡牌回复1点生命。 | — | 治疗2 |
| Wood_028 | 守护者 | 凡 | 木2 | 辅助防御。 | — | — |
| Wood_029 | 叶刃 | 凡 | 木1 | 造成3点木伤，回复2点生命。 | 伤害3 | 治疗1 |
| Wood_030 | 草木萌发 | 凡 | 木2 | 回复5点生命。 | 治疗5 | 治疗2 |
| Wood_031 | 毒藤 | 凡 | 木2 | 赋予流血3层，持续2回合。 | 流血3（2回合） | 流血1（1回合） |
| Wood_032 | 嗜血藤 | 凡 | 木3 | 造成5点木伤。流血时+5。 | 条件伤害5（敌人流血+5） | 治疗3 |
| Wood_033 | 生命汲取 | 凡 | 木4 | 造成8点木伤，回复等量生命。 | 伤害8 | 治疗4 |
| Wood_034 | 枯木逢春 | 凡 | 木1 | 治疗效果+50%。 | — | 治疗2 |
| Wood_035 | 腐生 | 凡 | 木5 | 造成10点木伤。流血时追加。 | 伤害10，条件伤害0（敌人流血+8） | 伤害4 |

### 以太系（13 张）

| ID | 名称 | 稀有度 | 消耗 | 描述 | 主槽 | 副槽 |
|----|------|--------|------|------|------|------|
| Aether_028 | 归元 | 凡 | 以太3 | 返还本回合消耗元素的一半。 | — | — |
| Aether_029 | 五行轮转 | 凡 | 金1木1水1火1土1 | 造成15点伤害，触发元素反应。 | 伤害15 | — |
| Aether_030 | 流光 | 凡 | 以太5 | 取消「打出后不可再激活」限制。 | — | — |
| Aether_031 | 移形换位 | 凡 | 以太2 | 从卡包选牌替换副槽。 | — | — |
| Aether_032 | 混元归一 | 凡 | 以太8 | 造成消耗总量5%的伤害。 | 伤害0 | 生以太20 |
| Aether_033 | 星火 | 凡 | 以太1 | 获得2点以太。 | 生以太2 | 生以太1 |
| Aether_034 | 调和 | 凡 | 以太2 | 元素转化。 | — | 生以太2 |
| Aether_035 | 虚无 | 凡 | 以太3 | 造成10点伤害。 | 伤害10 | 伤害3 |
| Aether_036 | 灵气萦绕 | 凡 | 以太1 | 引气增益。 | — | 生以太2 |
| Aether_037 | 感应 | 凡 | 以太2 | 反应增益。 | — | 生以太3 |
| Aether_038 | 混沌种 | 凡 | 以太4 | 造成10点伤害，获得以太。 | 伤害10 | 生以太2 |
| Aether_039 | 返璞归真 | 凡 | 以太7 | 重置冷却。 | — | 治疗5 |
| Aether_040 | 五行流转 | 凡 | 金2木2水2火2土2 | 造成20点五行伤害。 | 伤害20 | 生以太3 |

### 元素反应卡（20 张）

| ID | 名称 | 元素组合 | 元素 | 描述 | 主槽词条 |
|----|------|----------|------|------|----------|
| Reaction_Fire_Water | 蒸腾 | 火+水 | 火 | 提供烧伤效果，每回合按层数结算扣血 | 灼烧4（2回合，敌人） |
| Reaction_Water_Fire | 熄灭 | 水+火 | 水 | 为目标赋予虚弱（造成伤害x0.75）2回合 | 虚弱1（2回合，敌人） |
| Reaction_Fire_Earth | 烧制 | 火+土 | 火 | 敌方获得脆化（受伤x1.5）2回合，主控获得1点土元素 | 脆化1（2回合，敌人），生土1 |
| Reaction_Earth_Fire | 余烬 | 土+火 | 土 | 本回合每受到伤害一次，则返还主控1火元素 | 余烬1（1回合，自身） |
| Reaction_Fire_Wood | 焚烬 | 火+木 | 火 | 本次火元素伤害翻倍 | 行动：伤害翻倍（x2.0） |
| Reaction_Wood_Fire | 添柴 | 木+火 | 木 | 主控获得3点火元素 | 生火3 |
| Reaction_Fire_Metal | 熔炼 | 火+金 | 火 | 如果目标有护盾，则破除目标的护盾，再结算伤害 | 行动：破盾 |
| Reaction_Metal_Fire | 过载 | 金+火 | 金 | 随机激活一个当前未激活的副槽卡牌 | 行动：过载 |
| Reaction_Water_Wood | 润泽 | 水+木 | 水 | 主控随机获得2单位非水元素 | 行动：润泽（随机2非水元素） |
| Reaction_Wood_Water | 吸纳 | 木+水 | 木 | 从目标处偷取1点以太 | 生以太1 |
| Reaction_Water_Earth | 泥沼 | 水+土 | 水 | 为目标赋予减速2回合 | 减速1（2回合，敌人） |
| Reaction_Earth_Water | 阻截 | 土+水 | 土 | 禁锢目标，若其行动是攻击则推迟到下回合 | 阻截1（1回合，敌人） |
| Reaction_Water_Metal | 淬火 | 水+金 | 水 | 触发该反应的卡牌可以在本回合内再次激活 | 行动：淬火（卡牌可再激活） |
| Reaction_Metal_Water | 涌泉 | 金+水 | 金 | 激活后，立即补充2单位水元素 | 生水2 |
| Reaction_Wood_Earth | 破土 | 木+土 | 木 | 无视目标护盾，直接造成5木元素伤害（真实伤害） | 真实伤害5 |
| Reaction_Earth_Wood | 固本 | 土+木 | 土 | 恢复4点生命值 | 治疗4 |
| Reaction_Wood_Metal | 坚韧 | 木+金 | 木 | 主控获得反震（受击时回敬3伤） | 反震3（2回合，自身） |
| Reaction_Metal_Wood | 伐断 | 金+木 | 金 | 施加流血效果（动作时扣血），持续2回合 | 流血5（2回合，敌人） |
| Reaction_Metal_Earth | 合金 | 金+土 | 金 | 主控获得合金，提供1点减伤，直到本次对局结束 | 合金1（999回合，自身） |
| Reaction_Earth_Metal | 埋藏 | 土+金 | 土 | 下次在车间节点打造装备时，消耗减少2点金元素 | 行动：埋藏（车间折扣+2） |

### 五行阵法卡（1 张）

| ID | 名称 | 稀有度 | 元素 | 描述 | 主槽词条 |
|----|------|--------|------|------|----------|
| Formation_Base | 五行归元阵 | 珍 | 以太 | 消耗所有槽位的激活状态，对敌方造成15点真实伤害，获得10点护盾，全基础元素+3 | 伤害15，护盾10，生金3，生木3，生水3，生火3，生土3 |

---

## 二、敌人数据（18 个，3 世界 × 6）

### World 1 — 五行初现（纯单元素教学）

| 分类 | ID | 名称 | 元素 | HP | DMG | 初始元素 | 意图元素 | 词条 |
|------|-----|------|------|-----|------|----------|----------|------|
| 小怪 | snake_wood | 竹叶青 | 木 | 32 | 8 | — | — | 无（教学怪） |
| 小怪 | fire_spirit | 赤炎灵 | 火 | 35 | 10 | — | — | ON_ATTACK: 灼烧1（2回合，玩家） |
| 小怪 | metal_spider | 砺金蛛 | 金 | 30 | 9 | — | — | TURN_START: 合金1（999回合，自身） |
| 精英 | earth_golem | 厚土傀儡 | 土 | 80 | 12 | — | — | TURN_START: 护盾+5 |
| 精英 | cold_spring | 寒泉之灵 | 水 | 55 | 9 | — | — | TURN_END: 治疗5 / ON_ATTACK: 减速1（2回合，玩家） |
| Boss | tree_boss | 百年树妖 | 木 | 120 | 12 | — | — | TURN_START: 生木+2 / ON_ATTACK: 流血2（2回合，玩家） |

### World 2 — 元素交融（双元素/反应）

| 分类 | ID | 名称 | 元素 | HP | DMG | 初始元素 | 意图元素 | 词条 |
|------|-----|------|------|-----|------|----------|----------|------|
| 小怪 | frost_bat | 霜火蝠 | 水 | 45 | 11 | ["水","火"] | ["火","水"] | ON_ATTACK: 灼烧1（2回合，玩家） |
| 小怪 | golden_vine | 金藤蔓 | 金 | 50 | 10 | ["金","木"] | — | TURN_START: 护盾+8 / ON_DEFEND: 合金1（999，自身） / ON_DEATH: 生金3 |
| 小怪 | mud_turtle | 泥石龟 | 土 | 48 | 9 | — | — | TURN_START: 护盾+8 / TURN_START: 合金1（999，自身） |
| 精英 | magma_beast | 岩浆巨兽 | 火 | 100 | 15 | ["土","火"] | — | TURN_START: 生火+2 / ON_ATTACK: 全体伤害5 / ON_HURT: 灼烧1（1回合，玩家） |
| 精英 | ice_eye | 玄冰之眼 | 水 | 70 | 8 | ["水","金"] | — | TURN_START: 易伤1（1回合，自身） / ON_ATTACK: 减速2（1回合，玩家） |
| Boss | element_aberration | 元素畸变体 | 以太 | 150 | 18 | ["以太","以太"] | ["火","水","木","金","土"] | TURN_START: 生以太2 / ON_ATTACK: 多次伤害8×2 / TURN_END: 治疗10 |

### World 3 — 五行归一（高压/复合词条）

| 分类 | ID | 名称 | 元素 | HP | DMG | 初始元素 | 意图元素 | 词条 |
|------|-----|------|------|-----|------|----------|----------|------|
| 小怪 | oathbreaker | 弃誓护法 | 金 | 60 | 12 | ["金","水"] | — | TURN_START: 护盾+10 / ON_HURT: 合金1（999，自身） / ON_ATTACK: 行动：弹出 |
| 小怪 | wildfire_spirit | 燎原火灵 | 火 | 50 | 14 | ["火","木"] | — | ON_ATTACK: 灼烧2（2回合，玩家），流血1（2回合，玩家） / ON_DEATH: 灼烧3（3回合，玩家） |
| 小怪 | faceless_servant | 无面水侍 | 水 | 55 | 11 | — | ["水","水"] | ON_ATTACK: 减速1（1回合，玩家） / ON_HURT: 缓冲1（1回合，自身） |
| 精英 | immortal_vajra | 不朽金刚 | 金 | 120 | 14 | ["土","金"] | — | TURN_START: 护盾+10，合金2（999，自身） / TURN_END: 治疗8 / ON_DEFEND: 合金3（999，自身） / ON_HURT: 反震3（1回合，自身） |
| 精英 | void_devourer | 虚空噬灵 | 以太 | 80 | 13 | ["以太","以太"] | — | TURN_START: 生以太1 / ON_HURT: 脆化1（1回合，玩家） / TURN_END: 行动：过载 |
| Boss | five_elements_sage | 五行真君 | 以太 | 200 | 20 | ["以太","以太","以太"] | ["火","水","金","木","土"] | TURN_START: 生五行各1，力量2（999，自身），敏捷2（999，自身） / ON_ATTACK: 全体伤害10，灼烧2（2回合，玩家），行动：瓦解 / ON_DEFEND: 护盾20，合金2（999，自身） / TURN_END: 治疗15 / ON_DEATH: 生五行各5 |

---

## 三、架构说明

### 卡牌系统
- **数据驱动**：所有卡牌效果通过 `KeywordSlot` → `compile()` → `KeywordData` → `EffectBase` 管线执行
- **元素反应**：20 张反应卡已统一为 `CardData` + `is_reaction=true`，效果走 KeywordSlot 管线
- **五行阵法**：1 张阵法卡 `is_formation=true`，效果走 KeywordSlot 管线

### 敌人系统
- **词条驱动**：敌人通过 `enemy_keywords: Array[KeywordSlot]` 定义行为，支持 7 种触发时机
- **双向元素**：`element_system` 支持玩家和敌人双向元素附着，敌人可通过 `intent_elements` 对玩家附着元素触发反应
- **双元素队列**：多元素敌人通过 `initial_elements` 数组依次附着，一层消耗后自动出队下一元素

---

## 四、词条系统完整参考

### 4.1 SlotType（14 种卡牌词条类型）

> 定义在 `Data/KeywordSlot.gd` enum `SlotType`

| 编号 | SlotType | 编译 Effect | Phase | 可配置字段 | 描述 |
|------|----------|-------------|-------|-----------|------|
| 0 | 无 | — | — | — | 空槽位，不产生效果 |
| 1 | 伤害 | `DamageEffect` | AGGREGATION | `value` | 造成 N 点伤害 |
| 2 | 护盾 | `ShieldEffect` | AGGREGATION | `value` | 获得 N 点护盾 |
| 3 | 治疗 | `HealEffect` | POST_HIT | `value` | 恢复 N 点生命（上限 max_hp） |
| 4 | 伤害护盾 | `DamageAndShieldEffect` | AGGREGATION | `value`(伤害), `value2`(护盾) | 造成 N 点伤害并获得 M 点护盾 |
| 5 | 施加状态 | `StatusEffect` | POST_HIT | `status_id`, `value`(层数), `duration`, `to_player` | 赋予指定状态 N 层，持续 T 回合 |
| 6 | 生成元素 | `GenerateElementEffect` | POST_HIT | `element_type`, `value`(数量) | 获得 N 单位指定元素（金木水火土以太） |
| 7 | 条件伤害 | `ConditionDamageEffect` | AGGREGATION | `value`(基础), `condition`, `value2`(加成) | 造成 N 点伤害，满足条件时 +M |
| 8 | 行动 | `SpecialActionEffect` | PRE_HIT | `action_id` | 执行特殊行动（过载/破盾/抽牌等） |
| 9 | 多次伤害 | `MultiHitDamageEffect` | AGGREGATION | `value`(伤害), `value2`(次数) | 造成 N 点伤害，重复 M 次 |
| 10 | 全体伤害 | `AOEDamageEffect` | AGGREGATION | `value` | 对所有敌人造成 N 点伤害 |
| 11 | 共鸣 | `ResonanceEffect` | PRE_HIT | `condition` | 其他卡牌激活时本卡视为激活（存根） |
| 12 | 休眠 | `DormantEffect` | PRE_HIT | `value`(延迟回合) | 激活后延迟 N 回合生效（存根） |
| 13 | 无法打出 | —（纯机制） | — | — | 卡牌无法被打出，由 card_slot 检查 `kw_cannot_play` |

### 4.2 TriggerTiming（7 种敌人词条触发时机）

> 定义在 `Data/KeywordSlot.gd` enum `TriggerTiming`

| 枚举值 | 名称 | 触发时机 | 代码位置 |
|--------|------|----------|----------|
| 0 | PASSIVE | 默认值，不自动触发 | — |
| 1 | TURN_START | 回合开始时 | `battle_manager.gd` `end_turn()` 末尾 |
| 2 | TURN_END | 回合结束时 | `battle_manager.gd` `end_turn()` DOT 结算后 |
| 3 | ON_ATTACK | 敌人攻击时 | `battle_manager.gd` `_execute_enemy_intent()` attack 分支 |
| 4 | ON_DEFEND | 敌人防御时 | `battle_manager.gd` `_execute_enemy_intent()` defend 分支 |
| 5 | ON_HURT | 敌人受伤时 | `battle_manager.gd` `take_damage()` HP 扣除后 |
| 6 | ON_DEATH | 敌人死亡时 | `battle_manager.gd` `end_turn()` DOT 击杀处 |

### 4.3 StatusEffect（15 种状态效果）

> 定义在 `Data/KeywordSlot.gd` `@export_enum status_id`

#### DOT 类（回合结束自动结算）

| status_id | 显示名 | 结算位置 | 公式 |
|-----------|--------|----------|------|
| `burn` | 灼烧 | `end_turn()` | 敌人/玩家 HP -= amount（默认 4） |
| `bleed` | 流血 | `end_turn()` | 敌人/玩家 HP -= amount（默认 5） |

#### 伤害修正类（战斗中实时计算）

| status_id | 显示名 | 目标 | 结算位置 | 公式 |
|-----------|--------|------|----------|------|
| `vulnerable` | 易伤 | 敌人 | `take_damage()` | damage × (1.0 + 0.5 × amount)，每层 +50% |
| `weak` | 虚弱 | 敌人 | `_execute_enemy_intent()` attack | dmg × max(0.25, 1.0 - 0.25 × amount)，每层 -25%，最低 25% |
| `frail` | 脆化 | 敌人 | `take_damage()` | damage × 1.5（固定倍率） |
| `strength` | 力量 | 玩家 | `play_card()` AGGREGATION | 总伤害 +amount（固定加成） |
| `vigor` | 活力 | 玩家 | `play_card()` AGGREGATION | 总伤害 +amount（固定加成） |
| `dexterity` | 敏捷 | 玩家 | `play_card()` EXECUTION | 获得护盾 +amount（固定加成） |

#### 防御/减伤类

| status_id | 显示名 | 目标 | 结算位置 | 公式 |
|-----------|--------|------|----------|------|
| `buffer` | 缓冲 | 玩家 | `_damage_player()` | hp_loss = 0（完全抵消一次伤害） |
| `ethereal` | 虚化 | 玩家 | `_damage_player()` | 所有伤害 = 1（本回合） |
| `damage_reduction` | 合金 | 玩家/敌人 | `damage_resolver.damage_player()` | dmg = max(0, dmg - amount）（永久减伤） |
| `reflect` | 反震 | 双向 | `play_card()` EXECUTION / `_execute_enemy_intent()` attack | 受击后反伤 amount（以太属性） |

#### 控制/特殊类

| status_id | 显示名 | 目标 | 结算位置 | 公式 |
|-----------|--------|------|----------|------|
| `slow` | 减速 | 敌人 | `_execute_enemy_intent()` defend | 护盾获得 = 15 × 0.5 = 7 |
| `stun_attack` | 阻截 | 敌人 | `_execute_enemy_intent()` attack | 跳过本次攻击意图（return） |
| `retaliate_generate_fire` | 余烬 | 玩家 | `_damage_player()` | 受击后 element_fire += 1 |

#### 状态同步伤害加成

| status_id | 加成值 | 结算位置 | 公式 |
|-----------|--------|----------|------|
| `burn` | +3 | `play_card()` AGGREGATION | 敌人有灼烧时，玩家总伤害 +3 |
| `bleed` | +2 | `play_card()` AGGREGATION | 敌人有流血时，玩家总伤害 +2 |

> 定义在 `battle_manager.gd`: `const STATUS_DAMAGE_BONUSES = {"burn": 3, "bleed": 2}`

### 4.4 ActionEffect（11 种特殊行动）

> 定义在 `Data/KeywordSlot.gd` `@export_enum action_id`，执行在 `SpecialActionEffect.gd`

| action_id | 显示名 | 效果 | 代码 |
|-----------|--------|------|------|
| `overload` | 过载 | 随机激活一个未激活的副槽卡牌 | `bm.overload_random_sub_slot()` |
| `shield_break` | 破盾 | 破除敌人当前护盾 | `bm.break_shield()` |
| `change_enemy_intent` | 撼地 | 强制将敌人下回合意图改为"防御" | `bm.enemy_intent_override = "defend"` |
| `draw_card` | 抽牌 | 从牌池随机抽卡置入空副槽并激活 | `bm.draw_card_from_pool()` |
| `charge` | 充能 | 随机激活一个卡槽，不进入冷却 | `bm.charge_random_slot()` |
| `eject` | 弹出 | 将该槽位卡牌移回手牌包 | `bm.eject_card_from_slot()` |
| `collapse` | 瓦解 | 激活后冷却直到战斗结束（999 回合） | `bm.collapse_card()` |
| `reactivate` | 淬火 | 本回合内可再次激活该卡牌 | `bm.reactivate_current_card = true` |
| `damage_multiplier` | 翻倍 | 本次伤害 ×2.0 | `dr.damage_multiplier = 2.0` |
| `random_element_2` | 润泽 | 随机获得 2 单位非水元素 | `bm._grant_random_elements(2)` |
| `workshop_discount` | 埋藏 | 下次车间打造消耗 -2 金元素 | `GameManager.workshop_discount_amount += 2` |

### 4.5 Condition（8 种条件伤害触发）

> 定义在 `Data/KeywordSlot.gd` `@export_enum condition`，评估在 `ConditionDamageEffect._check_condition()`

| condition | 显示名 | 检查逻辑 |
|-----------|--------|----------|
| `prev_turn_active` | 上回合激活 | `context.get("prev_turn_active")` |
| `player_has_shield` | 持有护盾 | `context.get("player_has_shield")` 或 `status_manager.has("reflect", "player")` |
| `enemy_has_shield` | 敌人护盾 | `context.get("enemy_has_shield")` |
| `enemy_has_burn` | 敌人灼烧 | `sm.has("burn", "enemy")` |
| `enemy_has_bleed` | 敌人流血 | `sm.has("bleed", "enemy")` |
| `enemy_has_slow` | 敌人减速 | `sm.has("slow", "enemy")` |
| `enemy_has_frail` | 敌人脆化 | `sm.has("frail", "enemy")` |
| `any_card_activated` | 任意激活 | `condition == ""`（始终为 true） |

### 4.6 战斗管道完整流程

#### 玩家攻击流程 (`play_card()`)

```
PRE_HIT (Phase 0)
  └─ DormantEffect, ResonanceEffect, SpecialActionEffect

AGGREGATION (Phase 1)
  └─ DamageEffect, ShieldEffect, HealEffect, DamageAndShieldEffect
     ConditionDamageEffect, MultiHitDamageEffect, AOEDamageEffect
  └─ 动态加成: strength(+flat), vigor(+flat)
     burn 在敌人(+3), bleed 在敌人(+2)

REACTION_CHECK
  └─ element_system.attach(card_element, layers)

EXECUTION
  └─ 护盾: player_shield += total_shield
     (dexterity 加成)
  └─ 伤害: get_final_damage() → take_damage()
     (equip_bonus → frail ×1.5 → vulnerable ×(1+0.5×amount)
      → damage_after_shield → enemy_hp - hp_loss)
  └─ 真实伤害: enemy_hp -= true_damage
  └─ 反震: 敌人 reflect → _damage_player(reflect_amount)

POST_HIT (Phase 2)
  └─ StatusEffect, GenerateElementEffect, HealEffect
```

#### 敌人回合流程 (`end_turn()`)

```
TURN_START 敌人词条执行
  └─ _execute_enemy_slots(TriggerTiming.TURN_START)

玩家护盾清空: player_shield = 0

敌人 DOT 结算
  └─ burn(amount|4), bleed(amount|5) → enemy_hp

TURN_END 敌人词条执行
  └─ _execute_enemy_slots(TriggerTiming.TURN_END)

玩家 DOT 结算
  └─ burn(amount|4), bleed(amount|5) → player_hp

敌人意图执行
  ├─ attack:
  │   ├─ stun_attack? → 跳过
  │   ├─ weak: dmg = dmg × max(0.25, 1-0.25×amount)
  │   ├─ intent_elements → element_system.attach("player")
  │   ├─ _damage_player(dmg)
  │   │   ├─ equip_reduction, equip_vulnerability
  │   │   ├─ ethereal: dmg=1
  │   │   ├─ buffer: hp_loss=0
  │   │   ├─ damage_reduction: dmg = max(0, dmg-amount)
  │   │   ├─ shield → hp_loss
  │   │   └─ retaliate_generate_fire: fire += 1
  │   ├─ ON_ATTACK 敌人词条
  │   └─ 玩家 reflect → take_damage on enemy
  ├─ defend:
  │   ├─ slow: shield = 7 (else 15)
  │   └─ ON_DEFEND 敌人词条
  └─ buff:
       └─ enemy_atk_buff += 3

DECAY: 所有 status duration - 1（≤0 则移除）
```

### 4.7 伤害计算完整公式

**玩家 → 敌人 (`take_damage(amount, element)`)**:
```
actual_dmg = amount + equip_damage_bonus()
if enemy has frail:    actual_dmg = floor(actual_dmg × 1.5)
if enemy has vulnerable: actual_dmg = floor(actual_dmg × (1.0 + 0.5 × vuln_amount))
result = damage_after_shield(actual_dmg, enemy_shield)
  → hp_loss = max(0, actual_dmg - enemy_shield)
  → shield_remaining = max(0, enemy_shield - actual_dmg)
enemy_hp -= hp_loss
→ ON_HURT 敌人词条
```

**敌人 → 玩家 (`_damage_player(amount, element)`)**:
```
modified = amount - equip_damage_reduction + equip_element_vulnerability
modified = max(1, modified)
if player has ethereal: modified = 1
result = damage_player(modified, player_shield, player_damage_reduction)
  → dmg = max(0, modified - player_damage_reduction)
  → hp_loss = max(0, dmg - player_shield)
  → shield_remaining = max(0, player_shield - dmg)
if player has buffer: hp_loss = 0
player_hp -= hp_loss
if player has retaliate_generate_fire: fire += 1
```

### 4.8 卡牌类型词条

#### CardData 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `element` | enum(金/木/水/火/土/以太) | 卡牌五行属性，决定元素附着 |
| `element_attachment_layers` | int | 元素附着层数（默认 1） |
| `rarity` | enum(凡/稀/珍) | 卡牌稀有度（当前全为"凡"，阵法为"珍"） |
| `is_formation` | bool | 五行阵法标记 |
| `is_reaction` | bool | 元素反应标记 |
| `is_carry` | bool | 携带：在 deck 中即生效（未实现） |
| `is_embed` | bool | 嵌入：在副槽即生效（未实现） |
| `is_initiate` | bool | 初动：在主槽即生效（未实现） |
| `is_exhaust` | bool | 消耗：打出后从牌组永久移除 |
| `single_use` | bool | 一次性：本场战斗仅可使用一次 |

#### 元素消耗

| 字段 | 类型 | 说明 |
|------|------|------|
| `cost_metal` / `cost_wood` / `cost_water` / `cost_fire` / `cost_earth` / `cost_aether` | int | 打出卡牌所需的各元素消耗量 |

### 4.9 KeywordSlot 字段速查

| 字段 | 类型 | 适用 SlotType | 说明 |
|------|------|-------------|------|
| `type` | SlotType enum | 全部 | 词条类型 |
| `value` | int | 伤害/护盾/治疗/生成元素/条件伤害/多次伤害/全体伤害/施加状态/休眠 | 主数值（伤害量、护盾量、治疗量、元素量、状态层数等） |
| `value2` | int | 伤害护盾/条件伤害/多次伤害 | 辅助数值（护盾量、条件加成、攻击次数） |
| `element_type` | enum(金木水火土以太) | 生成元素 | 生成哪种元素 |
| `status_id` | enum(15 种) | 施加状态 | 施加哪种状态 |
| `duration` | int | 施加状态 | 状态持续回合数 |
| `to_player` | bool | 施加状态 | true=作用于玩家，false=作用于敌人 |
| `condition` | enum(8 种) | 条件伤害/共鸣 | 触发条件字符串 |
| `action_id` | enum(11 种) | 行动 | 特殊行动 ID |
| `trigger_timing` | TriggerTiming enum | 全部（敌人用） | 敌人词条触发时机 |
| `display_name_override` | String | 全部（可选） | 覆盖自动生成的显示名 |
| `description_override` | String | 全部（可选） | 覆盖自动生成的描述 |

### 4.10 Effect 管线架构

```
KeywordSlot (Inspector 编辑)
  └─ compile() → KeywordData
       └─ .keyword_id: "kw_<type>_<params>"
       └─ .display_name: 自动生成或覆盖
       └─ .description: 自动生成或覆盖
       └─ .category: ACTION / STATUS / MECHANIC
       └─ .effect: EffectBase 子类实例

CardData
  └─ main_slots: Array[KeywordSlot] → main_keywords: Array[KeywordData]
  └─ sub_slots: Array[KeywordSlot] → sub_keywords: Array[KeywordData]
  └─ mechanic_slots: Array[KeywordSlot] → mechanic_keywords: Array[KeywordData]
  └─ compile_slots() 一次性编译

EnemyData
  └─ enemy_keywords: Array[KeywordSlot]
  └─ compile_keywords() → compiled_keywords: Array[KeywordData]
  └─ _execute_enemy_slots(timing) 按 TriggerTiming 触发执行
```
