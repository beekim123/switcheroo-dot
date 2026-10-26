# 任务池

开发者持续维护：做完打勾，太大的任务拆小，新发现的问题加进来。用户的试玩意见放在最前面，标为最高优先级。

## 用户反馈（最高优先级）

（暂无）

## D0 · 地基

- [ ] 目录骨架、`.gitignore`、`README.md` 补运行方式
- [ ] `package.json` 脚本
- [ ] 拷贝 Fusion Pixel 12px 字体和全部许可证到 `third_party/fonts/`
- [ ] `resources/art/palette.json`（47 色）+ 换色表 `dream` / `dark_slot` / `ghost`
- [ ] `resources/art/lib/png.mjs`、`pixel.mjs`
- [ ] `tools/resources/art.mjs`：build / verify / sheet
- [ ] 素材：`char.cupper` 待机（字符画）、`stage.frame`（程序）
- [ ] `resources/audio/synth.ts`（含锣、钹、板的音色）+ `audio-pack.ts` + `audio:check`
- [ ] 音效 `sfx.cup_down`、`sfx.cup_up`、一声锣；8 秒测试旋律
- [ ] `content/registry.json`、最小 `duels.json`、`tools/qa/content-check`
- [ ] `tools/resources/sync-godot.mjs`（含 `--verify`）
- [ ] Godot 工程设置、AssetCatalog、AudioService、SaveService 空壳
- [ ] 标题画面
- [ ] 无界面测试框架 + `tools/godot/cli.mjs`
- [ ] D0 验收

## D1 · 规则可玩

- [ ] 内容数据：duels、props、foes、items、rehearsals、roads、investigations、upgrades、marks、acts
- [ ] `stage_state.gd`：站位、属性、持有物、主人、标记、亮暗
- [ ] `swap.gd`：换位（距离、重、隐身、空站位）、换物（持有物、看得见）
- [ ] `intents.gd`：循环、目标锁定站位、编号结算、打到自己、移动失败
- [ ] `duel_rules.gd`：回合顺序、主行动（出手/架势/道具）、胜负、preview_swap（威胁重算、反转标签）
- [ ] `signboard.gd`：空格、台上触发、词签预填、识破、反转只一次
- [ ] `rules/prologue.gd`（失控杯戏师的交换意图、第 2 回合解锁换位）
- [ ] `rules/rule_thief.gd`（摸、挡打、婆婆喊话、物归原主）
- [ ] `rules/rule_ferryman.gd`（吹灭、隐身、撑篙现身、光还回去）
- [ ] 戏台界面（灰盒）：站位、意图箭头与靶标、选择与预览、底部操作栏、水牌
- [ ] 战败与援助（提示、让一让）
- [ ] 排练 ×6 + 排练界面 + `solver.gd`
- [ ] 路遇 ×2 + 岔路牌
- [ ] 查访 ×3（灰盒）+ 词签 + 手账
- [ ] 葛伦的铺子：领悟升级、印记
- [ ] 插画页、信（三选一）、梦的纯文字版
- [ ] 存档与读档、损坏保护
- [ ] 规则单元测试 + 边界情况测试 + 回放测试
- [ ] `bots.gd` 三种策略 + `npm run sim` 报告
- [ ] D1 验收（含自己完整玩一遍）

## D2 · 叙事与表现

- [ ] StoryPlayer（图层、小循环、平移、翻页、跳过、信纸版式、梦换色）
- [ ] 全部插画页素材与 `pages.json`
- [ ] CurtainDirector：开幕、谢幕、识破、两种反转演出
- [ ] BanterDirector + `banter.json`（台词、杯戏师表情、观众反应、冷却）
- [ ] 写信与纸鹤演出
- [ ] 戏台彩蛋（幕布绳、脚灯、提词小窗、双月、台下熟人）
- [ ] 正式美术：戏台框架与幕布、3 块布景、3 幅查访布景、阿鸣、杯戏师、葛伦、对手与戏灵、小怪、物件、意图图标、水牌、观众、界面、插画
- [ ] 音乐 ×8、短乐句 ×9、音效全表、说话音
- [ ] 设置菜单
- [ ] `npm run shots` 截图脚本
- [ ] D2 验收

## D3 · 试玩版

- [ ] 按自动试玩和自玩调数值与空格触发时机
- [ ] 阻断性问题清零
- [ ] macOS 导出（Web 可选）
- [ ] 试玩说明 + 问卷
- [ ] D3 验收，打标签 `demo-1`
