#!/usr/bin/env bash
# Real GTK2 main-window debug regression. Run under an isolated xvfb-run.
# The preload probe only observes GTK state; all commands use real X keyboard events.
set -euo pipefail
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
app_dir="$source_root/linux-noi-lazarus"
if [[ -n ${GDB_UI_ARTIFACT_DIR:-} ]]; then
  test_dir=$GDB_UI_ARTIFACT_DIR
  mkdir -p "$test_dir"
else
  test_dir=$(mktemp -d)
fi
mkdir -p "$test_dir/home/.config" "$test_dir/run data"
test_dir=$(cd "$test_dir" && pwd)
app_pid=''
cleanup() {
  local status=$?
  if [[ -n $app_pid ]]; then
    if [[ -n ${window:-} ]] && kill -0 "$app_pid" 2>/dev/null; then
      xdotool windowfocus "$window" key --clearmodifiers F6 2>/dev/null || true
      sleep 0.3
    fi
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
  fi
  if [[ $status -eq 0 && -z ${GDB_UI_ARTIFACT_DIR:-} ]]; then rm -rf -- "$test_dir";
  else echo "GUI debug artifacts: $test_dir"; fi
}
trap cleanup EXIT
fail() { echo "FAIL: $*" >&2; cat "$test_dir/runtime.log" >&2 || true; exit 1; }
alive() { kill -0 "$app_pid" 2>/dev/null || fail 'IDE exited unexpectedly'; }
press() {
  alive
  xdotool windowfocus "$window" key --clearmodifiers --delay 60 "$@"
  sleep 0.15
}
type_text() { xdotool type --clearmodifiers --delay 8 -- "$1"; sleep 0.15; }
wait_text() {
  local expected=$1
  for i in {1..150}; do
    if python3 - "$test_dir/state.json" "$expected" <<'PY'
import json,sys
try: items=json.load(open(sys.argv[1]))
except (OSError,ValueError): sys.exit(1)
sys.exit(0 if any(sys.argv[2] in item['text'] for item in items) else 1)
PY
    then return 0; fi
    alive; sleep 0.1
  done
  fail "GTK text did not appear: $expected"
}
wait_enabled() {
  local caption=$1 enabled=$2
  for i in {1..150}; do
    if python3 - "$test_dir/state.json" "$caption" "$enabled" <<'PY'
import json,sys
try: items=json.load(open(sys.argv[1]))
except (OSError,ValueError): sys.exit(1)
desired=sys.argv[3]=='true'
sys.exit(0 if any(item['text']==sys.argv[2] and item['sensitive']==desired for item in items) else 1)
PY
    then return 0; fi
    alive; sleep 0.1
  done
  fail "GTK command state did not appear: $caption enabled=$enabled"
}
wait_file() {
  for i in {1..150}; do [[ ! -s $1 ]] || return 0; alive; sleep 0.1; done
  fail "file did not appear: $1"
}
focused_entry() {
  python3 - "$test_dir/state.json" <<'PY'
import json,sys
for item in json.load(open(sys.argv[1])):
 if item['focus'] and item['type']=='GtkEntry': print(item['id'])
PY
}
snapshot() {
  rm -f -- "$test_dir/current.png"
  touch "$test_dir/current.png.request"
  wait_file "$test_dir/current.png"
  cp "$test_dir/current.png" "$test_dir/$1.png"
  cp "$test_dir/state.json" "$test_dir/$1.json"
}
go_line() {
  press ctrl+alt+e ctrl+g
  type_text "$1"
  press Return
}
# Read actual screen geometry and rendered line-number glyphs. No assumed
# window position, font height or hard-coded screen click coordinates are used.
# The probe only observes GTK; XGetImage below only observes the gutter pixels.
gutter_geometry() {
  python3 - "$test_dir/state.json" "$1" <<'PY_GUTTER'
import array, ctypes, ctypes.util, json, sys
items = json.load(open(sys.argv[1]))
focused = [w for w in items if w['focus'] and w['type'] in
           ('LCLWinapiClient', 'GtkCustomControl') and w.get('width', 0) > 80]
if len(focused) != 1:
    raise SystemExit('FAIL: focus the source editor before observing its gutter')
w = focused[0]
x, y, width, height = (int(w[k]) for k in ('x', 'y', 'width', 'height'))
line = int(sys.argv[2])
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
lib.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
lib.XDefaultRootWindow.restype = ctypes.c_ulong
lib.XGetImage.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_int,
                         ctypes.c_uint, ctypes.c_uint, ctypes.c_ulong, ctypes.c_int]
