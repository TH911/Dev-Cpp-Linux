#!/usr/bin/env bash
# Slow full font enumeration must not hold up an installed-style first window.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'result=$?; if [[ $result == 0 ]]; then rm -rf -- "$fixture"; else echo "First-frame fixture: $fixture"; cat "$fixture/runtime.log" >&2; fi' EXIT
cc -shared -fPIC "$root/tests/font-enumeration-probe.c" -o "$fixture/fonts.so" -ldl
python3 - "$root" "$fixture" <<'PY'
import os,pathlib,subprocess,sys,time
root,folder=map(pathlib.Path,sys.argv[1:]);(folder/'home/.config').mkdir(parents=True)
env=dict(os.environ,HOME=str(folder/'home'),LD_PRELOAD=str(folder/'fonts.so'),DEVC_FONT_ENUM_PROBE=str(folder/'enumerations'),DEV_CPP_STARTUP_TRACE='1')
with (folder/'runtime.log').open('w') as log:
 app=subprocess.Popen([os.environ.get('FIRST_FRAME_APP',str(root/'linux-noi-lazarus/dev-cpp')),'--new-window'],env=env,stdout=log,stderr=log)
 try:
  started=time.monotonic()
  while time.monotonic()-started<4:
   match=subprocess.run(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+'],capture_output=True)
   if match.returncode==0:break
   assert app.poll() is None,'IDE exited before its first window'
   time.sleep(.05)
  else:raise AssertionError('First window blocked by slow full font enumeration')
  assert not (folder/'enumerations').exists(),'Startup must not enumerate the font catalogue'
  print('PASS: first GTK window without blocking full font enumeration (injected 5s latency); %.3fs'%(time.monotonic()-started))
 finally:app.terminate();app.wait(timeout=5)
PY
