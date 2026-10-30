# 原版图标 / Original icons

本目录的 16×16 菜单与工具栏 BMP 来自 Orwell Dev-C++ 5.11 的
`Source/DataFrm.dfm` 内嵌 `MenuImages_NewLook`，以 Windows 程序实际使用的图标为准。
原版 `Source/Images/newlook/` 中同名文件可能不同。来源提交为
`0e4d598b172efd7df97b7ecc941d6aa08340cd70`，遵循原项目 GPL-2.0-or-later 许可。
可在仓库根目录执行 `python3 tools/import-upstream-icons.py /path/to/orwell`
重现提取。`tools/upstream-icon-manifest.json` 记录原始图标列表及各文件的 SHA-256。
保留可见像素的 RGB；原版独立遮罩中的透明像素转为洋红色，加载时显式用该颜色作遮罩。

The 16×16 menu and toolbar BMPs come from the embedded `MenuImages_NewLook`
in Orwell Dev-C++ 5.11's `Source/DataFrm.dfm`, matching the icons actually used
by the Windows application. Standalone files under `Source/Images/newlook/`
can differ. Reference commit: `0e4d598b172efd7df97b7ecc941d6aa08340cd70`;
the original GPL-2.0-or-later license applies. Reproduce extraction from the
repository root with `python3 tools/import-upstream-icons.py /path/to/orwell`.
`tools/upstream-icon-manifest.json` records the source image-list and output
SHA-256 hashes. Visible RGB pixels are retained; transparent pixels from the
original separate mask become fuchsia and are explicitly masked when loaded.

`about-banner.bmp`、`about-donate.bmp`、`about-authors.bmp` 另外直接提取自同一提交的 `Source/AboutFrm.dfm`，不改变原始 BMP 字节。提取脚本为 `tools/import-upstream-about.py`，同样保留原项目 GPL 许可。

`about-banner.bmp`, `about-donate.bmp` and `about-authors.bmp` are extracted separately from `Source/AboutFrm.dfm` at the same commit, retaining the original BMP bytes. See `tools/import-upstream-about.py`; the original GPL license applies.

`browser-0.bmp` 至 `browser-11.bmp` 提取自同一 Windows 5.11 提交的 `Source/DataFrm.dfm:ClassImages`，保持可见 RGB 和原版透明遮罩。调试监视图标使用已提取的 `search.bmp`（原版菜单图像 21）。提取脚本及校验清单分别为 `tools/import-upstream-sidebar.py`、`tools/upstream-sidebar-manifest.json`。

`browser-0.bmp` through `browser-11.bmp` come from `Source/DataFrm.dfm:ClassImages` at the same Windows 5.11 commit, preserving visible RGB and the original transparency mask. Watch rows reuse `search.bmp` (original menu image 21). Reproduction and hashes: `tools/import-upstream-sidebar.py`, `tools/upstream-sidebar-manifest.json`.
