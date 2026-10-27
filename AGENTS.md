# 开发约定

常规开发和测试改动推送到 `beta` 分支，通过完整检查后自动发布为 GitHub Pre-release，并附带源码 ZIP、tar.gz 和 amd64 `.deb`。`main` 用于用户明确要求的稳定发布。

发布新的 beta 内容时，先递增测试版本（例如 `1.1.3~beta1` → `1.1.3~beta2`），同步更新 `VERSION`、`linux-noi-lazarus/app_version.pas`、`PORT_REVISION` 和对应说明。Git 标签及 GitHub 附件文件名将 `~` 转为 `-`，例如 `v1.1.3-beta2`；安装包内部版本保留 Debian 的 `~beta2`。既有发布标签和附件不覆盖，Pre-release 不替换最新稳定 Release。

Git 分支仅提交源码、文档和必要的原始运行资源，不提交可执行文件、安装包或本地构建状态。正式 Release 包含 `linux-noi-lazarus/` 的 ZIP、tar.gz 源码归档及 amd64 `.deb`。

目标环境是 NOI Linux 2.0：Ubuntu 20.04、Lazarus 2.0.6、FPC 3.0.4、GCC/G++ 9.3、GDB 9.1。修改界面后使用对应工具链和相关真实 GTK2 回归验证；完整检查入口为 `ci/check.sh`，打包和安装检查入口为 `ci/build-and-package.sh`。