lib.XGetImage.restype = ctypes.POINTER(XImage)
lib.XDestroyImage.argtypes = [ctypes.POINTER(XImage)]
lib.XCloseDisplay.argtypes = [ctypes.c_void_p]
display = lib.XOpenDisplay(None)
if not display: raise SystemExit('FAIL: cannot open test display')
image = lib.XGetImage(display, lib.XDefaultRootWindow(display), x, y,
                      min(width, 60), height, 0xffffffff, 2)
if not image: raise SystemExit('FAIL: cannot observe editor gutter')
try:
    picture = image.contents
    if picture.bits_per_pixel != 32:
        raise SystemExit('FAIL: test display must use 24-bit Xvfb/32-bit pixels')
    pixels = array.array('I', ctypes.string_at(picture.data,
                                               picture.bytes_per_line * height))
    stride = picture.bytes_per_line // 4
    def rgb(col, row):
        value = pixels[row * stride + col]
        return (value >> 16) & 255, (value >> 8) & 255, value & 255
    def ink(col, row):
        r,g,b = rgb(col, row)
        return max(r,g,b) < 200 and max(r,g,b) - min(r,g,b) < 35
    # Default SynEdit has a separate 22px marks part before the line-number
    # part. Remove constant separator columns; retain only rendered digits.
    columns = [col for col in range(23, min(width, 52))
               if 0.01 < sum(ink(col,row) for row in range(2,height-2)) / height < 0.55]
    rows = [row for row in range(2,height-2) if any(ink(col,row) for col in columns)]
    bands = []
    for row in rows:
        if not bands or row - bands[-1][-1] > 2: bands.append([row])
        else: bands[-1].append(row)
    if line < 1 or line > len(bands):
        raise SystemExit('FAIL: rendered gutter does not show requested fixture line: ' + str((line, bands)))
    band = bands[line - 1]
    center = (band[0] + band[-1]) // 2
    marker = 0
    for row in range(max(0,center-7), min(height,center+8)):
        for col in range(2,22):
            r,g,b = rgb(col,row)
            marker += r > 120 and r > g * 1.4 and r > b * 1.4
    # Aim inside the line-number part, rather than only its icon margin.
    print(x + 34, y + center, marker)
finally:
    lib.XDestroyImage(image)
    lib.XCloseDisplay(display)
PY_GUTTER
}
click_gutter() {
  local point gx gy red
  point=$(gutter_geometry "$1") || fail 'could not locate actual rendered line number'
  read -r gx gy red <<< "$point"
  xdotool mousemove --sync "$gx" "$gy" click "${2:-1}"
  sleep 0.2
}
expect_gutter_marker() {
  local point gx gy red
  for i in {1..30}; do
    point=$(gutter_geometry "$1") || fail 'could not observe actual gutter marker'
    read -r gx gy red <<< "$point"
    if [[ $2 == present && $red -ge 8 ]] || [[ $2 == absent && $red -eq 0 ]]; then return 0; fi
    alive; sleep 0.1
  done
  fail "line $1 breakpoint marker did not become $2 (red pixels: $red)"
}
evaluate() {
  press alt+d e ctrl+a
  type_text "$1"
  press Return
  wait_text "$1 = $2"
}
continue_debug() { press alt+d c; }
source_line() {
  # Escape does not move the caret. Its KeyUp refreshes the normal editor
  # status, allowing observation of the actual caret set by DebugLocation.
  press ctrl+alt+e Escape
  wait_text "Line: $1 "
}

