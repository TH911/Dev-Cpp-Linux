# 关于与经典控件 / About and classic controls

## 中文

v1.4.0 合入此前本地 beta7–beta9 的改进；正式版先完成本地构建、回归与安装验证，再发布源码、安装包及版本标签。

“关于 Dev-C++”按原版 `AboutFrm.dfm` / `AboutFrm.pas` 补全：保留 Bloodshed Software 版权、原版横幅、GPL 第 2 版完整文本、作者名单、捐赠入口、编译器网站、论坛、邮件列表及历史网站；另列出原版语言资源中的两个历史联系邮箱。原始信息来自 Orwell Dev-C++ 5.11 的提交 `0e4d598b172efd7df97b7ecc941d6aa08340cd70`。资源和文本可用 `tools/import-upstream-about.py` 重现提取，校验和记录在 `tools/upstream-about-manifest.json`。

界面区分 `<= 4.9.9.2` 的 Bloodshed 版、`> 4.9.9.2` 的 Orwell 版（5.11）与当前 Linux 版，并加入 `https://github.com/TH911/Dev-Cpp-Linux`。所列 `2015-04-27 22:11` 是用户提供的 Windows 5.11 参考构建信息，不是当前 Linux 程序的构建时间。历史地址按原版保留，不以当前 Linux 版名义替换收款人或联系人。“构建与安装信息”仍可查看实际程序路径、配置、FPC/GTK2 平台和启动计时，并用 Ctrl+A/C 复制。

侧栏标签按文字自然宽度绘制，选中标签与白色页面衔接；右侧是相邻的 18×18 小三角箭头，不再显示文本 `<`、`>`。滚动标签不会启动调试；选择“调试”时才创建面板。标签支持鼠标和方向键。GTK 勾选框、菜单勾选及列表勾选只改变绘制，仍使用原生状态和输入事件；勾选框的焦点提示保留。关于窗口的确定按钮采用绿色对勾，避免 Linux 主题将确认图标替换成回车箭头。

## English

Version 1.4.0 incorporates the previous local beta7–beta9 improvements. Stable source, packages and tags are published after local build, regression and installation checks.

About restores the original `AboutFrm.dfm` / `AboutFrm.pas` information: Bloodshed Software copyright, banner, full GPL version 2 text, complete authors, donation link, compiler sites, forum, mailing list and historical websites, plus the two contact addresses retained in the original language resources. The immutable Orwell Dev-C++ 5.11 reference is commit `0e4d598b172efd7df97b7ecc941d6aa08340cd70`. Extraction is reproducible with `tools/import-upstream-about.py`; hashes are recorded in `tools/upstream-about-manifest.json`.

The interface distinguishes Bloodshed `<= 4.9.9.2`, Orwell `> 4.9.9.2` (5.11), and the current Linux port, adding `https://github.com/TH911/Dev-Cpp-Linux`. `2015-04-27 22:11` is the Windows 5.11 reference build supplied by the user, not the current Linux build time. Historical addresses and donation recipients are retained as original information. Build and installation still shows real executable/configuration paths, FPC/GTK2 platform and startup timings, selectable with Ctrl+A/C.

Sidebar tabs use natural text widths and a selected tab adjoining the white page, with adjacent 18×18 triangle arrow buttons instead of `<`/`>` text. Scrolling does not start debugging; selecting Debug creates its panel. Mouse and arrow-key navigation are supported. GTK checkbox/menu/list checks retain native state and input handling, with only painting changed; checkbox focus cues remain. About uses a green confirmation tick so a Linux theme cannot replace it with a Return-arrow icon.

## beta8 侧栏 / beta8 sidebar

按 Windows 5.11 的 `main.dfm`、`Debugger.pas`、`ClassBrowser.pas` 对齐侧栏：标签按 GTK2 实际字体和边框测量高度，狭窄侧栏保留相邻双箭头，部分露出的标签不会被误判为已完整显示。“查看类”使用原版 `ClassImages` 的 12 个图标、方框加减号、加粗名称、栗色参数/数组维数及灰色类型，按类型、函数、变量排序，不增加“globals”分组。当前缓冲区的声明索引包含结构体成员、函数与全局/命名空间变量；它是词法索引，不能代替 Windows 原版完整的 C++ 头文件语义分析器。

“调试”是平铺监视行，沿用原版 `MenuImages_NewLook[21]` 图标（`search.bmp`），未求值时显示红色 `Execute to evaluate`。空列表不显示分组标题，单步后监视表达式重新求值；双击条目仍可进入表达式输入。断点继续通过源码边栏与调试命令管理。原始类浏览器图标可用 `tools/import-upstream-sidebar.py` 重现，哈希在 `tools/upstream-sidebar-manifest.json`。

The sidebar follows Windows 5.11 `main.dfm`, `Debugger.pas` and `ClassBrowser.pas`. Header height uses actual GTK2 font/frame metrics; the narrow sidebar retains paired arrows and partly visible tabs do not stop scrolling. Classes uses the twelve original `ClassImages` icons, boxed plus/minus expanders, bold names, maroon arguments/array dimensions and gray types, ordered by types, functions and variables without an added globals group. The current-buffer declaration index includes structure members, functions and global/namespace variables. It is a lexical index, not a replacement for the original Windows full C++ header semantic parser.

Debug uses flat watch rows and the original `MenuImages_NewLook[21]` icon (`search.bmp`). Unevaluated rows show red `Execute to evaluate`; an empty list has no group headings. Watched expressions are evaluated again after stepping, and double-click still focuses expression input. Breakpoints remain accessible through the source gutter and debugger commands. Reproduce the original browser icons with `tools/import-upstream-sidebar.py`; hashes are in `tools/upstream-sidebar-manifest.json`.

## beta9 标签栏 / beta9 tab header

标签区域使用相邻两个标签，不再绘制第三个标签的片段。箭头是独立绘制的 18×18 方形控制，不继承 GTK 按钮圆角和额外边距；标签保留原生文字及辅助功能，原生框架边距设为零。普通、按下、移出取消以及两组标签的切换均有真实 GTK2 鼠标回归，并检查截图中的箭头方角和按下颜色。

The viewport shows two adjacent tabs and never paints a fragment of a third. Arrow controls draw their own 18×18 square appearance rather than inheriting GTK button rounding or margins. Captions retain native text/accessibility with zero frame padding. Real GTK2 mouse tests cover normal/pressed/drag-out states and both tab pairs, including screenshot checks of square arrow corners and pressed color.
