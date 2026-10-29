# Orwell Dev-C++ 5.11 功能对齐与 UI 交互审计

本清单用于维护 NOI Linux 2.0 原生移植版，区分交互缺陷修复、已有功能的适用范围和后续移植工作。它不是“全部对齐”的声明。

## 对照基准与状态

原版基准为官方 SourceForge Git 提交 [`0e4d598b172efd7df97b7ecc941d6aa08340cd70`][upstream-tree]。
该提交的 [`Source/Version.pas`][upstream-version] 第 35 行明确声明 `DEVCPP_VERSION = '5.11'`。
后续开发版本不能直接作为 5.11 的功能和快捷键依据。

审计读取了 [`Source/main.dfm`][upstream-actions] 的 144 个 Action，以及对应事件处理函数和 [`Source/README.txt`][upstream-shortcuts] 的快捷键说明。
其中包含上下文菜单、调试专用动作和不同状态下的动作；不能把动作数当作用户功能数，也不能据此计算完成率。

移植基线为 `v1.0.0`，提交 `c2370a53665b5f9c2b6d7532d355142bc90306ae`。
下表按已通过的测试范围记录状态，末列保留完整验收目标，不表示其每个组合均已实测。“已实施”只表示代码存在；独立 helper 测试、真实 GTK2 操作与目标桌面实机验收分别记录，避免扩大结论。
源码入口为 [`mainform.pas`](../linux-noi-lazarus/mainform.pas)，集成检查入口为 [`ci/check.sh`](../ci/check.sh)。

## 本轮交互缺陷修复

| 问题 | 基线中的触发条件与影响 | 本轮状态 | 必须通过的验收 |
| --- | --- | --- | --- |
| 编辑动作不能撤销 | 删除行、复制行和批量注释直接修改 `Editor.Lines`；随后 Ctrl+Z 无法恢复操作前文本 | helper 与真实 UI 已验证 | 分别执行删除行、复制行、注释/取消注释、批量替换；一次撤销恢复原文本，重做恢复新文本；同时覆盖多行选区和中文 |
| 快捷键作用于错误控件 | `FormKeyDown` 无视焦点，把 Ctrl+A/C/X/V/Z/Y 发送给当前源码编辑器；焦点在编译日志时也可能剪切或改写源码 | 真实 UI 已验证 | 日志中的全选/复制针对日志；日志的剪切/粘贴不修改后台源码；返回编辑器后对应动作仍有效。菜单和工具栏也须遵守焦点与只读状态 |
| 同一路径出现两个独立缓冲区 | A.cpp、B.cpp 同时打开，将 A 另存为 B 后，原 B 缓冲区仍可能覆盖新内容 | 文件 helper 与真实 UI 已验证 | 拒绝将文档另存为另一个已打开文档的路径；取消、拒绝覆盖或写入失败时，文件名、选区和脏状态保持一致 |
| 外部修改被静默覆盖 | 基线文件监测只检查删除，不检查外部内容变化；保存直接覆盖目标文件 | 文件 helper 已验证；模态交互仍需验收 | 外部修改后重新加载与保留编辑内容均可选择；脏缓冲区保存时检查冲突；取消不写磁盘；监测对话框不能在模态操作中重复弹出 |
| 另存为后项目仍引用旧文件 | 文档路径改变，`.dev` 单元路径与项目树没有同步 | 已实施；项目交互仍需验收 | 项目中的源文件另存为后，树、项目配置、重新打开项目和后续 F9 使用同一新路径；写入失败不能留下半更新状态 |
| 编译中的 UI 重入 | 编译循环处理消息时仍能运行目标或切换项目，可能启动未链接完成的文件或把结果归属到错误项目 | 已验证：实际编译、取消和旧目标拒绝运行 | 编译期间禁用冲突动作，保留取消和日志复制；完成结果归属于本次源文件/项目快照；失败或取消后 F10 不能悄悄运行旧目标 |
| 编译诊断不能定位合法路径 | 按首个冒号拆分诊断会丢弃 `a:b.cpp`；相对头文件路径没有依据本次编译目录展开 | 诊断解析 helper 已验证；定位交互仍需验收 | 对含冒号、中文、空格的源文件和 `include/bad.h` 诊断双击定位；行列与 UTF-8 文本对应，已关闭文档的旧结果不能访问失效对象 |
| 搜索、配对与选区边界不一致 | 前后搜索的循环起点、替换撤销分组、自动闭合引号可能导致重复匹配或多余字符 | helper 已验证；完整搜索/配对交互仍需验收 | 首尾循环搜索不遗漏或重复当前选区；未找到时保留光标和选区；输入已有闭合引号时正确越过；注释与字符串内不错误补齐 |

