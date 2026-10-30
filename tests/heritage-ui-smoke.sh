#!/usr/bin/env bash
# Native sidebar arrows, original About contents/links/authors, and GTK checks.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'result=$?; if [[ $result == 0 ]]; then rm -rf -- "$fixture"; else echo "Heritage UI fixture: $fixture"; cat "$fixture/runtime.log"; fi' EXIT
cc -shared -fPIC -Wno-deprecated-declarations "$root/tests/gtk-state-probe.c" -o "$fixture/probe.so" $(pkg-config --cflags --libs gtk+-2.0) -ldl
python3 - "$root" "$fixture" "${CLASSIC_UI_ARTIFACT_DIR:-$fixture/images}" <<'PY'
import ctypes,json,os,pathlib,subprocess,sys,time
root,folder,images=map(pathlib.Path,sys.argv[1:]);images.mkdir(parents=True,exist_ok=True)
home=folder/'home';(home/'.config').mkdir(parents=True);(folder/'bin').mkdir()
(folder/'bin/xdg-open').write_text('#!/bin/sh\nprintf "%s\\n" "$@" > "$HERITAGE_LINK"\n');(folder/'bin/xdg-open').chmod(0o755)
source=folder/'fixture.cpp';source.write_text('constexpr const int N=200005;\nint n,q,a[N+1];\nstruct query { int l1,r1,l2,r2; } t[N+1];\nnamespace Subtask1 { int b[10],c[10],d[10]; void Start() {} }\nint main() { return 0; }\n')
config=home/'.config/dev-cpp.ini';config.write_text('[Interface]\nLanguage=zh\n')
env=dict(os.environ,HOME=str(home),XDG_CACHE_HOME=str(home/'.cache'),PATH=str(folder/'bin')+':'+os.environ['PATH'],HERITAGE_LINK=str(folder/'link'),LD_PRELOAD=str(folder/'probe.so'),DEVC_GTK_STATE=str(folder/'state.json'),DEVC_GTK_SCREENSHOT=str(folder/'current.png'))
if os.environ.get('HERITAGE_HOSTILE_THEME')=='1':
 theme=folder/'hostile-arrows.rc'
 theme.write_text('style "hostile-arrows" { bg[NORMAL]="#ff00ff" bg[PRELIGHT]="#00ff00" bg[ACTIVE]="#ff0000" xthickness=7 ythickness=7 GtkButton::inner-border={8,8,8,8} }\nwidget "*.devcpp-sidebar-left" style "hostile-arrows"\nwidget "*.devcpp-sidebar-right" style "hostile-arrows"\n')
 env['GTK2_RC_FILES']=str(theme)
app=None

def state():
 try:return json.loads((folder/'state.json').read_text())
 except (ValueError,OSError):return []
def wait(test,message):
 until=time.monotonic()+12
 while time.monotonic()<until:
  if test():return
  assert app.poll() is None,'IDE exited'
  time.sleep(.08)
 raise AssertionError(message)
