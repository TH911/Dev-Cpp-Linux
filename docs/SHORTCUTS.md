# 快捷键与保存目录 / Shortcuts and save folders

## 中文

基准是 Orwell Dev-C++ **5.11** 官方提交 [`0e4d598b172efd7df97b7ecc941d6aa08340cd70`](https://sourceforge.net/p/orwelldevcpp/code/ci/0e4d598b172efd7df97b7ecc941d6aa08340cd70/tree/) 的 `Source/main.dfm`、`Source/README.txt`、`Source/main.pas` 和 SynEdit 默认键表。以下逐项记录带快捷键的 Action/菜单定义；表中的“绑定一致”表示默认键一致，不表示整个功能已完整移植。

`v1.3.1-beta4` 恢复 **Ctrl+Shift+S → 全部保存**、**Ctrl+Shift+A → AStyle 格式化当前文件**。**另存为**按原版没有默认快捷键，从“文件 → 另存为”进入，也可在“工具 → 快捷键选项”自行指定。格式化需要可选的系统 `astyle` 软件包，未安装时会提示。F2 可在编译时中止编译；Alt+F4 对应退出。

旧设置第一次载入时，只迁移能识别的旧默认值：另存为的 Ctrl+Shift+S 清空，全部保存的 Ctrl+Shift+A 改为 Ctrl+Shift+S。其他自定义或禁用设置保留。若自定义绑定占用了 Ctrl+Shift+A，格式化不会抢占该键；可在快捷键选项中调整。自定义值恰好等于旧默认值时，无法判断设置意图，将按旧默认值迁移。

新建源码第一次保存默认进入**最近一次成功打开或保存源码/项目的目录**。文件名仍由用户决定；Ctrl+Shift+S 遇到多个未命名且有修改的文件时逐个询问文件名，取消后停止后续保存。目录在重启后保留。已有源码“另存为”优先使用它所在的目录；仅在文件对话框中浏览、取消或保存失败不会修改记忆目录。记忆目录已被删除时回退到用户主目录。中文与含空格的路径使用无损编码保存。

仍有差异：Find All 只搜索已打开文档，Replace All 只作用于当前文档；F12 目前与 F9 一样全量编译；F6 只能停止受控 GDB 会话，外部普通运行终端尚不能由它终止。Ctrl+I 增量搜索、Ctrl+Shift+G 函数跳转、Ctrl+M 双编辑区、Ctrl+T TODO、Ctrl+F12 全屏工具栏、F1 帮助及项目树 F2 重命名仍未完整移植。Ctrl+T/M/I 在源码区保留给原版功能，不允许回退为 SynEdit 的删词/换行等其他操作；自定义绑定仍优先。Ctrl+F2 测试动作也尚未移植。

## English

The reference is the immutable official Orwell Dev-C++ **5.11** commit linked above, including `main.dfm`, `README.txt`, `main.pas` and SynEdit defaults. The table audits every explicit shortcut-bearing Action/menu definition. “Binding matches” describes the default key, not complete feature parity.

**Ctrl+Shift+S saves all files**; **Ctrl+Shift+A formats the current file** using optional system `astyle`. **Save As has no default key**, matching 5.11; use File → Save As or assign a custom shortcut. F2 aborts an active compilation; Alt+F4 exits. Known old factory values migrate once, while other custom/disabled values remain. A custom assignment takes precedence over the new format default. An intentional custom value identical to an old factory value cannot be distinguished and migrates as a factory value.

A new source file's first save starts in the **last successfully opened/saved source or project directory**. Save All prompts for each modified unnamed file and stops on Cancel. The directory persists across restarts. Save As for a named source starts beside that source. Browsing, cancellation and failed saves do not change the remembered directory; a deleted directory falls back to the user's home. UTF-8 paths and spaces are preserved.

Remaining differences: Find All searches open buffers; Replace All changes the active buffer; F12 currently rebuilds the same scope as F9. F6 stops managed GDB sessions, not ordinary external terminal processes. Incremental search, function-jump shortcut, split editor, TODO, fullscreen bars, F1 help and project-tree F2 rename remain incomplete. In the source editor Ctrl+T/M/I are reserved rather than falling through to unrelated SynEdit word deletion/newline commands; custom assignments still take priority. The original Ctrl+F2 test action is also pending.

## Action 对照 / Action audit

| 原版 Action / Menu | 原版键 / Key | 移植状态 / Port status |
| --- | --- | --- |
| `Abortcompilation2` | `F2` | 绑定一致 / Binding matches |
| `actNewSource` | `Ctrl+N` | 绑定一致 / Binding matches |
| `actOpen` | `Ctrl+O` | 绑定一致 / Binding matches |
| `actSave` | `Ctrl+S` | 绑定一致 / Binding matches |
| `actSaveAll` | `Ctrl+Shift+S` | 绑定一致 / Binding matches |
| `actClose` | `Ctrl+W` | 绑定一致 / Binding matches |
| `actCloseAll` | `Ctrl+Shift+W` | 绑定一致 / Binding matches |
| `actPrint` | `Ctrl+P` | 绑定一致 / Binding matches |
| `actExit` | `Alt+F4` | 绑定一致 / Binding matches |
| `actUndo` | `Ctrl+Z` | 绑定一致 / Binding matches |
| `actRedo` | `Ctrl+Y` | 绑定一致 / Binding matches |
| `actCut` | `Ctrl+X` | 绑定一致 / Binding matches |
| `actCopy` | `Ctrl+C` | 绑定一致 / Binding matches |
| `actPaste` | `Ctrl+V` | 绑定一致 / Binding matches |
| `actSelectAll` | `Ctrl+A` | 绑定一致 / Binding matches |
| `actFind` | `Ctrl+F` | 绑定一致 / Binding matches |
| `actFindAll` | `Ctrl+Shift+F` | 键一致，范围有限 / Matching key, limited scope |
| `actReplace` | `Ctrl+R` | 绑定一致 / Binding matches |
| `actReplaceAll` | `Ctrl+Shift+R` | 键一致，范围有限 / Matching key, limited scope |
| `actIncremental` | `Ctrl+I` | 待移植 / Pending |
| `actGotoLine` | `Ctrl+G` | 绑定一致 / Binding matches |
| `actProjectOptions` | `Ctrl+H` | 绑定一致 / Binding matches |
| `actCompile` | `F9` | 绑定一致 / Binding matches |
| `actRun` | `F10` | 绑定一致 / Binding matches |
| `actCompRun` | `F11` | 绑定一致 / Binding matches |
| `actRebuild` | `F12` | 键一致，范围有限 / Matching key, limited scope |
| `actDebug` | `F5` | 绑定一致 / Binding matches |
| `actFullScreen` | `Ctrl+F11` | 绑定一致 / Binding matches |
| `actNext` | `Ctrl+Tab` | 绑定一致 / Binding matches |
| `actPrev` | `Ctrl+Shift+Tab` | 绑定一致 / Binding matches |
| `actUnitRename` | `F2` | 待移植 / Pending |
| `actShowBars` | `Ctrl+F12` | 待移植 / Pending |
| `actBreakPoint` | `F4` | 绑定一致 / Binding matches |
| `actStopExecute` | `F6` | 键一致，范围有限 / Matching key, limited scope |
| `actSwapHeaderSource` | `Ctrl+Q` | 绑定一致 / Binding matches |
| `actComment` | `Ctrl+.` | 绑定一致 / Binding matches |
| `actUncomment` | `Ctrl+,` | 绑定一致 / Binding matches |
| `actToggleComment` | `Ctrl+/` | 绑定一致 / Binding matches |
| `actToggleCommentInline` | `Ctrl+;` | 绑定一致 / Binding matches |
| `actIndent` | `Tab` | 绑定一致 / Binding matches |
| `actUnindent` | `Shift+Tab` | 绑定一致 / Binding matches |
| `actGotoFunction` | `Ctrl+Shift+G` | 待移植 / Pending |
| `actSyntaxCheckFile` | `Ctrl+F9` | 绑定一致 / Binding matches |
| `actAddToDo` | `Ctrl+T` | 待移植 / Pending |
| `actNextLine` | `F7` | 绑定一致 / Binding matches |
| `actStepLine` | `F8` | 绑定一致 / Binding matches |
| `actMsgCut` | `Ctrl+X` | 只读日志部分支持 / Partial read-only log support |
| `actMsgCopy` | `Ctrl+C` | 只读日志复制 / Copy from read-only log |
| `actMsgCopyAll` | `Ctrl+Shift+C` | 待移植 / Pending |
| `actMsgPaste` | `Ctrl+V` | 只读日志部分支持 / Partial read-only log support |
| `actMsgSelAll` | `Ctrl+A` | 只读日志全选 / Select read-only log |
| `actMsgSaveAll` | `Ctrl+S` | 未对齐，当前保存源码 / Not aligned; currently saves source |
| `actSearchAgain` | `F3` | 绑定一致 / Binding matches |
| `actRevSearchAgain` | `Shift+F3` | 绑定一致 / Binding matches |
| `actDeleteLine` | `Ctrl+D` | 绑定一致 / Binding matches |
| `actDuplicateLine` | `Ctrl+E` | 绑定一致 / Binding matches |
| `actMoveSelUp` | `Ctrl+Shift+Up` | 绑定一致 / Binding matches |
| `actMoveSelDown` | `Ctrl+Shift+Down` | 绑定一致 / Binding matches |
| `actCodeCompletion` | `Ctrl+Space` | 绑定一致 / Binding matches |
| `actHelp` | `F1` | 待移植 / Pending |
| `actSwapEditor` | `Ctrl+M` | 待移植 / Pending |
| `actOpenFolder` | `Ctrl+B` | 绑定一致 / Binding matches |
| `actFormatCurrentFile` | `Ctrl+Shift+A` | 绑定一致 / Binding matches |
| `actRunTests` | `Ctrl+F2` | 待移植 / Pending |

Tab / Shift+Tab 缩进、Ctrl+1…9 设置书签、Alt+1…9 跳至书签沿用原版；Home、方向键、选择、Ctrl+Backspace、Insert、Shift+Insert、Ctrl+Insert、Shift+Delete、Alt+Backspace 等编辑键继续交给 SynEdit。Linux 扩展 Ctrl+Alt+L（日志）、Ctrl+Alt+E（源码）和 Ctrl+Alt+O（编译器设置）保留，并可配置。

Tab/Shift+Tab and the original dynamic bookmark bindings are retained. Ordinary movement, selection, Ctrl+Backspace, Insert, Shift+Insert, Ctrl+Insert, Shift+Delete and Alt+Backspace remain SynEdit operations. Linux extensions Ctrl+Alt+L (log), Ctrl+Alt+E (source), and Ctrl+Alt+O (compiler settings) remain configurable.

自动回归 / Automated validation: `tests/shortcuts-test.lpr` checks 49 existing action bindings, duplicate defaults and custom-setting migration; `tests/save-shortcuts-ui-smoke.sh` checks real GTK keyboard input, saved bytes, multi-file prompts and chooser folders. Existing editor, focus, compiler and GDB suites remain required. This is not a claim that every 5.11 feature or every desktop keyboard layout is supported.

## 标签页排序 / Tab order

按住源码标签页并左右拖动，可调整已打开文件的顺序；未保存的文件也可移动。当前文档、源码缓冲区、未保存标记和撤销记录跟随原标签页，Ctrl+Tab / Ctrl+Shift+Tab、全部保存及关闭操作按新的顺序使用同一文档。仅调整本次窗口内的顺序，不会重命名或移动磁盘文件；重启后不会自动恢复窗口的打开文件列表。

Hold and drag a source tab left/right to reorder open files, including unnamed files. The document, source buffer, dirty state and Undo history remain attached to the same tab. Keyboard switching, Save All and Close use the reordered document identities. This changes the current window's order; it does not rename/move disk files or add cross-restart session restoration.

`tests/tab-order-ui-smoke.sh` uses actual GTK labels and mouse gestures to verify both directions, click/right/outside guards, active identity, keyboard order, saved bytes, close cancellation and Save All for a moved unnamed file.

## 撤销与重做历史 / Undo and redo history

源码编辑器不再按 SynEdit 默认的 1024 条上限丢弃较早操作，撤销和重做改用框架可表示的最大容量。历史保存在内存中，保存文件不会清空；关闭文档或确认从磁盘重新加载后不保留。新编辑仍会丢弃被放弃的重做分支。“成组恢复”仍控制一次 Ctrl+Z 合并哪些连续输入，和历史容量是两回事。已验证 6000 次独立编辑可以全部撤销至起点，再全部重做，内容逐字节一致。

Source editors no longer evict old operations after SynEdit's default 1024 actions. Undo and redo use the framework's maximum representable capacity. History resides in memory and survives Save; it is not retained after closing a document or confirming a disk reload. A new edit still discards the abandoned redo branch. Group undo controls which consecutive input is undone together, independently of history capacity. Regression checks exercise 6000 independent edits, full Undo/Redo and exact source-byte restoration.
