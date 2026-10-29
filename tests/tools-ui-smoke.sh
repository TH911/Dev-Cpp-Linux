#!/usr/bin/env bash
# Actual restored Tools menus, editable shortcuts, settings and literal tool argv.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'result=$?; if [[ $result == 0 ]]; then rm -rf -- "$fixture"; else echo "Tools UI fixture: $fixture"; cat "$fixture/runtime.log" >&2; fi' EXIT
cc -shared -fPIC -Wno-deprecated-declarations "$root/tests/gtk-state-probe.c" -o "$fixture/probe.so" $(pkg-config --cflags --libs gtk+-2.0) -ldl
python3 - "$root" "$fixture" "${CLASSIC_UI_ARTIFACT_DIR:-$fixture/screenshots}" <<'PY'
import configparser,json,os,pathlib,shlex,subprocess,sys,time
root=pathlib.Path(sys.argv[1]); folder=pathlib.Path(sys.argv[2]); output=pathlib.Path(sys.argv[3]);output.mkdir(parents=True,exist_ok=True)
home=folder/'home';(home/'.config').mkdir(parents=True)
config=home/'.config/dev-cpp.ini'; p=configparser.ConfigParser(interpolation=None);p.optionxform=str
p['Interface']={'Language':'en'};p['Shortcuts']={'menu.0.0.1':str(78+16384+32768)}
code='import sys,pathlib;pathlib.Path(sys.argv[1]).write_text(repr(sys.argv[2:]))'
p['ExternalTool']={'Name':'Fixture tool','Executable':'/usr/bin/python3','Arguments':shlex.join(['-c',code,str(folder/'tool-output'),'%FILE%','a b','$(literal)'])}
with config.open('w') as stream:p.write(stream)
env=dict(os.environ,DEV_CPP_STARTUP_TRACE='1',HOME=str(home),LD_PRELOAD=str(folder/'probe.so'),DEVC_GTK_STATE=str(folder/'state.json'),DEVC_GTK_SCREENSHOT=str(folder/'current.png'))
app=None
def state():
 try:return json.loads((folder/'state.json').read_text())
 except (OSError,ValueError):return []
def wait(predicate,message):
 until=time.monotonic()+12
 while time.monotonic()<until:
  items=state()
  if predicate(items):return items
  assert app.poll() is None,'IDE exited'
  time.sleep(.08)
 raise AssertionError(message)
