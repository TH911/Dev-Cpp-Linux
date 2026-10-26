#!/usr/bin/env bash
# Destructive to this container's package installation: use a disposable Ubuntu
# 20.04 amd64 container with the package dependencies and test tools installed.
set -euo pipefail
if [[ $EUID != 0 ]]; then
  echo 'Run as root inside a disposable test container.' >&2
  exit 1
fi
deb=$(realpath -- "${1:?Usage: verify-install.sh /path/to/devcpp-noi_VERSION_amd64.deb}")
for tool in dpkg runuser xvfb-run xdotool timeout sha256sum fpc python3; do
  command -v "$tool" >/dev/null || { echo "Missing test tool: $tool" >&2; exit 1; }
done
if dpkg-query -W -f='${Status}' devcpp-noi 2>/dev/null | grep -q ' installed$'; then
  echo 'Refusing to replace an existing install; use a fresh test container.' >&2
  exit 1
fi
test_dir=$(mktemp -d /tmp/devcpp-package-test.XXXXXX)
cleanup() {
  if [[ ${KEEP_INSTALL_FIXTURE:-0} == 1 ]]; then
    echo "Install test fixture: $test_dir"
  else
    rm -rf -- "$test_dir"
  fi
}
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
# Simulate source registration from v1.1.0, before the package exists.
mkdir -p "$test_dir/old source" "$test_dir/home/.local/share/applications" \
  "$test_dir/home/.local/share/nautilus/scripts"
cat > "$test_dir/old source/launch.sh" <<'SH'
#!/bin/sh
echo old-launcher-was-used > "$HOME/old-launcher-was-used"
exit 1
SH
python3 - "$test_dir" <<'PYFIXTURE'
import sys
from pathlib import Path
folder = Path(sys.argv[1])
old = folder / 'old source'
text = f'''[Desktop Entry]
Type=Application
Name=Dev-C++
Comment=Dev-C++ for NOI Linux
Comment[zh_CN]=适用于 NOI Linux 的 Dev-C++
Exec=/bin/bash "{old}/launch.sh" %F
Icon={old}/devcpp.ico
Terminal=false
Categories=Development;IDE;
MimeType=text/x-c++src;text/x-csrc;text/x-c++hdr;text/x-chdr;
Actions=NewWindow;

[Desktop Action NewWindow]
Name=Open in New Window
Name[zh_CN]=在新窗口打开
Exec=/bin/bash "{old}/launch.sh" --new-window %F
'''
(folder / 'home/.local/share/applications/devcpp-noi.desktop').write_text(text)
(folder / 'legacy-desktop.expected').write_text(text)
PYFIXTURE
# A v1.1.0 IPC server, using the old unversioned address, must never receive
# activation from the new installed program.
cat > "$test_dir/legacy-instance.pas" <<'PAS'
program LegacyInstance;
{$mode objfpc}{$H+}
uses Classes, SysUtils, SimpleIPC;
var Server: TSimpleIPCServer; F: TextFile;
begin
  ForceDirectories(ExtractFileDir(ParamStr(1)));
  Server := TSimpleIPCServer.Create(nil);
  Server.ServerID := ParamStr(1); Server.Global := True; Server.StartServer(False);
  AssignFile(F, ParamStr(2)); Rewrite(F); WriteLn(F, 'ready'); CloseFile(F);
  while True do begin
    if Server.PeekMessage(0, True) then begin
      AssignFile(F, ParamStr(3)); Rewrite(F); WriteLn(F, Server.StringMessage); CloseFile(F);
    end;
    Sleep(10);
  end;
end.
PAS
fpc -FU"$test_dir" -FE"$test_dir" "$test_dir/legacy-instance.pas" > "$test_dir/legacy-build.log" 2>&1 || {
  cat "$test_dir/legacy-build.log" >&2; exit 1;
}
chown -R "$test_user:$test_group" "$test_dir"
dpkg -i "$deb"
dpkg --audit
test -x /usr/bin/devcpp-noi
test -r /usr/share/icons/hicolor/scalable/apps/devcpp-noi.svg
test -r /usr/share/applications/devcpp-noi-installed.desktop
test -x /usr/lib/devcpp-noi/migrate-launchers.py
test -r /etc/xdg/autostart/devcpp-noi-migrate.desktop
if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate /usr/share/applications/devcpp-noi.desktop
  desktop-file-validate /usr/share/applications/devcpp-noi-installed.desktop
fi
find /usr/lib/devcpp-noi -type f -exec sha256sum {} + | sort > "$test_dir/installed.before"
# Launch from a directory containing a relative, spaced, non-ASCII filename;
# verify a real window then forward to that instance using the installed wrapper.
runuser -u "$test_user" -- env HOME="$test_dir/home" XDG_CACHE_HOME="$test_dir/home/.cache" \
  LANG=C.UTF-8 PACKAGE_TEST_DIR="$test_dir" PACKAGE_TEST_VERSION="$(dpkg-deb -f "$deb" Version)" \
  PACKAGE_TEST_TRACE="${PACKAGE_TEST_TRACE:-0}" timeout 60 xvfb-run -a bash <<'SH'
