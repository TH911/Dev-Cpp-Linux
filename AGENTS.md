# 开发约定

常规开发和测试改动推送到 `beta` 分支。`main` 用于用户明确要求的稳定发布；测试构建通过 beta 的 GitHub Actions 产物提供。

Git 分支仅提交源码、文档和必要的原始运行资源，不提交可执行文件、安装包或本地构建状态。正式 Release 包含 `linux-noi-lazarus/` 的 ZIP、tar.gz 源码归档及 amd64 `.deb`。

目标环境是 NOI Linux 2.0：Ubuntu 20.04、Lazarus 2.0.6、FPC 3.0.4、GCC/G++ 9.3、GDB 9.1。修改界面后使用对应工具链和相关真实 GTK2 回归验证；完整检查入口为 `ci/check.sh`，打包和安装检查入口为 `ci/build-and-package.sh`。