[[ -x "$app_dir/devcpp-noi" ]] || fail 'build the IDE before this GUI test'
gcc -shared -fPIC -Wno-deprecated-declarations \
  "$source_root/tests/gtk-state-probe.c" -o "$test_dir/gtk-state-probe.so" \
  $(pkg-config --cflags --libs gtk+-2.0) -ldl
cat > "$test_dir/home/.config/devcpp-noi.ini" <<EOF
[Interface]
Language=en
[Run]
WorkingDirectory=$test_dir/run data
EOF
cat > "$test_dir/debug fixture.c" <<'C'
#include <stdio.h>
#include <unistd.h>
int twice(int x) {
  return x * 2;
}
int main(void) {
  int value = 7;
  int input = 0;
  FILE *pid = fopen("inferior.pid", "w"); fprintf(pid, "%d\n", getpid()); fclose(pid);
  printf("GUI_READY\n"); fflush(stdout);
  scanf("%d", &input);
  value += input;
  value = twice(value);
  FILE *result = fopen("result.txt", "w"); fprintf(result, "%d\n", value); fclose(result);
  printf("GUI_VALUE=%d\n", value); fflush(stdout);
  return 0;
}
C
cp "$test_dir/debug fixture.c" "$test_dir/original.c"
export LANG=C.UTF-8
env HOME="$test_dir/home" XDG_CACHE_HOME="$test_dir/home/.cache" \
  XDG_DATA_HOME="$test_dir/home/.local/share" \
  LD_PRELOAD="$test_dir/gtk-state-probe.so" DEVC_GTK_STATE="$test_dir/state.json" \
  DEVC_GTK_SCREENSHOT="$test_dir/current.png" \
  "$app_dir/devcpp-noi" --new-window "$test_dir/debug fixture.c" > "$test_dir/runtime.log" 2>&1 &
app_pid=$!
window=''
for i in {1..100}; do
  window=$(xdotool search --all --onlyvisible --pid "$app_pid" --name 'Dev-C' 2>/dev/null | head -1) || true
  [[ -z $window ]] || break
  alive; sleep 0.1
done
[[ -n $window ]] || fail 'main window missing'
wait_file "$test_dir/state.json"
go_line 1
click_gutter 13
expect_gutter_marker 13 present
click_gutter 13
expect_gutter_marker 13 absent
click_gutter 13 3
press Escape
expect_gutter_marker 13 absent
# A drag across the line-number area must not toggle a breakpoint.
read -r drag_x drag_y _ <<< "$(gutter_geometry 13)"
read -r _ drag_end_y _ <<< "$(gutter_geometry 14)"
xdotool mousemove --sync "$drag_x" "$drag_y" mousedown 1 \
  mousemove --sync "$drag_x" "$drag_end_y" mouseup 1
sleep 0.2
expect_gutter_marker 13 absent
expect_gutter_marker 14 absent
click_gutter 13
expect_gutter_marker 13 present
press F5
wait_enabled 'Next Line' true
source_line 6
snapshot main-paused
python3 - "$test_dir/state.json" <<'PY_BUTTONS'
import json, sys
widgets = json.load(open(sys.argv[1]))
unexpected = {'Evaluate expression', 'Send input', 'Copy details'}
shown = {widget['text'] for widget in widgets
         if widget['type'] == 'GtkButton' and widget['visible']}
assert not (unexpected & shown), 'Non-original debugger buttons are visible: ' + str(unexpected & shown)
PY_BUTTONS
echo 'PASS: actual line-number clicks add/remove source breakpoints; right-click and drag do not toggle; F5 builds and stops at main.'

