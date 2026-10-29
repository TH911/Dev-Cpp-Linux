# v1.3.1-beta5：界面与编辑行为 / Interface and editing

## 中文

本轮依据 Orwell Dev-C++ 5.11 的 `Source/main.dfm`、`EditorOptFrm.dfm`、`EditorOptFrm.pas` 和用户提供的截图继续移植。参考提交为 [`0e4d598b172efd7df97b7ecc941d6aa08340cd70`](https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/)。这是 beta，GTK 的窗口边框、控件和字体渲染仍由 Linux 桌面提供。

编辑器属性保留基本、显示、语法、代码、代码补全、自动保存六页。代码页拆为插入／默认代码；补全页拆为引擎／完成符号。配对总开关、大中小括号、include 分隔符、引号、块注释及成对删除均可设置。自动成员补全延时、背景色、本地头文件扫描可以设置；系统头文件的完整索引尚未实现。

语法预览使用原版十六行示例，第 7、9、11、15 行分别表示断点、活动断点、错误、选中行，默认整行背景为红、蓝、栗色、深蓝色。语法列表中可分别修改这些颜色，以及装订线、折叠标记颜色；设置应用于实际编辑器。多行选择不再生成“把所选文本折叠”的额外标记，正常代码块折叠保留。

`.in`、`.out`、`.ans` 强制作为纯文本；其他未列入语法扩展名的文件也不运行 C++ 词法高亮、括号匹配、符号导航、补全或函数提示。未命名新源码仍使用 C++。另存为改变扩展名时，编辑器同步切换模式。语法页可设置源码扩展名；数据文件三种后缀仍保持纯文本。

左栏提供项目、查看类、调试三个页面，用两个箭头切换可见页签。开始调试时显示调试页；暂停和单步执行后，局部变量自动向 GDB 查询并更新，表达式监视仍可使用。复合对象显示类型，可通过表达式查询具体成员；尚未提供完整调用栈和对象展开器。调试组件在实际使用时才创建。

搜索窗口统一为搜索、搜索文件内容、替换、替换文件内容四个标签。支持区分大小写、全字匹配、前后方向、选区／全文、从光标／开头搜索。文件范围支持当前、已打开、项目文件；项目搜索可以读取尚未打开的文件。跨文件替换会打开匹配的项目文件并修改编辑缓冲区，**不自动写入磁盘**；每个文件可撤销，再使用全部保存。开启替换确认后逐次询问；跨文件操作可取消剩余替换。结果最多显示 10,000 条并提示缩小范围。全字边界对非 ASCII 字节采用保守的标识符规则，尚未完整区分所有 Unicode 标点。

快捷键窗口显示已移植命令，选中后直接按键；Esc／Delete 清除选中绑定，按钮可重置全部或选中项。保留已有自定义及旧默认值迁移规则。窗口菜单提供全屏、前后标签、打开文件列表；查看菜单可切换已有工具条。未移植的 TODO、双编辑视图等仍见 [快捷键对照](SHORTCUTS.md)。

环境选项包含基本、文件和路径、外部程序、文件关联四页。可以设置语言、编辑器主题、界面字体、报告标签位置及默认目录。默认目录仅在没有有效的最近目录时使用。程序资源路径只读。外部程序沿用“配置工具”的直接执行和参数替换规则。文件关联只修改当前用户的 `mimeapps.list`，只在勾选项发生改变后写入；适用于已安装的 `dev-cpp.desktop`。

AStyle 选项显示括号风格、Tab／空格、宽度、行长和缩进类型，以及可编辑的最终参数与代码预览。更改选项会重新生成参数；手工参数按等价形式保存，换行可分隔选项；后续改动选项会用界面选项替换它们。预览最多使用当前源码的前 40,000 字节；实际格式化处理整个文件，作为一次可撤销编辑，不自动保存。需要系统 `astyle` 软件包。修正了 GTK2 参数文本框在完成编辑后保留鼠标抓取、导致确定按钮首次点击无效的问题；仍按住鼠标选择文字时保留正常选择行为。