set -euo pipefail
[[ $PACKAGE_TEST_TRACE != 1 ]] || set -x
cd "$PACKAGE_TEST_DIR/work folder"
launch_desktop() {
  python3 - "$@" <<'DESKTOPPY'
import ctypes, os, sys
from ctypes.util import find_library

gio = ctypes.CDLL(find_library('gio-2.0'))
glib = ctypes.CDLL(find_library('glib-2.0'))
gio.g_desktop_app_info_new_from_filename.argtypes = [ctypes.c_char_p]
gio.g_desktop_app_info_new_from_filename.restype = ctypes.c_void_p
gio.g_file_new_for_path.argtypes = [ctypes.c_char_p]
gio.g_file_new_for_path.restype = ctypes.c_void_p
glib.g_list_append.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
glib.g_list_append.restype = ctypes.c_void_p
gio.g_app_info_launch.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
gio.g_app_info_launch.restype = ctypes.c_int
app = gio.g_desktop_app_info_new_from_filename(os.fsencode(sys.argv[1]))
assert app, 'Invalid installed desktop entry'
files = None
for filename in sys.argv[2:]:
    files = glib.g_list_append(files, gio.g_file_new_for_path(os.fsencode(filename)))
assert gio.g_app_info_launch(app, files, None, None), 'Desktop launch failed'
DESKTOPPY
}
legacy_pid=''
ide_pid=''
source_pid=''
cleanup_gui() {
  for pid in "$ide_pid" "$source_pid" "$legacy_pid"; do
    [[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true
    [[ -z "$pid" ]] || wait "$pid" 2>/dev/null || true
  done
}
trap cleanup_gui EXIT
"$PACKAGE_TEST_DIR/legacy-instance" "$HOME/.cache/devcpp-noi/instance.pipe" \
  "$PACKAGE_TEST_DIR/legacy.ready" "$PACKAGE_TEST_DIR/legacy.received" &
legacy_pid=$!
for attempt in {1..100}; do [[ ! -f "$PACKAGE_TEST_DIR/legacy.ready" ]] || break; sleep 0.05; done
# A running source build at another path must also retain its separate window.
cp /usr/lib/devcpp-noi/devcpp-noi "$PACKAGE_TEST_DIR/old source/devcpp-noi"
"$PACKAGE_TEST_DIR/old source/devcpp-noi" --new-window > "$PACKAGE_TEST_DIR/source.log" 2>&1 &
source_pid=$!
source_window=''
for attempt in {1..100}; do
  source_window=$(xdotool search --all --onlyvisible --pid "$source_pid" --name 'Dev-C' 2>/dev/null | head -1) || true
  [[ -z "$source_window" ]] || break
  kill -0 "$source_pid"
  sleep 0.05
done
[[ -n "$source_window" ]] || { cat "$PACKAGE_TEST_DIR/source.log" >&2; exit 1; }
# Software panels use GDesktopAppInfo to execute this desktop ID.
launch_desktop /usr/share/applications/devcpp-noi-installed.desktop \
  "$PWD/中文 relative.cpp" > "$PACKAGE_TEST_DIR/startup.log" 2>&1
for attempt in {1..100}; do
  ide_pid=$(python3 - "$PWD/中文 relative.cpp" <<'FINDPID'
import os,sys
from pathlib import Path
for path in Path('/proc').iterdir():
    if not path.name.isdigit(): continue
    try:
        if os.readlink(str(path / 'exe')) != '/usr/lib/devcpp-noi/devcpp-noi': continue
        args = (path / 'cmdline').read_bytes().split(b'\0')
        if os.fsencode(sys.argv[1]) in args: print(path.name); break
    except OSError: pass
FINDPID
  )
  [[ -z "$ide_pid" ]] || break
  sleep 0.05
done
[[ -n "$ide_pid" ]] || { echo 'FAIL: desktop did not start the installed executable (possible old IPC forwarding)' >&2; exit 1; }
window=''
for attempt in {1..100}; do
  window=$(xdotool search --all --onlyvisible --pid "$ide_pid" --name 'Dev-C' 2>/dev/null | head -1) || true
  [[ -z "$window" ]] || break
  kill -0 "$ide_pid"
  sleep 0.1
done
[[ -n "$window" ]] || { cat "$PACKAGE_TEST_DIR/startup.log" >&2; exit 1; }
python3 - "$window" "$ide_pid" "$source_window" <<'WINDOWMETA'
import ctypes, os, stat, sys
from ctypes.util import find_library
from pathlib import Path

class ClassHint(ctypes.Structure):
    _fields_ = [('name', ctypes.c_char_p), ('klass', ctypes.c_char_p)]
x11 = ctypes.CDLL(find_library('X11'))
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XGetClassHint.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ClassHint)]
display = x11.XOpenDisplay(None)
hint = ClassHint()
assert display and x11.XGetClassHint(display, int(sys.argv[1]), ctypes.byref(hint))
assert hint.klass.decode() == 'DevCppNoiInstalled', (hint.name, hint.klass)
source_hint = ClassHint()
assert x11.XGetClassHint(display, int(sys.argv[3]), ctypes.byref(source_hint))
assert source_hint.klass.decode() == 'Devcpp-noi', (source_hint.name, source_hint.klass)
assert source_hint.klass != hint.klass, 'Source and installed windows would be grouped together'
fifo_count = 0
for fd in (Path('/proc') / sys.argv[2] / 'fd').iterdir():
    try:
        target = os.readlink(str(fd))
        if not target.startswith(str(Path.home() / '.cache/devcpp-noi/instance-')):
            continue
        assert stat.S_ISFIFO(fd.stat().st_mode), target
        info = (fd.parent.parent / 'fdinfo' / fd.name).read_text()
        flags = int(next(line.split()[1] for line in info.splitlines() if line.startswith('flags:')), 8)
        assert flags & os.O_CLOEXEC, 'IDE IPC FIFO would leak into child processes'
        fifo_count += 1
    except FileNotFoundError:
        pass