# A source edit attempted during debugging must be rejected by the IDE.
press ctrl+alt+e
type_text 'INVALID_WHILE_DEBUGGING'
press Tab Return
type_text '('
press ctrl+space Return Escape
press ctrl+s
cmp -s "$test_dir/debug fixture.c" "$test_dir/original.c" || fail 'debugging allowed source mutation'
# Saving is disabled during a session, so comparing the disk above cannot
# detect a mutation of the in-memory editor. Stop, save the actual buffer, then
# compare before starting a fresh session for the stepping assertions below.
press F6
wait_enabled 'Start Debugging' true
press ctrl+alt+e ctrl+s
cmp -s "$test_dir/debug fixture.c" "$test_dir/original.c" || fail 'debugging editing callbacks changed the source buffer'
echo 'PASS: ordinary text, Tab, Return, paired brackets and accepted completion cannot mutate the paused source buffer.'
press F5
wait_enabled 'Next Line' true
source_line 6
# The paused editor is read-only, but its gutter must still support real MI
# breakpoint deletion and insertion. This line is hit after program input.
go_line 1
click_gutter 13
expect_gutter_marker 13 absent
click_gutter 13
expect_gutter_marker 13 present
go_line 6
press F7
source_line 7
press F7
source_line 8
evaluate value 7
expression_id=$(focused_entry)
[[ -n $expression_id ]] || fail 'Evaluate Expression did not focus its entry'
snapshot value-evaluated
echo 'PASS: source is read-only while debugging; F7 moves the real editor to the next source line and UI expression evaluation reports value = 7.'

continue_debug
wait_text 'GUI_READY'
# Start from the known expression entry and use actual Tab traversal. The
# read-only probe identifies focused GTK entries, avoiding pixel coordinates.
input_id=''
for i in {1..24}; do
  press Tab
  candidate=$(focused_entry)
  if [[ -n $candidate && $candidate != "$expression_id" ]]; then input_id=$candidate; break; fi
done
[[ -n $input_id ]] || fail 'could not reach program input with normal Tab traversal'
type_text 5
press Return
wait_enabled 'Next Line' true
source_line 13
evaluate value 12
press ctrl+alt+e F8
source_line 3
press F7
source_line 4
evaluate x 12
snapshot function-paused
echo 'PASS: program output is visible, Tab-reached program input feeds scanf, the user breakpoint stops at line 13, and F8 enters twice with x = 12.'

continue_debug
wait_file "$test_dir/run data/result.txt"
[[ $(cat "$test_dir/run data/result.txt") == 24 ]] || fail 'wrong program result after TTY input'
wait_text 'GUI_VALUE=24'
wait_enabled 'Start Debugging' true
press ctrl+alt+e ctrl+End
type_text '// EDIT_AFTER_EXIT'
press ctrl+s
tail -1 "$test_dir/debug fixture.c" | grep -q 'EDIT_AFTER_EXIT' || fail 'normal exit did not restore editing'
snapshot exited-and-editable
echo 'PASS: output and file result equal 24; normal exit releases GDB and restores source editing.'

rm -f -- "$test_dir/run data/inferior.pid"
press F5
wait_enabled 'Next Line' true
continue_debug
wait_text 'GUI_READY'
wait_file "$test_dir/run data/inferior.pid"
inferior_pid=$(cat "$test_dir/run data/inferior.pid")
kill -0 "$inferior_pid" 2>/dev/null || fail 'second inferior did not start'
# The IDE remains visibly running while the backend briefly interrupts Linux
# GDB's target, edits its breakpoint, then resumes it. Exercise both operations
# while the program waits for input, without opening a modal dialog.
go_line 1
click_gutter 14
expect_gutter_marker 14 present
sleep 0.2
click_gutter 14
expect_gutter_marker 14 absent
press F6
wait_enabled 'Start Debugging' true
if kill -0 "$inferior_pid" 2>/dev/null; then fail 'F6 left the inferior alive'; fi
snapshot stopped
echo 'PASS: line-number clicks add/remove breakpoints while the target is running; F6 terminates its inferior.'
echo 'Scope: actual main-window keyboard actions and read-only GTK observations; no production instrumentation or guessed click coordinates.'