原版针对输出区提供独立动作，而非把所有键盘输入交给源码编辑器：见 [`main.dfm`][upstream-actions] 的 `actMsgCut`、`actMsgCopy`、`actMsgPaste`、`actMsgSelAll`，以及 [`main.pas`][upstream-main] 的 `actMsgCopyExecute`（第 3312 行）和 `actMsgSelAllExecute`（第 3385 行）。

## 本轮继续移植的原版功能

| 功能 | 原版 5.11 证据 | 本轮状态 | 验收要求 |
| --- | --- | --- | --- |
| 程序执行参数 | [`main.pas`][upstream-main] `actExecParamsExecute`，第 4737 行；单文件用 `fCompiler.RunParams`，项目用 `Project.Options.CmdLineArgs`。[`Compiler.pas`][upstream-compiler] 将参数交给目标程序 | 已验证：实际 F10/F11 参数、目录与项目隔离 | 与编译参数分开设置；F10、F11 实测 `argv`，覆盖中文、空格、空参数、引号和反斜杠；单文件与不同项目的设置不串用；参数先按 `argv` 解析，针对 FPC 3.0.x 的空参数截断缺陷，终端 wrapper 对每个路径和参数逐项严格作 shell 字面引用 |
| 编号书签 1..9 | [`main.pas`][upstream-main] `BuildBookMarkMenus`（第 996 行）、`ToggleBookmarkClick`（第 1371 行）、`GotoBookmarkClick`（第 1390 行） | 真实 UI 已验证 | Ctrl+1..9 设置/清除，Alt+1..9 跳转；文档之间独立；插入/删除行后位置合理；切换标签后菜单状态刷新，并覆盖 SynEdit 默认映射冲突 |
| 上下移动行块 | [`main.pas`][upstream-main] `actMoveSelUpExecute`（第 6365 行）、`actMoveSelDownExecute`（第 6374 行）调用 `ecMoveSelUp/ecMoveSelDown` | helper 与真实 UI 已验证 | Ctrl+Shift+Up/Down 支持当前行和多行选区，保留选区；一次撤销恢复；首尾行、空行和选区结束于下一行第一列均不损坏文本 |
| 关闭项目 | [`main.pas`][upstream-main] `actCloseProjectExecute`，第 2060 行；[`main.dfm`][upstream-actions] 的 `actCloseProject` | 已实施；保存/取消交互仍需验收 | 保存、放弃、取消均有正确语义；成功关闭后项目路径、项目树与编译目标重置；关闭项目不误关闭无关文件；取消时原项目继续可用 |
| 最近文件与项目历史 | [`main.dfm`][upstream-actions] 的 `actHistoryClear`；[`DataFrm.pas`][upstream-data] 的历史记录管理 | 已实施；历史菜单与重启交互仍需验收 | 重启后保留顺序，重复打开不产生重复项；中文/空格路径可打开；不存在的文件不能假装打开成功；清除历史立即刷新且能够持久化 |

“执行参数”与“编译参数”是两个独立功能。仅在菜单中保留 Compiler Options，不能算作已实现原版 Parameters。
书签按原版真实映射验收，不套用常见 SynEdit 默认的 Ctrl+Shift+数字映射。

## beta6：完整主题、语言资源与菜单响应

