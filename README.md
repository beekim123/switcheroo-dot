# 掉包记（暂定名）

> 一个能力，越用越多用法。

回合制斗智对戏，2D 像素风，用 Godot 4 制作。换月夜，阿鸣心里的戏灵「杯戏师」第一次走出来，一出手就把最好的朋友麦朵和北方遗迹里的一尊石像对调了。阿鸣带着这个只会"交换"的小戏法师上路：在每座小镇的戏台上，看懂对手戏灵的怪规则，用一次巧妙的交换把它反过来，最后把麦朵换回来。

当前阶段：**核心玩法 demo**（第一到第三出，「换位」「换物」两个形态，40–55 分钟）。

## 当前状态

D0 地基已实现：原创代码像素戏台与杯戏师、4 个确定性合成声音、内容检查与单向同步、Godot 标题、无界面测试。**当前不是可战斗试玩版**；三出故事、对戏、排练与自动策略属于 D1。

已检查的[标题画面](artifacts/screenshots/d0-title-3x.png)是原生 640×360 视口的精确 3 倍最近邻展示，不是 1920×1080 实际桌面截图。验证范围与限制见 [D0 验收记录](artifacts/reports/d0-acceptance.md)。开发规则见 [AGENTS.md](AGENTS.md)。

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

`npm run shots` 需要原生图形桌面，导出 `artifacts/screenshots/d0-title-1x.png` 和精确最近邻 3× 展示图。无界面测试不需要桌面。CLI 严格检查 Godot 4.7.2，避免误用 PATH 中其他版本。

工具启动的 Godot 使用项目专属 `.local/` 下的 HOME/XDG 目录及 `switcheroo-dot` 存档名，不与其他游戏共享存档。应用遇到 Dummy 音频驱动时只验证并加载音频，不假装能听到声音；正常音频后端第一次点击后启声。当前云端没有可听音频设备，因此听感与 macOS 真机运行尚未验证。

字体来自 Fusion Pixel 官方发行版，以 OFL 许可保留当前项目字形子集；全部许可、来源及重建说明见 `third_party/fonts/fusion-pixel-12px/`。
