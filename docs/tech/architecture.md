# 技术架构

目录与模块边界见 [repository-layout.md](repository-layout.md)。本文的【定】：

- 引擎 **Godot 4.7.x（与 rpg2d-dot 相同的 4.7.2）+ GDScript**，渲染器 Compatibility。
- **规则与表现分离**，规则是确定性的（同一布置 + 同一串指令 = 同一结果）。
- 美术、声音、内容各走自己的管线，Godot 只读同步副本。
- 有**自动试玩**，证明"不识破也能赢"；有**排练求解器**，证明每个排练都有解。
- 运行时不访问网络。

## 1 工具链

| 项 | 选择 |
|---|---|
| 游戏 | Godot 4.7.2，GDScript（静态类型标注尽量写全） |
| 资源工具 | Node.js 22.13+，`.mjs` 与 `node --experimental-strip-types` 运行的 `.ts` |
| Godot 位置 | 环境变量 `GODOT_BIN`，或仓库根目录的本机 `Godot.app`（不提交），或 PATH |
| 测试 | Godot 无界面运行自写测试框架；Node 端 `node --test` |

### npm 脚本【建议】

| 命令 | 作用 |
|---|---|
| `npm run art:build` / `art:verify` / `art:sheet` | 美术构建、校验、对照表 |
| `npm run audio:build` / `audio:check` | 声音导出与检查 |
| `npm run content:check` | 内容引用、空格来源完整、美术/声音 id 存在 |
| `npm run sync` / `sync:verify` | 同步资源和内容进 `godot/`；只读校验 |
| `npm run dev` | 打开游戏（调试版） |
| `npm run godot:test` | 无界面跑规则测试、回放测试、排练求解 |
| `npm run sim` | 对戏自动试玩，输出报告 |
| `npm run shots` | 按脚本走一遍主要画面截图到 `artifacts/screenshots/` |
| `npm run check` | art:verify、audio:check、content:check、sync:verify、godot:test、sim（快速档） |

## 2 Godot 工程设置【建议】

- 视口 640×360；拉伸模式 `viewport`，比例 `keep`，缩放 `integer`。
- 默认纹理过滤 `Nearest`；2D 变换和顶点吸附像素。
- 字体关闭抗锯齿、hinting、亚像素定位。

## 3 模块

```text
godot/scripts/
├─ core/                      纯规则（RefCounted，不碰 Node、资源）
│  ├─ stage_state.gd          5 个站位、东西（生命、守护、属性、持有物、主人、标记）、亮暗计算
│  ├─ duel_rules.gd           start / main_action / swap / preview / end_turn / legal_actions → 事件列表
│  ├─ swap.gd                 换位、换物的合法性与执行（距离、重、隐身、持有物）
│  ├─ intents.gd              意图循环、目标站位锁定、按编号结算、"打到自己"
│  ├─ rules/                  每个对手的规则钩子：rule_thief.gd、rule_ferryman.gd、prologue.gd
│  ├─ signboard.gd            水牌：空格、来源（台上触发 / 词签）、识破判定、反转判定
│  ├─ rehearsal.gd            排练：布置、环境意图、目标判定
│  ├─ solver.gd               排练求解器（穷举所有交换与主行动组合）
│  ├─ journey_state.gd        进度：当前出与步骤、词签、领悟、升级、印记、信的选择、援助开关
│  └─ bots.gd                 对戏自动试玩策略
├─ content/                   读取 godot/data/*.json，校验并构造规则对象
├─ view/                      戏台、站位、东西、意图箭头与靶标、水牌、观众、底部操作栏；EventPlayer 逐条播放
├─ story/                     StoryPlayer（插画页、信、梦）、BanterDirector（台词、观众反应）、CurtainDirector（开幕、谢幕、识破演出）
├─ services/                  AssetCatalog、AudioService、SaveService
└─ debug/
```

### 3.1 规则接口【建议】

```gdscript
var r := DuelRules.start(duel_def, journey_state)                 # -> {state, events}；词签填进水牌也在这里产生事件
var ev := DuelRules.main_action(state, "strike", target_slot)     # 出手 / 架势 / 道具
var ok := Swap.can(state, "position", slot_a, slot_b)             # -> {ok, reason}
var pv := DuelRules.preview_swap(state, "position", slot_a, slot_b) # -> {ghost_positions, threats_per_slot, reversal}
var ev := DuelRules.swap(state, "position", slot_a, slot_b)
var ev := DuelRules.end_turn(state)                               # 对手回合 + 新意图
var acts := DuelRules.legal_actions(state)                        # 机器人和界面共用
```

事件示例：`{type="swap", mode="position", a=2, b=4}`、`{type="intent_resolve", actor="rival.thief", n=1, kind="touch", slot=2}`、`{type="damage", target=3, amount=4, blocked_by=2}`、`{type="self_hit", actor=3}`、`{type="blank_filled", blank="touch", source="stage"}`、`{type="exposed"}`、`{type="reversal", id="reversal.return_owner"}`、`{type="audience", reaction="laugh"}`、`{type="victory"}`。

