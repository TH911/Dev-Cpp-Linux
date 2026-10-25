#!/usr/bin/env bash
# Destructive to this container's package installation: use a disposable Ubuntu
# 20.04 amd64 container with the package dependencies and test tools installed.
set -euo pipefail
if [[ $EUID != 0 ]]; then
  echo 'Run as root inside a disposable test container.' >&2
  exit 1
fi
deb=$(realpath -- "${1:?Usage: verify-install.sh /path/to/devcpp-noi_VERSION_amd64.deb}")
for tool in dpkg runuser xvfb-run xdotool timeout sha256sum; do
  command -v "$tool" >/dev/null || { echo "Missing test tool: $tool" >&2; exit 1; }
done
if dpkg-query -W -f='${Status}' devcpp-noi 2>/dev/null | grep -q ' installed$'; then
  echo 'Refusing to replace an existing install; use a fresh test container.' >&2
  exit 1
fi
test_dir=$(mktemp -d /tmp/devcpp-package-test.XXXXXX)
cleanup() { rm -rf -- "$test_dir"; }
trap 'result=$?; if [[ $result != 0 && -f "$test_dir/startup.log" ]]; then cat "$test_dir/startup.log" >&2; fi; cleanup; exit "$result"' EXIT
test_user=nobody
test_group=$(id -gn "$test_user")
mkdir -p "$test_dir/home/.config" "$test_dir/work folder"
cat > "$test_dir/home/.config/devcpp-noi.ini" <<'EOF'
[Interface]
Language=en
EOF
cat > "$test_dir/home/.config/mimeapps.list" <<'EOF'
[Default Applications]
text/x-c++src=example-editor.desktop;
EOF
cp "$test_dir/home/.config/mimeapps.list" "$test_dir/mimeapps.expected"
cat > "$test_dir/work folder/中文 relative.cpp" <<'CPP'
#include <fstream>
int main() { std::ofstream("packaged-ran.txt") << "ok\n"; }
CPP
chown -R "$test_user:$test_group" "$test_dir"
dpkg -i "$deb"
dpkg --audit
test -x /usr/bin/devcpp-noi
test -r /usr/share/icons/hicolor/scalable/apps/devcpp-noi.svg
if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate /usr/share/applications/devcpp-noi.desktop
fi
find /usr/lib/devcpp-noi -type f -exec sha256sum {} + | sort > "$test_dir/installed.before"
# Launch from a directory containing a relative, spaced, non-ASCII filename;
# verify a real window then forward to that instance using the installed wrapper.
runuser -u "$test_user" -- env HOME="$test_dir/home" XDG_CACHE_HOME="$test_dir/home/.cache" \
  LANG=C.UTF-8 PACKAGE_TEST_DIR="$test_dir" timeout 30 xvfb-run -a bash <<'SH'
set -euo pipefail
cd "$PACKAGE_TEST_DIR/work folder"
/usr/bin/devcpp-noi --new-window '中文 relative.cpp' > "$PACKAGE_TEST_DIR/startup.log" 2>&1 &
ide_pid=$!
trap 'kill "$ide_pid" 2>/dev/null || true; wait "$ide_pid" 2>/dev/null || true' EXIT
window=''
for attempt in {1..100}; do
  window=$(xdotool search --all --onlyvisible --pid "$ide_pid" --name 'Dev-C' 2>/dev/null | head -1) || true
  [[ -z "$window" ]] || break
  kill -0 "$ide_pid"
  sleep 0.1
done
[[ -n "$window" ]] || { cat "$PACKAGE_TEST_DIR/startup.log" >&2; exit 1; }
sleep 0.3
/usr/bin/devcpp-noi --forward-only '中文 relative.cpp'
xdotool windowfocus "$window" key F11
for attempt in {1..100}; do
  [[ ! -s packaged-ran.txt ]] || break
  kill -0 "$ide_pid"
  sleep 0.1
done
[[ $(cat packaged-ran.txt) == ok ]] || { cat "$PACKAGE_TEST_DIR/startup.log" >&2; exit 1; }
# A normal user must be able to read all resources but cannot alter /usr/lib.
test -r /usr/lib/devcpp-noi/icons/compile.bmp
test ! -w /usr/lib/devcpp-noi
SH
find /usr/lib/devcpp-noi -type f -exec sha256sum {} + | sort > "$test_dir/installed.after"
cmp "$test_dir/installed.before" "$test_dir/installed.after"
test ! -e /usr/lib/devcpp-noi/.build.lock
test ! -e /usr/lib/devcpp-noi/devcpp-noi.ini
test ! -e /usr/lib/devcpp-noi/build.sh
cmp "$test_dir/mimeapps.expected" "$test_dir/home/.config/mimeapps.list"
cp "$test_dir/home/.config/devcpp-noi.ini" "$test_dir/config.expected"
dpkg -r devcpp-noi
test ! -e /usr/bin/devcpp-noi
test ! -e /usr/lib/devcpp-noi/devcpp-noi
cmp "$test_dir/config.expected" "$test_dir/home/.config/devcpp-noi.ini"
cmp "$test_dir/mimeapps.expected" "$test_dir/home/.config/mimeapps.list"
dpkg --purge devcpp-noi
cmp "$test_dir/config.expected" "$test_dir/home/.config/devcpp-noi.ini"
cmp "$test_dir/mimeapps.expected" "$test_dir/home/.config/mimeapps.list"
echo 'PASS: install, non-root launch, relative Unicode path, IPC forwarding, C++ compile/run, immutable /usr, remove/purge retain settings and MIME defaults'
