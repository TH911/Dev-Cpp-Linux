#!/usr/bin/env python3
"""Observe real GTK startup and ensure repeat source launches never recompile."""
import json
import configparser
import os
from pathlib import Path
import statistics
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'linux-noi-lazarus'
BINARY = SOURCE / 'dev-cpp'
VERSION = (ROOT / 'VERSION').read_text().strip()
samples = []
with tempfile.TemporaryDirectory(prefix='dev-cpp-startup-') as directory:
    home = Path(directory)
    (home / '.config').mkdir()
    env = dict(os.environ, HOME=directory, DEV_CPP_STARTUP_TRACE='1')
    for language in ('en', 'zh'):
        (home / '.config/dev-cpp.ini').write_text('[Interface]\nLanguage=' + language + '\n')
        for trial in range(3):
            started = time.monotonic()
            with tempfile.TemporaryFile(mode='w+') as trace:
                app = subprocess.Popen([str(BINARY), '--new-window'], env=env,
                                       stdout=subprocess.DEVNULL, stderr=trace)
                try:
                    while time.monotonic() - started < 5:
                        found = subprocess.run(['xdotool', 'search', '--onlyvisible', '--pid', str(app.pid),
                                                '--name', r'Dev-C\+\+'], capture_output=True)
                        if found.returncode == 0:
                            break
                        assert app.poll() is None, 'IDE exited before showing its window'
                        time.sleep(.01)
                    else:
                        raise AssertionError('main window did not appear within 5 seconds')
                    elapsed = time.monotonic() - started
                    trace.seek(0)
                    assert 'translations applied' in trace.read(), 'startup instrumentation did not finish'
                    samples.append({'language': language, 'trial': trial + 1, 'seconds': round(elapsed, 3)})
                    if language == 'en' and trial == 0:
                        original = BINARY.with_name('.startup-original')
                        assert not original.exists()
                        query = [str(BINARY), '--forward-only']
                        assert subprocess.run(query, env=env, capture_output=True, timeout=5).returncode == 0
                        BINARY.rename(original)
                        try:
                            shutil.copy2(original, BINARY)
                            assert subprocess.run(query, env=env, capture_output=True, timeout=5).returncode == 3, 'new binary activated the old mapped executable'
                        finally:
                            original.replace(BINARY)
                        assert subprocess.run(query, env=env, capture_output=True, timeout=5).returncode == 0

                finally:
                    app.terminate()
                    app.wait(timeout=5)
    for case, expected in (('noi-only','noi'), ('both-legacy','linux'), ('existing-new','new')):
        case_home=home/case;settings=case_home/'.config';settings.mkdir(parents=True)
        originals={settings/'devcpp-noi.ini':'[Interface]\nLanguage=en\n[Migration]\nSentinel=noi\n'}
        if case!='noi-only':originals[settings/'dev-cpp-linux.ini']='[Interface]\nLanguage=en\n[Migration]\nSentinel=linux\n'
        for path, content in originals.items():path.write_text(content)
        target=settings/'dev-cpp.ini'
        if case=='existing-new':target.write_text('[Interface]\nLanguage=en\n[Migration]\nSentinel=new\n')
        case_env=dict(env,HOME=str(case_home))
        app=subprocess.Popen([str(BINARY),'--new-window'],env=case_env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            deadline=time.monotonic()+5
            while subprocess.run(['xdotool','search','--onlyvisible','--pid',str(app.pid),'--name',r'Dev-C\+\+'],capture_output=True).returncode:
                assert app.poll() is None and time.monotonic()<deadline,'configuration migration prevented startup'
                time.sleep(.02)
            saved=configparser.ConfigParser(interpolation=None);saved.read(target)
            assert saved.get('Migration','Sentinel')==expected,'wrong legacy config selected or new config overwritten'
            assert all(path.read_text()==content for path,content in originals.items()),'migration changed an old config'
            if case!='existing-new':assert target.stat().st_mode&0o777==0o600,'migration config is not private'
        finally:
            app.terminate();app.wait(timeout=5)
    before = BINARY.stat().st_mtime_ns
    no_display = dict(env)
    no_display.pop('DISPLAY', None)
    no_display.pop('DEV_CPP_STARTUP_TRACE', None)
    help_result = subprocess.run([str(BINARY), '--help'], env=no_display, text=True, capture_output=True, check=True, timeout=5)
    assert 'Usage: dev-cpp ' in help_result.stdout
    for trial in range(2):
        result = subprocess.run(['bash', str(SOURCE / 'run.sh'), '--version'], env=no_display,
                                text=True, capture_output=True, check=True, timeout=10)
        assert result.stdout.splitlines()[0] == 'dev-cpp ' + VERSION, result.stdout
        assert BINARY.stat().st_mtime_ns == before, 'unchanged source launcher rebuilt the executable'
        assert 'building' not in result.stdout.lower(), result.stdout
print(json.dumps({'process_to_visible_window': samples,
                  'median_seconds': round(statistics.median(s['seconds'] for s in samples), 3)}, indent=2))
print('PASS: real English/Chinese startup, headless version, cached source launch without compilation and both legacy config migrations')
