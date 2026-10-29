#!/usr/bin/env bash
# Verify real GTK input colors under a theme with low-contrast normal entry text.
set -euo pipefail
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
app_pid=''
cleanup() {
  local result=$?
  if [[ -n $app_pid ]]; then
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
  fi
  if [[ $result == 0 && ${KEEP_INPUT_COLORS_FIXTURE:-0} != 1 ]]; then
    rm -rf -- "$test_dir"
  else
    echo "Input colors test fixture: $test_dir"
    cat "$test_dir/runtime.log" >&2 || true
  fi
}
trap cleanup EXIT
mkdir -p "$test_dir/home/.config"
printf '[Interface]\nLanguage=en\n' > "$test_dir/home/.config/dev-cpp.ini"
cat > "$test_dir/theme.rc" <<'RC'
style "low-contrast-input" {
  text[NORMAL] = "#999999"
  base[NORMAL] = "#ffffff"
  text[ACTIVE] = "#ffffff"
  base[ACTIVE] = "#4b6078"
  text[SELECTED] = "#ffffff"
  base[SELECTED] = "#245b9c"
  text[INSENSITIVE] = "#999999"
  base[INSENSITIVE] = "#eeeeee"
}
class "GtkEntry" style "low-contrast-input"
class "GtkTextView" style "low-contrast-input"
RC
cc -shared -fPIC -Wno-deprecated-declarations "$source_root/tests/gtk-state-probe.c" \
  -o "$test_dir/gtk-state-probe.so" $(pkg-config --cflags --libs gtk+-2.0) -ldl
printf 'int main() { return 0; }\n' > "$test_dir/sample.cpp"
export LANG=C.UTF-8
env HOME="$test_dir/home" XDG_CACHE_HOME="$test_dir/home/.cache" \
  GTK2_RC_FILES="$test_dir/theme.rc" LD_PRELOAD="$test_dir/gtk-state-probe.so" \
  DEVC_GTK_STATE="$test_dir/state.json" DEVC_GTK_SCREENSHOT="$test_dir/current.png" \
  "${INPUT_COLORS_APP:-$source_root/linux-noi-lazarus/dev-cpp}" \
  --new-window "$test_dir/sample.cpp" > "$test_dir/runtime.log" 2>&1 &
app_pid=$!
python3 - "$test_dir" "$app_pid" <<'PY'
import json, pathlib, subprocess, sys, time
root, pid = pathlib.Path(sys.argv[1]), sys.argv[2]
def snapshot():
    try: return json.loads((root/'state.json').read_text())
    except (OSError, ValueError): return []
def wait(predicate, message):
    deadline=time.monotonic()+12
    while time.monotonic()<deadline:
        items=snapshot()
        if predicate(items): return items
        subprocess.run(['kill','-0',pid], check=True, capture_output=True)
        time.sleep(.1)
    raise AssertionError(message)
def window(title=None):
    return next(w for w in snapshot() if w['type']=='GtkWindow' and w['visible']
                and (w['text']==title if title else 'Dev-C++ ' in w['text']))
def keys(*values):
    subprocess.run(['xdotool','key','--clearmodifiers','--delay','70',*values],check=True)
    time.sleep(.2)
def focus(w):
    # No window manager runs in Xvfb; request the same native window focus that
    # existing interaction tests use, then send actual keyboard/mouse events.
    ids=subprocess.check_output(['xdotool','search','--all','--onlyvisible','--pid',pid,'--name','^'+w['text'].replace('+',r'\+')+'$'],text=True).split()
    subprocess.run(['xdotool','windowfocus',ids[0]],check=True)
def descendants(items,w):
    ids={w['id']}
    while True:
        added={x['id'] for x in items if x['parent'] in ids}-ids
        if not added: break
        ids.update(added)
    return [x for x in items if x['id'] in ids and x['visible'] and x['mapped'] and x['viewable']]
def contrast(a,b):
    def luminance(color):
        rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
        rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
        return sum(v*w for v,w in zip(rgb,(.2126,.7152,.0722)))
    x,y=sorted((luminance(a),luminance(b)))
    return (y+.05)/(x+.05)
def inputs(title, minimum):
    w=window(title)
    def ready(items):
        rows=[x for x in descendants(items,w) if 'normal_text' in x and x['sensitive'] and x['width']>0]
        return len(rows)>=minimum and all(x['normal_text']=='000000' and x['normal_base']=='ffffff' for x in rows)
    observed=wait(ready, 'input colors did not settle to black on white: '+title)
    rows=[x for x in descendants(observed,w) if 'normal_text' in x and x['sensitive'] and x['width']>0]
    for x in rows:
        assert x['normal_text']=='000000' and x['normal_base']=='ffffff',(title,x)
        for state in ('selected','active'):
            assert contrast(x[state+'_text'],x[state+'_base'])>=4.5,(title,state,x)
    return rows
