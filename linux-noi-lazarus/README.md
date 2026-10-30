# Dev-C++ for NOI Linux 2.0

[中文](#中文) | [English](#english)

## 中文

这是基于 Lazarus/LCL 的原生 Linux 移植版，界面和功能以 Orwell Dev-C++ 5.11 为基准。目标环境为 NOI Linux 2.0（64 位），使用预装的 Lazarus 2.0.6、FPC 3.0.4、GCC/G++ 9.3 和 GDB 9.1。当前正式版为 **1.4.0**；[下载安装包及源码](https://github.com/TH911/Dev-Cpp-Linux/releases/tag/v1.4.0)。

在此目录打开终端，运行：

```sh
bash run.sh
# 打开指定源码或项目：
bash run.sh /path/to/main.cpp
bash run.sh /path/to/project.dev
```

源码构建还需要 Python 3 和 Lazarus 2.0.6 的源码（`lazarus-src-2.0`）。构建脚本在 `lib/` 内生成 SynEdit 启动兼容修正，不修改系统 Lazarus。

首次运行会编译程序，后续可用 `bash launch.sh` 启动；源码变动后会重新编译。请保留旁边的脚本、`icons/`、`profiles/` 和 `languages/`。编译错误保存到 `~/.cache/dev-cpp/launch-build.log`，运行错误保存到 `~/.cache/dev-cpp/runtime.log`。

- F9 编译、F10 运行、F11 编译并运行；Ctrl+F9 检查语法。
- “文件 → 新建 → 项目”创建空的控制台 `.dev` 项目，再通过“项目 → 添加文件到项目”添加 C/C++ 源文件。Ctrl+N 新建源码。完整项目模板向导尚未实现。
- “查看 → 编辑器主题”提供原版全部 11 套配色；“编辑器选项”可设置字体、字号和 Tab 宽度。设置保存并应用于现有和新建文档。Consolas 的安装与回退规则见 [FONTS.md](FONTS.md)，安装包不附带微软字体文件。
- “查看 → 语言”提供原版 33 份语言资源，切换即时生效并保存。Linux 新增文字缺少译文时回退英语，简体中文保留已有补充翻译。资源数量不代表所有新功能都已完成母语校对，详见 [语言说明](languages/README.md)。控制台提示目前提供中英两种。
- F5 开始调试、F4 切换断点、F7 单步跳过、F8 单步进入、F6 停止；单击行号或标记区也可切换断点。红点表示断点，黄色箭头表示当前执行行。本轮支持进程内表达式监视、逐指令及跳出函数；跨重启监视保存、条件断点、调用栈浏览、进程附加等高级功能尚未完成。
- “帮助 → 关于”显示版本、GitHub 链接、许可证和实际程序路径。菜单弹窗会在 GTK 菜单激活完成后打开；编辑或切换文档后，按钮状态立即刷新。

`.deb` 安装版无需 Lazarus/FPC。更新时先保存代码并关闭旧窗口，然后在安装包所在目录运行（替换为实际文件名）：

```bash
sudo apt install --reinstall ./dev-cpp_1.4.0_amd64.deb
/usr/bin/dev-cpp --version
/usr/bin/dev-cpp --new-window
```

更新无需先卸载，用户设置会保留。源码版与安装版使用不同启动入口和实例标识；如果旧图标仍打开旧版，可运行 `/usr/bin/dev-cpp --repair-launchers` 迁移可识别的历史自动生成入口。自定义入口保持不变。完整的中英双语更新步骤见 [仓库 README](https://github.com/TH911/Dev-Cpp-Linux/blob/v1.4.0/README.md#使用命令行更新已安装的-dev-cpp)。

当前仍有移植范围限制，包括完整模板向导、增量项目构建、完整 C++ 语义解析、第二编辑视图及高级调试功能。完整检查使用 Ubuntu 20.04 对应工具链、Xvfb 和 XTerm；NOI Linux 原版 GNOME 桌面上的焦点、缩放和终端行为仍需实机验收。代码与原始资源按 GPL-2.0-or-later 提供，见 `COPYING.txt`。

启动优化、名称与旧版本迁移见 [双语说明](https://github.com/TH911/Dev-Cpp-Linux/blob/v1.4.0/docs/STARTUP.md)。源码菜单注册请运行 `bash register-desktop.sh --register`，普通启动不再自动重写桌面入口。

本轮 UI／搜索／纯文本模式说明见[双语说明](https://github.com/TH911/Dev-Cpp-Linux/blob/v1.4.0/docs/UI-RESTORATION.md)。

v1.3.0 恢复双排工具栏、函数导航、折叠和全宽输出页；提供基础打印、文本导出和可选 AStyle 格式化。已有字体设置保留。

输入框使用清晰的黑字白底，选中文字保留原生高亮配色；禁用状态仍由 GTK 主题控制。

## English

This is the **Lazarus/LCL native port in progress**. It uses only software
listed in the official NOI Linux 2.0 environment: Lazarus 2.0.6, FPC 3.0.4,
GCC/G++ 9.3 and GDB 9.1. This program follows Orwell Dev-C++ 5.11's main window
structure, menu names, F9/F10/F11 actions, and `.dev` project format.
The interface restores the original two-row toolbar, function selectors, folding
and full-width report tabs; printing and HTML/RTF/TeX text export are available.
AStyle formatting uses an optional system astyle package. The symbol navigator
is a lightweight index, not full C++ semantic analysis. Existing font settings
are retained; new editor configurations use size 14.
The application supports installed Consolas detection and a monospace fallback; see
[font setup](FONTS.md). Existing user font preferences are retained.

The current stable version is **[v1.4.0](https://github.com/TH911/Dev-Cpp-Linux/releases/tag/v1.4.0)**, including the amd64 Debian package and corresponding directory source archives. Stable releases use `main`; development pushes to `beta` publish Pre-releases after successful checks. Manual beta publication requires `publish_beta`.

On a stock NOI Linux 2.0 desktop, open a terminal in this directory and run:

```sh
bash run.sh [source.cpp | project.dev]
```

The terminal launcher builds with the preinstalled `lazbuild`; desktop icons
and file association use `launch.sh` to start an up-to-date binary immediately.
If no binary exists or sources are newer, the desktop launcher builds once and saves any build error
to `~/.cache/dev-cpp/launch-build.log`. The build uses no network access. Install the listed build/source prerequisites first if your image lacks them.
The build needs Python 3 and the Lazarus 2.0.6 source package (`lazarus-src-2.0`). It generates an isolated SynEdit startup fix under `lib/` without changing system Lazarus files, and selects GTK2.
It links to `dev-cpp.build`, then atomically moves the successful
output to `dev-cpp`. A build lock serializes builders. This avoids Linux's
`Text file busy` error when an earlier IDE executable is still running.
Normal launches forward file paths to an existing window using FPC SimpleIPC,
which is part of the preinstalled Free Pascal libraries. The UI polls requests
without creating a background GUI thread. If no window exists, a window starts.
After checking the build timestamp, the binary forwards to an existing instance without a separate GTK launch. Instance forwarding is now separated by executable path and version, so an
installed release does not activate a running source build or another version.
Close earlier windows when upgrading to avoid confusing them with the new IDE.
`bash launch.sh --new-window file.cpp` explicitly starts a new window. Desktop
registration adds a New Window action and a second Open With application,
plus GNOME Files' Scripts > Open in New Window (Dev-C++) context entry (Chinese
when the interface language is Chinese). It forwards all selected files.
`F9` compiles, `Ctrl+F9` checks syntax, `F10` runs, and `F11` compiles and runs in GNOME Terminal.
Execute > Abort Compilation stops an active compiler process.
The application starts with no document. Ctrl+N creates Untitled1, and the
number increases during the current application run. Ctrl+N/O/S/W/F/G and
Ctrl+Shift+S Save All, Ctrl+Shift+A AStyle Format Current File, Ctrl+B Open Containing Folder,
Ctrl+Y redo, Ctrl+R replace, Ctrl+H project options, Ctrl+/ toggle line
comment, Ctrl+; toggle inline comment, Ctrl+Shift+F Find All,
Ctrl+Shift+R Replace in Files, Ctrl+Tab/Shift+Ctrl+Tab tab
switching, and Ctrl+Shift+W close all work while the editor has focus. Ctrl+1..9 toggles
numbered bookmarks, Alt+1..9 jumps to them, and Ctrl+Shift+Up/Down moves the
current line or selection as one undoable action. Window includes full screen
(Ctrl+F11); View includes status-bar visibility, compiler log (Ctrl+Alt+L), and editor focus
(Ctrl+Alt+E). File > Recent Files / Recent Projects retains the last ten entries;
Close Project supports saving or cancelling before closing project documents.
F3 searches from the caret and wraps without moving the caret if nothing is
found. Dropping source or `.dev` files
onto the window opens them. Ctrl+click opens local or installed headers and
finds simple function definitions in the current file, open documents, project
files, and local quoted headers. Template, macro, and overload resolution are
not yet part of the navigation index.

Run `bash register-desktop.sh --register` once to register **Dev-C++** in the desktop's **Open With** list for C/C++
files using only your user account. To make it the default application for
`.cpp` and `.c` files, run `bash register-desktop.sh --default` in this folder.
No sudo or network connection is needed. The user-level desktop entry points
to this folder, so rerun the registration command after moving it. Source desktop entries use the separate `dev-cpp-source.desktop` identity.
The installed package has its own visible `dev-cpp-installed.desktop` entry,
so rebuilding from source does not shadow the installed application. The source
entry is hidden from menus when the package is installed, keeping one visible
Dev-C++ application. Source entries are refreshed by `bash register-desktop.sh --register` or
`bash register-desktop.sh --default`; ordinary launches do not rewrite desktop files.
When the package is installed, the explicit `--default` command chooses the
installed entry. Normal launching or package installation does not change MIME
defaults. See [launcher migration](../docs/PACKAGING.md).

Input fields use readable black-on-white normal text while preserving native
selection colors and disabled-state styling.

Current implementation: tabbed SynEdit editing with C/C++ syntax highlighting,
line numbers, literal Tab indentation with width 4 on Enter and Tab (including
Enter between `{}`), caret movement across each whole Tab, preserved Tab-only
lines, colored preprocessor directives and modern C++ keywords, hidden gutter
change bars, all eleven original syntax themes (Classic, Classic Plus, Twilight, Ocean,
Visual Studio, Borland, Matrix, Obsidian, GSS Hacker, Oblivion and
PlasticCodeWrap), with independent bracket highlighting and configurable font;
Classic Plus retains red symbols, bold blue strings, blue comments, a light
gray gutter, turquoise current-line color and red matched-bracket backgrounds, vertical caret movement with a remembered visual column
and 4-column Tab width (clamped only on shorter lines until a nonvertical action), Home toggling
between first nonblank character and column one,
and automatic `()`, `[]`, `{}`, quote pairing and pair deletion (`struct` and `class`
declarations close with `};`); word completion from C++ keywords and identifiers in the current
file (`Ctrl+Space` or Edit > Code Completion), plus `struct`/`class`
member completion after `.`, `->`, `::` from the current file and local quoted
headers. `using` and `typedef` aliases and `struct Node {} a,b;` declarations
are indexed. Common standard container members such as `vector<int> g; g.` are
indexed when their standard header is included. The completion popup uses
the original borderless layout, handles Backspace through the dot,
and supports Enter, Escape, and arrow selection while the editor retains
keyboard focus. It distinguishes member functions, types, and
variables; function candidates show `()` and inserting one adds `()` unless an
opening parenthesis is already present. Escape suppresses immediate reopening
until the source changes; array element expressions such as `s[1].` resolve
back to the declared array name. Known standard container members are indexed
from their declared type even when the header line is absent from the current
snippet. Ctrl+mouse wheel zooms the fonts of all open editors. New files are
named Untitled1, Untitled2, and so on for the current session; the Save dialog
prefills UntitledN.cpp. String quote delimiters follow the original string
color; bracket matching excludes quotes, as in Orwell Dev-C++.
The interface defaults to Chinese. View > Language offers all 33 original
language catalogs; changes apply immediately and persist in
`~/.config/dev-cpp.ini`. Missing Linux-specific translations fall back to
English; Simplified Chinese keeps its existing extra translations. See
[language resources](languages/README.md) for provenance and translation limits.
Menus, tooltips, settings, dialog buttons and status labels use the selected
locale where a translation exists. Console exit messages currently offer Chinese
and English. Compiler diagnostics and C++ source identifiers retain their original text.
Integer suffixes are validated as a whole: `1ll` and `1ull` are colored as
numbers, while malformed literals such as `1llllll` are black. Ctrl+; acts only
on a selection and retains the selected content when toggling comment markers.
Home first goes to the first nonblank character, skipping spaces and Tab
characters. Consecutive Home presses toggle between that position and column
one; other keys and mouse actions reset the cycle. It is intercepted before
SynEdit's native Home processing. Shift+Up/Down uses the same remembered visual
column as Up/Down, with a stable selection anchor. Ctrl+Backspace from inside
an empty function-call pair removes both parentheses with the function name.
Confirmation and input dialogs measure labels and buttons using the current
font instead of fixed text heights. Compiler settings place labels above their
fields and size each row to fit. Dialog buttons are translated directly, so
Chinese confirmations no longer retain the native English Yes/No captions.
Angle bracket pairing is restricted to `#include<...>`; comparison and template
expressions do not insert `>`. Completion categories such as `function` retain
their English spelling. Save As asks before replacing an existing file.
Compiler diagnostics move the caret to the reported position and paint the
error line white on maroon, as in the original Classic Plus theme; editing or
compiling again clears that marker.
Function completion candidates show the return type and typed parameters. After insertion,
the argument tip marks the active parameter in red. Candidate row height is
the measured Courier font height plus two pixels; the tip uses measured text
height plus six pixels. The tip is a panel within
the editor window, so it cannot take focus. Function declarations do not show
a call tip. The popup is scheduled
immediately after the triggering key, with no artificial delay. An externally
deleted open file prompts to keep it in the editor or close it.
Closing an untouched empty UntitledN document needs no confirmation. Modified
UntitledN and named files prompt to save, discard, or cancel. Opening an
existing file does not advance the UntitledN counter.
Original New Look toolbar icons and left-side tabs; editor options for font
size and tab width, plus project creation, adding/removing files and project
compiler flags in the original `.dev` INI format;
open/save, project tree, single-file and multi-file console compilation,
search, go to line, and a compiler error list that selects the first error
and highlights its source line. Execute > Compiler Parameters (also available
under Tools, or Ctrl+Alt+O) edits the C and C++ compiler commands, compile flags
such as `-std=c++14`, and Linux linker flags; these settings are saved
in `~/.config/dev-cpp.ini`. New C++ settings include `-O2 -std=c++14`;
an unchanged earlier default is upgraded, while custom saved flags are kept.
The compiler dialog supports named profiles: create, copy, delete and switch
independent C/C++ commands and flags. The toolbar selects the active profile;
Cancel discards dialog edits. View > Editor Theme changes themes immediately
for open and new documents; editor options also select a font and size. Theme,
font and active compiler profile persist across restarts.
Remove Windows-only `-Wl,--stack=...` from
Linker flags on NOI Linux; Linux `ld` rejects that option. The compile log
shows arguments separated by spaces. F10/F11 launch GNOME Terminal and run through
the included `console-pauser.sh`, which displays elapsed time, exit status,
and a UTF-8 keypress prompt. The member index does not yet parse the full C++
standard library or resolve overloads, macros, and expression chains.
Debug > Start Debugging (F5) rebuilds with debug information and stops at
`main`. F4 toggles a breakpoint, F7 steps over, F8 steps into, and F6 stops the
session. Left-clicking a line number or gutter marker also toggles its
breakpoint; right-clicks and drag selection do not toggle it. Red dots mark
breakpoints, yellow arrows mark the stopped source line, and line colors come
from the corresponding original syntax theme.
The 1.1.1 Debug report tab places commands and an expression/value table on the
left, with program input/output and the GDB log on the right. The left sidebar
Debug page shows flat watch expressions; the main toolbar provides debugger actions.
The compact Sans 9 interface and panel structure move toward the original
5.11 layout while remaining native GTK2 controls. Editors become read-only during a session and
are restored after Stop or normal exit. See [the debugger guide](../docs/DEBUGGING.md).
Watch persistence across IDE restarts, conditional breakpoints, call-stack browsing, attach and
other advanced debugger features remain pending. Project resource builds,
full C++ signature resolution and a second editor view are also pending. F9 currently recompiles all project
sources, so F12 has the same compilation scope until an incremental builder
exists. Ctrl+Shift+S saves all files and Ctrl+Shift+A formats the current file, matching Orwell 5.11. Save As has no default key. See the bilingual [shortcut audit and save-folder guide](../docs/SHORTCUTS.md). Find All currently searches open documents, and Replace All
currently acts on the active document.

Execute > Parameters configures program arguments and working directory
separately from compiler flags. Project values are stored in the `.dev` file;
single-file settings do not leak into projects. Arguments support quoted
spaces and empty values. FPC 3.0.x truncates a raw process argument list at an
empty value, so the terminal runner uses a fixed Bash `exec` wrapper with every
path and argument individually quoted as a literal. Shell metacharacters in
arguments are not evaluated.

Saving uses an atomic same-directory replacement, checks for external changes
and preserves file permissions. Symlink aliases identify the same document;
Save As refuses the path of another open buffer and updates project unit
references when applicable. Cancel leaves the document identity intact.
Modified/deleted files prompt before reload or overwrite. Compilation publishes
a new executable only on success; failure/cancellation preserves the previous
file but prevents F10 from silently running it as the latest result.

The source is built and tested in an Ubuntu 20.04 amd64 container
with Lazarus 2.0.6, FPC 3.0.4, GCC/G++ 9.3.0 and GDB 9.1. Run
`bash ci/check.sh` from the repository root with that toolchain to build and
execute the helper and real GTK2 interaction suites. They cover file identity
and save conflicts, Home/Shift+Home and undo, focus, quoted execution arguments,
working directories, compilation cancellation, actual GDB sessions, themes
and compiler profiles, along with the revised layout, actual line-number clicks,
running breakpoint changes, repeated single-click About activation, immediate
command states, all eleven themes, all 33 language actions, About links/clipboard
and launcher migration.
See [the parity audit](../docs/DEVCPP-5.11-PARITY.md).
Tests use Xvfb and the XTerm fallback. They do not reproduce the official NOI
Linux ISO's GNOME desktop or kernel; visual behavior and GNOME Terminal still
need acceptance testing on that desktop.

Future Release assets include a source ZIP and tar.gz rooted at
`linux-noi-lazarus/`, plus an amd64 `.deb` with the prebuilt binary. Install
with `sudo apt install ./dev-cpp_VERSION_amd64.deb`, then open **Dev-C++** from the software panel or run `/usr/bin/dev-cpp`.
Use `/usr/bin/dev-cpp --version` or Help > About to check the version and
actual executable path. The installer keeps old custom launchers and MIME
defaults; recognized historical source launchers are backed up and migrated.
APT installs runtime dependencies; Lazarus/FPC are required only for source
builds. The installed program uses `/usr/lib/dev-cpp` read-only and stores
user settings separately. See [packaging and uninstall instructions](../docs/PACKAGING.md).

Help > About now shows the application version, the clickable GitHub project
link, Orwell Dev-C++ 5.11 attribution and GPL license. Build and installation
details show the executable and configuration paths, installation type, FPC
version and target platform. Copy Details copies this information for bug
reports. For a terminal-only version check, use `./dev-cpp --version` from a
source build or `/usr/bin/dev-cpp --version` for the package; no GUI window
is opened. Check the executable path in About when diagnosing an old launcher.

The launcher now initializes Xlib thread support before GTK and uses CreateNew
for the resource-free main form. Runtime stderr is saved in
`~/.cache/dev-cpp/runtime.log` (or `$XDG_CACHE_HOME/dev-cpp/runtime.log`).
These startup changes address possible causes of the reported XCB assertion;
the complete cause still needs confirmation on the NOI Linux desktop.

The port is GPL-2.0-or-later; see `COPYING.txt`. The toolbar bitmaps are copied
from Orwell Dev-C++ 5.11's `Source/Images/newlook` directory (the editor-options icon uses `Source/Images/blue/EditorOptions.bmp`).

Version 1.1.2 uses the name Dev-C++ and the unchanged upstream ICO for both
source and installed launches. Extra toolbar Continue/Step/Breakpoint actions
and the added Evaluate/Send/Copy buttons were removed. Evaluation and program
input use Enter; About details remain selectable with Ctrl+A/C. The source
launcher prints the version reported by its actual compiled binary.

本轮六页编辑器属性、GDB 面板与恢复副本说明见 [原版 UI 移植说明](https://github.com/TH911/Dev-Cpp-Linux/blob/v1.4.0/docs/CLASSIC-UI.md)。界面名为 **Dev-C++**，命令与包名为 `dev-cpp`；旧名称保留升级兼容。

See [classic UI behavior](https://github.com/TH911/Dev-Cpp-Linux/blob/v1.4.0/docs/CLASSIC-UI.md) for the six-page properties dialog, debugger actions and recovery copies. The display name is **Dev-C++**; the command and package are `dev-cpp`, retaining legacy upgrade redirects.

快捷键及保存目录：Ctrl+Shift+S 全部保存，Ctrl+Shift+A 格式化，另存为不设默认键；新源码保存时记住最近成功打开/保存的目录。详见 [中英文说明](../docs/SHORTCUTS.md)。

源码标签页可左右拖动排序，未保存文件也保留内容和未保存状态。Source tabs support drag reordering while retaining document identity and unsaved edits. See [shortcuts, folders and tabs](../docs/SHORTCUTS.md).

源码撤销与重做不再使用默认的 1024 条操作上限，保存仍保留历史。Source Undo/Redo no longer use the default 1024-action cap; Save retains history. Details: [undo history](../docs/SHORTCUTS.md).

See the [bilingual beta6 interface notes](https://github.com/TH911/Dev-Cpp-Linux/blob/v1.4.0/docs/UI-RESTORATION.md) for search, plain-text files, settings and remaining gaps.


beta6 根据用户回溯修正 IBus/GVFS 的启动等待，并用独立 GTK 输入上下文提交完整中文词组；标签留白、拖动指针、原版嵌入式图标与“视图”等译名继续对齐。详情见 [启动与输入法](../docs/STARTUP.md)。

beta6 addresses the IBus/GVFS startup wait found in the user's backtrace and commits complete Chinese phrases through independent GTK input contexts. Tab padding, drag feedback, embedded upstream icons and original menu wording are aligned further. See [startup and input-method details](../docs/STARTUP.md).

## v1.4.0：侧栏与关于 / Sidebar and About

侧栏显示项目管理/查看类或查看类/调试；前两个标签显示时不露出“调试”。方形双箭头只移动标签栏，当前内容页保持不变，点击标签才切换内容；标签字高、原版类浏览器图标和配色、平铺监视行及勾选样式均已调整。“关于”补全 Bloodshed ≤4.9.9.2、Orwell 5.11 与 Linux 版信息，以及原版许可证、完整作者名单、联系地址和本仓库链接。新包可直接覆盖更新，设置保留。

The sidebar shows Project/Classes or Classes/Debug, without exposing Debug in the first pair. Square arrows move tab labels while preserving the current content pane; clicking a tab selects its content. Caption height, original browser icons/colors, flat watch rows and check styles are restored. About includes Bloodshed ≤4.9.9.2, Orwell 5.11 and the Linux port, with the original full license, complete credits, contacts and repository link. Install the new package directly over the old version; settings are retained.
