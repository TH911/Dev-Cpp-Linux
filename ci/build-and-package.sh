#!/usr/bin/env bash
# Run inside a disposable Ubuntu 20.04 CI container with dependencies installed.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
if [[ $EUID != 0 ]]; then
  echo 'Run this CI wrapper as root in a disposable container.' >&2
  exit 1
fi
ci_home=$(mktemp -d /tmp/devcpp-ci-home.XXXXXX)
trap 'rm -rf -- "$ci_home"' EXIT
ci_group=$(id -gn nobody)
# Permission and read-only-file regressions must run as an ordinary user.
chown -R nobody:"$ci_group" "$PWD" "$ci_home"
runuser -u nobody -- env HOME="$ci_home" LANG=C.UTF-8 \
  bash ci/check.sh
runuser -u nobody -- env HOME="$ci_home" LANG=C.UTF-8 \
  SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-315532800}" \
  python3 packaging/build-release.py all --output dist
python3 packaging/verify-artifacts.py --output dist
package_version=$(tr -d '\r\n' < VERSION)
package_version=${package_version#v}
bash packaging/verify-install.sh "dist/dev-cpp-linux_${package_version}_amd64.deb"
