#!/usr/bin/python3
"""Repair only launchers written by the historical Dev-C++ source installer.

Run as the desktop user, never by scanning other users' home directories.
Customized files and symlinks are preserved. Backups live outside applications/.
"""
import configparser
import os
from pathlib import Path
import shlex
import stat
import subprocess
import tempfile


def owned_regular(path):
    try:
        info = path.lstat()
        return stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
    except OSError:
        return False


def original_desktop(path):
    if not owned_regular(path):
        return False
    try:
        text = path.read_text()
        ini = configparser.ConfigParser(interpolation=None, strict=True)
        ini.optionxform = str
        ini.read_string(text)
        entry = ini['Desktop Entry']
        if entry.get('Type') != 'Application' or entry.get('Terminal') != 'false':
            return False
        if entry.get('MimeType') != 'text/x-c++src;text/x-csrc;text/x-c++hdr;text/x-chdr;':
            return False
        args = shlex.split(entry.get('Exec', ''))
        if len(args) not in (3, 4) or args[0] != '/bin/bash' or args[-1] != '%F':
            return False
        if len(args) == 4 and args[2] != '--new-window':
            return False
        launch = Path(args[1])
        if not launch.is_absolute() or launch.name != 'launch.sh':
            return False
        if entry.get('Icon') != str(launch.parent / 'devcpp.ico'):
            return False
        # Whitelists keep hand-edited launchers, including additional fields.
        if path.name == 'devcpp-noi.desktop':
            if len(args) != 3:
                return False
            expected = {'Type', 'Name', 'Comment', 'Comment[zh_CN]', 'Exec', 'Icon',
                        'Terminal', 'Categories', 'MimeType', 'Actions'}
            if set(entry) != expected or entry.get('Name') != 'Dev-C++':
                return False
            if entry.get('Comment') not in ('Dev-C++ for NOI Linux', 'dev-cpp-linux for NOI Linux') or entry.get('Comment[zh_CN]') not in ('适用于 NOI Linux 的 Dev-C++', '适用于 NOI Linux 的 dev-cpp-linux'):
                return False
            if entry.get('Categories') != 'Development;IDE;' or entry.get('Actions') != 'NewWindow;':
                return False
            if set(ini.sections()) != {'Desktop Entry', 'Desktop Action NewWindow'}:
                return False
            action = ini['Desktop Action NewWindow']
            return (set(action) == {'Name', 'Name[zh_CN]', 'Exec'} and
                    action['Name'] == 'Open in New Window' and
                    action['Name[zh_CN]'] == '在新窗口打开' and
                    shlex.split(action['Exec']) == ['/bin/bash', str(launch), '--new-window', '%F'])
        expected = {'Type', 'Name', 'Name[zh_CN]', 'Exec', 'Icon', 'Terminal', 'NoDisplay', 'MimeType'}
        return (set(ini.sections()) == {'Desktop Entry'} and set(entry) == expected and
                entry.get('Name') == 'Dev-C++ (Open in New Window)' and
                entry.get('Name[zh_CN]') == 'Dev-C++（在新窗口打开）' and
                entry.get('NoDisplay') == 'true' and len(args) == 4)
    except (OSError, ValueError, configparser.Error):
        return False


def backup(path, backup_dir):
    backup_dir.mkdir(parents=True, exist_ok=True)
    # A unique name avoids replacing an earlier backup on repeated upgrades.
    descriptor, target = tempfile.mkstemp(prefix=path.name + '.', suffix='.bak', dir=str(backup_dir))
    with os.fdopen(descriptor, 'wb') as stream:
        stream.write(path.read_bytes())
    return target


