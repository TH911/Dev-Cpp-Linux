# Dev-Cpp v1.2.0

## 中文

正式版合入此前 beta 分支的移植改进，并修复部分输入框文字像禁用状态一样呈灰色的问题。

- 编译器选项、编辑器选项、运行参数、编译日志、调试输入及“关于”详情使用清晰的黑字白底；选中文字保留 GTK 原生高亮，真正禁用的控件仍显示禁用配色。
- 修复覆盖模态窗口重建控件的情况，不改变输入框的可编辑/只读状态及保存、取消逻辑。
- 包含原版 11 套主题和 33 份语言资源、科学计数法高亮、菜单弹窗响应改进、中英双语 README 及安装更新指南。原版没有提供的 Linux 专用译文回退英语。
- 保持 Dev-Cpp 名称和原版图标，提供 amd64 `.deb` 以及仅含 `linux-noi-lazarus/` 的 ZIP、tar.gz 源码归档。

安装或覆盖更新前，请保存代码并关闭旧窗口。下载新版 `.deb` 后，可按 [README 更新说明](../README.md#使用命令行更新已安装的-dev-cpp) 操作；用户设置会保留。

验证使用 Ubuntu 20.04、Lazarus 2.0.6、FPC 3.0.4、GCC/G++ 9.3 和 GDB 9.1，包含真实 GTK2 鼠标聚焦与选区对比度检查，以及文件、编辑、项目、编译、调试和安装/卸载回归。NOI Linux 原版 GNOME 桌面的焦点、缩放和终端表现仍需实机验收。

## English

This stable release incorporates the previous beta improvements and fixes input text that looked gray and disabled even in editable fields.

- Compiler/editor options, runtime parameters, compiler logs, debugger inputs and About details use readable black-on-white text. Selection retains native GTK highlight colors; disabled controls keep their insensitive appearance.
- The fix handles native controls recreated for modal dialogs and preserves editing, read-only, Save and Cancel behavior.
- Includes all eleven original themes and thirty-three language catalogs, scientific-literal highlighting, more responsive modal menus, bilingual READMEs and installation/update guides. Unavailable Linux-specific translations fall back to English.
- Retains the Dev-Cpp name and original icon, with an amd64 `.deb` and source ZIP/tar.gz archives rooted at `linux-noi-lazarus/`.

Save your work and close old windows before updating. Download the new `.deb` and follow the [README update guide](../README.md#command-line-updates). User settings are retained.

Verification uses Ubuntu 20.04, Lazarus 2.0.6, FPC 3.0.4, GCC/G++ 9.3 and GDB 9.1, covering actual GTK2 mouse focus and selection contrast, file/edit/project/build/debug regressions, and package installation/removal. Stock NOI Linux GNOME focus, scaling and terminal behavior still require desktop acceptance testing.
