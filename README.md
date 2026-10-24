# Dev-Cpp-Linux

基于 Lazarus/LCL 的 Dev-C++ 原生 Linux 移植版，目标运行环境为 **NOI Linux 2.0（64 位）**。

目标工具链以 [NOI 官方环境说明](https://www.noi.cn/gynoi/jsgz/2021-07-16/732450.shtml) 为准：

| 组件 | 版本 |
| --- | --- |
| Ubuntu | 20.04.1 |
| Lazarus | 2.0.6 |
| Free Pascal | 3.0.4 |
| GCC / G++ | 9.3.0 |

在 NOI Linux 2.0 桌面中，将仓库解压到可写目录，在终端运行：

```sh
cd Dev-Cpp-Linux/linux-noi-lazarus
bash run.sh
```

也可以打开指定源文件或项目：

```sh
bash run.sh /path/to/main.cpp
bash run.sh /path/to/project.dev
```

首次运行会使用系统预装的 `lazbuild` 编译。F9 编译，F10 运行，F11 编译并运行。
后续启动可使用 `bash launch.sh`；源码有更新时会重新编译。
请保留可执行文件旁的脚本和 `icons/` 目录。

详细功能和当前限制见 [移植版说明](linux-noi-lazarus/README.md)。

兼容性检查使用 Ubuntu 20.04 容器，固定 Lazarus 2.0.6、FPC 3.0.4 和 GCC/G++ 9.3.0，
并通过虚拟显示验证 F9/F10/F11、中文与空格路径、单实例文件转发。
配置见 [GitHub Actions](.github/workflows/noi-linux.yml)。
容器测试使用 XTerm，NOI Linux 2.0 原版 GNOME 桌面的显示和终端行为仍需实机验收。

也可以从 [Actions 构建记录](https://github.com/TH911/Dev-Cpp-Linux/actions/workflows/noi-linux.yml)
中选择成功的检查，下载 `devcpp-noi-linux-2.0-x86_64` 构建包。
包内包含已测试的二进制、对应源码和运行脚本；解压后在 `linux-noi-lazarus` 目录运行 `bash launch.sh`。