- 导入原版 `Source/DefaultFiles.rc` 的全部 11 套、每套 22 项配色；保留既有主题名称和设置，并支持原版拼写别名。新增独立浮点、十六进制和八进制属性，避免 Matrix 等主题丢失原版数字颜色差异。
- 转换并打包原版 33 份语言文件，提供母语名称、即时切换和重启持久化。简体中文保留移植版补充译文，其余语言按原版编号匹配；Linux 新增文字缺少译文时回退英语，格式参数不兼容时不采用旧译文。资源列表、来源与原始编码见 [languages/README.md](../linux-noi-lazarus/languages/README.md)。
- 菜单弹窗排入异步队列，先结束原生 GTK 菜单事件，再进入模态窗口，合并待处理的重复请求；退出时移除回调。新建、切换、关闭文档、编辑状态及焦点变化立即刷新命令可用性，100ms 定时器仅作补充。
- 回归覆盖 33 种语言实际载入、切换、重启设置及不修改用户文本，11 套主题的属性与新数字类别，以及新建后无定时器仍立即启用 Find/Save。真实 GTK2 鼠标连续十次单击“关于”菜单、版本信息、链接、复制及 Escape 关闭均纳入验收。
- README 同时提供完整中文和英文说明，包含命令行覆盖安装与旧快捷方式排查。

## 已有功能及其适用范围

`1.1.3~beta4` 恢复“文件 → 新建 → 项目 / 源代码”的原版菜单路径，
保留 Ctrl+N 新建源码；“添加文件到项目”从当前项目目录开始选择。
新建仍为控制台空项目，需添加源文件；尚未实现 `NewProjectFrm` 的完整模板向导。
行号留白依据 `Source/devCFG.pas` 的 `LeftOffset=4`、`RightOffset=21` 和
`BorderStyle=gbsNone` 映射到 Lazarus gutter，主题切换保留间距和背景色。
新增真实 GTK2 回归覆盖中英文菜单下取消/创建项目、在中文及空格路径添加两个源文件、
F11 编译运行、关闭和重新打开项目，以及 Ctrl+N 新建源码；行号鼠标断点回归继续通过。

| 功能 | 当前可用范围 | 仍有的边界 |
| --- | --- | --- |
| 编辑与文件管理 | 多标签 C/C++ 编辑、语法高亮、保存、拖放、头源切换 | 本轮修复及验收范围见上表；编码转换、换行选项尚未完整对齐；权限、符号链接和别名保存已有独立回归 |
| C/C++ 编译运行 | 控制台源文件与多源文件 `.dev` 项目，F9/F10/F11；Ubuntu 20.04 对应旧工具链已有自动检查 | 不等同于原版完整项目模型；Windows 专用链接选项与资源模板不能直接照搬 |
| 查找与替换 | 当前文档前后查找、当前文档替换；Find All 扫描已打开文档 | 查找选项和未打开项目文件的作用域未完整实现；Find All 复用编译结果列表，仍缺少独立结果模型 |
| 补全与导航 | 关键词、当前文本/局部头文件的简化成员索引、部分标准容器成员、Ctrl+Click 导航 | 词法索引不等同于 C++ 语义分析；模板、宏、重载和表达式链解析不完整；Classes 页不等同于原版类浏览器 |
| 中文与英文界面 | 菜单、提示和常用对话框可切换并保存语言设置 | 新增菜单和异常提示需要同步翻译；原生 GTK 对话框与字体还需目标桌面验收 |

## Issue #2 的处理范围

