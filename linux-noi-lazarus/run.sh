#!/usr/bin/env bash
set -euo pipefail
run_origin=$PWD
run_args=()
for run_arg in "$@"; do
  case "$run_arg" in
    --new-window|--forward-only|/*) run_args+=("$run_arg") ;;
    *) run_args+=("$run_origin/$run_arg") ;;
  esac
done
set -- "${run_args[@]}"
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./ui-language.sh
if [[ "$devcpp_ui_language" == en ]]; then
  printf 'Dev-C++ NOI port: %s\n' "$(cat PORT_REVISION)"
else
  printf 'Dev-C++ NOI 移植版：%s\n' "$(cat PORT_REVISION)"
fi
bash build.sh
bash register-desktop.sh --register || true
runtime_cache=${XDG_CACHE_HOME:-"$HOME/.cache"}/devcpp-noi
mkdir -p -- "$runtime_cache"
exec ./devcpp-noi "$@" 2> >(tee "$runtime_cache/runtime.log" >&2)
