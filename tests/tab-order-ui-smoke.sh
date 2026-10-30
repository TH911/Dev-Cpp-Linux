#!/usr/bin/env bash
# Native tab-label drag gestures with document identity and saved-byte checks.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'result=$?; if [[ $result == 0 ]]; then rm -rf -- "$fixture"; else echo "Tab UI fixture: $fixture"; cat "$fixture/runtime.log" >&2; fi' EXIT
cc -shared -fPIC -Wno-deprecated-declarations "$root/tests/gtk-state-probe.c" -o "$fixture/probe.so" $(pkg-config --cflags --libs gtk+-2.0) -ldl
python3 - "$root" "$fixture" <<'PY'
import ctypes as c,ctypes.util,json,os,pathlib,struct,subprocess,sys,time,zlib
root,folder=map(pathlib.Path,sys.argv[1:]);home=folder/'home';(home/'.config').mkdir(parents=True)
(home/'.config/dev-cpp.ini').write_text('[Interface]\nLanguage=en\n')
names=['alpha.cpp','beta.cpp','gamma.cpp','delta.cpp'];original={name:'// '+name+'\n' for name in names}
for name,content in original.items():(folder/name).write_text(content)
env=dict(os.environ,HOME=str(home),XDG_CACHE_HOME=str(home/'.cache'),LD_PRELOAD=str(folder/'probe.so'),DEVC_GTK_STATE=str(folder/'state.json'))
app=None
class CursorImage(c.Structure):
 _fields_=[('x',c.c_short),('y',c.c_short),('width',c.c_ushort),('height',c.c_ushort),('xhot',c.c_ushort),('yhot',c.c_ushort),('serial',c.c_ulong),('pixels',c.POINTER(c.c_ulong))]
xlib=c.CDLL(ctypes.util.find_library('X11'));fixes=c.CDLL(ctypes.util.find_library('Xfixes'))
xlib.XOpenDisplay.argtypes=[c.c_char_p];xlib.XOpenDisplay.restype=c.c_void_p
xlib.XCloseDisplay.argtypes=[c.c_void_p];xlib.XFree.argtypes=[c.c_void_p]
fixes.XFixesGetCursorImage.argtypes=[c.c_void_p];fixes.XFixesGetCursorImage.restype=c.POINTER(CursorImage)
def cursor():
 display=xlib.XOpenDisplay(None);assert display
 image=fixes.XFixesGetCursorImage(display);assert image
 try:
  value=image.contents;return value.width,value.height,value.xhot,value.yhot,[value.pixels[i]&0xffffffff for i in range(value.width*value.height)]
 finally:xlib.XFree(image);xlib.XCloseDisplay(display)
def save_cursor(value):
 directory=pathlib.Path(os.environ.get('CLASSIC_UI_ARTIFACT_DIR',str(folder/'images')));directory.mkdir(parents=True,exist_ok=True)
 w,h,_,_,pixels=value
 def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
 rows=b''.join(b'\0'+b''.join(bytes(((p>>16)&255,(p>>8)&255,p&255,(p>>24)&255)) for p in pixels[y*w:(y+1)*w]) for y in range(h))
 (directory/'tab-drag-cursor.png').write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b''))

def state():
 try:return json.loads((folder/'state.json').read_text())
 except (OSError,ValueError):return []
def wait(test,message):
 end=time.monotonic()+8
 while time.monotonic()<end:
  if test():return
  assert app.poll() is None,'IDE exited'
  time.sleep(.05)
 raise AssertionError(message+'; visible tabs='+str(tabs()))
def keys(*args):subprocess.run(['xdotool','key','--clearmodifiers','--delay','40',*args],check=True);time.sleep(.15)
def text(value):subprocess.run(['xdotool','type','--clearmodifiers','--delay','12','--',value],check=True);time.sleep(.1)
def label(name):return next(x for x in state() if x['type']=='GtkLabel' and x['viewable'] and x['text'].replace('[*]','')==name)
def tabs():return [x['text'].replace('[*]','') for x in sorted(state(),key=lambda x:x['x']) if x['type']=='GtkLabel' and x['viewable'] and (x['text'].replace('[*]','') in names or 'Untitled' in x['text'])]
def point(name):
 w=label(name);return w['x']+w['width']//2,w['y']+w['height']//2
def mouse(x,y):subprocess.run(['xdotool','mousemove',str(x),str(y)],check=True);time.sleep(.08)
def button(action,value=1):subprocess.run(['xdotool',action,str(value)],check=True);time.sleep(.1)
def click(name):mouse(*point(name));button('click')
def drag(source,target=None,button_number=1,escape=False,outside=False):
 sx,sy=point(source);tx,ty=point(target) if target else (sx+1,sy)
 if outside:ty+=180
 mouse(sx,sy);before=cursor();button('mousedown',button_number)
 for n in range(1,7):mouse(round(sx+(tx-sx)*n/6),round(sy+(ty-sy)*n/6))
 if target and button_number==1 and not outside:
  during=cursor();assert during[4]!=before[4],'real pointer must show drag feedback'
  w,h,xhot,yhot,pixels=during
  lower=[pixels[y*w+x] for y in range(yhot+16,min(h,yhot+26)) for x in range(xhot+3,min(w,xhot+18))]
  save_cursor(during)
  assert sum((p>>24)>0 for p in lower)>40,('drag cursor must include the lower-right document square',w,h,xhot,yhot,sum((p>>24)>0 for p in lower))
 if escape:keys('Escape')
 button('mouseup',button_number)
