# 原版界面与当前行为 / Classic UI and current behavior

## 中文

本轮以用户提供的 Windows Dev-C++ 5.11 截图为基准，版本为 `1.3.1~beta2`。窗口、菜单、关于和桌面入口显示 **Dev-C++**；主命令、包名和配置目录使用 `dev-cpp`。界面还在还原，Linux 原生窗口、字体渲染和控件不会与 Windows 完全一致。

- **编辑菜单**：恢复插入、设置/跳至书签、注释、缩进/取消缩进、全部折叠/展开、复制/删除行和移动选区的分组。已有自定义快捷键保留。
- **编辑器属性**：按原版分为基本、显示、语法、代码、代码补全、自动保存。显示页提供编辑器字体、字号、行号字体、栏距、行号起始值和前导零；字体下拉列表预览各字体。选择 Consolas 需要先安装合法取得的字体，安装包不附带微软字体。
- **语法页**：实际编辑器预览、11 套原版主题、逐项前景/背景和粗体/斜体/下划线设置。科学计数法继续使用实际 C++ 词法分类。
- **代码页**：自定义插入片段和新文件默认代码。片段出现在“编辑 → 插入”，多行文本按原样保存。取消对话框不应用修改。
- **编译器**：未自定义的旧 Default 配置保留，并一次性增加真实的 `GCC 64-bit Release`、`Debug`、`Profiling` 配置。Profiling 加入 `-pg`，但尚无完整性能报告界面。已有自定义配置不自动改写。Linux 不显示未安装的 MinGW/TDM 编译器。
- **调试**：底部左侧两排操作、表达式历史及查看结果；右侧 GDB 命令框和输出。下一行、进入函数、跳出函数、逐指令及停止均连接 GDB。CPU 窗口显示寄存器和当前位置反汇编。运行期间保留程序终端页供输入输出。

“自动保存”当前生成**恢复副本**，不覆盖原始源码，也不清除文档的未保存标记。启用后按设置间隔保存到 `${XDG_CACHE_HOME:-~/.cache}/dev-cpp/autosave/`；未命名文件也有副本。异常退出后可在文件管理器中打开该目录，选择所需 `.cpp` 文件并另存为源码。当前还没有自动恢复选择对话框，副本不会自动清理。

函数和编辑器提示使用当前文件的轻量索引，不能代替完整 C++ 语义分析。GDB 命令直接交给调试器；在命令框手工改变断点时，行号区的断点列表尚不能保证完整同步。真实 GTK2 测试验证设置保存/取消、恢复副本、调试与原有交互，NOI Linux 原生 GNOME 桌面仍需实际使用验证。

## English

This beta (`1.3.1~beta2`) follows the supplied Windows Dev-C++ 5.11 screenshots. The display name is **Dev-C++**; the executable, command, package and configuration directory use `dev-cpp`. Restoration remains ongoing; Linux window decorations, rendering and native controls differ from Windows.

- **Edit** restores insert, bookmark, comment, indent, folding and line-operation groups. Existing customized shortcuts remain valid.
- **Editor properties** has Basic, Display, Syntax, Code, Code completion and Auto save pages. Display includes font previews, sizes, gutter spacing, custom line-number font, zero-based numbering and leading zeros. Consolas requires a legally installed font; Microsoft font files are not redistributed.
- **Syntax** uses the actual editor/lexer for previews, with all 11 original presets and per-token foreground/background/style overrides, including scientific-notation classification.
- **Code** supports multiline insertion snippets and a default new-file template. Cancel discards dialog edits.
- **Compiler profiles** retain an untouched Default and add actual GCC 64-bit Release, Debug and Profiling profiles once. Profiling adds `-pg`; a complete profiling report UI remains unimplemented. Customized compiler configurations are preserved; uninstalled MinGW/TDM compilers are not listed.
- **Debugging** restores two rows of actions, expression history/results, a GDB command field and output. Source/instruction stepping, finish and stop invoke GDB. The CPU window shows registers and disassembly. An active session retains a program terminal page for stdin/stdout.

Auto save currently writes **recovery copies**, preserving source files and dirty-buffer markers. When enabled, copies are written at the selected interval under `${XDG_CACHE_HOME:-~/.cache}/dev-cpp/autosave/`, including unnamed buffers. After an unexpected exit, open that directory in the file manager and save the desired `.cpp` elsewhere. There is no automatic recovery chooser or automatic copy cleanup yet.

Hints use a lightweight source index rather than complete C++ semantic analysis. Console commands go directly to GDB; manually changing breakpoints there may not fully synchronize gutter indicators. Native GTK2 tests cover preferences, recovery, debugger behavior and existing interactions; the original NOI Linux GNOME desktop still needs real-device acceptance.
