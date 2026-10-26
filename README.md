# Dev-Cpp-Linux

基于 Lazarus/LCL 的 Dev-C++ 原生 Linux 移植版，目标运行环境为 **NOI Linux 2.0（64 位）**。最近稳定版本为 **[v1.1.2](https://github.com/TH911/Dev-Cpp-Linux/releases/tag/v1.1.2)**，本分支测试版本为 **1.1.3~beta1**。

开发与测试改动先推送到 [`beta`](https://github.com/TH911/Dev-Cpp-Linux/tree/beta)；`main` 保留稳定发布源码。测试包可从 [beta 的 Actions](https://github.com/TH911/Dev-Cpp-Linux/actions/workflows/noi-linux.yml?query=branch%3Abeta) 下载，不会自动发布为稳定 Release。beta 已加入 [Consolas 字体支持与安装说明](linux-noi-lazarus/FONTS.md)。

本次 beta 同时修复科学计数法高亮，`1e5`、`1e-5f` 等在 Classic Plus 主题中使用原版的紫色。

目标工具链以 [NOI 官方环境说明](https://www.noi.cn/gynoi/jsgz/2021-07-16/732450.shtml) 为准：

| 组件 | 版本 |
| --- | --- |
| Ubuntu | 20.04.1 |
| Lazarus | 2.0.6 |
| Free Pascal | 3.0.4 |
| GCC / G++ | 9.3.0 |
| GDB | 9.1 |

在 NOI Linux 2.0 桌面中，将源码解压到可写目录，在终端运行：

```sh
cd Dev-Cpp-Linux/linux-noi-lazarus
bash run.sh
# 也可以打开指定源文件或项目：
bash run.sh /path/to/main.cpp
bash run.sh /path/to/project.dev
```

首次运行会使用系统预装的 `lazbuild` 编译。F9 编译，F10 运行，F11 编译并运行。后续启动可使用 `bash launch.sh`；源码有更新时会重新编译。请保留可执行文件旁的脚本和 `icons/` 目录。

1.1.2 保留原版已有的按钮，并整理调试面板，使布局更接近 Orwell Dev-C++ 5.11：底部左侧放调试操作与表达式结果，右侧放程序输出/GDB 日志，左侧 Debug 页列出断点。源码行号或标记区支持单击切换断点，红点和黄色箭头分别标识断点与当前执行行。关于窗口显示版本、可点击 GitHub 链接、许可证及安装和构建信息，详情可用 Ctrl+A/C 复制。调试、行号交互和关于窗口已通过真实 GTK2 回归，界面按原版结构整理，并非像素复刻。

程序名称统一为 **Dev-Cpp**，安装版与源码版使用同一份原版图标。源码启动提示读取实际程序版本，不再显示旧的 v1.0.0。

安装版启动器已修复：使用独立的“Dev-Cpp”系统菜单入口与窗口标识，识别并备份旧版自动生成的源码启动入口，防止安装 `.deb` 后仍启动旧目录中的程序。安装、旧入口迁移和确认实际运行版本的步骤见 [打包与安装说明](docs/PACKAGING.md)。已有 Home/Shift+Home、编辑撤销、保存冲突、编译取消、GDB、主题与命名编译器配置等功能的范围见 [移植版说明](linux-noi-lazarus/README.md) 和 [原版 5.11 对齐清单](docs/DEVCPP-5.11-PARITY.md)。

Release 除 GitHub 默认的整库源码外，由 [发布工作流](.github/workflows/release.yml) 构建并附加以下资产：

- `linux-noi-lazarus-版本-src.zip` 和 `.tar.gz`：只包含 `linux-noi-lazarus/` 的源码、脚本和资源。
- `devcpp-noi_版本_amd64.deb`：预编译程序、桌面入口和运行资源。用 `sudo apt install ./devcpp-noi_版本_amd64.deb` 安装，APT 会处理编译器、GDB、GTK2 和终端依赖；安装版无需 Lazarus/FPC。

打包与卸载说明见 [PACKAGING.md](docs/PACKAGING.md)。源码仓库不提交可执行文件和安装包；既有发布标签保持不变。Release 的安装包和源码归档由发布工作流验证后上传；未发布的构建也可从 [Actions](https://github.com/TH911/Dev-Cpp-Linux/actions/workflows/noi-linux.yml) 下载。

兼容性检查使用 Ubuntu 20.04 amd64 容器，固定 Lazarus 2.0.6、FPC 3.0.4、GCC/G++ 9.3.0 和 GDB 9.1；[检查入口](ci/check.sh) 包含文件保存、编辑、运行参数、调试和真实 GTK2 交互回归；[打包检查](ci/build-and-package.sh) 另验证压缩包及 `.deb` 安装/卸载。容器使用 Xvfb 和 XTerm，NOI Linux 2.0 原版 GNOME 桌面的显示、焦点及 GNOME Terminal 行为仍需实机验收。
