#!/usr/bin/env bash
# Exercise actual GTK preference dialogs/menu actions. Run under xvfb-run after build.sh.
set -euo pipefail
app_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../linux-noi-lazarus" && pwd)
test_dir=$(mktemp -d)
preferences_home="$test_dir/home"
config="$preferences_home/.config/dev-cpp.ini"
app_pid=''
window=''
dialog_window=''
export LANG=C.UTF-8
export PREFERENCES_COMPILER_LOG="$test_dir/compiler-argv"
mkdir -p "$preferences_home/.config"
cc -shared -fPIC -Wno-deprecated-declarations "$app_dir/../tests/gtk-state-probe.c" -o "$test_dir/probe.so" $(pkg-config --cflags --libs gtk+-2.0) -ldl
editor_control() { python3 "$app_dir/../tests/gtk-control.py" "$test_dir/state.json" 'Editor Options' "$@"; }

cleanup() {
  local result=$?
  if [[ -n "$app_pid" ]]; then
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
  fi
  if [[ $result -eq 0 && ${KEEP_PREFERENCES_FIXTURE:-0} != 1 ]]; then
    rm -rf -- "$test_dir"
  else
    echo "Preferences test fixture: $test_dir"
  fi
}
trap cleanup EXIT
fail() {
  echo "FAIL: $*" >&2
  cat "$config" >&2 || true
  cat "$test_dir/runtime.log" >&2 || true
  exit 1
}
alive() { kill -0 "$app_pid" 2>/dev/null || fail 'IDE exited unexpectedly'; }
press() {
  alive
  dialog_window=''
  xdotool windowfocus "$window" key --clearmodifiers --delay 70 "$@"
  sleep 0.15
}
dialog_press() {
  alive
  xdotool windowfocus "$dialog_window" key --clearmodifiers --delay 70 "$@"
  sleep 0.15
}
type_text() {
  alive
  xdotool type --clearmodifiers --delay 5 -- "$1"
  sleep 0.15
}
wait_dialog() {
  local dialog=''
  for i in {1..80}; do
    dialog=$(xdotool search --all --onlyvisible --pid "$app_pid" --name "^$1$" 2>/dev/null | head -1) || true
    if [[ -n "$dialog" ]]; then
      dialog_window=$dialog
      xdotool windowfocus "$dialog"
      sleep 0.15
      return 0
    fi
    alive
    sleep 0.1
  done
  fail "dialog did not appear: $1"
}
expect_config() {
  python3 - "$config" "$1" "$2" "$3" <<'PY'
import configparser, sys
config = configparser.ConfigParser(interpolation=None)
config.read(sys.argv[1])
actual = config.get(sys.argv[2], sys.argv[3], fallback='<missing>')
if actual != sys.argv[4]:
    raise SystemExit(f'FAIL: [{sys.argv[2]}] {sys.argv[3]}: {actual!r} != {sys.argv[4]!r}')
PY
}
# Capture the whole actual X window and count exact editor background colors.
# This verifies active-document rendering without choosing or guessing UI pixels.
expect_background() {
  local color=$1 label=$2
  local geometry
  geometry=$(xdotool getwindowgeometry --shell "$window")
  eval "$geometry"
  python3 - "$window" "$WIDTH" "$HEIGHT" "$color" "$test_dir/$label.ppm" <<'PY'
import array, ctypes, ctypes.util, sys
lib = ctypes.CDLL(ctypes.util.find_library('X11'))
class XImage(ctypes.Structure):
    _fields_ = [('width', ctypes.c_int), ('height', ctypes.c_int),
                ('xoffset', ctypes.c_int), ('format', ctypes.c_int),
                ('data', ctypes.c_void_p), ('byte_order', ctypes.c_int),
                ('bitmap_unit', ctypes.c_int), ('bitmap_bit_order', ctypes.c_int),
                ('bitmap_pad', ctypes.c_int), ('depth', ctypes.c_int),
                ('bytes_per_line', ctypes.c_int), ('bits_per_pixel', ctypes.c_int)]
lib.XOpenDisplay.argtypes = [ctypes.c_char_p]
lib.XOpenDisplay.restype = ctypes.c_void_p
lib.XGetImage.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_int,
                         ctypes.c_uint, ctypes.c_uint, ctypes.c_ulong, ctypes.c_int]
