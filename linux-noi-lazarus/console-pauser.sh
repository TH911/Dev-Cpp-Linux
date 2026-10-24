#!/usr/bin/env bash
# ConsolePauser behavior for a native NOI Linux executable.
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/ui-language.sh"
# GNOME Terminal uses UTF-8; keep the Chinese pause prompt readable even when
# the desktop inherited a legacy C locale.
unset LC_ALL
export LANG=C.UTF-8
export LC_CTYPE=C.UTF-8
started_ns=$(date +%s%N)
"$@"
return_value=$?
finished_ns=$(date +%s%N)
elapsed=$(awk -v start="$started_ns" -v finish="$finished_ns" \
  'BEGIN { printf "%.3f", (finish - start) / 1000000000 }')
printf '\n--------------------------------\n'
if [[ "$devcpp_ui_language" == en ]]; then
  printf 'Process exited after %s seconds with return value %s\n' "$elapsed" "$return_value"
  read -r -n 1 -p 'Press any key to continue. . .'
else
  printf '程序运行 %s 秒后退出，返回值为 %s\n' "$elapsed" "$return_value"
  read -r -n 1 -p '请按任意键继续. . .'
fi
printf '\n'