def keys(*args):subprocess.run(['xdotool','key','--clearmodifiers','--delay','80',*args],check=True);time.sleep(.2)
def click(text):
 items=wait(lambda xs:any(x['type'] in ['GtkLabel','GtkButton'] and x['viewable'] and x['visible'] and x['mapped'] and x['width']>0 and x['text'].replace('_','')==text for x in xs),'missing '+text)
 item=next(x for x in items if x['type'] in ['GtkLabel','GtkButton'] and x['viewable'] and x['visible'] and x['mapped'] and x['width']>0 and x['text'].replace('_','')==text)
 subprocess.run(['xdotool','mousemove','--sync',str(item['x']+item['width']//2),str(item['y']+item['height']//2),'click','1'],check=True);time.sleep(.2)
def window(title):return wait(lambda xs:any(x['type']=='GtkWindow' and x['viewable'] and x['text']==title for x in xs),'missing dialog '+title)
def image(name):
 (folder/'current.png').unlink(missing_ok=True);(folder/'current.png.request').touch()
 wait(lambda xs:(folder/'current.png').exists() and (folder/'current.png').read_bytes().endswith(bytes.fromhex('0000000049454e44ae426082')),'screenshot missing');(output/name).write_bytes((folder/'current.png').read_bytes())
def read_config():
 q=configparser.ConfigParser(interpolation=None);q.read(config);return q
try:
 with (folder/'runtime.log').open('w') as log:
  app=subprocess.Popen([str(root/'linux-noi-lazarus/dev-cpp'),'--new-window'],env=env,stdout=log,stderr=log)
  wait(lambda xs:any(x['type']=='GtkWindow' and x['viewable'] and 'Dev-C++ ' in x['text'] for x in xs),'main window')
  win=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+'],text=True).split()[0]
  subprocess.run(['xdotool','windowsize',win,'1920','1040','windowmove',win,'0','0','windowfocus',win],check=True)
  # An unchanged/default shortcut may not bypass a saved remapping.
  keys('ctrl+n');assert not any('Untitled' in x['text'] for x in state() if x['type']=='GtkWindow')
  keys('ctrl+alt+n');wait(lambda xs:any('Untitled1' in x['text'] for x in xs if x['type']=='GtkWindow'),'configured shortcut did not run')
  keys('alt+t');click('Environment Options...');window('Environment Options')
  click('Show report window');click('OK');assert not read_config().getboolean('Interface','ShowReports')
  keys('alt+t');click('Environment Options...');window('Environment Options');click('Show report window');click('OK')
  assert read_config().getboolean('Interface','ShowReports')
  keys('alt+t');click('Shortcut Options...');window('Shortcut Options')
  items=wait(lambda xs:any(x['type']=='GtkEntry' and x['viewable'] and x['text']=='Ctrl+Alt+N' for x in xs),'shortcut value editor not exposed')
  entry=next(x for x in items if x['type']=='GtkEntry' and x['viewable'] and x['text']=='Ctrl+Alt+N')
  assert entry['normal_text']=='000000' and entry['normal_base']=='ffffff',entry
  subprocess.run(['xdotool','mousemove','--sync',str(entry['x']+entry['width']//2),str(entry['y']+entry['height']//2),'click','1'],check=True)
  keys('ctrl+a');subprocess.run(['xdotool','type','--clearmodifiers','Ctrl+Alt+B'],check=True);keys('Tab');click('OK')
  wait(lambda xs:not any(x['type']=='GtkWindow' and x['viewable'] and x['text']=='Shortcut Options' for x in xs),'shortcut edit did not accept')
  assert read_config().getint('Shortcuts','menu.0.0.1')==66+16384+32768
  keys('ctrl+n');assert not any('Untitled2' in x['text'] for x in state() if x['type']=='GtkWindow')
  keys('ctrl+alt+b');wait(lambda xs:any('Untitled2' in x['text'] for x in xs if x['type']=='GtkWindow'),'edited shortcut did not run')
  keys('alt+t');click('Configure Tools...');window('Configure Tools');keys('Escape')
  keys('alt+t');click('Fixture tool')
  wait(lambda xs:(folder/'tool-output').exists(),'external tool did not execute')
  assert (folder/'tool-output').read_text()==repr(['','a b','$(literal)'])
  keys('alt+t');click('Package Manager');wait(lambda xs:any('Debian package' in x['text'] for x in xs if x['type'] in ['GtkWindow','GtkFileChooserDialog']),'native package chooser');keys('Escape')
  keys('alt+t');image('classic-tools-menu-en.png');keys('Escape')
  app.terminate();app.wait(timeout=5)
  q=read_config();q['Interface']['Language']='zh';q.remove_section('ExternalTool')
  with config.open('w') as stream:q.write(stream)
  app=subprocess.Popen([str(root/'linux-noi-lazarus/dev-cpp'),'--new-window'],env=env,stdout=log,stderr=log)
  time.sleep(.4)
  win=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+'],text=True).split()[0]
  subprocess.run(['xdotool','windowsize',win,'1920','1040','windowmove',win,'0','0','windowfocus',win],check=True);keys('alt+t');image('classic-tools-menu-zh.png')
  print('PASS: restored Tools menus, environment persistence, editable/suppressed shortcuts, literal external argv and native package chooser')
except Exception:
 image('tools-failure.png')
 raise
finally:
 if app and app.poll() is None:app.terminate();app.wait(timeout=5)
PY
