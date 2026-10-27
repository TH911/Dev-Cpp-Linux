# Release 打包与安装

后续 Release 在 GitHub 默认的整库源码档案之外，由 [发布工作流](../.github/workflows/release.yml) 构建并额外上传本项目生成的三个资产。已发布标签保持不变；修复以新版本发布。默认版本读取仓库根目录 `VERSION`；`--version v1.2.3` 可指定 Release tag，文件名和 Debian 版本会去掉开头的 `v`。

```bash
# Python 3.8+；源码打包只需要 Python 标准库。
python3 packaging/build-release.py source --output dist

# 在 Ubuntu 20.04 amd64 中先完成 GTK2 构建，再打二进制安装包。
bash linux-noi-lazarus/build.sh
python3 packaging/build-release.py deb --output dist \
  --binary linux-noi-lazarus/devcpp-noi

# CI 也可一次生成全部资产；此命令本身不会编译。
python3 packaging/build-release.py all --version v1.1.2 --output dist
python3 packaging/verify-artifacts.py --version v1.1.2 --output dist
```

以 `VERSION=1.1.2` 为例，Release 资产名称为：

- `linux-noi-lazarus-1.1.2-src.tar.gz`
- `linux-noi-lazarus-1.1.2-src.zip`
- `devcpp-noi_1.1.2_amd64.deb`

源码归档解压后直接得到 `linux-noi-lazarus/`，包含 Pascal/Lazarus 源码、构建和启动脚本、说明、许可证及运行资源。它们采用文件类型白名单，排除编译产物 `.o/.or/.ppu/.compiled`、可执行文件、`.build.lock`、IDE 会话、备份、临时文件和用户设置。新增运行资源类型时，请同步更新 `packaging/build-release.py` 中的白名单。归档内脚本为 0755，其他文件为 0644，不依赖 checkout 的权限。可设置 `SOURCE_DATE_EPOCH` 固定归档时间；默认固定为 1980-01-01，保证相同输入可重现。

Debian 打包需要 `dpkg-deb`，并拒绝非 amd64 ELF 输入。**发布的程序必须在 Ubuntu 20.04 amd64 中预先构建并验证**，不能把较新发行版生成的程序标为兼容 20.04。此工具不会替代目标系统上的兼容性测试。所有产物请写入未跟踪的构建目录，不要把程序或安装包提交到 Git。

## 检查与按需发布

常规 [兼容性工作流](../.github/workflows/noi-linux.yml) 在 push、PR 和手动触发时执行检查并保存打包产物。推送到 `beta` 和普通手动运行均只检查和保存构建产物，不创建 **Pre-release**。只有用户明确要求发行后，才在 `beta` 分支手动运行并启用 `publish_beta`；完整构建、GTK2 回归和安装检查均通过后，发布任务才使用同一次构建的产物创建 **Pre-release**。发布标签固定到通过检查的提交；三个附件先上传到草稿，全部成功后再公开，并保留最新稳定 Release。

beta 版本使用 `1.1.3~beta3` 格式，Git 标签将 `~` 转成 `-`，对应 `v1.1.3-beta3`。GitHub 会改写附件名中的 `~`，因此上传时明确使用连字符，例如 `devcpp-noi_1.1.3-beta3_amd64.deb`；安装包内部版本仍为 `1.1.3~beta3`，本地构建和 Actions 产物文件名也保留 `~`。发布新测试内容时递增 beta 编号，并同步 `VERSION`、应用版本、`PORT_REVISION` 和相关说明；已发布的版本不能用于另一提交。重跑同一提交不会覆盖已有附件，未完成的草稿可继续上传。

正式 [发布工作流](../.github/workflows/release.yml) 在 Release 发布后签出该标签，使用同样的 Ubuntu 20.04 工具链重新构建和检查，然后上传 ZIP、tar.gz 和 `.deb`；也可指定已经公开的 Release 标签手动触发（按标签查询接口不提供草稿）。正式版标签去掉 `v` 后与 `VERSION` 一致，例如 `VERSION=1.2.3` 对应 `v1.2.3`；手动构建 beta 标签时同样使用上述 `~` → `-` 映射。

构建资产来自标签所指向的源码。重复执行不得静默替换既有同名资产；需要修复发布内容时，使用包含修复的新版本标签。工作流失败时应检查 Actions，不能把“Release 已建立”当作资产已完成验证。

