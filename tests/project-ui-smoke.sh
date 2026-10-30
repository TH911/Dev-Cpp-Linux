#!/usr/bin/env bash
# Real File -> New -> Project discovery, creation and multi-source build.
set -euo pipefail
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=${PROJECT_UI_ARTIFACT_DIR:-$(mktemp -d)}
mkdir -p "$test_dir"
test_dir=$(cd "$test_dir" && pwd)
app_pid=''
cleanup() {
  local status=$?
  if [[ -n $app_pid ]]; then
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
  fi
  if [[ $status == 0 && -z ${PROJECT_UI_ARTIFACT_DIR:-} ]]; then
    rm -rf -- "$test_dir"
  else
    echo "Project UI fixture: $test_dir"
  fi
}
trap cleanup EXIT
export LANG=C.UTF-8
fail() {
  echo "FAIL: $*" >&2
  touch "$case_dir/screen.png.request"; sleep 0.2
  cat "$case_dir/runtime.log" >&2
  exit 1
}
alive() { kill -0 "$app_pid" 2>/dev/null || fail 'IDE exited'; }
wait_window() {
  local found=''
  for attempt in {1..100}; do
    found=$(xdotool search --all --onlyvisible --pid "$app_pid" --name "$1" 2>/dev/null | head -1) || true
    [[ -z $found ]] || { echo "$found"; return; }
    alive; sleep 0.1
  done
  fail "window did not appear: $1"
}
press() { xdotool windowfocus "$window" key --clearmodifiers --delay 100 "$@"; sleep 0.15; }
choose_path() {
  # Explicitly open Location before typing: '/' otherwise changes the Open
  # chooser's focus asynchronously and can consume the first path characters.
  xdotool windowfocus "$dialog" key --clearmodifiers ctrl+l
  sleep 0.2
  xdotool key --clearmodifiers ctrl+a
  # XTest keymap remapping can lose adjacent non-ASCII characters; paste the
  # literal UTF-8 path through GTK's clipboard, as a user can in the chooser.
  rm -f "$case_dir/clipboard.ready"
  "$test_dir/clipboard" "$1" "$case_dir/clipboard.ready" &
  local clipboard_pid=$!
  for attempt in {1..50}; do
    [[ ! -f "$case_dir/clipboard.ready" ]] || break
    sleep 0.02
  done
  xdotool key --clearmodifiers ctrl+v
  sleep 0.2
  kill "$clipboard_pid"; wait "$clipboard_pid" 2>/dev/null || true
  xdotool key --clearmodifiers Return
  sleep 0.3
}
wait_project_units() {
  for attempt in {1..100}; do
    if python3 - "$project" "$1" <<'PY'
import configparser, sys
try:
    p = configparser.ConfigParser(); p.read(sys.argv[1])
    assert p.getint('Project', 'UnitCount') == int(sys.argv[2])
except (OSError, configparser.Error, AssertionError):
    sys.exit(1)
PY
    then return; fi
    alive; sleep 0.1
  done
  fail "project does not contain $1 units"
}
gcc -shared -fPIC "$source_root/tests/gtk-state-probe.c" -o "$test_dir/probe.so" \
  $(pkg-config --cflags --libs gtk+-2.0) -ldl > "$test_dir/probe-build.log" 2>&1
cat > "$test_dir/clipboard.c" <<'C'
#include <gtk/gtk.h>
#include <stdio.h>
int main(int argc, char **argv) {
    gtk_init(&argc, &argv);
    gtk_clipboard_set_text(gtk_clipboard_get(GDK_SELECTION_CLIPBOARD), argv[1], -1);
    FILE *ready = fopen(argv[2], "w");
    if (!ready) return 1;
    fclose(ready);
    gtk_main();
    return 0;
}
C
gcc "$test_dir/clipboard.c" -o "$test_dir/clipboard" \
  $(pkg-config --cflags --libs gtk+-2.0) >> "$test_dir/probe-build.log" 2>&1
