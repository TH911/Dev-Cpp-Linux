# 开发约定

常规开发和测试改动推送到 `beta` 分支，完整检查通过后**自动发布 GitHub Pre-release**，附带源码 ZIP、tar.gz 和 amd64 `.deb`，不必逐次询问发行。普通手动检查默认不发行；手动运行并启用 `publish_beta` 可在检查通过后发行。`main` 用于用户明确要求的稳定发布。

发布新的 beta 内容时，先递增测试版本（例如 `1.1.3~beta1` → `1.1.3~beta2`），同步更新 `VERSION`、`linux-noi-lazarus/app_version.pas`、`PORT_REVISION` 和对应说明。Git 标签及 GitHub 附件文件名将 `~` 转为 `-`，例如 `v1.1.3-beta2`；安装包内部版本保留 Debian 的 `~beta2`。既有发布标签和附件不覆盖，Pre-release 不替换最新稳定 Release。

Git 分支仅提交源码、文档和必要的原始运行资源，不提交可执行文件、安装包或本地构建状态。正式 Release 包含 `linux-noi-lazarus/` 的 ZIP、tar.gz 源码归档及 amd64 `.deb`。

目标环境是 NOI Linux 2.0：Ubuntu 20.04、Lazarus 2.0.6、FPC 3.0.4、GCC/G++ 9.3、GDB 9.1。修改界面后使用对应工具链和相关真实 GTK2 回归验证；完整检查入口为 `ci/check.sh`，打包和安装检查入口为 `ci/build-and-package.sh`。

README 使用中英双语编写，新增使用说明须同时维护两种语言。主题与语言资源以已记录的原版 Dev-C++ 5.11 为基准；缺少的 Linux 专用译文明确回退为英语，不冒称全部翻译已完成校对。

当前软件名称、主命令与 Debian 包名统一为 `dev-cpp-linux`。常规 beta 使用 `x.y.z~betaN`，GitHub 标签和附件文件名将 `~` 替换为 `-`。保留旧入口和配置迁移用于兼容，历史标签不可覆盖。
