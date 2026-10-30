#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# Serialize builders and never link over an executable mapped by a running IDE.
exec 9> .build.lock
flock 9
python3 prepare-synedit.py
lazbuild --widgetset=gtk2 --build-all devcpp_noi.lpi
mv -f -- dev-cpp.build dev-cpp
printf '1\n' > dev-cpp.instance-api
