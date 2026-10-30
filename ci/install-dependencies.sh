#!/usr/bin/env bash
# CI image setup for the Ubuntu 20.04 / NOI Linux 2.0 toolchain.
set -euo pipefail
if [[ $EUID != 0 ]]; then
  echo 'Run this setup inside a disposable Ubuntu 20.04 CI container as root.' >&2
  exit 1
fi
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 20.04 ]]
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Retries=3 update
apt-get -o Acquire::Retries=3 install -y --no-install-recommends \
  git ca-certificates make binutils astyle python3 dpkg-dev appstream desktop-file-utils \
  lcl-utils-2.0 lcl-gtk2-2.0 lcl-units-2.0 lazarus-src-2.0 \
  fp-compiler fp-utils fp-units-fcl fp-units-gfx fp-units-misc \
  libgtk2.0-dev libx11-dev gcc g++ \
  gcc-9-base=9.3.0-10ubuntu2 cpp-9=9.3.0-10ubuntu2 \
  gcc-9=9.3.0-10ubuntu2 g++-9=9.3.0-10ubuntu2 \
  libgcc-9-dev=9.3.0-10ubuntu2 libstdc++-9-dev=9.3.0-10ubuntu2 \
  libasan5=9.3.0-10ubuntu2 gdb=9.1-0ubuntu1 \
  xvfb xauth xdotool xterm xfonts-base fonts-dejavu-core fonts-wqy-zenhei \
  ibus-gtk ibus ibus-libpinyin gvfs dbus
