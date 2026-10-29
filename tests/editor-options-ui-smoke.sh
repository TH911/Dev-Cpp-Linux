#!/usr/bin/env bash
# Native six-page preferences, cancellation and recovery copies.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'result=$?; if [[ $result == 0 ]]; then rm -rf -- "$fixture"; else echo "Editor options fixture: $fixture"; cat "$fixture/runtime.log" >&2; fi' EXIT
cc -shared -fPIC -Wno-deprecated-declarations "$root/tests/gtk-state-probe.c" -o "$fixture/probe.so" $(pkg-config --cflags --libs gtk+-2.0) -ldl
python3 - "$root" "$fixture" "${CLASSIC_UI_ARTIFACT_DIR:-$fixture/screenshots}" <<'PY'
import base64,configparser,json,os,pathlib,subprocess,sys,time
root,folder,output=map(pathlib.Path,sys.argv[1:]);output.mkdir(parents=True,exist_ok=True)
home=folder/'home';(home/'.config').mkdir(parents=True);config=home/'.config/dev-cpp.ini'
config.write_text('[Interface]\nLanguage=en\n')
source=folder/'fixture.cpp';original='int main() { return 0; }\n';source.write_text(original)
env=dict(os.environ,HOME=str(home),LD_PRELOAD=str(folder/'probe.so'),DEVC_GTK_STATE=str(folder/'state.json'),DEVC_GTK_SCREENSHOT=str(folder/'current.png'))
app=None;dialog_title='Editor Options'
def state():
 try:return json.loads((folder/'state.json').read_text())
 except (OSError,ValueError):return []
def wait(test,message):
 end=time.monotonic()+18
 while time.monotonic()<end:
  if test(state()):return
  assert app.poll() is None,'IDE exited'
  time.sleep(.08)
 raise AssertionError(message)
def keys(*args):subprocess.run(['xdotool','key','--clearmodifiers','--delay','60',*args],check=True);time.sleep(.2)
def control(*args):subprocess.run(['python3',str(root/'tests/gtk-control.py'),str(folder/'state.json'),dialog_title,*args],check=True)
def image(name):
 (folder/'current.png').unlink(missing_ok=True);(folder/'current.png.request').touch()
 wait(lambda _: (folder/'current.png').exists() and (folder/'current.png').read_bytes().endswith(bytes.fromhex('0000000049454e44ae426082')),'screenshot missing')
 (output/name).write_bytes((folder/'current.png').read_bytes())
def read():
 p=configparser.ConfigParser(interpolation=None);p.read(config);return p
def open_options():
 keys('alt+t','Home','Down','Down','Return')
 wait(lambda xs:any(x['type']=='GtkWindow' and x['viewable'] and x['text']==dialog_title for x in xs),'editor dialog missing')
try:
 with (folder/'runtime.log').open('w') as log:
  app=subprocess.Popen([str(root/'linux-noi-lazarus/dev-cpp'),'--new-window',str(source)],env=env,stdout=log,stderr=log)
  wait(lambda xs:any(x['type']=='GtkWindow' and x['viewable'] and 'Dev-C++ ' in x['text'] for x in xs),'main window')
  win=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+'],text=True).split()[0]
  subprocess.run(['xdotool','windowsize',win,'1920','1040','windowmove',win,'0','0','windowfocus',win],check=True)
  open_options()
  for page in ['Basic','Display','Syntax','Code','Code completion','Auto save']:
   control('click',page);image('editor-'+page.lower().replace(' ','-')+'-en.png')
  control('click','Display');control('entry','0','Consolas');control('entry','1','12')
  control('click','Use custom gutter font');control('entry','2','1');control('entry','3','Liberation Mono');control('entry','4','11')
  control('click','Syntax');control('list','0','4');control('click','Bold')
  control('click','Code');control('click','Default insert');control('click','Insert default code in new files')
  control('memo','0','// literal <LF>\nint main() { return 0; }')
  control('click','Auto save');image('editor-auto-save-edit-en.png');control('click','Auto-save recovery copies');control('entry','0','10');control('click','OK')
  p=read();assert p.get('Editor','FontName')=='Consolas';assert p.getint('Editor','FontSize')==12
  assert p.getint('Editor.Display','GutterSpacing')==1 and p.getboolean('Editor.Behavior','CustomGutterFont')
  assert p.get('Editor.Display','GutterFont')=='Liberation Mono'
  template=base64.b64decode(p.get('Editor.Code','Default')).decode();assert '// literal <LF>\nint main()' in template
  assert p.getboolean('Editor.Behavior','DefaultCode') and p.getboolean('Editor.Behavior','AutoSave')
  assert any(k.endswith('.style') and int(v)&1 for k,v in p.items('Editor.Colors')),p.items('Editor.Colors')
  # Cancel must preserve accepted values.
  open_options();control('click','Display');control('entry','1','18');control('click','Cancel');assert read().getint('Editor','FontSize')==12
  keys('ctrl+n')
  cache=home/'.cache/dev-cpp/autosave'
  wait(lambda _:cache.exists() and any('literal <LF>' in f.read_text() for f in cache.glob('*.cpp')),'new-buffer recovery copy missing')
  assert source.read_text()==original,'auto save modified the source file'
  keys('alt+e');image('classic-edit-menu-en.png');keys('Escape')
  app.terminate();app.wait(timeout=5);(folder/'state.json').unlink(missing_ok=True)
  p=read();p.set('Interface','Language','zh')
  with config.open('w') as stream:p.write(stream)
  app=subprocess.Popen([str(root/'linux-noi-lazarus/dev-cpp'),'--new-window',str(source)],env=env,stdout=log,stderr=log)
  wait(lambda xs:any(x['type']=='GtkWindow' and x['viewable'] and 'Dev-C++ ' in x['text'] for x in xs),'restarted main window')
  win=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+'],text=True).split()[0]
  subprocess.run(['xdotool','windowsize',win,'1920','1040','windowmove',win,'0','0','windowfocus',win],check=True)
  dialog_title='编辑器属性';open_options()
  for page,name in [('基本','basic'),('显示','display'),('语法','syntax'),('代码','code'),('代码补全','completion'),('自动保存','auto-save')]:
   control('click',page);image('editor-'+name+'-zh.png')
  assert read().getint('Editor','FontSize')==12 and read().get('Editor.Display','GutterFont')=='Liberation Mono'
  control('click','取消')
  print('PASS: Chinese/English six actual preference pages, restart persistence, fonts/gutter/colors, multiline default insertion, Cancel and private auto-save recovery')
finally:
 if app and app.poll() is None:app.terminate();app.wait(timeout=5)
PY
