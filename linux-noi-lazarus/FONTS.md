# Consolas 字体

`beta` 分支增加 Consolas 优先与缺失字体回退支持。Consolas 字体文件需要由用户自行安装，源码和安装包不附带该字体。

Windows 随附字体的普通许可不包含随应用再次分发的权利；应用打包需另行取得授权，详见[微软字体分发说明](https://learn.microsoft.com/en-us/typography/fonts/font-faq#redistribution-and-extended-rights)。本项目当前没有 Consolas 再分发授权，因此不把它附在公开的 `.deb` 或源码归档中。

将自己有权使用的 Consolas `.ttf` 文件（常见文件名为 `consola.ttf`、`consolab.ttf`、`consolai.ttf`、`consolaz.ttf`）复制到用户字体目录，无需 sudo：

```bash
mkdir -p ~/.local/share/fonts/Consolas
# 将字体文件放入以上目录，然后刷新字体缓存：
fc-cache -f
fc-match -f '%{family}\n' Consolas
```

最后一条命令应显示 `Consolas`。如果显示 DejaVu Sans Mono 等其他名称，说明系统仍在替代缺失字体，不能表示 Consolas 已安装成功。字体安装后请完全退出并重新打开 dev-cpp-linux，以刷新 GTK 的字体列表。

在“工具 → 编辑器选项”中，将字体设为 `Consolas` 并确定。所选字体名同时用于已打开和新建的编辑器、编译日志、代码补全和函数提示，并在重启后保留。已有的其他字体设置不会被自动覆盖。

没有保存过字体设置的新用户，在系统已安装 Consolas 时默认使用它；未安装时依次选择 DejaVu Sans Mono、Liberation Mono、Noto Sans Mono，最后使用系统 Monospace。手动选择 Consolas 后即使字体暂时缺失，也会保留这一偏好，并使用等宽字体显示；以后安装字体并重启即可生效。调试终端和 GDB 日志也会优先使用系统已安装的 Consolas。