def title_contains(name):return any(x['type']=='GtkWindow' and x['viewable'] and name+' - Dev-C++' in x['text'] for x in state())
try:
 with (folder/'runtime.log').open('w') as log:
  app=subprocess.Popen([str(root/'linux-noi-lazarus/dev-cpp'),'--new-window',*map(lambda x:str(folder/x),names)],env=env,stdout=log,stderr=log)
  wait(lambda:tabs()==names,'original tab order')
  win=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+'],text=True).split()[0]
  subprocess.run(['xdotool','windowsize',win,'1400','950','windowmove',win,'0','0','windowfocus',win],check=True)
  wait(lambda:any(x['type']=='GtkWindow' and x['viewable'] and x['x']==0 and x['width']==1400 for x in state()),'resized native geometry')
  time.sleep(.2)
  notebook=next(x for x in state() if x['type']=='GtkNotebook' and x['name']=='devcpp-document-tabs')
  assert notebook['focus_line_width']==0 and notebook['focus_padding']==0,'document tabs must not draw a dashed focus border'
  assert notebook['tab_hborder']>=8,'document labels need comfortable horizontal padding'
  assert label('beta.cpp')['x']-label('alpha.cpp')['x']-label('alpha.cpp')['width']>=16,'tab captions must not be cramped together'
  drag('alpha.cpp','gamma.cpp');expected=['beta.cpp','gamma.cpp','alpha.cpp','delta.cpp'];wait(lambda:tabs()==expected,'left-to-right drag')
  drag('delta.cpp','beta.cpp');expected=['delta.cpp','beta.cpp','gamma.cpp','alpha.cpp'];wait(lambda:tabs()==expected,'right-to-left drag')
  for options in ({'target':None},{'target':'alpha.cpp','button_number':3},{'target':'alpha.cpp','outside':True}):
   drag('delta.cpp',**options);assert tabs()==expected,('jitter/right/outside must not reorder',options,tabs(),expected)
  click('gamma.cpp');keys('ctrl+alt+e','ctrl+End');text('X');keys('Escape');drag('gamma.cpp','delta.cpp');expected=['gamma.cpp','delta.cpp','beta.cpp','alpha.cpp'];wait(lambda:tabs()==expected,'active tab drag')
  wait(lambda:title_contains('gamma.cpp'),'active document stays attached to dragged tab')
  keys('ctrl+alt+e','ctrl+z','ctrl+s')
  wait(lambda:(folder/'gamma.cpp').read_text()==original['gamma.cpp'],'Undo history follows the moved buffer')
  keys('ctrl+y','ctrl+s');wait(lambda:'X' in (folder/'gamma.cpp').read_text(),'Redo follows the moved buffer')
  keys('ctrl+End');text('// edited after move');keys('Escape','ctrl+s')
  wait(lambda:'edited after move' in (folder/'gamma.cpp').read_text(),'save goes to dragged document')
  for name in ('alpha.cpp','beta.cpp','delta.cpp'):assert (folder/name).read_text()==original[name],'other documents unchanged'
  keys('ctrl+Tab');wait(lambda:title_contains('delta.cpp'),'Ctrl+Tab follows visual order')
  keys('ctrl+shift+Tab');wait(lambda:title_contains('gamma.cpp'),'previous tab follows visual order')
  keys('ctrl+w');expected=['delta.cpp','beta.cpp','alpha.cpp'];wait(lambda:tabs()==expected,'close removes the moved document only')
  keys('ctrl+n');text('int unnamed;');keys('Escape');wait(lambda:'Untitled1' in tabs(),'new unsaved tab')
  drag('Untitled1','delta.cpp');expected=['Untitled1','delta.cpp','beta.cpp','alpha.cpp'];wait(lambda:tabs()==expected,'dirty unnamed tab can move')
  keys('ctrl+w');keys('Escape');wait(lambda:tabs()==expected,'cancel close retains moved dirty tab')
  keys('ctrl+shift+s');wait(lambda:any(x.get('folder')==str(folder) and x['viewable'] for x in state()),'Save All reaches moved unnamed tab')
  savewin=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name','^Save As$'],text=True).split()[0]
  subprocess.run(['xdotool','windowfocus',savewin],check=True);keys('alt+n','ctrl+a');text('moved.cpp');keys('Return')
  wait(lambda:(folder/'moved.cpp').exists(),'moved unnamed source saved')
  assert (folder/'moved.cpp').read_text().strip()=='int unnamed;'
  for name in ('alpha.cpp','beta.cpp','delta.cpp'):assert (folder/name).read_text()==original[name],'Save All preserves other document identities'
  print('PASS: bidirectional native tab drag; click/right/outside guards; active identity, visual keyboard order, saved bytes, close cancellation and moved unnamed Save All')
finally:
 if app and app.poll() is None:app.terminate();app.wait(timeout=5)
PY
