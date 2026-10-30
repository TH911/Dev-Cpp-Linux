#!/usr/bin/env bash
# Observe real bracket-markup pixels and exercise actual keyboard pairing/undo.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'result=$?; if [[ $result == 0 ]]; then rm -rf -- "$fixture"; else echo "Bracket UI fixture: $fixture"; cat "$fixture/runtime.log" >&2; fi' EXIT
cc -shared -fPIC -Wno-deprecated-declarations "$root/tests/gtk-state-probe.c" -o "$fixture/probe.so" $(pkg-config --cflags --libs gtk+-2.0) -ldl
python3 - "$root" "$fixture" <<'PY'
import array,ctypes,ctypes.util,json,os,pathlib,subprocess,sys,time
root,folder=map(pathlib.Path,sys.argv[1:]);home=folder/'home';(home/'.config').mkdir(parents=True)
(home/'.config/dev-cpp.ini').write_text('[Interface]\nLanguage=en\n[Editor]\nTheme=Classic Plus\nFontSize=14\n')
lines=['f();','const char* text = "([]{})";',"char l = '('; char r = ')';",'//([]{})','/*','([]{})','*/','auto raw = R"tag("([]{})"','([]{}))tag";','f(/* ) */ "(", arr[0]);','f()','a[]','{}',')',']','}','f(/* ( */)','f(")")','const char* s = "";','// note']
source=folder/'fixture.cpp';original='\n'.join(lines)+'\n';source.write_text(original)
env=dict(os.environ,HOME=str(home),LD_PRELOAD=str(folder/'probe.so'),DEVC_GTK_STATE=str(folder/'state.json'))
app=None
def state():
 try:return json.loads((folder/'state.json').read_text())
 except (OSError,ValueError):return []
def wait(test,message):
 end=time.monotonic()+10
 while time.monotonic()<end:
  if test():return
  assert app.poll() is None,'IDE exited'
  time.sleep(.05)
 raise AssertionError(message)
def keys(*args):subprocess.run(['xdotool','key','--clearmodifiers','--delay','25',*args],check=True);time.sleep(.09)
def text(value):subprocess.run(['xdotool','type','--clearmodifiers','--delay','10','--',value],check=True);time.sleep(.09)
def caret(row,column):
 keys('ctrl+alt+e','ctrl+g');text(str(row));keys('Return','Home')
 if column>1:subprocess.run(['xdotool','key','--clearmodifiers','--repeat',str(column-1),'--delay','5','Right'],check=True)
 time.sleep(.2)
def saved(expected):
 keys('ctrl+s');wait(lambda:source.read_text()==expected,'pairing or Undo produced unexpected bytes: '+source.read_text())
lib=ctypes.CDLL(ctypes.util.find_library('X11'))
class XImage(ctypes.Structure):
 _fields_=[('width',ctypes.c_int),('height',ctypes.c_int),('xoffset',ctypes.c_int),('format',ctypes.c_int),('data',ctypes.c_void_p),('byte_order',ctypes.c_int),('bitmap_unit',ctypes.c_int),('bitmap_bit_order',ctypes.c_int),('bitmap_pad',ctypes.c_int),('depth',ctypes.c_int),('bytes_per_line',ctypes.c_int),('bits_per_pixel',ctypes.c_int)]
lib.XOpenDisplay.restype=ctypes.c_void_p
lib.XDefaultRootWindow.argtypes=[ctypes.c_void_p];lib.XDefaultRootWindow.restype=ctypes.c_ulong
lib.XGetImage.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.c_int,ctypes.c_int,ctypes.c_uint,ctypes.c_uint,ctypes.c_ulong,ctypes.c_int];lib.XGetImage.restype=ctypes.POINTER(XImage)
lib.XDestroyImage.argtypes=[ctypes.POINTER(XImage)]
lib.XCloseDisplay.argtypes=[ctypes.c_void_p]
def red_pixels():
 editor=next(x for x in state() if x['focus'] and x['viewable'] and x['type'] in ('LCLWinapiClient','GtkCustomControl') and x['width']>400)
 display=lib.XOpenDisplay(None);assert display
 picture=lib.XGetImage(display,lib.XDefaultRootWindow(display),editor['x'],editor['y'],editor['width'],editor['height'],0xffffffff,2);assert picture
 try:
  p=picture.contents;assert p.bits_per_pixel==32
  pixels=array.array('I',ctypes.string_at(p.data,p.bytes_per_line*p.height))
  return sum((pixel&0xffffff)==0xff0000 for pixel in pixels)
 finally:lib.XDestroyImage(picture);lib.XCloseDisplay(display)
try:
 with (folder/'runtime.log').open('w') as log:
  app=subprocess.Popen([os.environ.get('BRACKETS_APP',str(root/'linux-noi-lazarus/dev-cpp')),'--new-window',str(source)],env=env,stdout=log,stderr=log)
  wait(lambda:any(x['type']=='GtkWindow' and x['viewable'] and 'Dev-C++ ' in x['text'] for x in state()),'main window missing')
  win=subprocess.check_output(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+'],text=True).split()[0]
  subprocess.run(['xdotool','windowsize',win,'1400','950','windowmove',win,'0','0','windowfocus',win],check=True)
  caret(1,1);baseline=red_pixels();caret(1,3);matched=red_pixels()
  assert matched>baseline+100,(baseline,matched,'code pair must have a red matching background')
  for row in (2,3,4,6,8,9):
   caret(row,lines[row-1].index('(')+2);observed=red_pixels()
   assert observed<baseline+70,(row,baseline,observed,'literal/comment must not acquire red matching markup')
  cases=[(11,3,'(','f(())'),(12,3,'[','a[[]]'),(13,2,'{','{{}}'),(14,1,'(','()'),(15,1,'[','[]'),(16,1,'{','{}'),(17,len(lines[16]),'(','f(/* ( */())'),(18,len(lines[17]),'(','f(")"())'),(19,lines[18].index('"')+2,'(',lines[18].replace('""','"("')),(20,len(lines[19])+1,'(',lines[19]+'(')]
  for row,col,key,expected_line in cases:
   caret(row,col);text(key)
   expected=lines.copy();expected[row-1]=expected_line;changed='\n'.join(expected)+'\n';saved(changed)
   keys('ctrl+z');saved(original);keys('ctrl+y');saved(changed);keys('ctrl+z');saved(original)
  print('PASS: real code-only red bracket markup; nested/orphan (), [], {} pairing; ignored literal/comment brackets; one-step Undo/Redo')
finally:
 if app and app.poll() is None:app.terminate();app.wait(timeout=5)
PY
