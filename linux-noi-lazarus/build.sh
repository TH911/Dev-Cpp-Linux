#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# Serialize builders and never link over an executable mapped by a running IDE.
exec 9> .build.lock
flock 9
lazbuild --widgetset=gtk2 --build-all devcpp_noi.lpi
mv -f -- dev-cpp-linux.build dev-cpp-linux
printf '1\n' > dev-cpp-linux.instance-api
