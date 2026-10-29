#!/usr/bin/env bash
# Four native search pages and real buffer edits, using only X input.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'result=$?; if [[ $result == 0 ]]; then rm -rf -- "$fixture"; else echo "Search fixture: $fixture"; cat "$fixture/runtime.log" >&2; fi' EXIT
cc -shared -fPIC -Wno-deprecated-declarations "$root/tests/gtk-state-probe.c" -o "$fixture/probe.so" $(pkg-config --cflags --libs gtk+-2.0) -ldl
python3 - "$root" "$fixture" "${CLASSIC_UI_ARTIFACT_DIR:-$fixture/images}" <<'PY'
import json,os,pathlib,subprocess,sys,time
root,folder,images=map(pathlib.Path,sys.argv[1:]);images.mkdir(parents=True,exist_ok=True)
home=folder/'home';(home/'.config').mkdir(parents=True);(home/'.config/dev-cpp.ini').write_text('[Interface]\nLanguage=en\n')
first=folder/'first.cpp';second=folder/'second.cpp';hidden=folder/'hidden.cpp';project=folder/'search.dev'
hidden.write_text('cat hidden\n');project.write_text('[Project]\nName=search\nUnitCount=3\n[Unit1]\nFileName=first.cpp\n[Unit2]\nFileName=second.cpp\n[Unit3]\nFileName=hidden.cpp\n')
original='cat Cat scatter cat\ncat LAST\n';first.write_text(original);second.write_text('Cat cat scatter\n')
env=dict(os.environ,HOME=str(home),LD_PRELOAD=str(folder/'probe.so'),DEVC_GTK_STATE=str(folder/'state.json'),DEVC_GTK_SCREENSHOT=str(folder/'current.png'))
app=None;title='Search'
def state():
 try:return json.loads((folder/'state.json').read_text())
 except (OSError,ValueError):return []
def wait(test,message):
 end=time.monotonic()+15
 while time.monotonic()<end:
  if test(state()):return
  assert app.poll() is None,'IDE exited'
  time.sleep(.08)
 raise AssertionError(message)
def keys(*args):subprocess.run(['xdotool','key','--clearmodifiers','--delay','50',*args],check=True);time.sleep(.2)
def control(*args):subprocess.run(['python3',str(root/'tests/gtk-control.py'),str(folder/'state.json'),title,*args],check=True)
def image(name):
 (folder/'current.png').unlink(missing_ok=True);(folder/'current.png.request').touch()
 wait(lambda _: (folder/'current.png').exists() and (folder/'current.png').read_bytes().endswith(bytes.fromhex('0000000049454e44ae426082')),'screenshot')
 (images/name).write_bytes((folder/'current.png').read_bytes())
def groups_fit():
 rows=state();by_id={x['id']:x for x in rows};window=next(x for x in rows if x['type']=='GtkWindow' and x['text']==title and x['viewable'])
 count=0
 for item in rows:
  if item['type'] not in ('GtkCheckButton','GtkRadioButton') or not item['viewable'] or not item['mapped']:continue
  parent=by_id.get(item['parent']);frame=None
  while parent and parent['id']!=window['id']:
   if parent['type']=='GtkFrame':frame=parent
   parent=by_id.get(parent['parent'])
  if not parent or frame is None:continue
  count+=1
  assert item['y']>=frame['y'] and item['y']+item['height']<=frame['y']+frame['height'],('search option clipped by group frame',item,frame)
  for label in rows:
   if label['type']=='GtkLabel' and label['parent']==item['id']:
    assert label['width']>=label['text_width'],('search option caption clipped',label)
 assert count>=6,('missing visible search options',count)
def opened(name):return any(x['type']=='GtkWindow' and x['viewable'] and x['text']==name for x in state())
def dialog(shortcut,name):
 global title
 title=name;keys(shortcut);wait(lambda _:opened(name),'missing '+name)
def accept():
 control('button',title);wait(lambda _:not opened(title),'dialog did not close')
