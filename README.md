# Dev-Cpp-Linux

基于 Lazarus/LCL 的 Dev-C++ 原生 Linux 移植版，目标运行环境为 **NOI Linux 2.0（64 位）**。当前发布版本为 [v1.0.0](https://github.com/TH911/Dev-Cpp-Linux/releases/tag/v1.0.0)；`main` 包含后续修复和移植工作。

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

本轮工作改进了 Home/Shift+Home、编辑撤销、保存冲突、编译取消和焦点处理，并加入 GDB 断点/单步/求值/程序输入输出、四套编辑器主题、命名编译器配置、执行参数、书签和最近文件。详细功能、快捷键及限制见 [移植版说明](linux-noi-lazarus/README.md) 和 [原版 5.11 对齐清单](docs/DEVCPP-5.11-PARITY.md)，Issue 反馈见 [#2](https://github.com/TH911/Dev-Cpp-Linux/issues/2)。

后续 Release 除 GitHub 默认的整库源码外，会由 [发布工作流](.github/workflows/release.yml) 构建并附加以下资产：

- `linux-noi-lazarus-版本-src.zip` 和 `.tar.gz`：只包含 `linux-noi-lazarus/` 的源码、脚本和资源。
- `devcpp-noi_版本_amd64.deb`：预编译程序、桌面入口和运行资源。用 `sudo apt install ./devcpp-noi_版本_amd64.deb` 安装，APT 会处理编译器、GDB、GTK2 和终端依赖；安装版无需 Lazarus/FPC。

打包与卸载说明见 [PACKAGING.md](docs/PACKAGING.md)。源码仓库不提交可执行文件和安装包；既有 `v1.0.0` 标签保持不变，上述资产适用于后续发布。未发布的构建也可从 [Actions](https://github.com/TH911/Dev-Cpp-Linux/actions/workflows/noi-linux.yml) 下载。

兼容性检查使用 Ubuntu 20.04 amd64 容器，固定 Lazarus 2.0.6、FPC 3.0.4、GCC/G++ 9.3.0 和 GDB 9.1；[检查入口](ci/check.sh) 包含文件保存、编辑、运行参数、调试和真实 GTK2 交互回归，并验证压缩包及 `.deb` 安装/卸载。容器使用 Xvfb 和 XTerm，NOI Linux 2.0 原版 GNOME 桌面的显示、焦点及 GNOME Terminal 行为仍需实机验收。
