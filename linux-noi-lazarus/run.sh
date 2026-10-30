#!/usr/bin/env bash
set -euo pipefail
run_origin=$PWD
run_args=()
for run_arg in "$@"; do
  case "$run_arg" in
    --new-window|--forward-only|--version|--help|/*) run_args+=("$run_arg") ;;
    *) run_args+=("$run_origin/$run_arg") ;;
  esac
done
set -- "${run_args[@]}"
cd "$(dirname "${BASH_SOURCE[0]}")"
# launch.sh rebuilds only when inputs changed. Registration is an explicit
# operation; it must not slow down every editor launch.
exec bash ./launch.sh "$@"
