#!/usr/bin/env bash
set -euo pipefail
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
fpc -Fu"$source_root/linux-noi-lazarus" -FU"$test_dir" -FE"$test_dir" \
  "$source_root/tests/runtime-support-test.pas" > "$test_dir/compile.log" 2>&1 || {
  cat "$test_dir/compile.log" >&2
  exit 1
}
"$test_dir/runtime-support-test"
