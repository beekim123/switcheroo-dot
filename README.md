# 掉包记（暂定名）

> 一个能力，越用越多用法。

回合制斗智对戏，2D 像素风，用 Godot 4 制作。换月夜，阿鸣心里的戏灵「杯戏师」第一次走出来，一出手就把最好的朋友麦朵和北方遗迹里的一尊石像对调了。阿鸣带着这个只会"交换"的小戏法师上路：在每座小镇的戏台上，看懂对手戏灵的怪规则，用一次巧妙的交换把它反过来，最后把麦朵换回来。

当前阶段：**核心玩法 demo**（第一到第三出，「换位」「换物」两个形态，40–55 分钟）。

## 当前状态

尚未开工，只有设计文档。从 [docs/README.md](docs/README.md) 开始读；开发规则见 [AGENTS.md](AGENTS.md)。

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

## 运行（开发开始后补全）

需要 Node.js 22.13+ 和 Godot 4.7.2。

```sh
npm ci
npm run sync
npm run dev
```
