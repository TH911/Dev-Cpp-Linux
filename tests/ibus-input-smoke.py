#!/usr/bin/env python3
"""Type a real libpinyin phrase into the source editor; save and undo it.

Run as an ordinary user under dbus-run-session and xvfb-run. No synthetic GTK
commit signal or source-buffer manipulation is used: keys go through IBus.
"""
import os
import json
from pathlib import Path
import subprocess
import tempfile
import time

root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='devcpp-pinyin-') as temp:
    folder=Path(temp);home=folder/'home';(home/'.config').mkdir(parents=True)
    (home/'.config/dev-cpp.ini').write_text('[Interface]\nLanguage=en\n')
    runtime=folder/'runtime';runtime.mkdir(mode=0o700)
    source=folder/'comment.cpp';source.write_text('// ')
    env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),
        XDG_CACHE_HOME=str(home/'.cache'),XDG_RUNTIME_DIR=str(runtime),
        GTK_IM_MODULE='ibus',GSETTINGS_BACKEND='memory',DEV_CPP_STARTUP_TRACE='1')
    env.pop('GIO_USE_VFS',None)
    probe=folder/'probe.so'
    flags=subprocess.check_output(['pkg-config','--cflags','--libs','gtk+-2.0'],text=True).split()
    subprocess.run(['cc','-shared','-fPIC','-Wno-deprecated-declarations',str(root/'tests/gtk-state-probe.c'),'-o',str(probe),*flags,'-ldl'],check=True)
    app=None;daemon=None
    def state():
        try:return json.loads((folder/'state.json').read_text())
        except (OSError,ValueError):return []
    def command(*args):return subprocess.run(args,env=env,capture_output=True,text=True,timeout=8)
    def wait(test,message):
        limit=time.monotonic()+12
        while time.monotonic()<limit:
            if test():return
            if app is not None:assert app.poll() is None,'IDE exited'
            time.sleep(.1)
        raise AssertionError(message)
    def keys(*values):
        subprocess.run(['xdotool','key','--clearmodifiers','--delay','80',*values],env=env,check=True)
        time.sleep(.2)
    try:
        with (folder/'ibus.log').open('w') as ibuslog,(folder/'ide.log').open('w') as log:
            daemon=subprocess.Popen(['ibus-daemon','--replace','--xim','--panel=disable','--config=/usr/libexec/ibus-memconf','--cache=refresh','--emoji-extension=disable'],env=env,stdout=ibuslog,stderr=ibuslog)
            wait(lambda:command('ibus','address').returncode==0,'IBus service did not become ready')
            wait(lambda:'libpinyin' in command('ibus','list-engine').stdout,'libpinyin engine unavailable')
            env['IBUS_ADDRESS']=command('ibus','address').stdout.strip()
            app=subprocess.Popen([os.environ.get('IBUS_INPUT_APP',str(root/'linux-noi-lazarus/dev-cpp')),'--new-window',str(source)],env=dict(env,LD_PRELOAD=str(probe),DEVC_GTK_STATE=str(folder/'state.json')),stdout=log,stderr=log)
            wait(lambda:command('xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+').returncode==0,'IBus enabled first window')
            window=command('xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+').stdout.split()[0]
            subprocess.run(['xdotool','windowfocus',window],env=env,check=True);keys('ctrl+alt+e','ctrl+End')
            time.sleep(2)
            selected=command('gdbus','call','--address',env['IBUS_ADDRESS'],'--dest','org.freedesktop.IBus','--object-path','/org/freedesktop/IBus','--method','org.freedesktop.IBus.SetGlobalEngine','libpinyin')
            assert selected.returncode==0,selected.stderr
            time.sleep(.8)
            subprocess.run(['xdotool','type','--clearmodifiers','--delay','120','--','nihao'],env=env,check=True)
            keys('space');time.sleep(.5);keys('ctrl+s')
            wait(lambda:'你好' in source.read_text(),'the complete Chinese phrase must reach the source buffer')
            saved=source.read_text();assert 'nihao' not in saved and saved.count('你好')==1,saved
            keys('ctrl+z','ctrl+s');wait(lambda:'你好' not in source.read_text(),'one Undo removes the committed phrase')
            keys('ctrl+y','ctrl+s');wait(lambda:source.read_text()==saved,'Redo restores the complete UTF-8 phrase')
            keys('ctrl+f')
            wait(lambda:any(x['type']=='GtkWindow' and x['viewable'] and x['text']=='Search' for x in state()),'native search dialog')
            dialog=command('xdotool','search','--onlyvisible','--pid',str(app.pid),'--name','^Search$').stdout.split()[0]
            subprocess.run(['xdotool','windowfocus',dialog],env=env,check=True);keys('ctrl+a')
            subprocess.run(['xdotool','type','--clearmodifiers','--delay','120','--','nihao'],env=env,check=True);keys('space')
            wait(lambda:any(x['type']=='GtkEntry' and x['viewable'] and x['text']=='你好' for x in state()),'native GTK input remains compatible')
            keys('Escape');subprocess.run(['xdotool','windowfocus',window],env=env,check=True);keys('ctrl+alt+e','ctrl+End')
            subprocess.run(['xdotool','type','--clearmodifiers','--delay','120','--','nihao'],env=env,check=True);keys('space','ctrl+s')
            wait(lambda:source.read_text().count('你好')==2,'source IM context regains focus after a native dialog')
            print('PASS: native GTK Chinese entry, source focus restoration; real IBus/libpinyin multi-character Chinese input, exact UTF-8 save and one-step Undo/Redo')
    except Exception:
        print('saved source:',repr(source.read_text()))
        print('native entries:',[(x['type'],x['text']) for x in state() if x['type'] in ['GtkEntry','GtkWindow'] and x['viewable']])
        for name in ['ibus.log','ide.log']:
            path=folder/name
            if path.exists():print(name+':\n'+path.read_text())
        raise
    finally:
        for process in [app,daemon]:
            if process and process.poll() is None:
                process.terminate()
                try:process.wait(timeout=4)
                except subprocess.TimeoutExpired:process.kill();process.wait()
