#!/usr/bin/env bash
# Verify version, installation details, repository link and the actual clipboard.
# Run under xvfb-run after building the application.
set -euo pipefail
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
app_dir="$source_root/linux-noi-lazarus"
test_dir=$(mktemp -d)
app_pid=''
cleanup() {
  local result=$?
  if [[ -n $app_pid ]]; then
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
  fi
  if [[ $result == 0 && ${KEEP_ABOUT_FIXTURE:-0} != 1 ]]; then
    rm -rf -- "$test_dir"
  else
    echo "About test fixture: $test_dir"
  fi
}
trap cleanup EXIT
fail() { echo "FAIL: $*" >&2; cat "$test_dir/runtime.log" >&2 || true; exit 1; }
alive() { kill -0 "$app_pid" 2>/dev/null || fail 'IDE exited unexpectedly'; }
wait_text() {
  for i in {1..100}; do
    if python3 - "$test_dir/state.json" "$1" <<'PY'
import json,sys
try: items=json.load(open(sys.argv[1]))
except (OSError,ValueError): sys.exit(1)
sys.exit(0 if any(sys.argv[2] in item['text'] for item in items) else 1)
PY
    then return 0; fi
    alive; sleep 0.1
  done
  fail "GTK text missing: $1"
}
click_text() {
  local position
  position=$(python3 - "$test_dir/state.json" "$1" <<'PY'
import json,sys
items=json.load(open(sys.argv[1]))
for item in items:
 if item['text']==sys.argv[2] and item['visible'] and item.get('width',0)>0:
  print(item['x']+item['width']//2,item['y']+item['height']//2)
  break
else: raise SystemExit('Visible control geometry missing: '+sys.argv[2])
PY
  ) || fail "Cannot locate control: $1"
  read -r click_x click_y <<< "$position"
  xdotool mousemove --sync "$click_x" "$click_y" click 1
  sleep 0.2
}
snapshot() {
  # Native GTK labels can be observable before their first expose event.
  # Let that queued paint finish before requesting the visual review artifact.
  sleep 0.25
  rm -f -- "$test_dir/current.png"
  touch "$test_dir/current.png.request"
  for i in {1..100}; do
    if [[ -s "$test_dir/current.png" ]]; then
      cp "$test_dir/current.png" "$test_dir/$1.png"
      return
    fi
    alive; sleep 0.1
  done
  fail 'About screenshot was not captured'
}

mkdir -p "$test_dir/home/.config" "$test_dir/bin"
printf '[Interface]\nLanguage=en\n' > "$test_dir/home/.config/dev-cpp.ini"
cat > "$test_dir/bin/xdg-open" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$ABOUT_BROWSER_LOG"
SH
chmod +x "$test_dir/bin/xdg-open"
cat > "$test_dir/clipboard-reader.c" <<'C'
#include <gtk/gtk.h>
#include <stdio.h>
int main(int argc,char **argv) {
  gtk_init(&argc,&argv);
  gchar *text=gtk_clipboard_wait_for_text(gtk_clipboard_get(GDK_SELECTION_CLIPBOARD));
  if(!text) return 1;
  fputs(text,stdout); g_free(text); return 0;
}
C
cc -shared -fPIC -Wno-deprecated-declarations "$source_root/tests/gtk-state-probe.c" \
  -o "$test_dir/gtk-state-probe.so" $(pkg-config --cflags --libs gtk+-2.0) -ldl
cc -Wno-deprecated-declarations "$test_dir/clipboard-reader.c" -o "$test_dir/clipboard-reader" \
  $(pkg-config --cflags --libs gtk+-2.0)
export LANG=C.UTF-8
env HOME="$test_dir/home" XDG_CACHE_HOME="$test_dir/home/.cache" \
  PATH="$test_dir/bin:$PATH" ABOUT_BROWSER_LOG="$test_dir/browser-url" \
  LD_PRELOAD="$test_dir/gtk-state-probe.so" DEVC_GTK_STATE="$test_dir/state.json" \
  DEVC_GTK_SCREENSHOT="$test_dir/current.png" \
  "$app_dir/dev-cpp" --new-window > "$test_dir/runtime.log" 2>&1 &
app_pid=$!
window=''
for i in {1..100}; do
  window=$(xdotool search --all --onlyvisible --pid "$app_pid" --name 'Dev-C\+\+' 2>/dev/null | head -1) || true
  [[ -z $window ]] || break
  alive; sleep 0.1
done
[[ -n $window ]] || fail 'Main window missing'
for attempt in {1..10}; do
  xdotool windowfocus "$window"
  click_text Help
  started=$(date +%s%3N)
  click_text 'About Dev-C++'
  dialog=''
  for poll in {1..40}; do
    dialog=$(xdotool search --all --onlyvisible --pid "$app_pid" --name '^About Dev-C\+\+$' 2>/dev/null | head -1) || true
    [[ -z $dialog ]] || break
    alive; sleep 0.02
  done
  [[ -n $dialog ]] || fail 'single About menu click did not open a window'
  elapsed=$(( $(date +%s%3N) - started ))
  [[ $elapsed -lt 2000 ]] || fail "About click took ${elapsed}ms"
  echo "About single mouse click $attempt: ${elapsed}ms"
  xdotool windowfocus "$dialog" key --clearmodifiers Escape
  sleep 0.15
  if xdotool search --all --onlyvisible --pid "$app_pid" --name '^About Dev-C\+\+$' >/dev/null 2>&1; then
    fail 'About remained open after Escape or a duplicate request opened another window'
  fi
done
xdotool windowfocus "$window" key --clearmodifiers --delay 80 alt+h a
wait_text 'About Dev-C++'
version=$(tr -d '\r\n' < "$source_root/VERSION")
wait_text "Version $version"
wait_text 'Orwell Dev-C++ 5.11'
wait_text 'GPL-2.0-or-later'
wait_text 'https://github.com/TH911/Dev-Cpp-Linux'
snapshot about
click_text 'https://github.com/TH911/Dev-Cpp-Linux'
for i in {1..100}; do [[ ! -s "$test_dir/browser-url" ]] || break; alive; sleep 0.1; done
[[ $(cat "$test_dir/browser-url") == 'https://github.com/TH911/Dev-Cpp-Linux' ]] || fail 'Repository click opened wrong URL'
click_text 'Build and installation'
wait_text 'Directory build'
wait_text "Executable: $app_dir/dev-cpp"
wait_text "Configuration: $test_dir/home/.config/dev-cpp.ini"
snapshot installation-details
position=$(python3 - "$test_dir/state.json" "$app_dir/dev-cpp" <<'PY'
import json,sys
items=json.load(open(sys.argv[1]))
assert not any(item['type']=='GtkButton' and item['text']=='Copy details'
               for item in items), 'Non-original Copy details button is present'
for item in items:
 if item['type']=='GtkTextView' and sys.argv[2] in item['text'] and item['visible']:
  print(item['x']+item['width']//2,item['y']+item['height']//2)
  break
else: raise SystemExit('Installation details text widget missing')
PY
)
read -r details_x details_y <<< "$position"
xdotool mousemove --sync "$details_x" "$details_y" click 1
xdotool key --clearmodifiers ctrl+a ctrl+c
"$test_dir/clipboard-reader" > "$test_dir/clipboard.txt"
python3 - "$test_dir/clipboard.txt" "$version" "$app_dir/dev-cpp" "$test_dir/home/.config/dev-cpp.ini" <<'PY'
from pathlib import Path
import sys
text=Path(sys.argv[1]).read_text()
for expected in ('Dev-C++ '+sys.argv[2],sys.argv[3],sys.argv[4],
                 'Free Pascal 3.0.4','x86_64-linux / GTK2',
                 'Directory build','https://github.com/TH911/Dev-Cpp-Linux'):
 assert expected in text,(expected,text)
PY
dialog=$(xdotool search --all --onlyvisible --pid "$app_pid" --name '^About Dev-C\+\+' 2>/dev/null | head -1)
[[ -n $dialog ]] || fail 'About dialog missing before Escape'
xdotool windowfocus "$dialog" key --clearmodifiers Escape
sleep 0.2
if xdotool search --all --onlyvisible --pid "$app_pid" --name '^About Dev-C\+\+' >/dev/null 2>&1; then
  fail 'Escape did not close About'
fi
alive
echo 'PASS: About version, upstream/license, actual paths, repository click, real clipboard details and Escape.'
