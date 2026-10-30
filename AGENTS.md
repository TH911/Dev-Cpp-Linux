# 开发约定

开发改动先完成本地构建、回归及安装检查。未经用户明确要求，不提交或推送远端分支、不创建标签或发布 Release。测试版使用 `beta` 并发布 Pre-release；用户明确要求的正式版使用 `main`、对应的稳定版本标签及非 Pre-release 的 Release。发布时先备齐并核验 `.deb` 和对应源码归档，再公开 Release；已有标签和附件不覆盖。

发布新的 beta 内容时，先递增测试版本（例如 `1.1.3~beta1` → `1.1.3~beta2`），同步更新 `VERSION`、`linux-noi-lazarus/app_version.pas`、`PORT_REVISION` 和对应说明。Git 标签及 GitHub 附件文件名将 `~` 转为 `-`，例如 `v1.1.3-beta2`；安装包内部版本保留 Debian 的 `~beta2`。既有发布标签和附件不覆盖，Pre-release 不替换最新稳定 Release。

Git 分支仅提交源码、文档和必要的原始运行资源，不提交可执行文件、安装包或本地构建状态。正式 Release 包含 `linux-noi-lazarus/` 的 ZIP、tar.gz 源码归档及 amd64 `.deb`。

目标环境是 NOI Linux 2.0：Ubuntu 20.04、Lazarus 2.0.6、FPC 3.0.4、GCC/G++ 9.3、GDB 9.1。修改界面后使用对应工具链和相关真实 GTK2 回归验证；完整检查入口为 `ci/check.sh`，打包和安装检查入口为 `ci/build-and-package.sh`。

README 使用中英双语编写，新增使用说明须同时维护两种语言。主题与语言资源以已记录的原版 Dev-C++ 5.11 为基准；缺少的 Linux 专用译文明确回退为英语，不冒称全部翻译已完成校对。

软件显示名称（窗口、菜单、关于、桌面入口）为 `Dev-C++`；主命令、可执行文件、Debian 包与配置路径使用 `dev-cpp`。保留 `dev-cpp-linux`、`devcpp-noi` 的升级兼容。beta 版本采用 `x.y.z~betaN`，发布标签和附件用连字符，历史发布不覆盖。
