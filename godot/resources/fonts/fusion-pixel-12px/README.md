# 字体来源与许可

源自 [Fusion Pixel Font 2026.10.25 官方发行版](https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.10.25) 的简体中文 12px 等宽 TTF。没有读取其他游戏项目。

上游完整字体约 7.2 MB，超过仓库单文件 2 MB 上限，因此使用 `tools/resources/subset-font.py` 保留当前项目文案与 ASCII 字符，字形不修改，派生字体更名为 **Switcheroo Pixel 12**。内容扩充时应重建子集，避免缺字。

`OFL.txt` 和 `LICENSES/` 包含发行包的全部许可及版权通知；派生字体仍使用 OFL-1.1。`provenance.json` 记录源版本、原件哈希、修改范围和导出哈希。游戏与同步副本须一起分发这些文件。

正常 `npm ci` / 构建无需联网或 Python；只有维护字体子集时需要 Python fontTools 和许可源字体。
