#!/usr/bin/env bash
# Actual native GTK screenshots and mouse/keyboard interaction at reference size.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
app_pid=''
cleanup() {
  local result=$?
  if [[ -n $app_pid ]]; then kill "$app_pid" 2>/dev/null || true; wait "$app_pid" 2>/dev/null || true; fi
  if [[ $result == 0 ]]; then rm -rf -- "$fixture"; else echo "Classic UI fixture: $fixture"; cat "$fixture/runtime.log" >&2 || true; fi
}
trap cleanup EXIT
mkdir -p "$fixture/home/.config"
printf '[Interface]\nLanguage=en\n[Editor]\nFontSize=14\nTheme=Classic Plus\n' > "$fixture/home/.config/dev-cpp-linux.ini"
cat > "$fixture/example.cpp" <<'CPP'
#include <iostream>
struct Solver {
    int value;
    void solve() {
        for (int i=0;i<10;i++) {
            value += i;
        }
    }
};
int helper(int x) {
    return x * 2;
}
int main() {
    Solver solver;
    solver.solve();
    std::cout << helper(21) << "\n";
    return 0;
}
CPP
cc -shared -fPIC -Wno-deprecated-declarations "$root/tests/gtk-state-probe.c" \
  -o "$fixture/probe.so" $(pkg-config --cflags --libs gtk+-2.0) -ldl
HOME="$fixture/home" LD_PRELOAD="$fixture/probe.so" DEVC_GTK_STATE="$fixture/state.json" \
  DEVC_GTK_SCREENSHOT="$fixture/current.png" "$root/linux-noi-lazarus/dev-cpp-linux" \
  --new-window "$fixture/example.cpp" > "$fixture/runtime.log" 2>&1 &
app_pid=$!
python3 - "$fixture" "$app_pid" "${CLASSIC_UI_ARTIFACT_DIR:-$fixture/screenshots}" <<'PY'
import json, pathlib, subprocess, sys, time
root=pathlib.Path(sys.argv[1]); pid=sys.argv[2]; output=pathlib.Path(sys.argv[3]);output.mkdir(parents=True,exist_ok=True)
def state():
    try: return json.loads((root/'state.json').read_text())
    except (OSError,ValueError): return []
def wait(check, message):
    until=time.monotonic()+15
    while time.monotonic()<until:
        data=state()
        if check(data): return data
        subprocess.run(['kill','-0',pid],check=True,capture_output=True)
        time.sleep(.1)
    raise AssertionError(message)
def keys(*args):
    subprocess.run(['xdotool','key','--clearmodifiers','--delay','60',*args],check=True);time.sleep(.2)
def click(widget):
    subprocess.run(['xdotool','mousemove','--sync',str(widget['x']+widget['width']//2),str(widget['y']+widget['height']//2),'click','1'],check=True)
    time.sleep(.2)
def image(name):
    (root/'current.png').unlink(missing_ok=True);(root/'current.png.request').touch()
    wait(lambda _: (root/'current.png').exists() and (root/'current.png').read_bytes().endswith(bytes.fromhex('0000000049454e44ae426082')),'screenshot not captured')
    (output/name).write_bytes((root/'current.png').read_bytes())
wait(lambda data:any(x['type']=='GtkWindow' and x['viewable'] and 'dev-cpp-linux ' in x['text'] for x in data),'main window missing')
win=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',pid,'--name','dev-cpp-linux'],text=True).split()[0]
subprocess.run(['xdotool','windowsize',win,'1920','1040','windowmove',win,'0','0','windowfocus',win],check=True)
time.sleep(.6)
data=state()
combos=sorted([x for x in data if x['type']=='GtkComboBox' and x['viewable'] and x['width']>=300],key=lambda x:x['x'])
assert len(combos)==2,combos
click(combos[-1]);keys('End','Return')
wait(lambda data:any(x['type']=='GtkLabel' and x['text'].strip()=='Line: 13' for x in data),'native function selector did not navigate to main')
keys('ctrl+alt+e','ctrl+Home')
image('classic-normal.png')
keys('ctrl+a');image('classic-selection.png');keys('Right','alt+f');image('classic-file-menu.png');keys('Escape')
keys('F9')
wait(lambda data:any(x['type']=='GtkTextView' and 'Compilation successful.' in x['text'] and 'Compilation results...' in x['text'] for x in data),'actual compilation summary missing')
image('classic-compile-log.png')
close=next(x for x in state() if x['type']=='GtkLabel' and x['viewable'] and x['text']=='Close' and x['y']>500)
click(close)
wait(lambda data:not any(x['id']==close['id'] and x['viewable'] for x in data),'Close report tab did not hide output')
keys('alt+v','r')
wait(lambda data:any(x['id']==close['id'] and x['viewable'] for x in data),'View/Report did not restore output')
print('PASS: actual function selection, compile summary, report Close/reopen and four native GTK screenshots')
PY
