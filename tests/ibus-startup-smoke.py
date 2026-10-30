#!/usr/bin/env python3
"""Real GTK2 IBus/GVFS with an authenticated D-Bus server withholding replies.

Run under xvfb-run as an ordinary user. The test bus accepts authentication and
withholds the Hello reply to exercise startup with an unresponsive session bus.
The actual 25-second GVFS/IBus lock was identified from the user's backtrace.
IBUS_STARTUP_APP selects an installed binary for the same check.
"""
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time

root=Path(__file__).resolve().parent.parent
app_path=os.environ.get('IBUS_STARTUP_APP',str(root/'linux-noi-lazarus/dev-cpp'))
assert Path('/usr/lib/x86_64-linux-gnu/gtk-2.0/2.10.0/immodules/im-ibus.so').is_file(),'Install ibus-gtk for the real input-method test'
assert Path('/usr/lib/x86_64-linux-gnu/gio/modules/libgvfsdbus.so').is_file(),'Install gvfs for the real desktop backend test'
with tempfile.TemporaryDirectory(prefix='devcpp-ibus-') as temp:
    folder=Path(temp);(folder/'home/.config').mkdir(parents=True)
    (folder/'home/.config/dev-cpp.ini').write_text('[Interface]\nLanguage=en\n')
    bus=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
    bus.bind(str(folder/'bus'));bus.listen(8);bus.settimeout(.1)
    done=threading.Event();authenticated=[]
    def handle(client):
        with client:
            client.settimeout(.1);pending=b'';begun=False
            while not done.is_set():
                try:data=client.recv(4096)
                except socket.timeout:continue
                except OSError:return
                if not data:return
                if begun:continue
                pending+=data
                while b'\r\n' in pending:
                    line,pending=pending.split(b'\r\n',1);line=line.lstrip(b'\0')
                    try:
                        if line.startswith(b'AUTH'):
                            client.sendall(b'OK 0123456789abcdef0123456789abcdef\r\n')
                        elif line.startswith(b'NEGOTIATE_UNIX_FD'):client.sendall(b'ERROR\r\n')
                        elif line==b'BEGIN':
                            authenticated.append(True);begun=True;break
                    except OSError:return
    def accept():
        while not done.is_set():
            try:client,_=bus.accept()
            except socket.timeout:continue
            except OSError:return
            threading.Thread(target=handle,args=(client,),daemon=True).start()
    threading.Thread(target=accept,daemon=True).start()
    env=dict(os.environ,HOME=str(folder/'home'),XDG_CONFIG_HOME=str(folder/'home/.config'),
             XDG_CACHE_HOME=str(folder/'home/.cache'),GTK_IM_MODULE='ibus',
             DBUS_SESSION_BUS_ADDRESS='unix:path='+str(folder/'bus'),DEV_CPP_STARTUP_TRACE='1')
    env.pop('GIO_USE_VFS',None)
    with (folder/'startup.log').open('w') as log:
        started=time.monotonic()
        app=subprocess.Popen([app_path,'--new-window'],env=env,stdout=log,stderr=log)
        visible=False
        try:
            while time.monotonic()-started<4:
                result=subprocess.run(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+'],capture_output=True)
                if result.returncode==0:visible=True;break
                assert app.poll() is None,'Application exited during IBus initialization'
                time.sleep(.05)
            maps=Path('/proc/'+str(app.pid)+'/maps').read_text()
            assert 'im-ibus.so' in maps,'Test must exercise the real IBus input module'
            assert visible,'IBus/GVFS bus timeout blocked the first window'
            log.flush();timing=(folder/'startup.log').read_text()
            assert 'GIO file backend: local' in timing
            assert 'IBus synchronous commit: 1' in timing
            print('PASS: real GTK2 IBus first window in %.3fs with an unresponsive session bus'%(time.monotonic()-started))
        except Exception:
            print((folder/'startup.log').read_text());raise
        finally:
            app.terminate();app.wait(timeout=5);done.set();bus.close()
