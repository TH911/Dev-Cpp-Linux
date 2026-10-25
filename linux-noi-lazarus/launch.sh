#!/usr/bin/env bash
set -euo pipefail
launch_origin=$PWD
launch_args=()
for launch_arg in "$@"; do
  case "$launch_arg" in
    --new-window|--forward-only|/*) launch_args+=("$launch_arg") ;;
    *) launch_args+=("$launch_origin/$launch_arg") ;;
  esac
done
set -- "${launch_args[@]}"
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
source ./ui-language.sh

new_window=false
for launch_arg in "$@"; do
  if [[ "$launch_arg" == --new-window ]]; then new_window=true; fi
done
if [[ "$new_window" == false && -x ./devcpp-noi && -f ./devcpp-noi.instance-api ]]; then
  if ./devcpp-noi --forward-only "$@" 2>/dev/null; then exit 0; fi
fi

# The desktop launcher starts an existing build immediately.  New or changed
# sources are compiled once, so an unpacked update cannot launch an old binary.
needs_build=false
if [[ ! -x ./devcpp-noi || ! -f ./devcpp-noi.instance-api ]]; then
  needs_build=true
else
  for launch_source in ./*.pas ./*.lpr ./*.lpi ./build.sh; do
    if [[ -f "$launch_source" && "$launch_source" -nt ./devcpp-noi ]]; then
      needs_build=true
      break
    fi
  done
fi
if [[ "$needs_build" == true ]]; then
  cache_dir=${XDG_CACHE_HOME:-"$HOME/.cache"}/devcpp-noi
  mkdir -p -- "$cache_dir"
  log_file="$cache_dir/launch-build.log"
  if ! bash build.sh >"$log_file" 2>&1; then
    if [[ "$devcpp_ui_language" == en ]]; then
      build_error="Dev-C++ could not be built. See $log_file"
    else
      build_error="Dev-C++ 编译失败。请查看日志：$log_file"
    fi
    if command -v zenity >/dev/null 2>&1; then
      zenity --error --title='Dev-C++' \
        --text="$build_error" || true
    elif command -v notify-send >/dev/null 2>&1; then
      notify-send 'Dev-C++' "$build_error" || true
    fi
    exit 1
  fi
fi

runtime_cache=${XDG_CACHE_HOME:-"$HOME/.cache"}/devcpp-noi
mkdir -p -- "$runtime_cache"
exec ./devcpp-noi "$@" 2> >(tee "$runtime_cache/runtime.log" >&2)