lib.XGetImage.restype = ctypes.POINTER(XImage)
lib.XDestroyImage.argtypes = [ctypes.POINTER(XImage)]
lib.XCloseDisplay.argtypes = [ctypes.c_void_p]
display = lib.XOpenDisplay(None)
if not display: raise SystemExit('FAIL: cannot open test display')
width, height = map(int, sys.argv[2:4])
picture = lib.XGetImage(display, int(sys.argv[1]), 0, 0, width, height, 0xffffffff, 2)
if not picture: raise SystemExit('FAIL: cannot capture actual editor window')
try:
    image = picture.contents
    if image.bits_per_pixel != 32: raise SystemExit('FAIL: test display must use 24-bit Xvfb/32-bit pixels')
    values = array.array('I', ctypes.string_at(image.data, image.bytes_per_line * image.height))
    target = int(sys.argv[4], 16)
    pixels = [value & 0xffffff for value in values]
    count = pixels.count(target)
    with open(sys.argv[5], 'wb') as output:
        output.write(f'P6\n{width} {height}\n255\n'.encode())
        for row in range(height):
            for value in pixels[row * (image.bytes_per_line // 4):][:width]:
                output.write(bytes((value >> 16, (value >> 8) & 255, value & 255)))
    print(f'Window background #{target:06x}: {count} pixels')
    if count < 100000: raise SystemExit('FAIL: active editor did not apply the expected theme')
finally:
    lib.XDestroyImage(picture)
    lib.XCloseDisplay(display)
PY
}
start_app() {
  env HOME="$preferences_home" XDG_CACHE_HOME="$preferences_home/.cache" LD_PRELOAD="$test_dir/probe.so" DEVC_GTK_STATE="$test_dir/state.json" \
    "$app_dir/dev-cpp" --new-window "$test_dir/sample.cpp" >> "$test_dir/runtime.log" 2>&1 &
  app_pid=$!
  window=''
  for i in {1..100}; do
    window=$(xdotool search --all --onlyvisible --pid "$app_pid" --name 'Dev-C\+\+' 2>/dev/null | head -1) || true
    [[ -z "$window" ]] || break
    alive
    sleep 0.1
  done
  [[ -n "$window" ]] || fail 'main window did not appear'
  sleep 0.4
  press ctrl+alt+e
}
stop_app() {
  kill "$app_pid" 2>/dev/null || true
  wait "$app_pid" 2>/dev/null || true
  app_pid=''
}
compile_expect() {
  local expected=$1
  rm -f "$test_dir/sample" "$PREFERENCES_COMPILER_LOG"
  press ctrl+alt+e F9
  for i in {1..120}; do
    [[ ! -x "$test_dir/sample" ]] || break
    alive
    sleep 0.1
  done
  [[ -x "$test_dir/sample" ]] || fail 'configured compiler did not produce an executable'
  [[ $("$test_dir/sample") == "$expected" ]] || fail "active profile produced the wrong macro value (expected $expected)"
  grep -Fxq -- "-DPROFILE_VALUE=$expected" "$PREFERENCES_COMPILER_LOG" || fail 'actual compiler argv did not include the active profile flags'
}

cat > "$test_dir/compiler-wrapper" <<'SH'
#!/bin/sh
printf '%s\n' "$@" > "$PREFERENCES_COMPILER_LOG"
exec g++ "$@"
SH
chmod +x "$test_dir/compiler-wrapper"
cat > "$config" <<CONF
[Interface]
Language=en
[Compiler]
Cpp=$test_dir/compiler-wrapper
CppFlags=-std=c++14 -DPROFILE_VALUE=41
CONF
cat > "$test_dir/sample.cpp" <<'CPP'
#include <cstdio>
#ifndef PROFILE_VALUE
#define PROFILE_VALUE 0
#endif
int main() { std::printf("%d\n", PROFILE_VALUE); }
CPP
start_app
compile_expect 41
echo 'PASS: legacy compiler settings migrate and compile with their actual flags.'

# Tools -> third item, Editor Theme -> Twilight (second item).
press alt+v Home End Up Right Home Down Return
expect_config Editor Theme Twilight
expect_background 000000 twilight-existing
press ctrl+n
expect_background 000000 twilight-new
press ctrl+w
# Obsidian is the fourth original preset.
press alt+v Home End Up Right Home Down Down Down Return
expect_config Editor Theme Obsidian
expect_background 293134 obsidian-existing
echo 'PASS: theme menu updates existing and newly created documents.'

# Original 5.11 preset backgrounds in menu order; check real rendered pixels,
# saved names, and inheritance by a newly-created document for every preset.
theme_names=('Classic Plus' 'Twilight' 'Visual Studio' 'Obsidian' 'Classic'
             'Ocean' 'Borland' 'Matrix' 'GSS Hacker' 'Oblivion' 'PlasticCodeWrap')
theme_rgb=(ffffff 000000 ffffff 293134 ffffff 00ffff 000080 000000 171717 1e1e1e 0b161d)
for index in "${!theme_names[@]}"; do
  keys=(alt+v Home End Up Right Home)
  for ((step=0; step<index; step++)); do keys+=(Down); done
  keys+=(Return)
  press "${keys[@]}"
  expect_config Editor Theme "${theme_names[index]}"
  expect_background "${theme_rgb[index]}" "theme-$index-existing"
  press ctrl+n
  expect_background "${theme_rgb[index]}" "theme-$index-new"
  press ctrl+w
done
press alt+v Home End Up Right Home Down Down Down Return
expect_config Editor Theme Obsidian
echo 'PASS: all eleven original theme presets render, persist and apply to new documents.'

press ctrl+alt+o
wait_dialog 'Compiler Options'
# The profile list is first in tab order; New is next. New focuses its name.
dialog_press Tab space ctrl+a
type_text Profile73
dialog_press Tab Tab ctrl+a
type_text "$test_dir/compiler-wrapper"
dialog_press Tab Tab ctrl+a
type_text '-O0 -g -std=c++14 -DPROFILE_VALUE=73'
dialog_press Return
expect_config CompilerProfiles Count 2
expect_config CompilerProfiles Active 1
expect_config CompilerProfile.1 Name Profile73
expect_config CompilerProfile.1 CppFlags '-O0 -g -std=c++14 -DPROFILE_VALUE=73'
compile_expect 73
echo 'PASS: creating a named profile changes actual compiler argv and executable behavior.'

# Select Default in the profile list and confirm that its flags remain independent.
press ctrl+alt+o
wait_dialog 'Compiler Options'
dialog_press Home Return
expect_config CompilerProfiles Active 0
compile_expect 41
config_before=$(sha256sum "$config")
press ctrl+alt+o
wait_dialog 'Compiler Options'
dialog_press Tab space ctrl+a
type_text CancelledProfile
dialog_press Tab Tab Tab Tab ctrl+a
type_text '-DPROFILE_VALUE=99'
dialog_press Escape
[[ $(sha256sum "$config") == "$config_before" ]] || fail 'cancelling compiler preferences changed persisted settings'
compile_expect 41
echo 'PASS: switching profiles does not mix flags, and Cancel discards new profiles and edits.'

# Accept a Consolas preference even on a system without that font. The renderer
# must use a monospace fallback while retaining the user's requested family.
press alt+t Home Down Down Return
wait_dialog 'Editor Options'
editor_control click Display
editor_control entry 0 Consolas
editor_control entry 1 12
editor_control click OK
expect_config Editor FontName Consolas
expect_config Editor FontSize 12
press ctrl+n ctrl+w
echo 'PASS: accepting Consolas and font size persists the requested settings.'

# Tools -> Editor Options (second item): change font then cancel.
config_before=$(sha256sum "$config")
press alt+t Home Down Down Return
wait_dialog 'Editor Options'
editor_control click Display
editor_control entry 0 'Liberation Mono'
editor_control click Cancel
[[ $(sha256sum "$config") == "$config_before" ]] || fail 'cancelling editor preferences changed persisted settings'
echo 'PASS: cancelling font preferences preserves the saved configuration.'

stop_app
start_app
expect_config Editor FontName Consolas
expect_config Editor FontSize 12
expect_config Editor Theme Obsidian
expect_background 293134 obsidian-restarted
expect_config CompilerProfiles Active 0
compile_expect 41
press ctrl+alt+o
wait_dialog 'Compiler Options'
dialog_press End Return
expect_config CompilerProfiles Active 1
compile_expect 73
stop_app
start_app
expect_config CompilerProfiles Active 1
compile_expect 73
press ctrl+n
expect_background 293134 obsidian-restarted-new
echo 'PASS: restarted IDE retains theme, named profiles, independent flags and non-default active selection.'
echo 'PASS: real preferences UI regression completed.'
