#!/usr/bin/env bash
# Actual keyboard dispatch, saved bytes and GTK chooser directories.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'result=$?; if [[ $result == 0 ]]; then rm -rf -- "$fixture"; else echo "Save UI fixture: $fixture"; cat "$fixture/runtime.log" >&2; fi' EXIT
cc -shared -fPIC -Wno-deprecated-declarations "$root/tests/gtk-state-probe.c" -o "$fixture/probe.so" $(pkg-config --cflags --libs gtk+-2.0) -ldl
python3 - "$root" "$fixture" <<'PY'
import json,os,pathlib,subprocess,sys,time
root,folder=map(pathlib.Path,sys.argv[1:]);home=folder/'home';(home/'.config').mkdir(parents=True);(home/'.local/share').mkdir(parents=True)
config=home/'.config/dev-cpp.ini';config.write_text('[Interface]\nLanguage=en\n[Shortcuts]\nmenu.0.3=24659\nmenu.0.4=24641\n')
a=folder/'代码 A';b=folder/'代码 B';a.mkdir();b.mkdir()
first=a/'first.cpp';second=b/'second.cpp';first.write_text('int first(){return 1;}\n');second.write_text('int second(){return 2;}\n')
env=dict(os.environ,HOME=str(home),XDG_CACHE_HOME=str(home/'.cache'),LD_PRELOAD=str(folder/'probe.so'),DEVC_GTK_STATE=str(folder/'state.json'))
app=None;log=(folder/'runtime.log').open('w')
def state():
 try:return json.loads((folder/'state.json').read_text())
 except (OSError,ValueError):return []
def wait(test,message):
 end=time.monotonic()+8
 while time.monotonic()<end:
  if test():return
  assert app.poll() is None,'IDE exited'
  time.sleep(.05)
 raise AssertionError(message+'; windows='+str([x for x in state() if x['type'] in ('GtkWindow','GtkFileChooserDialog') and x['viewable']]))
def keys(*args):subprocess.run(['xdotool','key','--clearmodifiers','--delay','30',*args],check=True);time.sleep(.12)
def text(value):subprocess.run(['xdotool','type','--clearmodifiers','--delay','12','--',value],check=True);time.sleep(.1)
def window(title):
 ids=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',title],text=True).split();assert ids;return ids[0]
def start(*paths):
 global app
 (folder/'state.json').unlink(missing_ok=True)
 app=subprocess.Popen([str(root/'linux-noi-lazarus/dev-cpp'),'--new-window',*map(str,paths)],env=env,stdout=log,stderr=log)
 wait(lambda:any(x['type']=='GtkWindow' and x['viewable'] and 'Dev-C++ ' in x['text'] for x in state()),'main window')
 subprocess.run(['xdotool','windowfocus',window(r'Dev-C\+\+')],check=True);keys('ctrl+alt+e')
def stop():
 global app
 if app and app.poll() is None:app.terminate();app.wait(timeout=5)
 app=None
def chooser(expected,default_name=None):
 wait(lambda:any(x.get('folder')==str(expected) and x['viewable'] for x in state()) and (default_name is None or any('normal_text' in x and x['viewable'] and x['mapped'] and x['text']==default_name for x in state())),'chooser must open in '+str(expected))
 subprocess.run(['xdotool','windowfocus',window('^Save As$')],check=True)
def cancel_chooser():
 keys('Escape')
 wait(lambda:not any(x.get('folder') and x['viewable'] and x['mapped'] for x in state()),'cancelled chooser must finish closing')
 # Bare Xvfb has no window manager to restore focus to the parent after a
 # native modal closes. Do that explicitly before sending the next command.
 subprocess.run(['xdotool','windowfocus',window(r'Dev-C\+\+')],check=True)
def save_new(name,directory):
 keys('ctrl+s');chooser(directory);keys('alt+n','ctrl+a');text(name);keys('Return')
 wait(lambda:(directory/name).exists(),'new file saved in expected directory')
try:
 start(first,second)
 keys('ctrl+Home');text('// B ');keys('Escape','ctrl+Tab','ctrl+Home');text('// A ');keys('Escape','ctrl+shift+s')
 wait(lambda:first.read_text().startswith('// A ') and second.read_text().startswith('// B '),'Save All must write both modified buffers')
 assert not any(x.get('folder') and x['viewable'] for x in state()),'Save All must not open Save As for named buffers'
 # AStyle shortcut modifies the active buffer; it must not save modified files.
 keys('ctrl+Tab','ctrl+Home','ctrl+a');text('int main(){return 0;}');keys('Escape','ctrl+shift+a');time.sleep(.4)
 assert first.read_text().startswith('// A '),'format must not act as Save All'
 keys('ctrl+z','ctrl+s');wait(lambda:first.read_text().strip()=='int main(){return 0;}','format must be one undoable edit')
 # Unassigned Ctrl+Delete must not accidentally invoke Comment.
 keys('ctrl+Home','ctrl+Delete','ctrl+t','ctrl+m','ctrl+i','ctrl+s');wait(lambda:first.read_text().strip()=='int main(){return 0;}','Ctrl+Delete must leave the source unchanged')
 # Last successful save is now A. Relative new-file names must resolve there.
 keys('ctrl+n');text('int newer;');keys('Escape','ctrl+s');chooser(a)
 # Navigating and cancelling the native chooser does not change app history.
 keys('alt+Home');chooser(home);cancel_chooser();keys('ctrl+s');chooser(a);cancel_chooser()
 save_new('new.cpp',a);assert (a/'new.cpp').read_text().strip()=='int newer;'
 # Existing source Save As opens its own B directory rather than recent A.
 keys('ctrl+Tab','ctrl+Tab','alt+f')
 wait(lambda:any(x['type']=='GtkLabel' and x['text']=='Save As...' and x['viewable'] for x in state()),'Save As menu')
 item=next(x for x in state() if x['type']=='GtkLabel' and x['text']=='Save As...' and x['viewable'])
 subprocess.run(['xdotool','mousemove','--sync',str(item['x']+item['width']//2),str(item['y']+item['height']//2),'click','1'],check=True)
 chooser(b);cancel_chooser()
 # Save All prompts for two unnamed files; Cancel leaves the second pending.
 keys('ctrl+n');text('int one;');keys('Escape','ctrl+n');text('int two;');keys('Escape','ctrl+shift+s');chooser(a)
 keys('alt+n','ctrl+a');text('one.cpp');keys('Return')
 wait(lambda:(a/'one.cpp').exists(),'first unnamed file saved')
 # Wait for the second file's dialog, not a stale observation of the first.
 chooser(a,'Untitled3.cpp');cancel_chooser()
 assert (a/'one.cpp').read_text().strip()=='int one;'
 keys('ctrl+shift+s');chooser(a);keys('alt+n','ctrl+a');text('two.cpp');keys('Return')
 wait(lambda:(a/'two.cpp').exists(),'cancelled unnamed document remains pending and can be saved later')
 stop();start();keys('ctrl+n');text('int after_restart;');keys('Escape');save_new('restart.cpp',a)
 stop()
 # A removed remembered directory falls back to the user's home directory.
 for path in a.iterdir():path.unlink()
 a.rmdir();start();keys('ctrl+n');text('int fallback;');keys('Escape');save_new('fallback.cpp',home)
 print('PASS: old-default migration; real Save All/format/Ctrl+Delete; UTF-8 remembered save directory; Cancel, Save As, restart and removed-directory fallback')
finally:stop();log.close()
PY
