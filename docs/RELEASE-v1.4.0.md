# Dev-C++ v1.4.0

## 中文

本正式版合入 1.3 系列 beta 的 Linux 移植改进，并完善原版侧栏、“关于”及勾选控件。

- 启动与输入：修复 GTK2/IBus 经 GVFS 同步等待约 25 秒的启动路径；接入源码编辑器的中文输入提交。启动检查覆盖无响应会话总线，输入检查使用真实 IBus/libpinyin，并验证 UTF-8 保存及撤销/重做。
- 编辑与文件：恢复 Ctrl+Shift+S 全部保存、记住最近成功打开/保存的目录；源码标签可拖动排序，拖动时显示原版风格的方框指针。移除固定撤销步数上限，验证 6000 次独立撤销与重做。括号匹配忽略字符串/注释，嵌套补全保留外层括号；`.in/.out/.ans` 等非源码文件不执行代码高亮和折叠。
- 侧栏：显示项目管理/查看类或查看类/调试，前两个标签显示时完整隐藏调试。方形双箭头仅移动标签栏，不切换当前内容面板；点击标签才切换内容。支持真实按下反馈、移出取消及键盘导航，不继承 GTK 主题的圆角或多余按钮边距。
- 类与调试：恢复原版类浏览器图标、方框加减号及名称/参数/类型配色；监视表达式平铺显示，未求值时使用红色 `Execute to evaluate`，单步后重新求值。滚动条按需显示。
- 原版资源：菜单/工具栏采用 Windows 5.11 实际嵌入的图标和译名；调整勾选框、菜单对勾、原版语法示例第 7/9/11/15 行及六页编辑器属性。关于区分 Bloodshed ≤4.9.9.2、Orwell 5.11 和 Linux 版，保留原版完整 GPL、作者、横幅与历史联系信息，并加入本仓库链接。

附件：`dev-cpp_1.4.0_amd64.deb`、`linux-noi-lazarus-1.4.0-src.zip`、`linux-noi-lazarus-1.4.0-src.tar.gz`。源码归档仅包含 `linux-noi-lazarus/` 的源文件、脚本和运行资源；不包含构建输出或用户配置。

更新前保存代码并关闭旧窗口，在下载目录运行：

```bash
sudo apt install --reinstall ./dev-cpp_1.4.0_amd64.deb
/usr/bin/dev-cpp --version
```

期望输出 `dev-cpp 1.4.0`，更新保留用户设置。旧命令及历史安装入口继续兼容；安装器和桌面入口迁移见 [打包与安装说明](PACKAGING.md)。

验证目标为 Ubuntu 20.04 / NOI Linux 2.0、Lazarus 2.0.6、FPC 3.0.4、GCC/G++ 9.3 和 GDB 9.1，包含真实 GTK2 鼠标/键盘、主题干扰、侧栏内容页索引、实际 GDB 单步、文件/项目/编辑/编译、源码归档及安装/卸载检查。类浏览器仍是当前缓冲区的词法索引，并非原版完整 C++ 头文件语义分析器；完整模板向导和高级调试功能的范围见 [移植版说明](../linux-noi-lazarus/README.md)。窗口装饰、字体及 GNOME 桌面行为仍由系统环境决定。

## English

This stable release incorporates the Linux port improvements from the 1.3 beta series and restores more of the original sidebar, About and check-control presentation.

- Startup/input: fixes the GTK2/IBus startup path that could synchronously wait about 25 seconds through GVFS, and supports Chinese IME commits in the source editor. Checks cover an unresponsive session bus and real IBus/libpinyin input, UTF-8 saves and Undo/Redo.
- Editing/files: restores Ctrl+Shift+S Save All and the last successfully opened/saved directory; document tabs support drag reordering with the original square drag-cursor feedback. Removes the fixed undo-step cap and verifies 6000 independent Undo/Redo steps. Bracket matching ignores literals/comments and nested completion preserves outer closing brackets. Data files such as `.in/.out/.ans` skip source highlighting and folding.
- Sidebar: displays Project/Classes or Classes/Debug, completely hiding Debug in the first pair. Square arrows scroll tab labels without changing the active content pane; clicking a tab changes content. Real pressed feedback, drag-out cancellation and keyboard navigation are retained independently of GTK button rounding/margins.
- Classes/debug: restores the original browser icons, boxed expanders and name/argument/type colors. Watch expressions use flat rows with red `Execute to evaluate` for unevaluated entries and update after stepping. Scrollbars appear only when needed.
- Original resources: menus/toolbars use the actual embedded Windows 5.11 icons and original terminology. Includes classic checks/menu ticks, original syntax-preview rows 7/9/11/15 and six editor-properties pages. About distinguishes Bloodshed ≤4.9.9.2, Orwell 5.11 and the Linux port, retaining the full original GPL, credits, banner and historical contacts alongside this repository link.

Assets: `dev-cpp_1.4.0_amd64.deb`, `linux-noi-lazarus-1.4.0-src.zip` and `linux-noi-lazarus-1.4.0-src.tar.gz`. Source archives contain only the `linux-noi-lazarus/` sources, scripts and runtime resources, without build output or user configuration.

Save your work and close old windows before updating. From the download directory:

```bash
sudo apt install --reinstall ./dev-cpp_1.4.0_amd64.deb
/usr/bin/dev-cpp --version
```

Expect `dev-cpp 1.4.0`; user settings are retained. Legacy commands and recognized historical launchers remain compatible. See [packaging and installation](PACKAGING.md).

Validation targets Ubuntu 20.04 / NOI Linux 2.0, Lazarus 2.0.6, FPC 3.0.4, GCC/G++ 9.3 and GDB 9.1, covering real GTK2 mouse/keyboard interaction, hostile theme styling, sidebar content-page indices, real GDB stepping, files/projects/editing/builds, source archives and installation/removal. The class browser remains a current-buffer lexical index, not the original full C++ header semantic parser. Template-wizard and advanced debugger scope is described in the [port README](../linux-noi-lazarus/README.md). Window decorations, font rendering and GNOME desktop behavior still depend on the system environment.