wait(lambda xs:any(x['type']=='GtkWindow' and x['visible'] and 'Dev-C++ ' in x['text'] for x in xs),'main window missing')
main=window(); focus(main)
keys('ctrl+alt+o')
wait(lambda xs:any(x['type']=='GtkWindow' and x['visible'] and x['text']=='Compiler Options' for x in xs),'compiler options missing')
fields=inputs('Compiler Options',6)
f=fields[0]
subprocess.run(['xdotool','mousemove','--sync',str(f['x']+f['width']//2),str(f['y']+f['height']//2),'click','1'],check=True)
wait(lambda xs:any(x['id']==f['id'] and x['focus'] for x in xs),'entry did not receive mouse focus')
inputs('Compiler Options',6)
keys('ctrl+a')
wait(lambda xs:any(x['id']==f['id'] and x.get('selected') for x in xs),'entry text not selected')
inputs('Compiler Options',6)
(root/'current.png.request').touch()
wait(lambda xs:(root/'current.png').exists(),'focused selection screenshot missing')
keys('Escape')
focus(main); keys('alt+t','Home','Down','Down','Return')
wait(lambda xs:any(x['type']=='GtkWindow' and x['visible'] and x['text']=='Editor Options' for x in xs),'editor options missing')
display=next(x for x in snapshot() if x['type']=='GtkLabel' and x['viewable'] and x['text']=='Display')
subprocess.run(['xdotool','mousemove','--sync',str(display['x']+display['width']//2),str(display['y']+display['height']//2),'click','1'],check=True)
inputs('Editor Options',3)  # editable font combo and both spin edits
focus(window('Editor Options')); keys('Escape')
focus(main); keys('alt+x','End','Up','Return')
wait(lambda xs:any(x['type']=='GtkWindow' and x['visible'] and x['text']=='Execute Parameters' for x in xs),'parameters missing')
inputs('Execute Parameters',1)
keys('Escape')
focus(main); keys('alt+h','Home','Return')
wait(lambda xs:any(x['type']=='GtkWindow' and x['visible'] and 'About Dev-C++' in x['text'] for x in xs),'about missing')
about=next(x for x in snapshot() if x['type']=='GtkWindow' and x['visible'] and 'About Dev-C++' in x['text'])
focus(about)
info=next(x for x in snapshot() if x['type']=='GtkLabel' and x['viewable'] and x['text']=='Build and installation')
subprocess.run(['xdotool','mousemove','--sync',str(info['x']+info['width']//2),str(info['y']+info['height']//2),'click','1'],check=True)
inputs(about['text'],1)
keys('Escape')
focus(main)
inputs(main['text'],1)
disabled=[x for x in snapshot() if x['type']=='GtkEntry' and not x['sensitive']]
assert disabled and all(x['insensitive_text'] not in ('000000','ffffff') for x in disabled),disabled
keys('F5')
wait(lambda xs:sum(x['type']=='GtkEntry' and x['sensitive'] for x in descendants(xs,main))>=2, 'debugger inputs not enabled at main')
inputs(main['text'],2)
wait(lambda xs:any(x['type']=='GtkLabel' and x['viewable'] and x['sensitive'] and x['text'] in ('CPU','View CPU window') for x in xs),'CPU action not enabled at the source stop')
cpu=next(x for x in snapshot() if x['type']=='GtkLabel' and x['viewable'] and x['text'] in ('CPU','View CPU window'))
subprocess.run(['xdotool','mousemove','--sync',str(cpu['x']+cpu['width']//2),str(cpu['y']+cpu['height']//2),'click','1'],check=True)
wait(lambda xs:any(x['type']=='GtkWindow' and x['viewable'] and x['text']=='CPU' for x in xs),'CPU window missing')
inputs('CPU',1)
wait(lambda xs:any('rax' in x['text'] for x in xs if x['type']=='GtkTextView'),'CPU registers were not read from GDB')
focus(main); keys('F6')
print('PASS: active debugger inputs remain readable; inactive program input retains its disabled appearance')
print('PASS: compiler fields, font/spin controls, run parameters and About details use readable black-on-white text')
print('PASS: actual mouse focus and Ctrl+A preserve native, contrasting selection colors')
PY