assert fifo_count >= 1, 'No installed instance FIFO was checked'
print('PASS: distinct source/installed window classes and close-on-exec IPC descriptor')
WINDOWMETA
sleep 0.3
test ! -e "$PACKAGE_TEST_DIR/legacy.received"
kill -0 "$source_pid"
test ! -e "$HOME/old-launcher-was-used"
test ! -e "$HOME/.local/share/applications/devcpp-noi.desktop"
python3 - "$PACKAGE_TEST_DIR" <<'BACKUP'
import sys
from pathlib import Path
folder = Path(sys.argv[1])
files = list((folder / 'home/.local/share/devcpp-noi/launcher-backups').glob('devcpp-noi.desktop.*.bak'))
assert len(files) == 1 and files[0].read_text() == (folder / 'legacy-desktop.expected').read_text()
BACKUP
# An existing favorite/MIME ID still resolves to a hidden package alias.
launch_desktop /usr/share/applications/devcpp-noi.desktop "$PWD/中文 relative.cpp"
/usr/bin/devcpp-noi --forward-only '中文 relative.cpp'
xdotool windowfocus "$window" key F11
for attempt in {1..100}; do
  [[ ! -s packaged-ran.txt ]] || break
  kill -0 "$ide_pid"
  sleep 0.1
done
[[ $(cat packaged-ran.txt) == ok ]] || { cat "$PACKAGE_TEST_DIR/startup.log" >&2; exit 1; }
python3 - "$ide_pid" <<'CHILDIPC'
import os, sys
from pathlib import Path
pid = sys.argv[1]
identities = set()
for fd in (Path('/proc') / pid / 'fd').iterdir():
    try:
        if os.readlink(str(fd)).startswith(str(Path.home() / '.cache/devcpp-noi/instance-')):
            info = fd.stat()
            identities.add((info.st_dev, info.st_ino))
    except OSError:
        pass
assert identities, 'Installed IPC descriptor missing'
for process in Path('/proc').iterdir():
    if not process.name.isdigit() or process.name == pid:
        continue
    try:
        for fd in (process / 'fd').iterdir():
            try:
                info = fd.stat()
                assert (info.st_dev, info.st_ino) not in identities, 'Child inherited IDE IPC FIFO: ' + str(process)
            except OSError:
                pass
    except OSError:
        pass
print('PASS: compiled programs and terminal processes do not retain the IDE IPC FIFO')
CHILDIPC
# A normal user must be able to read all resources but cannot alter /usr/lib.
test -r /usr/lib/devcpp-noi/icons/compile.bmp
test ! -w /usr/lib/devcpp-noi
# Remove the source tree, stop both windows, then open from the desktop again.
kill "$source_pid" "$ide_pid"
wait "$source_pid" 2>/dev/null || true
wait "$ide_pid" 2>/dev/null || true
source_pid=''; ide_pid=''
rm -rf -- "$PACKAGE_TEST_DIR/old source"
launch_desktop /usr/share/applications/devcpp-noi-installed.desktop "$PWD/中文 relative.cpp"
for attempt in {1..100}; do
  ide_pid=$(python3 - <<'FINDRESTART'
import os
from pathlib import Path
for path in Path('/proc').iterdir():
    if not path.name.isdigit(): continue
    try:
        if os.readlink(str(path / 'exe')) == '/usr/lib/devcpp-noi/devcpp-noi':
            print(path.name); break
    except OSError: pass
FINDRESTART
  )
  [[ -z "$ide_pid" ]] || break
  sleep 0.05
done
[[ -n "$ide_pid" ]] || { echo 'FAIL: desktop did not start the installed executable (possible old IPC forwarding)' >&2; exit 1; }
window=''
for attempt in {1..100}; do
  window=$(xdotool search --all --onlyvisible --pid "$ide_pid" --name 'Dev-C' 2>/dev/null | head -1) || true
  [[ -z "$window" ]] || break
  sleep 0.05
done
[[ -n "$window" ]]
test ! -e "$PACKAGE_TEST_DIR/legacy.received"
/usr/bin/devcpp-noi --version | grep -Fx "Dev-C++ NOI $PACKAGE_TEST_VERSION"
echo 'PASS: real installed desktop, legacy launcher backup, old/source IPC isolation, restart after source removal'
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
