# NOI Linux 2.0：双击 deb 没反应时，如何修复“软件安装”

这份说明针对 NOI Linux 2.0（基于 Ubuntu 20.04）的一种实际故障：右键 `.deb`
已经有“用『软件安装』打开”，但点击后没有窗口。排查发现，旧版 Snap Store
启动时因 GTK / ATK 库不匹配而退出。更新商店时，又先后遇到了 snapd 太旧和
用户服务功能未启用的问题。

**只有出现相同故障时才需要按本文处理。安装 Dev-Cpp 本身不要求升级 Snap。**
命令需要在你自己的 NOI Linux 终端中执行。一次执行一行，看到成功结果再继续；
不要把报错信息当成下一条命令复制。`sudo` 会询问当前管理员密码，输入时不显示字符是正常的。

## 先了解这几个名字

| 名称 | 含义 |
| --- | --- |
| `.deb` | Debian / Ubuntu 的安装包，Dev-Cpp 的预编译安装包使用此格式 |
| “软件安装” | 文件管理器调用的图形安装入口，NOI Linux 中可能指向 Snap Store |
| `snap-store` | 软件商店；更新后窗口也可能叫“应用中心” |
| `snapd` | 支持 Snap 应用运行的后台服务，与 Dev-Cpp 程序是两回事 |
| `core24` | 某些新版 Snap 应用需要的隔离运行环境；不代表要把 NOI Linux 升级成 Ubuntu 24.04 |

## 第一步：确认打开 deb 的到底是什么

在终端执行：

```bash
xdg-mime query default application/vnd.debian.binary-package
command -v snap-store
```

这次故障的输出分别为：

```text
snap-store_ubuntu-software-local-file.desktop
/snap/bin/snap-store
```

这表明“软件安装”调用的是 Snap Store。若你的结果是 GDebi 或其他程序，
本文后面的 Snap 更新步骤未必适用，应先查看那个安装器的报错。

如果仍在使用旧入口，可直接从终端运行它，以看见原本被隐藏的错误。
下面是这次故障使用的命令示例，请将引号内的路径换成自己下载的文件：

```bash
snap run snap-store.ubuntu-software-local-file '/home/noilinux/1234/devcpp-noi_1.1.3-beta2_amd64.deb'
```

旧商店出现的关键错误是：

```text
symbol lookup error: .../libgtk-3.so.0: undefined symbol: atk_plug_set_child
```

这是商店自己的运行库冲突，发生在读取安装包之前。给 `.deb` 添加执行权限、
重新编译 Dev-Cpp，都不能解决这个启动错误。该冲突曾由 Snap 维护者确认，
处理方向是更新商店，而不是手动替换 GTK 库。

## 第二步：定向更新 snapd

先刷新 APT 软件包索引：

```bash
sudo apt update
```

再只升级 `snapd`：

```bash
sudo apt install --only-upgrade snapd
```

这里不需要执行整套 `apt upgrade`，也不需要升级操作系统。
若 APT 提示找不到 `snapd`，先停下并确认系统是否原本使用 Snap；
不要为了安装 Dev-Cpp，盲目新增整套 Snap 环境。

完成后检查：

```bash
snap version
```

这次实机升级前是 `2.45.1`，升级后 `snap` 和 `snapd` 两行都显示
`2.63+20.04ubuntu0.1`。这证明新版客户端和后台服务都已运行。
具体可用版本取决于你的软件源，不必追求与这里完全相同。

如果 APT 说已经是最新版，但更新商店仍提示需要更高版本，先记录以下输出再排查软件源：

```bash
apt-cache policy snapd
snap version
```

## 第三步：更新软件商店

关闭已经打开的软件商店窗口，然后执行：

```bash
sudo snap refresh snap-store
```

如果成功，直接进入第四步。如果报错，请按下面的具体情况处理。

### 提示 core24 要求 snapd2.55.5

```text
snap "core24" assumes unsupported features: snapd2.55.5
```

说明正在运行的 snapd 太旧。回到第二步，检查升级是否成功，尤其是
`snap version` 中后台 `snapd` 一行。不要只反复更新商店。

### 提示 experimental.user-daemons 未启用

```text
experimental feature disabled - test it by setting 'experimental.user-daemons' to true
```

