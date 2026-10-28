#!/usr/bin/env bash
set -euo pipefail
launch_origin=$PWD
launch_args=()
for launch_arg in "$@"; do
  case "$launch_arg" in
    --new-window|--forward-only|--version|--help|/*) launch_args+=("$launch_arg") ;;
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
if [[ $# == 1 && ( $1 == --version || $1 == --help ) ]]; then new_window=true; fi

# Both CLI and desktop launchers start an existing build immediately.  New or changed
# sources are compiled once, so an unpacked update cannot launch an old binary.
needs_build=false
if [[ ! -x ./dev-cpp-linux || ! -f ./dev-cpp-linux.instance-api ]]; then
  needs_build=true
else
  for launch_source in ./*.pas ./*.lpr ./*.lpi ./*.inc ./PORT_REVISION ./build.sh; do
    if [[ -f "$launch_source" && "$launch_source" -nt ./dev-cpp-linux ]]; then
      needs_build=true
      break
    fi
  done
fi
if [[ "$needs_build" == true ]]; then
  cache_dir=${XDG_CACHE_HOME:-"$HOME/.cache"}/dev-cpp-linux
  mkdir -p -- "$cache_dir"
  log_file="$cache_dir/launch-build.log"
  if ! bash build.sh >"$log_file" 2>&1; then
    if [[ "$devcpp_ui_language" == en ]]; then
      build_error="dev-cpp-linux could not be built. See $log_file"
    else
      build_error="dev-cpp-linux 编译失败。请查看日志：$log_file"
    fi
    if command -v zenity >/dev/null 2>&1; then
      zenity --error --title='dev-cpp-linux' \
        --text="$build_error" || true
    elif command -v notify-send >/dev/null 2>&1; then
      notify-send 'dev-cpp-linux' "$build_error" || true
    fi
    exit 1
  fi
fi

if [[ "$new_window" == false && -x ./dev-cpp-linux && -f ./dev-cpp-linux.instance-api ]]; then
  if ./dev-cpp-linux --forward-only "$@" 2>/dev/null; then exit 0; fi
fi


runtime_cache=${XDG_CACHE_HOME:-"$HOME/.cache"}/dev-cpp-linux
mkdir -p -- "$runtime_cache"
exec ./dev-cpp-linux "$@" 2> >(tee "$runtime_cache/runtime.log" >&2)