def keys(*args):subprocess.run(['xdotool','key','--clearmodifiers','--delay','60',*args],check=True);time.sleep(.2)
def click_item(item):subprocess.run(['xdotool','mousemove',str(item['x']+item['width']//2),str(item['y']+item['height']//2),'click','1'],check=True);time.sleep(.2)
def click_text(text):
 wait(lambda:any(x['type'] in ['GtkLabel','GtkButton'] and x['viewable'] and x['text'].replace('_','')==text for x in state()),'visible '+text)
 click_item(next(x for x in state() if x['type'] in ['GtkLabel','GtkButton'] and x['viewable'] and x['text'].replace('_','')==text))
def click_arrow(name):click_item(next(x for x in state() if x['name']==name and x['viewable']))
def capture(name):
 (folder/'current.png').unlink(missing_ok=True);(folder/'current.png.request').touch()
 wait(lambda:(folder/'current.png').exists() and (folder/'current.png').read_bytes().endswith(bytes.fromhex('0000000049454e44ae426082')),'complete screenshot')
 (images/name).write_bytes((folder/'current.png').read_bytes())
 (images/(name+'.json')).write_text(json.dumps(state()))
def pixels(path,points):
 lib=ctypes.CDLL('libgdk_pixbuf-2.0.so.0');obj=ctypes.CDLL('libgobject-2.0.so.0')
 lib.gdk_pixbuf_new_from_file.argtypes=[ctypes.c_char_p,ctypes.c_void_p];lib.gdk_pixbuf_new_from_file.restype=ctypes.c_void_p
 for name in ['gdk_pixbuf_get_rowstride','gdk_pixbuf_get_n_channels','gdk_pixbuf_get_pixels']:
  getattr(lib,name).argtypes=[ctypes.c_void_p]
 lib.gdk_pixbuf_get_pixels.restype=ctypes.c_void_p
 obj.g_object_unref.argtypes=[ctypes.c_void_p]
 pix=lib.gdk_pixbuf_new_from_file(os.fsencode(path),None);assert pix,'screenshot PNG decoded'
 try:
  stride=lib.gdk_pixbuf_get_rowstride(pix);channels=lib.gdk_pixbuf_get_n_channels(pix);data=lib.gdk_pixbuf_get_pixels(pix)
  return [tuple(ctypes.string_at(data+y*stride+x*channels,3)) for x,y in points]
 finally:obj.g_object_unref(pix)
def header_captions():
 return {x['text'] for x in state() if x['type']=='GtkLabel' and x['viewable'] and x['mapped'] and abs(x['y']-right['y'])<12 and x['text'] in ['项目管理','查看类','调试']}
def sidebar_page():
 return next(x['page'] for x in state() if x['type']=='GtkNotebook' and x['pages']==3 and x['width']==160)
def checked(text):
 items=state();byid={x['id']:x for x in items}
 item=next(x for x in items if x['type']=='GtkLabel' and x['viewable'] and x['text'].replace('_','')==text)
 while 'checked' not in item:item=byid[item['parent']]
 return item['checked']
def assert_link(url):
 click_text(url);wait(lambda:(folder/'link').exists() and (folder/'link').read_text().strip()==url,'original URL '+url)
try:
 with (folder/'runtime.log').open('w') as log:
  app=subprocess.Popen([str(root/'linux-noi-lazarus/dev-cpp'),'--new-window',str(source)],env=env,stdout=log,stderr=log)
  wait(lambda:any(x['type']=='GtkWindow' and x['viewable'] for x in state()),'main window')
  window=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+'],text=True).split()[0]
  subprocess.run(['xdotool','windowsize',window,'1360','940','windowmove',window,'0','0','windowfocus',window],check=True);time.sleep(.3)
  left=next(x for x in state() if x['name']=='devcpp-sidebar-left' and x['viewable'])
  right=next(x for x in state() if x['name']=='devcpp-sidebar-right' and x['viewable'])
  assert left['width']==right['width']==18 and left['height']==right['height']==18,(left,right)
  assert right['x']==left['x']+18 and right['y']==left['y'],'paired compact arrows'
  assert not any(x['type']=='GtkLabel' and x['viewable'] and x['text'] in ['<','>'] for x in state()),'arrows are glyphs, not text'
  for item in state():
   if item['type']=='GtkLabel' and item['viewable'] and item['text'] in ['项目管理','查看类']:
    assert item['height']>=item['text_height'],('sidebar text is vertically clipped',item)
  assert header_captions()=={'项目管理','查看类'},'Debug must be completely hidden in Project/Classes'
  capture('heritage-sidebar-project-zh.png')
  corners=[(right['x']+dx,right['y']+dy) for dx,dy in [(0,0),(17,0),(0,17),(17,17)]]
  assert pixels(images/'heritage-sidebar-project-zh.png',corners)==[(160,160,160)]*4,'square one-pixel arrow borders, independent of GTK rounding'
  subprocess.run(['xdotool','mousemove',str(right['x']+9),str(right['y']+9),'mousedown','1'],check=True);time.sleep(.15)
  capture('heritage-sidebar-arrow-pressed-zh.png')
  assert pixels(images/'heritage-sidebar-arrow-pressed-zh.png',[(right['x']+2,right['y']+2)])==[(204,228,247)],'pressed arrow feedback'
  subprocess.run(['xdotool','mousemove','450','180','mouseup','1'],check=True);time.sleep(.2)
  assert header_captions()=={'项目管理','查看类'},'dragging out cancels arrow click'
  assert sidebar_page()==0,'initial Project pane'
  click_arrow('devcpp-sidebar-right');assert sidebar_page()==0,'right arrow scrolls labels without selecting Classes or Debug'
  click_arrow('devcpp-sidebar-left');assert sidebar_page()==0,'left arrow preserves Project content'
  click_text('查看类');time.sleep(.5);assert header_captions()=={'项目管理','查看类'},'selecting Classes does not expose Debug'
  capture('heritage-sidebar-classes-zh.png');click_arrow('devcpp-sidebar-right')
  assert header_captions()=={'查看类','调试'},'right arrow reveals only Classes/Debug'
  assert sidebar_page()==1,'right arrow preserves Classes content'
  debug=next(x for x in state() if x['type']=='GtkLabel' and x['viewable'] and x['text']=='调试' and abs(x['y']-right['y'])<12)
  click_item(debug);capture('heritage-sidebar-debug-zh.png')
  bottom=next(x for x in state() if x['type']=='GtkLabel' and x['viewable'] and x['text']=='调试' and x['y']>right['y']+100)
  click_item(bottom)
  wait(lambda:any(x['type']=='GtkLabel' and x['viewable'] and '添加' in x['text'] for x in state()),'original Add watch button')
  click_item(next(x for x in state() if x['type']=='GtkLabel' and x['viewable'] and '添加' in x['text']))
  time.sleep(.2);keys('ctrl+a');subprocess.run(['xdotool','type','--clearmodifiers','C'],check=True);keys('Return')
  capture('heritage-sidebar-watch-zh.png');click_item(debug);keys('Left');click_arrow('devcpp-sidebar-left')
  click_text('项目管理');keys('alt+v');capture('heritage-view-checks-zh.png');keys('Escape','ctrl+alt+e','ctrl+f')
  wait(lambda:any(x['type']=='GtkWindow' and x['viewable'] and x['text']=='搜索' for x in state()),'original search dialog')
  search=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name','^搜索$'],text=True).split()[0]
  subprocess.run(['xdotool','windowfocus',search],check=True)
  assert not checked('全字匹配[W]')
  click_text('全字匹配[W]');wait(lambda:checked('全字匹配[W]'),'mouse changes actual check state');capture('heritage-checkbox-checked-zh.png')
  for attempt in range(10):
   items=state();byid={x['id']:x for x in items};label=next(x for x in items if x['type']=='GtkLabel' and x['viewable'] and x['text']=='全字匹配[W]')
   button=byid[label['parent']]
   if button['focus']:break
   keys('Tab')
  assert button['focus'],'whole-word checkbox is keyboard reachable'
  keys('space');wait(lambda:not checked('全字匹配[W]'),'Space changes actual check state');capture('heritage-checkbox-unchecked-zh.png');keys('Escape','alt+h','a')
  wait(lambda:any(x['type']=='GtkWindow' and x['viewable'] and x['text'].startswith('关于 Dev-C++') for x in state()),'About dialog')
  about=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name','^关于 Dev-C'],text=True).split()[0]
  subprocess.run(['xdotool','windowfocus',about],check=True)
  text='\n'.join(x['text'] for x in state())
  for value in ['Copyright (c) Bloodshed Software','Orwell Dev-C++ 5.11','<= 4.9.9.2','GNU GENERAL PUBLIC LICENSE','675 Mass Ave','END OF TERMS AND CONDITIONS','GPL-2.0-or-later','2015-04-27 22:11']:
   assert value in text,value
  capture('heritage-about-zh.png')
  for url in ['https://github.com/TH911/Dev-Cpp-Linux','https://sf.net/projects/orwelldevcpp/','http://www.bloodshed.net']:
   assert_link(url)
  click_text('作者[A]');wait(lambda:any('Johan Mes' in x['text'] and x['type']=='GtkTextView' and x['viewable'] for x in state()),'full original author list')
  authors=next(x['text'] for x in state() if x['type']=='GtkTextView' and x['viewable'] and 'Johan Mes' in x['text'])
  for name in ['Colin Laplace','Mike Berg','Hongli Lai','Yiannis Mandravellos','Peter Schraut','Marek Januszewski','Anonymous','Mumit Khan','J.J. van der Heijden','Colin Hendrix','GNU developers','Matthijs Crielaard','Gerard Caulfield','Gnome designers','Thomas Thron','TH911','inseculous@users.sourceforge.net','haiku@bloodshed.net']:
   assert name in authors,name
  capture('heritage-authors-zh.png');keys('Escape','Escape')
  assert app.poll() is None,'closing the dialogs leaves IDE alive'
  print('PASS: strict Project/Classes and Classes/Debug pairs; square arrow pixels, pressed/drag-out behavior and theme independence; project/class/debug selection and keyboard navigation; menu/checkbox screenshots; full original About')
finally:
 if app and app.poll() is None:app.terminate();app.wait(timeout=5)
PY