说明这个商店版本需要 Snap 的用户会话服务，而当前 snapd 尚未默认启用它。
执行下面一行可在系统级允许 Snap 应用使用此功能：

```bash
sudo snap set system experimental.user-daemons=true
```

注意是 **experimental**，拼错成 `exprimental` 会提示 `unsupported system option`。
这个开关不是关闭安全检查，也不是切换到商店的 beta 渠道；它允许 Snap 安装和运行用户会话服务。

开关设置成功后再执行：

```bash
sudo snap refresh snap-store
```

看到类似 `snap-store ... refreshed` 的输出，表示商店更新成功。
如果提示应用仍在运行，按提示关闭相应进程后重试；不要直接删除运行库或强制中断安装。

## 第四步：重新打开安装包并核对版本

在文件管理器中右键 `.deb`，选择“用『软件安装』打开”。也可以在文件所在目录执行：

```bash
xdg-open './devcpp-noi_1.1.3-beta2_amd64.deb'
```

请替换成实际文件名。更新后的商店入口可能与旧版不同，因此无需继续使用
第一步中旧商店专用的 `snap run ...ubuntu-software-local-file` 命令。

页面能打开后，检查版本，再点击安装。如果同一版本已经装好，按钮显示“已安装”是正常的。
安装完成后，可在终端确认：

```bash
/usr/bin/devcpp-noi --version
```

请注意路径是 `/usr/bin/`，不是 `/user/bin/`。软件面板和窗口中的应用名称应为 **Dev-Cpp**。

## 能打开以后，这些提示是什么意思？

- **“有潜在危险”**：应用中心对本地第三方安装包的来源提示，不等于检测到病毒。
  请从本仓库的 [Releases](https://github.com/TH911/Dev-Cpp-Linux/releases) 下载。
- **灰色图标、包名 `devcpp-noi`、未知发布者或许可证 `unknown`**：
  新版应用中心的本地 deb 页面会使用 PackageKit 信息和默认图标，未必读取包内 AppStream。
  本项目已提供 AppStream 名称、贡献者、GPL-2.0-or-later 许可证、仓库地址及原版图标的 PNG，
  但不能保证每个安装器都展示这些字段。`devcpp-noi` 是保持升级兼容的内部包名。
  本地页面显示 `unknown` 不会改变软件的实际许可证。
- **638 个软件包可以升级**：APT 提供的信息，不代表必须全部升级。
- **Typora 软件源连接失败**：与 Dev-Cpp 和 Snap Store 是不同问题。
  若 Ubuntu 软件源也失败，需要先解决网络或源问题；不能仅凭一条警告认定全部索引已更新。
- **升级时出现服务警告**：以最终命令状态和 `snap version` 为准。
  本次虽有 `snapd.mounts-pre.target` 的重启提示，但新版后台实际已经运行；
  其他错误仍应保留完整输出，不能一概忽略。

## 不使用软件商店，也可以安装

在安装包所在目录执行：

```bash
sudo apt install ./devcpp-noi_1.1.3-beta2_amd64.deb
```

APT 会处理依赖。文件名前面的 `./` 不能漏，文件名请按实际版本替换。
若希望使用其他图形安装器，可用 `sudo apt install gdebi` 安装 GDebi，
再在“打开方式”中自行选择。本项目安装脚本不会修改 `.deb` 的默认打开方式。

## 参考资料

- [Snap 官方：在 Ubuntu 安装或更新 snapd](https://snapcraft.io/docs/tutorials/install-the-daemon/ubuntu/)
- [Snap 维护者对 GTK / ATK 冲突的说明](https://forum.snapcraft.io/t/snap-store-broken/24902)
- [Snap 官方论坛：用户会话服务开关](https://forum.snapcraft.io/t/enabling-user-daemons-and-d-bus-activation/22318)
- [Ubuntu 应用中心：本地 deb 数据来源](https://github.com/ubuntu/app-center/blob/main/packages/app_center/lib/deb/local_deb_model.dart)
- [Ubuntu 应用中心：本地 deb 页面图标处理](https://github.com/ubuntu/app-center/blob/main/packages/app_center/lib/apps/app_title_bar.dart)

本文依据一次 NOI Linux 2.0 实机排查整理；软件商店更新后，界面和报错可能变化。
进一步安装、卸载及升级说明见 [PACKAGING.md](PACKAGING.md)。