def generated_source_desktop(path):
    """Recognize only the complete source entries produced by our own scripts."""
    if not owned_regular(path):
        return None
    try:
        ini = configparser.ConfigParser(interpolation=None, strict=True)
        ini.optionxform = str
        ini.read_string(path.read_text())
        entry = ini['Desktop Entry']
        args = shlex.split(entry.get('Exec', ''))
        if (len(args) not in (3, 4) or args[0] != '/bin/bash' or args[-1] != '%F' or
                (len(args) == 4 and args[2] != '--new-window')):
            return None
        launch = Path(args[1])
        if not launch.is_absolute() or launch.name != 'launch.sh':
            return None
        if (entry.get('Type') != 'Application' or entry.get('Terminal') != 'false' or
                entry.get('Icon') != str(launch.parent / 'devcpp.ico') or
                entry.get('MimeType') != 'text/x-c++src;text/x-csrc;text/x-c++hdr;text/x-chdr;'):
            return None
        if path.name in ('devcpp-noi-source.desktop', 'dev-cpp-linux-source.desktop', 'dev-cpp-source.desktop'):
            expected = {'Type', 'Name', 'Name[zh_CN]', 'Comment', 'Comment[zh_CN]', 'Exec',
                        'Icon', 'Terminal', 'Categories', 'MimeType', 'Actions'}
            if set(entry) - {'NoDisplay'} != expected or len(args) != 3:
                return None
            if (entry.get('Name'), entry.get('Name[zh_CN]')) not in (
                    ('Dev-C++ (Source)', 'Dev-C++（源码构建）'), ('Dev-Cpp', 'Dev-Cpp'), ('dev-cpp-linux', 'dev-cpp-linux'), ('Dev-C++', 'Dev-C++')):
                return None
            if (entry.get('Comment') not in ('Dev-C++ for NOI Linux', 'dev-cpp-linux for NOI Linux') or
                    entry.get('Comment[zh_CN]') not in ('适用于 NOI Linux 的 Dev-C++', '适用于 NOI Linux 的 dev-cpp-linux') or
                    entry.get('Categories') != 'Development;IDE;' or entry.get('Actions') != 'NewWindow;' or
                    set(ini.sections()) != {'Desktop Entry', 'Desktop Action NewWindow'}):
                return None
            action = ini['Desktop Action NewWindow']
            if (set(action) != {'Name', 'Name[zh_CN]', 'Exec'} or action['Name'] != 'Open in New Window' or
                    action['Name[zh_CN]'] != '在新窗口打开' or
                    shlex.split(action['Exec']) != ['/bin/bash', str(launch), '--new-window', '%F']):
                return None
        else:
            expected = {'Type', 'Name', 'Name[zh_CN]', 'Exec', 'Icon', 'Terminal', 'NoDisplay', 'MimeType'}
            if (set(ini.sections()) != {'Desktop Entry'} or set(entry) != expected or
                    entry.get('NoDisplay') != 'true' or len(args) != 4 or
                    (entry.get('Name'), entry.get('Name[zh_CN]')) not in (
                        ('Dev-C++ Source (Open in New Window)', 'Dev-C++ 源码构建（在新窗口打开）'),
                        ('Dev-Cpp', 'Dev-Cpp'), ('dev-cpp-linux', 'dev-cpp-linux'), ('Dev-C++', 'Dev-C++'))):
                return None
        if entry.get('NoDisplay', 'false') not in ('true', 'false'):
            return None
        return ini
    except (OSError, ValueError, configparser.Error):
        return None


def hide_source_entry(path, backup_dir):
    ini = generated_source_desktop(path)
    if ini is None:
        return False
    entry = ini['Desktop Entry']
    if entry.get('NoDisplay') == 'true' and entry.get('Name') == 'Dev-C++':
        return False
    backup(path, backup_dir)
    entry['Name'] = entry['Name[zh_CN]'] = 'Dev-C++'
    entry['NoDisplay'] = 'true'
    descriptor, temporary = tempfile.mkstemp(prefix='.devcpp-migrate-', dir=str(path.parent))
    try:
        with os.fdopen(descriptor, 'w') as stream:
            ini.write(stream, space_around_delimiters=False)
        os.chmod(temporary, path.stat().st_mode & 0o777)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return True


