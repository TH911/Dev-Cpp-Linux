#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
# Serialize builders and never link over an executable mapped by a running IDE.
exec 9> .build.lock
flock 9
lazbuild --build-all devcpp_noi.lpi
mv -f -- devcpp-noi.build devcpp-noi
printf '1\n' > devcpp-noi.instance-api
