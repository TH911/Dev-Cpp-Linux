# Dev-Cpp-Linux

[中文](#中文) | [English](#english)

## 中文

基于 Lazarus/LCL 的 Dev-C++ 原生 Linux 移植版，目标运行环境为 **NOI Linux 2.0（64 位）**。最近稳定版本为 **[v1.1.2](https://github.com/TH911/Dev-Cpp-Linux/releases/tag/v1.1.2)**，本分支测试版本为 **1.1.3~beta6**。

开发与测试改动先推送到 [`beta`](https://github.com/TH911/Dev-Cpp-Linux/tree/beta)；`main` 保留稳定发布源码。推送到 `beta` 后，完整检查通过就自动发布 **Pre-release**。当前测试包见 [v1.1.3-beta6](https://github.com/TH911/Dev-Cpp-Linux/releases/tag/v1.1.3-beta6)，包含 `.deb`、ZIP 和 tar.gz；[Actions](https://github.com/TH911/Dev-Cpp-Linux/actions/workflows/noi-linux.yml?query=branch%3Abeta) 也保留构建产物。Pre-release 不替换最新稳定版。beta 已加入 [Consolas 字体支持与安装说明](linux-noi-lazarus/FONTS.md)。

本次 beta 同时修复科学计数法高亮，`1e5`、`1e-5f` 等在 Classic Plus 主题中使用原版的紫色。

目标工具链以 [NOI 官方环境说明](https://www.noi.cn/gynoi/jsgz/2021-07-16/732450.shtml) 为准：

| 组件 | 版本 |
| --- | --- |
| Ubuntu | 20.04.1 |
| Lazarus | 2.0.6 |
| Free Pascal | 3.0.4 |
| GCC / G++ | 9.3.0 |
| GDB | 9.1 |

在 NOI Linux 2.0 桌面中，将源码解压到可写目录，进入包含 `linux-noi-lazarus/` 的目录后运行：

```sh
cd linux-noi-lazarus
bash run.sh
# 也可以打开指定源文件或项目：
bash run.sh /path/to/main.cpp
bash run.sh /path/to/project.dev
```

首次运行会使用系统预装的 `lazbuild` 编译。F9 编译，F10 运行，F11 编译并运行。后续启动可使用 `bash launch.sh`；源码有更新时会重新编译。请保留可执行文件旁的脚本和 `icons/` 目录。

1.1.2 保留原版已有的按钮，并整理调试面板，使布局更接近 Orwell Dev-C++ 5.11：底部左侧放调试操作与表达式结果，右侧放程序输出/GDB 日志，左侧 Debug 页列出断点。源码行号或标记区支持单击切换断点，红点和黄色箭头分别标识断点与当前执行行。关于窗口显示版本、可点击 GitHub 链接、许可证及安装和构建信息，详情可用 Ctrl+A/C 复制。调试、行号交互和关于窗口已通过真实 GTK2 回归，界面按原版结构整理，并非像素复刻。

程序名称统一为 **Dev-Cpp**，安装版与源码版使用同一份原版图标。源码启动提示读取实际程序版本，不再显示旧的 v1.0.0。

新建项目入口为 **文件 → 新建 → 项目**，与原版一致；Ctrl+N 仍用于新建源码。
当前创建的是空的控制台 `.dev` 项目：保存项目后，通过 **项目 → 添加文件到项目**
选择已有的 C/C++ 文件，再按 F9 编译或 F11 编译运行。尚未提供原版的完整模板选择向导。
行号右侧留白按原版 5.11 的 21 像素设置恢复，且随主题变色。

beta3 补充 AppStream 应用名称、贡献者、许可证及仓库链接，并将原版图标原样导出为 PNG 供软件中心使用。NOI Linux 上双击 `.deb` 无反应、升级 Snap Store 遇到报错时，请阅读 [“软件安装”修复指南](docs/NOI-LINUX-SOFTWARE-INSTALL.md)。不同安装器对本地包元数据的支持不同，应用中心仍可能显示内部包名或默认图标。

安装版启动器已修复：使用独立的“Dev-Cpp”系统菜单入口与窗口标识，识别并备份旧版自动生成的源码启动入口，防止安装 `.deb` 后仍启动旧目录中的程序。安装、旧入口迁移和确认实际运行版本的步骤见 [打包与安装说明](docs/PACKAGING.md)。已有 Home/Shift+Home、编辑撤销、保存冲突、编译取消、GDB、主题与命名编译器配置等功能的范围见 [移植版说明](linux-noi-lazarus/README.md) 和 [原版 5.11 对齐清单](docs/DEVCPP-5.11-PARITY.md)。

Release 除 GitHub 默认的整库源码外，由 [发布工作流](.github/workflows/release.yml) 构建并附加以下资产：

- `linux-noi-lazarus-版本-src.zip` 和 `.tar.gz`：只包含 `linux-noi-lazarus/` 的源码、脚本和资源。
- `devcpp-noi_版本_amd64.deb`：预编译程序、桌面入口和运行资源。用 `sudo apt install ./devcpp-noi_版本_amd64.deb` 安装，APT 会处理编译器、GDB、GTK2 和终端依赖；安装版无需 Lazarus/FPC。

打包与卸载说明见 [PACKAGING.md](docs/PACKAGING.md)。源码仓库不提交可执行文件和安装包；既有发布标签保持不变。Release 的安装包和源码归档由发布工作流验证后上传；未发布的构建也可从 [Actions](https://github.com/TH911/Dev-Cpp-Linux/actions/workflows/noi-linux.yml) 下载。

### 主题和界面语言

“工具 → 编辑器主题”或“工具 → 编辑器选项”提供原版 5.11 的全部 11 套配色：Classic、Classic Plus、Twilight、Ocean、Visual Studio、Borland、Matrix、Obsidian、GSS Hacker、Oblivion 和 PlasticCodeWrap。字体、字号、Tab 宽度和主题会保存，适用于现有及新建文档。

“工具 → 语言”提供原版的 33 种语言文件，包括简体/繁体中文、英语、日语、韩语、法语、德语、西班牙语等，选择后即时应用并在重启后恢复。旧语言文件已从各自的 Windows 编码转换为 UTF-8；Linux 新增功能中原版没有提供的译文回退为英语，简体中文继续使用已有补充翻译。详细列表和来源见 [语言资源说明](linux-noi-lazarus/languages/README.md)。这是语言资源接入范围，不表示新增功能已由所有语言的母语使用者完成校对。

### 使用命令行更新已安装的 Dev-Cpp

更新时可直接覆盖安装，**不需要先卸载旧版**，用户设置会保留。应用中心显示“已安装”，不代表已经更新到下载包中的版本。

#### 1. 下载新版，关闭旧窗口

从 [Releases](https://github.com/TH911/Dev-Cpp-Linux/releases) 下载新的 amd64 `.deb`；测试版标记为 **Pre-release**。先保存代码，并正常关闭所有 Dev-Cpp 窗口。

在文件管理器中打开安装包所在文件夹，右键空白处，选择“在终端打开”。下面以 `devcpp-noi_1.1.3-beta6_amd64.deb` 为例；下载其他版本时，请将命令中的文件名换成实际文件名。

#### 2. 确认下载包的版本

```bash
dpkg-deb -f ./devcpp-noi_1.1.3-beta6_amd64.deb Version
```

这个示例应输出 `1.1.3~beta6`。文件名里的 `-beta6` 和包内版本的 `~beta6` 是正常的表示差异。若这里仍显示旧版本，请先确认下载的是新版文件。

#### 3. 覆盖安装新版

```bash
sudo apt install --reinstall ./devcpp-noi_1.1.3-beta6_amd64.deb
```

`./` 表示使用当前文件夹中的安装包，不能漏掉。APT 会处理依赖；`--reinstall` 也允许重新安装相同版本，适合修复安装文件。输入管理员密码时，终端不显示字符是正常的。若命令报错，请先保留完整输出、处理错误，再继续核对版本。

#### 4. 核对系统记录和实际程序

```bash
dpkg-query -W -f='${Version}\n' devcpp-noi
/usr/bin/devcpp-noi --version
```

这个示例中，第一条应输出 `1.1.3~beta6`，第二条应包含 `Dev-Cpp 1.1.3~beta6` 和 GitHub 仓库地址。注意路径是 `/usr/bin/`，不是 `/user/bin/`。

确认版本正确后，直接启动安装版的新窗口：

```bash
/usr/bin/devcpp-noi --new-window
```

也可以在“帮助 → 关于”中查看实际版本和程序路径；安装版程序应位于 `/usr/lib/devcpp-noi/devcpp-noi`。

#### 如果点击旧图标仍打开旧版

如果上面的直接启动已经是新版，旧图标却仍打开旧版，请先确认旧窗口已经全部退出，并从应用列表重新打开 **Dev-Cpp**。这类情况需要区分旧进程、源码版和旧快捷方式。

对本程序历史脚本自动生成的快捷方式，可以尝试迁移到安装版，命令无需 `sudo`：

```bash
/usr/bin/devcpp-noi --repair-launchers
```

迁移只处理能识别的历史自动生成入口。自定义快捷方式需自行调整；若固定的图标仍指向源码版，可取消固定旧图标，再固定正确的安装版。不要通过删除源码目录或用户设置来尝试更新。

如果下载包是新版，但安装后的版本检查仍显示旧版，请提供安装命令和版本检查的完整输出，以便进一步定位。

本项目目前没有提供 APT 软件源，`apt upgrade` 不会自动从 GitHub 下载新版 Dev-Cpp。以后更新时，重新下载新版 `.deb`，按上述步骤覆盖安装即可。更多说明见 [打包与安装说明](docs/PACKAGING.md)；“软件安装”完全打不开时，参见 [Snap Store 修复指南](docs/NOI-LINUX-SOFTWARE-INSTALL.md)。

### 兼容性检查

兼容性检查使用 Ubuntu 20.04 amd64 容器，固定 Lazarus 2.0.6、FPC 3.0.4、GCC/G++ 9.3.0 和 GDB 9.1；[检查入口](ci/check.sh) 包含文件保存、编辑、运行参数、调试和真实 GTK2 交互回归；[打包检查](ci/build-and-package.sh) 另验证压缩包及 `.deb` 安装/卸载。容器使用 Xvfb 和 XTerm，NOI Linux 2.0 原版 GNOME 桌面的显示、焦点及 GNOME Terminal 行为仍需实机验收。


## English

Dev-Cpp is a native Lazarus/LCL port of Orwell Dev-C++ 5.11 for **NOI Linux 2.0, 64-bit**, based on Ubuntu 20.04. The stable release is [v1.1.2](https://github.com/TH911/Dev-Cpp-Linux/releases/tag/v1.1.2); this beta is **1.1.3~beta6** ([download](https://github.com/TH911/Dev-Cpp-Linux/releases/tag/v1.1.3-beta6)).

Development goes to the [`beta`](https://github.com/TH911/Dev-Cpp-Linux/tree/beta) branch. Successful compatibility, GUI and installation checks automatically publish a GitHub **Pre-release** with an amd64 `.deb` and source ZIP/tar.gz archives containing `linux-noi-lazarus/`. Existing release tags and assets are preserved. `main` is reserved for stable releases. [Actions](https://github.com/TH911/Dev-Cpp-Linux/actions/workflows/noi-linux.yml?query=branch%3Abeta) also retains build artifacts.

### Build and run from source

The target toolchain matches the [official NOI environment](https://www.noi.cn/gynoi/jsgz/2021-07-16/732450.shtml): Ubuntu 20.04.1, Lazarus 2.0.6, Free Pascal 3.0.4, GCC/G++ 9.3.0 and GDB 9.1.

Extract the source into a writable directory. From the directory containing `linux-noi-lazarus/`, run:

```sh
cd linux-noi-lazarus
bash run.sh
# Open a source file or project:
bash run.sh /path/to/main.cpp
bash run.sh /path/to/project.dev
```

The first launch builds with the preinstalled `lazbuild`. Later launches can use `bash launch.sh`; changed sources are rebuilt. Keep the helper scripts and `icons/` beside the executable. **F9** compiles, **F10** runs, and **F11** compiles and runs.

### Editor, projects and debugger

The application is named **Dev-Cpp** and uses the original icon in both source and packaged builds. The source launcher reports the actual program version. The interface follows the original structure; it is not a pixel-perfect Windows reproduction.

Create an empty console project through **File → New → Project**. Then use **Project → Add file to project** to select C/C++ files. **Ctrl+N** still creates a source file. The complete original project-template wizard is not yet implemented. The gutter restores the original spacing beside line numbers.

The debugger provides breakpoints, continue, step over/into, expression evaluation and program input/output. Clicking line numbers or the marker gutter toggles breakpoints; red markers and a yellow arrow distinguish breakpoints and the stopped line. The original top-level button set is retained. **Help → About** shows the version, GitHub link, license, executable path and installation information; details support Ctrl+A/C.

Installed [Consolas](linux-noi-lazarus/FONTS.md) is detected, with an explicit monospace fallback. Microsoft font files are not bundled. Scientific notation such as `1e5` and `1e-5f` uses the original purple in Classic Plus. Themes with separate decimal, float, hexadecimal and octal colors retain those distinctions.

See the [port README](linux-noi-lazarus/README.md) and [5.11 parity audit](docs/DEVCPP-5.11-PARITY.md) for tested behavior and remaining limits, including advanced debugging, project management, searches and completion.

### Themes and interface languages

**Tools → Editor Theme**, also available in **Editor Options**, includes all 11 original presets: Classic, Classic Plus, Twilight, Ocean, Visual Studio, Borland, Matrix, Obsidian, GSS Hacker, Oblivion and PlasticCodeWrap. Theme, font, font size and tab width are saved and applied to existing and new documents.

**Tools → Language** offers the original 33 language files, including Simplified/Traditional Chinese, English, Japanese, Korean, French, German and Spanish variants. Changes apply immediately and survive restart. The original Windows encodings are converted to UTF-8. Linux-specific text without an upstream translation falls back to English; Simplified Chinese retains the port's existing extra translations. See [language resources](linux-noi-lazarus/languages/README.md) for the complete list and provenance. Availability does not imply that every new feature has been reviewed by native speakers in every language.

### Packages and graphical installation

Download an amd64 `.deb` from [Releases](https://github.com/TH911/Dev-Cpp-Linux/releases), or a source ZIP/tar.gz if you want to build it. The binary package installs the IDE, launchers and resources, with GCC, G++, GDB, GTK2 and a terminal as dependencies. It does not require Lazarus/FPC at runtime.

The Debian package includes AppStream metadata, the repository link, GPL license details and a lossless PNG export of the original ICO. An installer's local-deb view may still show a generic icon, the internal package name `devcpp-noi`, or unknown publisher/license fields.

For graphical installation, use your system's package installer or GDebi. If “Software Install” does not open at all on NOI Linux, see the [Snap Store repair guide](docs/NOI-LINUX-SOFTWARE-INSTALL.md). Installation paths, removal and migration of historical launchers are documented in [PACKAGING.md](docs/PACKAGING.md).

### Command-line updates

**An update can replace the installed version directly; uninstalling first is unnecessary. User settings are retained.** An “Installed” label in App Center does not establish which version is installed.

1. Download the newer `.deb`, save your code, and close every Dev-Cpp window normally. Open a terminal in the download folder. Replace the example filename below with the file you actually downloaded.
2. Check the version inside that file:

```bash
dpkg-deb -f ./devcpp-noi_1.1.3-beta6_amd64.deb Version
```

The example should report `1.1.3~beta6`. The `-beta6` in the filename and `~beta6` in the Debian version are intentional.

3. Install or reinstall the downloaded package:

```bash
sudo apt install --reinstall ./devcpp-noi_1.1.3-beta6_amd64.deb
```

Keep the leading `./`. APT handles dependencies; `--reinstall` also permits repairing an installation of the same version. Password input is not echoed. If this command fails, retain its full output and resolve the error before proceeding.

4. Check both the package database and the actual installed executable:

```bash
dpkg-query -W -f='${Version}\n' devcpp-noi
/usr/bin/devcpp-noi --version
```

Expect `1.1.3~beta6` and `Dev-Cpp 1.1.3~beta6` respectively; the program also prints its GitHub URL. The path is `/usr/bin/`, not `/user/bin/`.

5. Start the installed program explicitly:

```bash
/usr/bin/devcpp-noi --new-window
```

**Help → About** also identifies the version and executable path. The installed executable should be `/usr/lib/devcpp-noi/devcpp-noi`.

If this starts the new version but an old icon starts an old one, make sure old windows are closed and launch **Dev-Cpp** from the application list. To migrate recognized, historically auto-generated launchers, run this as your normal user:

```bash
/usr/bin/devcpp-noi --repair-launchers
```

Custom launchers are preserved and may need manual correction. Unpin an obsolete source-build shortcut and pin the installed application if necessary. Deleting your source tree or settings is not an update procedure. If the package file is new but the installed version remains old, provide the full installation and version-check output.

This project does not currently provide an APT repository. `apt upgrade` does not download new Dev-Cpp releases from GitHub; download a newer `.deb` and repeat the steps above.

### Verification

[ci/check.sh](ci/check.sh) runs the Ubuntu 20.04 toolchain checks and file, editing, runtime, debugger and real GTK2 regressions. [ci/build-and-package.sh](ci/build-and-package.sh) additionally checks archives and package contents, exercises the IDE as an ordinary user, and verifies system installation/removal in a disposable container. Xvfb/XTerm results do not replace acceptance on the stock NOI Linux GNOME desktop, particularly for focus, scaling and GNOME Terminal behavior. Compiled programs and local build state are not committed to Git.