**界面上的威胁数字、预览、可选目标全部从规则层读，表现层不自己算。**

### 3.2 对手规则写成代码钩子

每个对手的规则都是独特的，用 `core/rules/` 里的小脚本实现，挂在固定的钩子上：

| 钩子 | 用途 |
|---|---|
| `on_intent(state, intent)` | 规则动作（摸、吹灭）的结算 |
| `redirect_damage(state, target, amount)` | 挡打（阿扒）之类的伤害改向 |
| `is_hidden(state, entity)` | 隐身（老乔） |
| `on_turn_end(state)` | 回合结束时的检查（婆婆喊话等） |
| `check_reversal(state, swap)` | 这次交换是不是反转，返回基础效果或反转效果 |

水牌的空格、触发条件、词签映射写在数据里（`content/data/duels.json`），钩子只负责发出"规则生效了"的事件，由 `signboard.gd` 决定填哪个空。

## 4 数据格式【建议】

```json
{
  "id": "duel.thief",
  "rival": "rival.thief",
  "hp": 16,
  "layout": ["char.aming", "prop.apple_basket", "rival.thief", "prop.wok", "prop.stall"],
  "intent_cycle": [
    { "kind": "touch", "target": "adjacent_unmarked_prop", "fallback": { "kind": "hit", "n": 4, "target": "aming_slot" } },
    { "kind": "hit", "n": 4, "target": "aming_slot" },
    { "kind": "move", "target": "farthest_from_aming_not_heavy" },
    { "kind": "hit", "n": 4, "target": "aming_slot" }
  ],
  "rule": "rule_thief",
  "signboard": {
    "text": "被他{touch}过的东西会忘记{owner}，替他{block}。",
    "blanks": {
      "touch": { "word": "摸",   "stage": "first_touch",       "clue": "clue.market.cloth" },
      "owner": { "word": "主人", "stage": "granny_shout_t2",   "clue": "clue.market.granny" },
      "block": { "word": "挡打", "stage": "first_block",       "clue": null }
    }
  },
  "reward_mark": "mark.missing"
}
```

`content:check` 要检查：每个水牌至少有一个 `clue: null` 的空格（只能台上看到）；每个 `clue` 都在对应的查访里能拿到；每个美术 id 存在。

## 5 存档

- `user://save.json`，带 `version`；内容是 `journey_state` + 设置。
- 自动存档点见 [02-rules.md](../design/02-rules.md) 第 12 节；对戏中途退出从这场开头重来，已填的空格保留。
- 读取失败：坏文件改名备份，回到标题，不崩溃。

## 6 测试与验证

| 层 | 内容 | 命令 |
|---|---|---|
| 规则单元测试 | 换位/换物合法性、意图锁定站位、打到自己、挡打、隐身与亮暗、空格填写、识破、反转只触发一次、[02-rules.md](../design/02-rules.md) 第 13 节的每条边界情况 | `npm run godot:test` |
| 回放测试 | 固定指令序列 → 期望的最终状态哈希 | 同上 |
| 排练求解 | `solver.gd` 穷举每个排练，断言至少有 1 个解，并记录解的数量 | 同上 |
| 对戏自动试玩 | 见下 | `npm run sim` |
| 内容检查 | 见第 4 节 | `npm run content:check` |
| 资源校验 | 美术逐字节、调色板；声音确定性、响度 | `art:verify`、`audio:check` |
| 画面 | 截图走查：标题、戏单、查访、排练、对戏（含预览、识破、反转）、谢幕、写信、葛伦铺子 | `npm run shots` |

### 自动试玩策略与报告

| 策略 | 怎么玩 | 用来证明 |
|---|---|---|
| 稳妥 | 只用出手、架势、道具，交换只用来躲开攻击 | **不识破也能赢**：三场对戏胜率 100%（可以用到糖葫芦） |
| 一步前瞻 | 枚举本回合所有"主行动 × 交换"组合，模拟到对手回合结束，选结果最好的 | 正常玩的回合数、识破率、反转率 |
| 不交换 | 完全不用交换 | 交换是否真的有用：这个策略应明显更慢或会输 |

报告包含：每场对戏各策略的胜率、平均回合数、阿鸣剩余生命；一步前瞻策略在第几回合识破、识破后多少回合内发动反转；每个空格平均在第几回合被填上（检查"挡打"之类的空格会不会一直填不上）。

目标区间写在 [plan/playtest.md](../plan/playtest.md)。

## 7 调试版

- 命令行参数：`--act=3`、`--step=duel`、`--fill=all`（直接填满水牌）、`--shots`。
- F1 调试面板，F2 台词立即显示。
- 发布版不加载 `scripts/debug/`。