## 安装与卸载

```bash
sudo apt install ./devcpp-noi_1.1.2_amd64.deb
/usr/bin/devcpp-noi --version
/usr/bin/devcpp-noi
/usr/bin/devcpp-noi --new-window '/home/user/中文 source/main.cpp'
sudo apt remove devcpp-noi
# purge 同样保留用户自己的设置和缓存。
sudo apt purge devcpp-noi
```

`apt install` 会安装 GCC、G++、GDB、GTK2 等共享库，以及 `gnome-terminal | xterm`。建议安装 `fonts-dejavu-core` 和 `fonts-noto-cjk` 保证等宽字体与中文显示。二进制发行不需要 Lazarus/FPC；从源码构建则按 `linux-noi-lazarus/README.md` 安装构建依赖。

## 双击安装 `.deb`

若右键已经有“用『软件安装』打开”，但点击没有反应，请先阅读
[NOI Linux “软件安装”修复指南](NOI-LINUX-SOFTWARE-INSTALL.md)。文档包含确认 Snap Store、
更新 snapd、处理 core24 和用户会话服务报错的完整步骤，以及如何理解安装页面的提示。

`.deb` 是标准 Debian 软件包，图形安装由 NOI Linux 桌面的“软件安装”或 GDebi 处理，不需要赋予包文件可执行权限。若双击没有安装器或打开了压缩管理器，可先安装 GDebi：

```bash
sudo apt install gdebi
```

然后右键 `.deb` →“使用其他应用打开”→“GDebi 软件包安装程序”；在文件属性的“打开方式”中将其设为默认后，即可双击安装。需要认证时输入当前管理员密码。这里设置的是系统如何打开 `.deb`，Dev-Cpp 包不会擅自修改此文件关联，也不会把 GDebi 设为自身的运行依赖。

