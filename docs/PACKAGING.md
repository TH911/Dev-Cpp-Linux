# Release 打包与安装

后续 Release 在 GitHub 默认的整库源码档案之外，由 [发布工作流](../.github/workflows/release.yml) 构建并额外上传本项目生成的三个资产。已发布的 `v1.0.0` 标签保持不变；新打包流程不把后续代码附到旧标签下。默认版本读取仓库根目录 `VERSION`；`--version v1.2.3` 可指定 Release tag，文件名和 Debian 版本会去掉开头的 `v`。

```bash
# Python 3.8+；源码打包只需要 Python 标准库。
python3 packaging/build-release.py source --output dist

# 在 Ubuntu 20.04 amd64 中先完成 GTK2 构建，再打二进制安装包。
bash linux-noi-lazarus/build.sh
python3 packaging/build-release.py deb --output dist \
  --binary linux-noi-lazarus/devcpp-noi

# CI 也可一次生成全部资产；此命令本身不会编译。
python3 packaging/build-release.py all --version v1.0.0 --output dist
python3 packaging/verify-artifacts.py --version v1.0.0 --output dist
```

以 `VERSION=1.0.0` 为例，Release 资产名称为：

- `linux-noi-lazarus-1.0.0-src.tar.gz`
- `linux-noi-lazarus-1.0.0-src.zip`
- `devcpp-noi_1.0.0_amd64.deb`

源码归档解压后直接得到 `linux-noi-lazarus/`，包含 Pascal/Lazarus 源码、构建和启动脚本、说明、许可证及运行资源。它们采用文件类型白名单，排除编译产物 `.o/.or/.ppu/.compiled`、可执行文件、`.build.lock`、IDE 会话、备份、临时文件和用户设置。新增运行资源类型时，请同步更新 `packaging/build-release.py` 中的白名单。归档内脚本为 0755，其他文件为 0644，不依赖 checkout 的权限。可设置 `SOURCE_DATE_EPOCH` 固定归档时间；默认固定为 1980-01-01，保证相同输入可重现。

Debian 打包需要 `dpkg-deb`，并拒绝非 amd64 ELF 输入。**发布的程序必须在 Ubuntu 20.04 amd64 中预先构建并验证**，不能把较新发行版生成的程序标为兼容 20.04。此工具不会替代目标系统上的兼容性测试。所有产物请写入未跟踪的构建目录，不要把程序或安装包提交到 Git。

## 自动发布

常规 [兼容性工作流](../.github/workflows/noi-linux.yml) 在 push、PR 和手动触发时执行检查并保存打包产物，供未发布版本试用。发布工作流在 Release 发布后签出该标签，使用同样的 Ubuntu 20.04 工具链重新构建和检查，然后上传 ZIP、tar.gz 和 `.deb`；也可指定标签手动触发。标签去掉开头的 `v` 后必须与该提交的 `VERSION` 一致，例如 `VERSION=1.2.3` 对应 `v1.2.3`。先更新版本并通过检查，再创建对应 Release。

构建资产来自标签所指向的源码。重复执行不得静默替换既有同名资产；需要修复发布内容时，使用包含修复的新版本标签。工作流失败时应检查 Actions，不能把“Release 已建立”当作资产已完成验证。

## 安装与卸载

```bash
sudo apt install ./devcpp-noi_1.0.0_amd64.deb
devcpp-noi
devcpp-noi --new-window '/home/user/中文 source/main.cpp'
sudo apt remove devcpp-noi
# purge 同样保留用户自己的设置和缓存。
sudo apt purge devcpp-noi
```

`apt install` 会安装 GCC、G++、GDB、GTK2 等共享库，以及 `gnome-terminal | xterm`。建议安装 `fonts-dejavu-core` 和 `fonts-noto-cjk` 保证等宽字体与中文显示。二进制发行不需要 Lazarus/FPC；从源码构建则按 `linux-noi-lazarus/README.md` 安装构建依赖。

安装位置：

| 位置 | 用途 |
| --- | --- |
| `/usr/bin/devcpp-noi` | 直接 exec 已编译程序，保留参数和调用者工作目录 |
| `/usr/lib/devcpp-noi/` | 程序、`console-pauser.sh`、`ui-language.sh`、窗口图标、工具栏图标及可用的 profiles |
| `/usr/share/applications/devcpp-noi.desktop` | 桌面菜单、支持的 C/C++ MIME 类型及“在新窗口打开”动作 |
| `/usr/share/icons/hicolor/scalable/apps/devcpp-noi.svg` | 系统桌面图标 |
| `/usr/share/doc/devcpp-noi/` | 说明和许可证 |

安装版入口不会运行开发目录的 `launch.sh`、`run.sh` 或 `build.sh`，不会尝试在 `/usr` 编译、写锁或注册用户桌面项。所有目录可供普通用户遍历，程序和资源可读。设置仍由程序保存到 `~/.config/devcpp-noi.ini`，卸载脚本不删除用户设置或缓存。菜单仅声明支持的文件类型，不执行 `xdg-mime default`，不修改 `mimeapps.list`；如需默认打开应用，请通过桌面“打开方式”自行选择。若之前从源码运行并生成了用户级同名 desktop 文件，它可能遮盖系统菜单项；可自行删除 `~/.local/share/applications/devcpp-noi.desktop` 后刷新菜单。

## 验证

先验证压缩包内容一致、构建产物排除、Debian 元数据、依赖、启动器和文件权限：

```bash
python3 packaging/verify-artifacts.py --version v1.0.0 --output dist
# 只有源码资产时：
python3 packaging/verify-artifacts.py --source-only --version v1.0.0 --output dist
```

安装验证会实际安装和卸载包，**仅在一次性 Ubuntu 20.04 amd64 容器中以 root 运行**。镜像须已安装本包全部依赖及 `xvfb xauth xdotool`；可选 `desktop-file-utils` 验证 desktop 文件。依赖不齐时先用 `apt install ./包文件.deb` 解决依赖，再移除该包，恢复到未安装状态后运行验证；CI 更适合预先安装依赖。脚本拒绝覆盖已有的 `devcpp-noi` 安装。

```bash
bash packaging/verify-install.sh dist/devcpp-noi_1.0.0_amd64.deb
```

验证包括：`dpkg -i`、普通用户启动并打开含空格的中文相对路径、IPC 转发到现有窗口、F11 实际编译运行 C++ 程序、`/usr/lib` 无变化和锁文件、文件类型默认关联保持不变、卸载和 purge 后设置保留。脚本需要能够创建 Xvfb 显示的容器，且结束后删除自己的临时 HOME。
