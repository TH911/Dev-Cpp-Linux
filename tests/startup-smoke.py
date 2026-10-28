#!/usr/bin/env python3
"""Observe real GTK startup and ensure repeat source launches never recompile."""
import json
import os
from pathlib import Path
import statistics
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'linux-noi-lazarus'
BINARY = SOURCE / 'dev-cpp-linux'
VERSION = (ROOT / 'VERSION').read_text().strip()
samples = []
with tempfile.TemporaryDirectory(prefix='dev-cpp-linux-startup-') as directory:
    home = Path(directory)
    (home / '.config').mkdir()
    env = dict(os.environ, HOME=directory, DEV_CPP_LINUX_STARTUP_TRACE='1')
    for language in ('en', 'zh'):
        (home / '.config/dev-cpp-linux.ini').write_text('[Interface]\nLanguage=' + language + '\n')
        for trial in range(3):
            started = time.monotonic()
            with tempfile.TemporaryFile(mode='w+') as trace:
                app = subprocess.Popen([str(BINARY), '--new-window'], env=env,
                                       stdout=subprocess.DEVNULL, stderr=trace)
                try:
                    while time.monotonic() - started < 5:
                        found = subprocess.run(['xdotool', 'search', '--onlyvisible', '--pid', str(app.pid),
                                                '--name', 'dev-cpp-linux'], capture_output=True)
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
    before = BINARY.stat().st_mtime_ns
    no_display = dict(env)
    no_display.pop('DISPLAY', None)
    no_display.pop('DEV_CPP_LINUX_STARTUP_TRACE', None)
    help_result = subprocess.run([str(BINARY), '--help'], env=no_display, text=True, capture_output=True, check=True, timeout=5)
    assert 'Usage: dev-cpp-linux ' in help_result.stdout
    for trial in range(2):
        result = subprocess.run(['bash', str(SOURCE / 'run.sh'), '--version'], env=no_display,
                                text=True, capture_output=True, check=True, timeout=10)
        assert result.stdout.splitlines()[0] == 'dev-cpp-linux ' + VERSION, result.stdout
        assert BINARY.stat().st_mtime_ns == before, 'unchanged source launcher rebuilt the executable'
        assert 'building' not in result.stdout.lower(), result.stdout
print(json.dumps({'process_to_visible_window': samples,
                  'median_seconds': round(statistics.median(s['seconds'] for s in samples), 3)}, indent=2))
print('PASS: real English/Chinese startup, headless version, cached source launch without compilation')