for language in en zh; do
  case_dir="$test_dir/$language"
  mkdir -p "$case_dir/home/.config" "$case_dir/home/.local/share" "$case_dir/中文 project"
  printf '[Interface]\nLanguage=%s\n' "$language" > "$case_dir/home/.config/dev-cpp.ini"
  project="$case_dir/中文 project/Project1.dev"
  if [[ $language == en ]]; then new_title='^New Project$'; open_title='^Open$';
  else new_title='^新项目$'; open_title='^打开$'; fi
  env HOME="$case_dir/home" XDG_CACHE_HOME="$case_dir/home/.cache" \
    LD_PRELOAD="$test_dir/probe.so" DEVC_GTK_STATE="$case_dir/state.json" \
    DEVC_GTK_SCREENSHOT="$case_dir/screen.png" \
    "$source_root/linux-noi-lazarus/dev-cpp" --new-window > "$case_dir/runtime.log" 2>&1 &
  app_pid=$!
  window=$(wait_window 'Dev-C\+\+')
  sleep 0.3
  # Traverse the same File -> New -> Project menu path as original Dev-C++.
  press alt+f n p
  dialog=$(wait_window "$new_title")
  xdotool windowfocus "$dialog" key --clearmodifiers Escape
  sleep 0.2
  [[ ! -e $project ]] || fail 'cancelled creation wrote a project'
  press alt+f n p
  dialog=$(wait_window "$new_title")
  choose_path "$project"
  wait_project_units 0
  xdotool getwindowname "$window" | grep -F 'Project1.dev' >/dev/null || fail 'project not activated'
  cat > "$case_dir/中文 project/main.cpp" <<'CPP'
#include <fstream>
int answer();
int main() { std::ofstream("project-ran.txt") << answer(); }
CPP
  printf 'int answer() { return 42; }\n' > "$case_dir/中文 project/helper.cpp"
  unit_count=0
  for unit in main.cpp helper.cpp; do
    press alt+p a
    dialog=$(wait_window "$open_title")
    # Add File starts in the project directory. Select actual rows, including
    # paths with spaces and Chinese names, rather than GTK's Location search.
    sleep 0.3
    point=$(python3 - "$case_dir/state.json" <<'PY'
import json,sys
items=json.load(open(sys.argv[1])); by_id={w['id']:w for w in items}
def shown(w):
    while w:
        if not w['visible']: return False
        w=by_id.get(w['parent'])
    return True
def in_chooser(w):
    while w:
        if w['type']=='GtkFileChooserDialog': return True
        w=by_id.get(w['parent'])
    return False
views=[w for w in items if w['type']=='GtkTreeView' and shown(w) and
       in_chooser(w) and w['width']>200]
assert views, 'file list not visible'
w=max(views,key=lambda w:w['width']); print(w['x']+w['width']//2,w['y']+50)
PY
    )
    read -r click_x click_y <<< "$point"
    xdotool windowfocus "$dialog"
    xdotool mousemove --sync "$click_x" "$click_y" click 1
    if [[ $unit == main.cpp ]]; then xdotool key --clearmodifiers End;
    else xdotool key --clearmodifiers Home; fi
    xdotool key --clearmodifiers Return
    unit_count=$((unit_count + 1))
    wait_project_units "$unit_count"
  done
  touch "$case_dir/screen.png.request"; sleep 0.2
  press F11
  for attempt in {1..150}; do
    [[ ! -s "$case_dir/中文 project/project-ran.txt" ]] || break
    alive; sleep 0.1
  done
  [[ $(cat "$case_dir/中文 project/project-ran.txt") == 42 ]] || fail 'multi-source project did not compile and run'
  # Closing the project resets the title; reopening restores both units.
  # The original Chinese Close Project caption has no C mnemonic.
  press alt+p Home Down Down Return
  sleep 0.2
  [[ $(xdotool getwindowname "$window") != *Project1.dev* ]] || fail 'project did not close'
  env HOME="$case_dir/home" XDG_CACHE_HOME="$case_dir/home/.cache" \
    "$source_root/linux-noi-lazarus/dev-cpp" --forward-only "$project"
  sleep 0.3
  wait_project_units 2
  xdotool getwindowname "$window" | grep -F 'Project1.dev' >/dev/null || fail 'project did not reopen'
  # Ctrl+N must still create a source file after the menu moves into a submenu.
  press ctrl+n ctrl+s
  dialog=$(wait_window '^(Save As|保存为)$')
  xdotool windowfocus "$dialog" key --clearmodifiers Escape
  kill "$app_pid"; wait "$app_pid" 2>/dev/null || true; app_pid=''
  echo "PASS: $language File/New/Project, cancel, create, add units, F11 build/run, close and reopen"
done