def main():
    # Root without an explicit desktop user's identity must not inspect root's
    # settings or search /home. postinst invokes us through runuser if available.
    if os.getuid() == 0:
        return
    home = Path.home()
    data = Path(os.environ.get('XDG_DATA_HOME') or home / '.local/share')
    if not data.is_absolute():
        return
    applications = data / 'applications'
    backup_dir = data / 'devcpp-noi/launcher-backups'
    changed = False
    for name in ('devcpp-noi.desktop', 'devcpp-noi-new-window.desktop'):
        path = applications / name
        if original_desktop(path):
            backup(path, backup_dir)
            path.unlink()
            changed = True
    for name in ('devcpp-noi-source.desktop', 'devcpp-noi-source-new-window.desktop',
                 'dev-cpp-linux-source.desktop', 'dev-cpp-linux-source-new-window.desktop',
                 'dev-cpp-source.desktop', 'dev-cpp-source-new-window.desktop'):
        changed = hide_source_entry(applications / name, backup_dir) or changed
    scripts = data / 'nautilus/scripts'
    for name in ('Open in New Window (Dev-C++)', '在新窗口打开 (Dev-C++)',
                 'Open in New Window (Dev-Cpp)', '在新窗口打开 (Dev-Cpp)',
                 'Open in New Window (dev-cpp-linux)', '在新窗口打开 (dev-cpp-linux)'):
        path = scripts / name
        if not owned_regular(path):
            continue
        try:
            lines = path.read_text().splitlines()
            expected_tail = [
                'set -euo pipefail',
                'if [[ -n ${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-} ]]; then',
                '  mapfile -t selected_files < <(printf \'%s\' "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS")',
                '  exec /bin/bash "$app_launch" --new-window "${selected_files[@]}"',
                'fi', 'exec /bin/bash "$app_launch" --new-window "$@"']
            source_script = (len(lines) == 8 and lines[0] == '#!/usr/bin/env bash' and
                             lines[1].startswith('app_launch=') and lines[2:] == expected_tail)
            installed_script = False
            for legacy_command in ('/usr/bin/devcpp-noi', '/usr/bin/dev-cpp-linux', '/usr/bin/dev-cpp'):
                installed_tail = [line.replace('/bin/bash "$app_launch"', legacy_command)
                                  for line in expected_tail]
                if (len(lines) == 9 and lines[0] == '#!/usr/bin/env bash' and
                        lines[1] in ('# Dev-C++ NOI installed launcher', '# dev-cpp-linux installed launcher', '# Dev-C++ installed launcher') and
                        lines[2:] == installed_tail):
                    installed_script = True
                    break
            if not source_script and not installed_script:
                continue
            if source_script:
                assignment = shlex.split(lines[1])
                if len(assignment) != 1 or not assignment[0].startswith('app_launch=/'):
                    continue
                target = assignment[0].split('=', 1)[1]
                if not target.endswith('/launch.sh') and target not in ('/usr/bin/dev-cpp-linux', '/usr/bin/devcpp-noi', '/usr/bin/dev-cpp'):
                    continue
            if name.endswith('(Dev-C++)') and (
                    (installed_script and legacy_command == '/usr/bin/dev-cpp') or
                    (source_script and target == '/usr/bin/dev-cpp')):
                continue
            renamed = scripts / name.replace('Dev-Cpp', 'Dev-C++').replace('dev-cpp-linux', 'Dev-C++')
            if renamed != path and (renamed.exists() or renamed.is_symlink()):
                continue
            backup(path, backup_dir)
            descriptor, temporary = tempfile.mkstemp(prefix='.devcpp-migrate-', dir=str(scripts))
            with os.fdopen(descriptor, 'w') as stream:
                stream.write('#!/usr/bin/env bash\n# Dev-C++ installed launcher\n'
                             'set -euo pipefail\n'
                             'if [[ -n ${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-} ]]; then\n'
                             '  mapfile -t selected_files < <(printf \'%s\' "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS")\n'
                             '  exec /usr/bin/dev-cpp --new-window "${selected_files[@]}"\n'
                             'fi\nexec /usr/bin/dev-cpp --new-window "$@"\n')
            os.chmod(temporary, 0o755)
            os.replace(temporary, renamed)
            if renamed != path: path.unlink()
        except (OSError, ValueError):
            continue
    if changed:
        try:
            subprocess.run(['update-desktop-database', str(applications)], stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, check=False)
        except OSError:
            pass


if __name__ == '__main__':
    main()
