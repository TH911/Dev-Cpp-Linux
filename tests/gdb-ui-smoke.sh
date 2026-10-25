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
  window=$(xdotool search --onlyvisible --pid "$app_pid" --name 'Dev-C' 2>/dev/null | head -1) || true
  [[ -z $window ]] || break
  alive; sleep 0.1
done
[[ -n $window ]] || fail 'main window missing'
wait_file "$test_dir/state.json"
go_line 13
press F4
press F5
wait_enabled 'Next Line' true
source_line 6
snapshot main-paused
echo 'PASS: F4 records a source breakpoint and F5 builds, starts GDB and stops at main in the real window.'

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
press F6
wait_enabled 'Start Debugging' true
if kill -0 "$inferior_pid" 2>/dev/null; then fail 'F6 left the inferior alive'; fi
snapshot stopped
echo 'PASS: a second debug run starts successfully and F6 terminates its running inferior.'
echo 'Scope: actual main-window keyboard actions and read-only GTK observations; no production instrumentation or guessed click coordinates.'