自动保存继续写入私有恢复副本，**不覆盖源码**。可以选择当前／全部打开／项目文件，以及覆盖恢复副本、附加 UNIX 时间戳或格式化时间戳。带时间戳的副本不会自动清理，请按需清理 `~/.cache/dev-cpp/autosave/`（设置了 `XDG_CACHE_HOME` 时使用对应缓存目录）。

启动改动和测试边界见 [启动说明](STARTUP.md)。原版的完整项目模板、所有环境选项、Windows DevPak、性能分析、第二编辑视图和高级调试仍未完成；本轮不宣称所有界面已经逐像素还原。

## English

This beta continues the port against Orwell Dev-C++ 5.11's `main.dfm`, `EditorOptFrm.dfm` and `EditorOptFrm.pas` at the immutable commit linked above, plus the supplied screenshots. Decorations, native controls and font rendering remain provided by Linux/GTK.

Editor Options retains six pages. Code has Inserts/Default Code subpages; Completion has engine/symbol subpages. Pairing, individual delimiter types, block comments and paired deletion are configurable, as are automatic member-completion delay, background and local-header scanning. Full system-header indexing remains unavailable.

The original sixteen-line syntax sample uses rows 7/9/11/15 for breakpoint/active breakpoint/error/selection, with red/blue/maroon/navy full-line backgrounds. These colors, gutter and fold-marker colors are editable and used by the actual editor. Selecting multiple lines no longer creates an extra selection-fold marker; normal code folds remain.

`.in`, `.out` and `.ans` always use plain text. Other extensions outside the configured source list also skip C++ highlighting, matching, navigation, completion and function hints. Untitled source buffers remain C++. Save As updates the mode after an extension change.

Two sidebar arrows reveal Project/Classes/Debug pages. GDB locals refresh after stops and steps alongside expression watches. Aggregates show their type; expressions can inspect members. Full stack/object browsers remain pending. Debugger widgets are created on demand.

The four search tabs support case/whole-word matching, direction, selection/document and caret/start origins. File scope includes current/open/project files, including unopened project sources. Cross-file replacements modify undoable editor buffers and **do not save automatically**; use Save All afterward. Confirmation asks per occurrence; cancellation stops remaining replacements. Results are capped at 10,000 with a refinement notice. Non-ASCII word boundaries conservatively treat UTF-8 bytes as identifiers; complete Unicode punctuation classification remains pending.

Shortcut Options lists ported actions and captures keys directly. Escape/Delete clears the selected binding; buttons reset selected/all defaults. Existing custom bindings and factory-value migration remain. Window contains fullscreen, previous/next and open-file lists. View toggles existing toolbars. See the [shortcut audit](SHORTCUTS.md) for unported actions.

Environment Options has Basic/Files and folders/External programs/File associations pages. It supports language, editor theme, UI font, report-tab position and a fallback default directory. Resource paths are read-only. External tools retain direct execution and literal argument substitution. Only changed association checkboxes update the current user's `mimeapps.list`, for an installed `dev-cpp.desktop`.

AStyle Options provides style, indentation, width/line length, editable final arguments and a preview capped at the first 40,000 source bytes. Changing controls regenerates arguments; accepted manual arguments are saved in equivalent form, with line breaks separating options, until controls change again. Actual formatting processes the whole buffer as one undoable edit without saving. It requires optional system `astyle`. A GTK2 memo selection grab left behind after editing is released once mouse buttons are up, so the first confirmation click works while active text drags remain intact.

Auto save continues to create private recovery copies, **never overwriting source files**. Scope can be current/all open/project files, with fixed recovery names or UNIX/formatted timestamps. Timestamped copies are retained until manually cleaned from `~/.cache/dev-cpp/autosave/` or the configured XDG cache directory.

See [startup notes](STARTUP.md) for performance changes and measurement limits. Full project templates, all upstream environment options, Windows DevPak, profiling, a second editor view and advanced debugging remain incomplete; this beta does not claim pixel-identical restoration.
