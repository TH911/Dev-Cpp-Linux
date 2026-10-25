#!/usr/bin/env bash
set -euo pipefail
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
# Both source and executable paths deliberately contain spaces.
cat > "$test_dir/debug fixture.c" <<'EOF'
#include <stdio.h>
int twice(int x) {
  return x * 2;
}
int main(int argc, char **argv) {
  int value = 7;
  int input = 0;
  printf("ready:%s\n", argv[1]); printf("argc=%d empty=<%s> last=<%s>\n", argc, argv[2], argv[3]); fflush(stdout);
  scanf("%d", &input);
  value += input;
  value = twice(value);
  printf("value=%d\n", value); fflush(stdout);
  return 0;
}
EOF
gcc -g3 -O0 "$test_dir/debug fixture.c" -o "$test_dir/debug fixture"
fpc -Fu"$source_root/linux-noi-lazarus" -FU"$test_dir" -FE"$test_dir" \
  "$source_root/tests/gdb-session-test.pas" > "$test_dir/compile.log" 2>&1 || {
  cat "$test_dir/compile.log" >&2
  exit 1
}
"$test_dir/gdb-session-test" "$test_dir/debug fixture.c" "$test_dir/debug fixture"