也可参考 [Ubuntu 安装软件说明](https://help.ubuntu.com/community/InstallingSoftware)中的本地 `.deb` 与 GDebi 安装方式。

如果安装器能打开但安装失败，应查看其具体错误：依赖下载失败、软件源不可用、认证取消和软件包格式错误是不同问题。可以使用 `sudo apt install ./包文件.deb` 获取完整错误信息。终端中出现“正在设置 devcpp-noi”且没有后续错误表示安装成功。

测试构建使用 `1.1.3~beta1` 这样的 Debian 预发布版本，以区分稳定版；版本顺序为 `1.1.2 < 1.1.3~beta1 < 1.1.3`。

安装位置：

| 位置 | 用途 |
| --- | --- |
| `/usr/bin/devcpp-noi` | 直接 exec 已编译程序，保留参数和调用者工作目录 |
| `/usr/lib/devcpp-noi/` | 程序、`console-pauser.sh`、`ui-language.sh`、窗口图标、工具栏图标及可用的 profiles |
| `/usr/share/applications/devcpp-noi-installed.desktop` | 可见的“Dev-Cpp”菜单项，直接启动安装版 |
| `/usr/share/applications/devcpp-noi.desktop`、`devcpp-noi-new-window.desktop` | 隐藏兼容入口，保留旧 MIME 关联与已固定的快捷方式 |
| `/etc/xdg/autostart/devcpp-noi-migrate.desktop` | 用户登录时迁移本程序历史自动生成的启动入口 |
| `/usr/share/pixmaps/devcpp-noi.ico` | 与源码版完全相同的原版图标 |
| `/usr/share/icons/hicolor/48x48/apps/devcpp-noi.png` | 从原版 ICO 无损导出的 PNG，供 AppStream 和图标主题加载 |
| `/usr/share/metainfo/io.github.TH911.DevCpp.metainfo.xml` | 应用名称、贡献者、GPL 许可证、仓库和帮助链接 |
| `/usr/share/doc/devcpp-noi/` | 说明和许可证 |

安装版入口不会运行开发目录的 `launch.sh`、`run.sh` 或 `build.sh`，不会尝试在 `/usr` 编译、写锁或注册用户桌面项。所有目录可供普通用户遍历，程序和资源可读。设置仍由程序保存到 `~/.config/devcpp-noi.ini`，卸载脚本不删除用户设置或缓存。菜单仅声明支持的文件类型，不执行 `xdg-mime default`，不修改 `mimeapps.list`；如需默认打开应用，请通过桌面“打开方式”自行选择。

包的 `Homepage` 指向 GitHub 仓库，简介使用 Dev-Cpp 名称并注明许可证。内部包名继续为
`devcpp-noi`，保证 APT 能正常升级旧版。AppStream 元数据遵循 freedesktop 标准，
关联可见的 `devcpp-noi-installed.desktop`；原版 ICO 保持字节不变，PNG 与其最大尺寸图像逐像素一致。
PNG 转换使用已有 GTK2 运行依赖中的 GdkPixbuf；不需要额外的 Python 图像包或在线转换服务。

**这些信息不能保证新版应用中心的本地 deb 页面显示完整。** 该页面可能使用默认图标、
包名和 PackageKit 返回的 `unknown` 许可证，并且保留第三方来源警告。
这与程序窗口、菜单图标、实际许可证及安装是否成功是不同问题；不能通过伪装可信来源来消除警告。

## 从旧源码版或 1.1.0 升级

安装后，在软件面板中选择 **Dev-Cpp**。这是独立的安装版入口，旧源码目录被删除也不会影响它。`--version` 无需图形显示环境；“帮助 → 关于”显示实际版本、程序路径与安装来源，安装版程序应位于 `/usr/lib/devcpp-noi/devcpp-noi`。

旧源码脚本曾将用户级 `devcpp-noi.desktop` 指向源码目录，该文件会遮蔽同名系统入口。安装包使用未修改的 `linux-noi-lazarus/devcpp.ico`，不再生成替代 SVG；升级时旧包拥有的 SVG 由 dpkg 移除。菜单回归通过 GIO 的实际应用发现、名称、可见性及图标加载来检查。

新启动器只识别历史脚本完整生成的入口，先备份到 `${XDG_DATA_HOME:-~/.local/share}/devcpp-noi/launcher-backups/`，再迁移到安装版。自定义名称、参数、额外字段、符号链接及 MIME 默认设置保持不变。由 `sudo apt install` 安装时，安装脚本只处理明确的 `SUDO_USER`；其他用户在首次启动安装版或下次登录时处理，不遍历所有用户的家目录。也可主动执行：

```bash
/usr/bin/devcpp-noi --repair-launchers
```

源码版使用独立的桌面入口 ID，名称同样为 Dev-Cpp；检测到安装版时隐藏源码入口，避免菜单中出现重复项目，直接运行 `bash run.sh` 仍可启动源码版。实例通信按版本和程序位置隔离，安装版不会把启动请求转交给旧源码进程；通信句柄也不会被编译器或终端继承，IDE 退出后能够正常重开。

## 验证

先验证压缩包内容一致、构建产物排除、Debian 元数据、依赖、启动器和文件权限。
检查 `.deb` 还需要 GdkPixbuf 和 `appstream`（CI 自动安装），用于比对原版 ICO / PNG 像素
及运行 `appstreamcli validate --no-net`：

```bash
python3 packaging/verify-artifacts.py --version v1.1.2 --output dist
# 只有源码资产时：
python3 packaging/verify-artifacts.py --source-only --version v1.1.2 --output dist
```

安装验证会实际安装和卸载包，**仅在一次性 Ubuntu 20.04 amd64 容器中以 root 运行**。镜像须已安装本包全部依赖及 `xvfb xauth xdotool`；可选 `desktop-file-utils` 验证 desktop 文件。依赖不齐时先用 `apt install ./包文件.deb` 解决依赖，再移除该包，恢复到未安装状态后运行验证；CI 更适合预先安装依赖。脚本拒绝覆盖已有的 `devcpp-noi` 安装。

```bash
bash packaging/verify-install.sh dist/devcpp-noi_1.1.2_amd64.deb
```

验证包括：`dpkg -i`、普通用户启动并打开含空格的中文相对路径、IPC 转发到当前安装实例、GIO 实际执行软件面板入口、旧实例隔离、旧入口备份、删除源码后重新打开、通信句柄不被终端继承、无 DISPLAY 版本查询、F11 实际编译运行 C++ 程序、`/usr/lib` 无变化和锁文件、文件类型默认关联保持不变、卸载和 purge 后设置保留。脚本需要能够创建 Xvfb 显示的容器，且结束后删除自己的临时 HOME。
