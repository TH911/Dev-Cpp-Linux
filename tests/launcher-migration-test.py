#!/usr/bin/env python3
"""Check recognition and preservation of user desktop launchers as a real user."""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
HELPER = ROOT / 'packaging/templates/migrate-launchers.py'


def legacy_desktop(source):
    escaped = str(source).replace('\\', '\\\\').replace('"', '\\"')
    return f'''[Desktop Entry]
Type=Application
Name=Dev-C++
Comment=Dev-C++ for NOI Linux
Comment[zh_CN]=适用于 NOI Linux 的 Dev-C++
Exec=/bin/bash "{escaped}/launch.sh" %F
Icon={source}/devcpp.ico
Terminal=false
Categories=Development;IDE;
MimeType=text/x-c++src;text/x-csrc;text/x-c++hdr;text/x-chdr;
Actions=NewWindow;

[Desktop Action NewWindow]
Name=Open in New Window
Name[zh_CN]=在新窗口打开
Exec=/bin/bash "{escaped}/launch.sh" --new-window %F
'''


def main():
    assert os.getuid() != 0, 'Run this preservation test as an ordinary user'
    with tempfile.TemporaryDirectory(prefix='devcpp-migration-') as folder:
        base = Path(folder)
        data = base / 'data'
        apps = data / 'applications'
        apps.mkdir(parents=True)
        ini = base / 'devcpp-noi.ini'
        ini.write_text('[Interface]\nLanguage=en\n')
        mime = apps / 'mimeapps.list'
        mime.write_text('[Default Applications]\ntext/x-c++src=my-editor.desktop;\n')
        old = apps / 'devcpp-noi.desktop'
        text = legacy_desktop(base / 'deleted 中文 source')
        old.write_text(text)
        scripts = data / 'nautilus/scripts'
        scripts.mkdir(parents=True)
        context = scripts / '在新窗口打开 (Dev-C++)'
        context.write_text('#!/usr/bin/env bash\napp_launch=' + shlex.quote(str(base / 'deleted 中文 source/launch.sh')) + '\n' +
                           'set -euo pipefail\n'
                           'if [[ -n ${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-} ]]; then\n'
                           '  mapfile -t selected_files < <(printf \'%s\' "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS")\n'
                           '  exec /bin/bash "$app_launch" --new-window "${selected_files[@]}"\n'
                           'fi\nexec /bin/bash "$app_launch" --new-window "$@"\n')
        env = dict(os.environ, HOME=str(base), XDG_DATA_HOME=str(data))
        def repair():
            subprocess.run(['python3', str(HELPER)], env=env, check=True)
        repair()
        assert not old.exists(), 'Known generated launcher still shadows package'
        backups = list((data / 'devcpp-noi/launcher-backups').glob('*.bak'))
        desktop_backups = [p for p in backups if p.name.startswith('devcpp-noi.desktop.')]
        assert len(backups) == 2 and len(desktop_backups) == 1 and desktop_backups[0].read_text() == text
        assert not context.exists(), 'Old context-menu brand remains'
        context = scripts / '在新窗口打开 (dev-cpp-linux)'
        assert 'exec /usr/bin/dev-cpp-linux --new-window' in context.read_text()
        assert context.stat().st_mode & 0o111
        repair()
        assert len(list((data / 'devcpp-noi/launcher-backups').glob('*.bak'))) == 2
        source = apps / 'devcpp-noi-source.desktop'
        source_text = text.replace('Name=Dev-C++\n',
                                   'Name=Dev-C++ (Source)\nName[zh_CN]=Dev-C++（源码构建）\n', 1)
        source.write_text(source_text)
        repair()
        migrated = source.read_text()
        assert 'Name=dev-cpp-linux\n' in migrated and 'Name[zh_CN]=dev-cpp-linux\n' in migrated
        assert 'NoDisplay=true\n' in migrated, 'Source registration duplicates the installed menu'
        assert 'Icon=' + str(base / 'deleted 中文 source/devcpp.ico') in migrated
        source_backups = list((data / 'devcpp-noi/launcher-backups').glob('devcpp-noi-source.desktop.*.bak'))
        assert len(source_backups) == 1 and source_backups[0].read_text() == source_text
        repair()
        assert len(list((data / 'devcpp-noi/launcher-backups').glob('devcpp-noi-source.desktop.*.bak'))) == 1
        custom_source = source_text + '\n[Custom User Section]\nKeep=true\n'
        source.write_text(custom_source)
        repair()
        assert source.read_text() == custom_source, 'Customized source menu was rewritten'
        source.unlink()
        source.symlink_to(base / 'custom-source.desktop')
        (base / 'custom-source.desktop').write_text(source_text)
        repair()
        assert source.is_symlink() and source.read_text() == source_text
        custom = text.replace('Name=Dev-C++\n', 'Name=My custom Dev-C++\n')
        old.write_text(custom)
        repair()
        assert old.read_text() == custom, 'Customized launcher was changed'
        old.write_text(text + 'X-Custom-Setting=keep\n')
        repair()
        assert old.exists(), 'Extended/customized launcher was removed'
        custom_exec = text.replace('/launch.sh" %F', '/launch.sh" --new-window %F', 1)
        old.write_text(custom_exec)
        repair()
        assert old.read_text() == custom_exec, 'Customized main launcher flags were changed'
        old.unlink()
        target = base / 'linked.desktop'
        target.write_text(text)
        old.symlink_to(target)
        repair()
        assert old.is_symlink() and target.read_text() == text
        assert mime.read_text() == '[Default Applications]\ntext/x-c++src=my-editor.desktop;\n'
        assert ini.read_text() == '[Interface]\nLanguage=en\n'
    print('PASS: precise launcher migration, source-menu deduplication, backups/idempotency, custom names/fields/flags, symlinks, MIME and settings preserved')


if __name__ == '__main__':
    main()
