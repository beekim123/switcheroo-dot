# 掉包记（暂定名）

> 一个能力，越用越多用法。

回合制斗智对戏，2D 像素风，用 Godot 4 制作。换月夜，阿鸣心里的戏灵「杯戏师」第一次走出来，一出手就把最好的朋友麦朵和北方遗迹里的一尊石像对调了。阿鸣带着这个只会"交换"的小戏法师上路：在每座小镇的戏台上，看懂对手戏灵的怪规则，用一次巧妙的交换把它反过来，最后把麦朵换回来。

当前阶段：**核心玩法 demo**（第一到第三出，「换位」「换物」两个形态，40–55 分钟）。

## 当前状态

D0 地基已验收并发布；D1 已实现从标题到第三出结尾的**五站位交换灰盒**：换位 / 换物、公开意图与预览、两条对手规则及识破反转、6 个排练、2 场路遇、3 处查访、升级印记、三选一信件和独立存档。不是卡牌游戏，也没有地图移动。

自动检查、13 组原生截图、完整原生手动 QA 与输入回归已通过，**D1 灰盒里程碑已由主审接受**。此次熟练 QA 墙钟 20 分 10 秒（含修复停顿），不是人类初见玩家时长。正式像素人物 / 插画 / 演出与完整音乐属于 D2，macOS 导出属于 D3。40–55 分钟是目标体验，不是自动测试测得的时长。

查看 [D1 检查记录](artifacts/reports/d1-acceptance.md)、[三策略报告](artifacts/reports/sim-d1.json)、[全流程回调测试](artifacts/reports/flow-d1.json)。[D0 标题图](artifacts/screenshots/d0-title-3x.png)为原生 640×360 视口的精确最近邻 3× 展示；当前实际入口已切换到 D1。

## 目录

| 目录 | 职责 |
|---|---|
| [`docs/`](docs/README.md) | 设计文档、计划、进度 |
| `resources/art/` | 美术制作源（代码绘制的像素图）与导出的 PNG |
| `resources/audio/` | 声音制作源（代码合成）与导出的 WAV |
| `content/` | 游戏内容数据（对戏、排练、查访、剧情、台词） |
| `godot/` | Godot 工程（游戏源码）；其中 `resources/`、`data/` 是自动同步副本 |
| `tools/`、`tests/` | 构建、校验、同步工具与测试 |
| `third_party/fonts/` | OFL 字体及许可证 |
| `artifacts/screenshots/` | 已检查的截图 |

详细规则见 [docs/tech/repository-layout.md](docs/tech/repository-layout.md)。

## 运行与验证

需要 Node.js 22.13+ 和 Godot 4.7.2。

```sh
# 先将 GODOT_BIN 指向本机 Godot 4.7.2 可执行文件
npm ci
npm run sync
npm run godot:import
npm run check
npm run dev
```

资源导出已提交，正常运行不需要先重建美术/声音，也不需要网络。要重建：

```sh
npm run art:build && npm run art:verify && npm run art:sheet
npm run audio:build && npm run audio:check
npm run sync && npm run godot:import
npm run check
```

`npm run shots` 需要原生图形桌面，使用 Dummy 驱动和 1280×720 窗口，导出标题、戏单、查访、排练、对戏、预览、识破、反转、信、铺子、结尾共 13 组 `artifacts/screenshots/d1-*-1x.png` 及精确最近邻 3× 展示图。不会写入玩家存档。无界面测试不需要桌面。CLI 严格检查 Godot 4.7.2，避免误用 PATH 中其他版本。

工具启动的 Godot 使用项目专属 HOME/XDG：`.local/play/`（正常游戏）、`.local/qa/`（测试）、`.local/shots/`（截图），以及 `switcheroo-dot` 存档名，不与其他游戏或测试共享存档。应用遇到 Dummy 音频驱动时只验证并加载音频，不假装能听到声音；正常音频后端第一次点击后启声。当前云端没有可听音频设备，因此听感与 macOS 真机运行尚未验证。

字体来自 Fusion Pixel 官方发行版，以 OFL 许可保留当前项目字形子集；全部许可、来源及重建说明见 `third_party/fonts/fusion-pixel-12px/`。

## 灰盒操作

- 点击两个站位 → 看虚影和伤害预览 → 确认；右键 / Esc 取消。
- 出手只打相邻站位；架势守护；每回合最多一次主行动和一次交换，顺序随意。
- 第三出可在换位 / 换物之间切换；两种共用交换次数。
- 键盘 A 出手、G 架势、I 弹珠、E 结束、Tab 形态、左右 / 回车选站位、Esc 暂停。
- 查访可提前离开；排练可无限重试且奖励不可刷；路遇可绕开；战败可开援助重来，已填规则空格保留。
- 开发版 F1 打开调试入口；`--act=3 --step=duel` 可直接检查第三出，`--fill=all` 填水牌。调试入口不是正式玩法流程。
