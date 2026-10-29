# 启动、名称与 beta 版本 / Startup, naming and beta versions

## 中文

界面名称为 **Dev-C++**，主命令和 Debian 包名为 `dev-cpp`。当前测试版本为 `1.3.1~beta4`，GitHub 标签和下载文件名为 `v1.3.1-beta4`、`dev-cpp_1.3.1-beta4_amd64.deb`。界面仍在按原版 Dev-C++ 5.11 逐步移植，beta 不代表 UI 已完全还原。

从旧的 `dev-cpp-linux` 或 `devcpp-noi` 安装包更新时，使用普通的 `sudo apt install ./dev-cpp_1.3.1-beta4_amd64.deb`。APT 会以新包替换旧包，无需先手工卸载。`1.3.1~beta4` 的 Debian 版本顺序高于已经发行的 `1.3.0`，避免把更新误判为降级。已发表的历史标签和附件保持不变。

首次运行优先读取上一版 `~/.config/dev-cpp-linux.ini`，否则读取 `~/.config/devcpp-noi.ini`，并将其 复制到 `~/.config/dev-cpp.ini`；已有新配置不会被覆盖，旧文件保留。旧命令 `/usr/bin/dev-cpp-linux`、`/usr/bin/devcpp-noi`、旧桌面 ID 和 MIME 关联只作为兼容转发，均启动新版。可识别的历史自动生成入口会备份后修复，自定义入口保持不变。

安装版直接运行预编译程序，无需安装 Lazarus，也不会在启动时重新编译。历史桌面入口的修复在后台执行，不再阻塞编辑器。

源码版使用：

```bash
bash run.sh
```

首次运行或源码有变化时才编译，后续启动直接运行已有程序。`.pas`、`.lpr`、`.lpi`、`.inc`、版本标记和构建脚本的变更都会触发重建。需要强制重建时运行 `bash build.sh`。

源码版不再在每次启动时重写桌面配置。需要加入应用菜单或“打开方式”时，在源码目录运行一次：

```bash
bash register-desktop.sh --register
```

需要明确设为 `.cpp`、`.c` 默认程序时，使用 `bash register-desktop.sh --default`。

排查启动耗时可运行：

```bash
DEV_CPP_STARTUP_TRACE=1 dev-cpp --new-window
```

终端将显示 GTK、配置、菜单、窗口构建等阶段的毫秒计时；正常启动不输出这些诊断。该计时不等于用户机器上的保证速度。仓库的 `tests/startup-smoke.py` 另外测量从启动进程到真实 GTK 窗口可见的时间，并检查重复源码启动不会编译。硬件、磁盘、字体缓存和桌面会影响结果；没有在用户设备上与 Geany 做同机比较。

在本次 Ubuntu 20.04 容器的 6 次测试中（中英各 3 次，字体缓存已存在），从进程启动到窗口可见的中位耗时由约 0.49 秒降至 0.11 秒。这不代表用户设备的实测结果。

本次把语言目录的反复线性查找改为索引查找，保留 33 种原版语言资源与语言切换。工具菜单恢复编译选项、环境选项、编辑器选项、快捷键选项、配置工具和 Package Manager 的顺序及图标。快捷键可编辑并保存；配置工具提供一个直接运行的外部程序，可在参数中使用 `%FILE%` 和 `%DIR%`，参数不会经 shell 执行。Package Manager 将所选 `.deb` 交给系统安装器，不安装 Windows DevPak。主题与语言的快速菜单移至“查看”，也可在编辑器和环境选项中设置。

## English

The display name is **Dev-C++**; the primary command and Debian package are `dev-cpp`. The beta version is `1.3.1~beta4`; the GitHub tag and public Debian filename use `v1.3.1-beta4` and `dev-cpp_1.3.1-beta4_amd64.deb`. UI restoration remains ongoing.

Upgrade with `sudo apt install ./dev-cpp_1.3.1-beta4_amd64.deb`. APT replaces the old `dev-cpp-linux` or `devcpp-noi` package; no manual uninstall is needed. Debian orders `1.3.1~beta4` after the already published `1.3.0`. Historical tags and assets are preserved.

On first launch, `~/.config/dev-cpp-linux.ini` (or the older `~/.config/devcpp-noi.ini` when absent) is copied to `~/.config/dev-cpp.ini` if the new file does not exist. The old file is retained. Old command and desktop IDs remain hidden compatibility redirects to the new application; existing MIME defaults are preserved. Recognized generated launchers are backed up and repaired; custom entries are retained.

The installed launcher executes the prebuilt binary without compiling or waiting for desktop migration. The source launcher, `bash run.sh`, builds only when necessary, including changes to `.inc` files. Use `bash build.sh` for an explicit rebuild. Register a source desktop entry once with `bash register-desktop.sh --register`; use `--default` only when you want to change C/C++ MIME defaults.

Run `DEV_CPP_STARTUP_TRACE=1 dev-cpp --new-window` for optional stage timings. `tests/startup-smoke.py` separately measures process-to-visible-window startup and verifies cached source launches. Timings depend on hardware, disk, font caches and desktop state; no same-device Geany comparison has been performed on the user's machine.

On the test Ubuntu 20.04 container, six runs (three per language, with an existing font cache) reduced median process-to-visible-window time from about 0.49 s to 0.11 s. These are not measurements from the user’s machine.

Language lookups now use an index, retaining the 33 upstream language catalogs. Tools restores the original command order and icons. Shortcut Options supports editing and persistence; Configure Tools supports one external executable with literal arguments and `%FILE%`/`%DIR%` substitutions. Package Manager opens a Debian package with the system installer; Windows DevPak installation is unsupported. Quick theme/language menus are under View, with the same settings available in Editor/Environment Options.