try:
 with (folder/'runtime.log').open('w') as log:
  app=subprocess.Popen([str(root/'linux-noi-lazarus/dev-cpp'),'--new-window',str(first),str(second)],env=env,stdout=log,stderr=log)
  wait(lambda xs:any(x['type']=='GtkWindow' and x['viewable'] and 'Dev-C++ ' in x['text'] for x in xs),'main window')
  win=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+'],text=True).split()[0]
  subprocess.run(['xdotool','windowsize',win,'1280','950','windowfocus',win],check=True)
  keys('ctrl+shift+Tab','ctrl+Home')
  dialog('ctrl+f','Search')
  for label,name in [('Search','search'),('Search in files','find-files'),('Replace','replace'),('Replace in files','replace-files')]:
   control('click',label);title='Replace' if label.startswith('Replace') else 'Search';groups_fit();image('classic-'+name+'-en.png')
  control('click','Search');title='Search';control('entry','0','cat');control('click','Case sensitive');control('click','Whole words');control('click','From start');accept()
  # Delete the found selection and save: proves exact case+whole-word match.
  keys('Delete','ctrl+s');assert first.read_text()==' Cat scatter cat\ncat LAST\n',first.read_text()
  keys('ctrl+z','ctrl+s');assert first.read_text()==original
  # Single replace uses the same options, and one Undo restores original bytes.
  keys('ctrl+Home');dialog('ctrl+r','Replace');control('entry','0','cat');control('entry','1','dog');accept()
  keys('ctrl+s');assert first.read_text()=='dog Cat scatter cat\ncat LAST\n',first.read_text()
  keys('ctrl+z','ctrl+s');assert first.read_text()==original
  # File replacement applies to each open buffer, never silently saves to disk.
  dialog('ctrl+shift+r','Replace');control('entry','0','cat');control('entry','1','fox');control('click','Open files');accept()
  assert first.read_text()==original and second.read_text()=='Cat cat scatter\n'
  keys('ctrl+shift+s');assert first.read_text()=='fox Cat scatter fox\nfox LAST\n',first.read_text();assert second.read_text()=='Cat fox scatter\n'
  keys('ctrl+shift+Tab','ctrl+z','ctrl+s');assert first.read_text()==original
  keys('ctrl+Tab','ctrl+z','ctrl+s');assert second.read_text()=='Cat cat scatter\n'
  # Selected-only replacement never reaches the second line.
  keys('ctrl+shift+Tab','ctrl+Home','shift+End');dialog('ctrl+r','Replace');control('entry','0','cat');control('entry','1','red');control('click','Selected text');accept()
  keys('ctrl+s');assert first.read_text()=='red Cat scatter cat\ncat LAST\n',first.read_text()
  keys('ctrl+z','ctrl+s');assert first.read_text()==original
  # Cancel the prompt and then the search dialog: no source bytes change.
  keys('ctrl+Home');dialog('ctrl+r','Replace');control('click','Prompt before replacing');control('click','All text');control('button','Replace')
  wait(lambda _:any(x['type']=='GtkWindow' and x['text']=='Dev-C++' and x['viewable'] for x in state()) and any(x['text']=='Yes' and x['viewable'] for x in state()),'replace prompt missing');subprocess.run(['python3',str(root/'tests/gtk-control.py'),str(folder/'state.json'),'Dev-C++','button','No'],check=True)
  keys('ctrl+s');assert first.read_text()==original
  dialog('ctrl+f','Search');keys('Escape');assert first.read_text()==original
  # Backward search starts at the caret rather than the first source row.
  keys('ctrl+End');dialog('ctrl+f','Search');control('entry','0','cat');control('click','Backward');control('click','From caret');accept()
  keys('Delete','ctrl+s');assert first.read_text()=='cat Cat scatter cat\n LAST\n',first.read_text()
  keys('ctrl+z','ctrl+s');assert first.read_text()==original
  # Project scope searches unopened files without opening them first.
  keys('ctrl+o');wait(lambda xs:any(x.get('folder') and x['viewable'] for x in xs),'project chooser')
  chooser=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name','^Open$'],text=True).split()[0]
  subprocess.run(['xdotool','windowfocus',chooser],check=True);keys('ctrl+l');subprocess.run(['xdotool','type','--clearmodifiers','--',str(project)],check=True);keys('Return')
  wait(lambda xs:any(x['type']=='GtkWindow' and x['viewable'] and x['text'].startswith(str(first)) for x in xs),'project source active')
  dialog('ctrl+shift+f','Search');control('entry','0','cat');control('click','Project files');accept()
  wait(lambda xs:any(x['type']=='GtkLabel' and x['text']=='5 matches for cat' for x in xs),'project search did not include unopened file')
  assert not any(x['type']=='GtkLabel' and x['text']=='hidden.cpp' and x['viewable'] for x in state()),'search should not open an unopened project source'
  keys('ctrl+alt+e');dialog('ctrl+shift+r','Replace');control('entry','0','cat');control('entry','1','birch');control('click','Prompt before replacing');control('click','Project files');accept()
  assert hidden.read_text()=='cat hidden\n','project replacement should stay in an undoable buffer'
  keys('ctrl+shift+s');assert hidden.read_text()=='birch hidden\n';assert first.read_text()=='birch Cat scatter birch\nbirch LAST\n';assert second.read_text()=='Cat birch scatter\n'
  keys('ctrl+z','ctrl+s');assert hidden.read_text()=='cat hidden\n','opened project replacement supports Undo'
  print('PASS: four native search pages; exact case/whole-word; current/open/selected scopes; buffer-only replace, Undo, confirmation, backward origin and unopened project files')
finally:
 if app and app.poll() is None:app.terminate();app.wait(timeout=5)
PY