对应 [仓库 Issue #2](https://github.com/TH911/Dev-Cpp-Linux/issues/2) 的五项反馈：

| 反馈 | 当前改动与证据 | 仍需确认 |
| --- | --- | --- |
| Shift 选区后 Home 跳到行首 | Home/Shift+Home 共用显式切换状态，跳到首个非空白字符；重复按键与移动/鼠标重置有编辑 helper 回归 | 目标桌面焦点行为；helper 与真实 UI 回归已通过 |
| 没有 GDB/断点 | 增加 GDB/MI2、F4 断点、F5 启动、F6 停止、F7 步过、F8 步入和表达式求值；独立会话与实际 GTK2 调试测试均通过 | 高级功能见下表；原版 GNOME 桌面仍需验收 |
| 没有主题切换 | 移植原版 Classic Plus、Twilight、Visual Studio、Obsidian；现有文档、新文档和重启持久化的真实 UI 测试通过 | 不同字体与缩放下的视觉效果 |
| 多套编译器配置及界面 | 增加配置列表、新建/复制/删除、活动配置工具栏选择；实际编译验证独立 flags，取消与重启持久化通过 | 布局采用 LCL，尚非原版 VCL 的像素复刻 |
| 括号字体/显示 | 括号高亮使用独立属性，避免意外加粗；字体可选，默认 Linux 等宽字体；主题属性 helper 测试通过 | 主观显示效果由目标桌面验收 |

## 1.1.1 调试、安装与版本识别

- 按原版 5.11 的 DebugSheet 整理底部左右分区，恢复左侧 Debug 页；断点红点、停止箭头和行色采用原版主题设置。
- 真实行号单击增删断点；右键与拖动不会误触。运行中通过内部暂停修改后恢复，真实用户断点竞争仍保留暂停。GDB 9.1 会话回归及真实鼠标 UI 测试均已通过。
- 安装版有独立菜单 ID、WM_CLASS 与按版本/路径隔离的 IPC，不转交旧源码实例。桌面入口迁移有精确识别与备份；实际 GIO 菜单启动、删除旧源码后重开、编译运行和卸载保留设置均通过。通信句柄设为 close-on-exec，终端不会让已退出的 IDE 保持“运行中”。
- 关于窗口显示版本、仓库、原版与许可证、安装来源和实际路径；仓库点击、标准快捷键复制详细信息及无 DISPLAY 的 `--version` 已实测通过。

## 1.1.2 原版按钮、图标与名称

对照 `main.dfm` 的 `tbCompile`、`DebugStartPanel` 和 `AboutFrm.dfm`，移除顶部新增的 Continue、Step over、Step into、Toggle Breakpoint，以及 Evaluate、Send input、Copy details 按钮。原版已有的 Debug/Stop、底部继续/步进/停止与编译器选择保留；求值和程序输入用 Enter，关于详情用 Ctrl+A/C。

源码与安装版的桌面名称、主标题统一为 Dev-C++，图标使用原版 ICO 原字节；Debug/Stop 使用原版 newlook BMP 原字节。源码运行脚本在构建后读取实际程序版本，兼容版本标记也纳入一致性检查，避免再次显示旧的 v1.0.0。

## 有意保留的差异

- 当前项目既定 **Ctrl+Shift+S = Save As、Ctrl+Shift+A = Save All**，本轮继续保留。
  原版快捷键表为 Ctrl+Shift+S = Save All，Ctrl+Shift+A = AStyle Format Current File；以后添加格式化时需选择其他键或允许配置。
- GTK2/LCL 控件、Linux 终端与路径处理服务于 NOI Linux 2.0。功能语义应对齐，不能以 Windows 像素布局、Win32 专用选项是否照搬来判断可用性。
- 本轮对原版功能的验收要求包括取消、撤销、焦点、跨文档和跨项目状态；仅新增同名菜单不算完成。

## 尚未移植或未完整对齐的较大功能

| 功能组 | 原版证据 | 后续最低验收条件 |
| --- | --- | --- |
| 高级 GDB 调试 | [`Debugger.pas`][upstream-debugger]、[`DebugReader.pas`][upstream-debug-reader] 与 [`main.dfm`][upstream-actions] 的断点、执行、单步、变量监视等动作 | 本轮已通过异步会话、断点、源码停靠、继续/步过/步入/停止、表达式求值和程序 stdin/stdout 的实际测试；后续需实现调用栈浏览、持久监视、条件断点、附加进程等高级功能，并保持会话清理语义 |
| 增量构建、Clean、真实 Rebuild | [`Compiler.pas`][upstream-compiler]、[`Project.pas`][upstream-project]；`actCompile/actRebuild/actClean` | 对象文件与头文件依赖；只编译受影响单元；Clean 删除受控产物；F12 强制重建。基线 F9/F12 每次把全部源文件交给一次编译器调用，不能称为增量构建 |
| 项目查找与完整搜索对话框 | [`FindFrm.pas`][upstream-find] 的 MatchCase、WholeWord、SelectedOnly、Backwards、Origin、OpenFiles、ProjectFiles | 未打开的项目源文件可搜索；大小写、全词、选区、方向与起点选项有效；结果与编译诊断分离；替换可取消并有明确撤销语义 |
| 项目管理扩展 | [`main.dfm`][upstream-actions] 的新建项目单元、另存项目等动作；[`Project.pas`][upstream-project] | 项目新建单元自动登记；项目另存为正确重写相对路径；项目树重命名/分组；不同输出类型与目录持久化，保留未知 `.dev` 字段 |
| 打印与导出 | [`main.dfm`][upstream-actions] 的 `actPrint`、打印设置与 HTML/RTF/TeX 导出动作 | 实际输出可读内容；选区和全文件范围正确；LCL/GTK/CUPS、分页和中文字体可用，不能只弹出空对话框 |
| AStyle 与用户工具 | [`main.dfm`][upstream-actions] 的 `actFormatCurrentFile` 和工具相关动作 | 实际格式化、可撤销、失败不改写文本；工具参数宏与路径安全传递；使用已记录的快捷键约定 |
| 第二编辑视图、类浏览器与结构辅助 | [`main.dfm`][upstream-actions]、[`main.pas`][upstream-main] 中的视图及类/成员动作 | 第二视图共享文档并同步保存/撤销；声明/定义与成员索引可导航；不同文档不会复用过期索引 |
| 完整视图与会话恢复 | [`main.pas`][upstream-main] `actFullScreenExecute`（第 2312 行）；[`main.dfm`][upstream-actions] 的状态栏、工具栏和窗口动作 | 本轮已提供全屏、状态栏显示和日志/编辑器焦点动作；仍需完整会话恢复、工具栏布局和窗口管理。隐藏面板须可恢复，关闭动作须遵守保存取消语义 |

## 已执行的验证与验收边界

以下实测使用 Ubuntu 20.04 amd64、Lazarus 2.0.6、FPC 3.0.4、GCC/G++ 9.3.0、GDB 9.1；真实窗口交互使用 Xvfb/GTK2 和 XTerm。

| 检查 | 已通过的范围 |
| --- | --- |
| `document-files-test.pas` | 普通用户执行 69 项断言，覆盖符号链接/硬链接别名、外部内容与元数据变化、原子保存、权限、失败清理及 INI 控制字符拒绝 |
| `editor-actions-test.lpi` | 编辑动作的撤销分组、选区与 UTF-8 边界，以及 Home/Shift+Home 和状态重置 |
| `ui-interaction-smoke.sh` | 真实窗口执行编辑动作与一次撤销、Home/Shift+Home、书签、日志焦点隔离、取消另存为及拒绝覆盖另一已打开缓冲区 |
| `runtime-support-smoke.sh` | 引号、空参数、中文、反斜杠和 shell 元字符的实际参数值；诊断解析 |
| `runtime-ui-smoke.sh` | F10/F11 实际参数与工作目录、项目/单文件隔离、已运行程序的重新链接、失败后拒绝旧目标、编译中动作禁用及取消进程清理 |
| `gdb-session-smoke.sh` | 实际 GDB 9.1 会话、断点增删、另存为路径迁移与去重、停靠源码、步进、求值、输入输出、重启、运行中停止与特殊参数 |
| `gdb-ui-smoke.sh` | 行号实际单击、右键/拖动保护、暂停/运行中断点、F4/F5/F7/F8/F6、源码停止位置、只读锁定、求值、程序输入输出、正常退出恢复编辑与停止清理 |
| `editor-themes-test.lpi`、`compiler-profiles-test.pas` | 四套主题属性、括号/字符属性、旧配置迁移、配置复制/切换/删除与独立 flags |
| `about-ui-smoke.sh` | 真实版本/路径显示、鼠标打开仓库、系统剪贴板复制及 Esc 关闭 |
| `launcher-migration-test.py` | 精确旧入口迁移、备份幂等、自定义项/参数及符号链接保留 |
| `preferences-ui-smoke.sh` | 真实菜单切换主题、创建和切换编译器配置后的实际编译、Cancel 丢弃编辑，以及重启持久化 |
| `packaging/verify-artifacts.py`、`verify-install.sh` | 归档排除产物、Debian 元数据；隔离容器安装、普通用户打开中文相对路径、IPC、F11 编译运行、只读安装目录、卸载/purge 保留设置与 MIME 默认值 |

`ui-interaction-smoke.sh` 的独立完整重跑已通过。另发现调试只读期间编辑回调仍可改写缓冲区的问题，已加入回调级防护，已通过暂停时输入普通字符、Tab、回车、配对括号和接受补全，停止后保存并比对原文的回归。文件 helper 证明底层保存规则，不能单独证明所有保存对话框和项目取消路径。完整检查由 [`ci/check.sh`](../ci/check.sh) 汇总，安装包另在一次性容器中验证；`ci/check.sh` 的本地完整集成运行亦已通过；GitHub CI 结果以对应提交的 Actions 记录为准。

仍需在原版 NOI Linux 2.0 GNOME 桌面验收显示、焦点、字体与 GNOME Terminal。容器不复现官方 ISO 的完整桌面或内核，这一项不能由 Xvfb/XTerm 测试替代。

[upstream-tree]: https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/
[upstream-version]: https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/Source/Version.pas
[upstream-main]: https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/Source/main.pas
[upstream-actions]: https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/Source/main.dfm
[upstream-shortcuts]: https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/Source/README.txt
[upstream-compiler]: https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/Source/Compiler.pas
[upstream-data]: https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/Source/DataFrm.pas
[upstream-debugger]: https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/Source/Debugger.pas
[upstream-debug-reader]: https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/Source/DebugReader.pas
[upstream-project]: https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/Source/Project.pas
[upstream-find]: https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/Source/FindFrm.pas

### v1.2.0 输入框可读性

编译器/编辑器选项、运行参数、编译日志、调试输入和关于详情使用黑字白底；原生选区和禁用配色保留。窗口显示时重新应用颜色，覆盖 GTK 模态窗口重建控件的情况。`tests/input-colors-ui-smoke.sh` 使用普通文字为灰色的 GTK2 测试主题，验证实际鼠标聚焦、Ctrl+A 选区、控件敏感状态及对比度，旧版在编译器选项处不能通过该检查。

### v1.3.0 截图布局对齐

恢复原版双排工具栏、菜单图标、作用域/函数导航、类树、窄侧栏、全宽六页输出区、七栏状态信息及修改标签。新增基础打印、文本导出、可选 AStyle 格式化和独立搜索结果。使用随发行版提供的 Lazarus 2.0.6 C++ lexer（保留 MPL/GPL 双许可证声明）补上真实花括号折叠、折叠状态序列化和灰色缩进虚线；`noi_syn_cpp.pas` 的修改不是独立重写词法器。轻量导航不提供完整 C++ 语义、重载解析或模板解析；Windows 工程导入、资源编译、性能分析等尚未完成，未用假按钮替代。GTK2 的窗口边框及字体渲染仍取决于桌面。

`tests/classic-layout-test.lpr` 验证真实折叠/展开、注释与字符串排除、函数/成员跳转、导出转义和 AStyle 一次撤销；`classic-ui-smoke.sh` 使用真实鼠标/键盘操作验证函数选择、编译摘要、输出区关闭恢复，并保存四张原生 GTK 截图。

## v1.3.1-beta2：设置和调试面板 / Preferences and debugging

按用户的 5.11 截图恢复编辑菜单分组、六页编辑器属性、两排调试动作和 GDB 命令框。加入真实 Linux GCC Release/Debug/Profiling 配置、可配置行号字体/栏距、语法预览与样式、插入片段及恢复副本。界面显示 Dev-C++，命令及安装包使用 `dev-cpp`，保留两代旧名称的升级兼容。具体行为及尚未完成的部分见 [CLASSIC-UI.md](CLASSIC-UI.md)。

The beta restores Edit groups, six editor-property pages, two debugger action rows and a GDB command field from the supplied 5.11 references. It adds actual Linux GCC profiles, gutter/font controls, syntax previews, snippets and recovery copies. The display name is Dev-C++; command/package naming is `dev-cpp`, retaining both legacy upgrade paths. See [CLASSIC-UI.md](CLASSIC-UI.md) for tested behavior and remaining gaps.
