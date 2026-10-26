#!/usr/bin/env bash
set -euo pipefail

app_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$app_dir/ui-language.sh"
data_dir=${XDG_DATA_HOME:-"$HOME/.local/share"}
applications_dir="$data_dir/applications"
desktop_file="$applications_dir/devcpp-noi-source.desktop"
# Source builds have a separate identity and never shadow the installed menu.
if [[ -x /usr/lib/devcpp-noi/migrate-launchers.py ]]; then
  /usr/lib/devcpp-noi/migrate-launchers.py || true
fi
mkdir -p -- "$applications_dir"

# Desktop files use double quotes around executable paths containing spaces.
escaped_dir=${app_dir//\\/\\\\}
escaped_dir=${escaped_dir//\"/\\\"}
cat > "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=Dev-C++ (Source)
Name[zh_CN]=Dev-C++（源码构建）
Comment=Dev-C++ for NOI Linux
Comment[zh_CN]=适用于 NOI Linux 的 Dev-C++
Exec=/bin/bash "$escaped_dir/launch.sh" %F
Icon=$app_dir/devcpp.ico
Terminal=false
Categories=Development;IDE;
MimeType=text/x-c++src;text/x-csrc;text/x-c++hdr;text/x-chdr;
Actions=NewWindow;

[Desktop Action NewWindow]
Name=Open in New Window
Name[zh_CN]=在新窗口打开
Exec=/bin/bash "$escaped_dir/launch.sh" --new-window %F
EOF

cat > "$applications_dir/devcpp-noi-source-new-window.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Dev-C++ Source (Open in New Window)
Name[zh_CN]=Dev-C++ 源码构建（在新窗口打开）
Exec=/bin/bash "$escaped_dir/launch.sh" --new-window %F
Icon=$app_dir/devcpp.ico
Terminal=false
NoDisplay=true
MimeType=text/x-c++src;text/x-csrc;text/x-c++hdr;text/x-chdr;
EOF

# Stock GNOME Files exposes executable Nautilus scripts in its context menu.
scripts_dir="$data_dir/nautilus/scripts"
mkdir -p -- "$scripts_dir"
if [[ "$devcpp_ui_language" == en ]]; then
  context_script="$scripts_dir/Open in New Window (Dev-C++ Source)"
else
  context_script="$scripts_dir/在新窗口打开 (Dev-C++ Source)"
fi
printf '#!/usr/bin/env bash\napp_launch=%q\n' "$app_dir/launch.sh" > "$context_script"
cat >> "$context_script" <<'EOF'
set -euo pipefail
if [[ -n ${NAUTILUS_SCRIPT_SELECTED_FILE_PATHS:-} ]]; then
  mapfile -t selected_files < <(printf '%s' "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS")
  exec /bin/bash "$app_launch" --new-window "${selected_files[@]}"
fi
exec /bin/bash "$app_launch" --new-window "$@"
EOF
chmod +x -- "$context_script"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$applications_dir" >/dev/null 2>&1 || true
fi

if [[ "${1:-}" == "--default" ]]; then
  if ! command -v xdg-mime >/dev/null 2>&1; then
    if [[ "$devcpp_ui_language" == en ]]; then
      echo 'xdg-mime is unavailable; Dev-C++ is registered in Open With.' >&2
    else
      echo '找不到 xdg-mime；Dev-C++ 已注册到“打开方式”。' >&2
    fi
    exit 1
  fi
  default_desktop=devcpp-noi-source.desktop
  if [[ -x /usr/bin/devcpp-noi ]]; then default_desktop=devcpp-noi-installed.desktop; fi
  xdg-mime default "$default_desktop" text/x-c++src
  xdg-mime default "$default_desktop" text/x-csrc
  if [[ "$devcpp_ui_language" == en ]]; then
    echo 'Dev-C++ is the default application for .cpp and .c files.'
  else
    echo 'Dev-C++ 已设置为 .cpp 和 .c 文件的默认打开程序。'
  fi
fi
