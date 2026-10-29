#!/usr/bin/env bash
# Run with xvfb-run on a clean Ubuntu 20.04 test machine after build.sh.
set -euo pipefail
app_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../linux-noi-lazarus" && pwd)
test_dir=$(mktemp -d)
test_home="$test_dir/home"
sample_dir="$test_dir/中文 path"
mkdir -p "$test_home" "$sample_dir" "$test_dir/cli"
ide_pid=''
cleanup() {
  if [[ -n "$ide_pid" ]]; then
    kill "$ide_pid" 2>/dev/null || true
    wait "$ide_pid" 2>/dev/null || true
  fi
  rm -rf -- "$test_dir"
}
trap cleanup EXIT
export LANG=C.UTF-8

cat > "$sample_dir/hello.cpp" <<'CPP'
#include <fstream>
#include <iostream>
int main() {
    std::ofstream("ran.txt") << "NOI_GUI_RUN_OK\n";
    std::cout << "NOI_GUI_RUN_OK\n";
}
CPP
printf 'int main() { return 0; }\n' > "$sample_dir/second.cpp"

launch() {
  env HOME="$test_home" XDG_CACHE_HOME="$test_home/.cache" \
    XDG_DATA_HOME="$test_home/.local/share" bash "$app_dir/launch.sh" "$@"
}
fail() {
  echo "FAIL: $*" >&2
  cat "$test_dir/runtime.log" >&2
  exit 1
}
wait_file() {
  for i in {1..100}; do
    [[ ! -s "$1" ]] || return 0
    kill -0 "$ide_pid" 2>/dev/null || fail 'IDE exited unexpectedly'
    sleep 0.1
  done
  fail "timed out waiting for $1"
}

launch --new-window "$sample_dir/hello.cpp" > "$test_dir/runtime.log" 2>&1 &
ide_pid=$!
window=''
for i in {1..100}; do
  window=$(xdotool search --onlyvisible --name 'Dev-C\+\+' 2>/dev/null | head -1) || true
  [[ -z "$window" ]] || break
  kill -0 "$ide_pid" 2>/dev/null || fail 'IDE failed to start'
  sleep 0.1
done
[[ -n "$window" ]] || fail 'main window did not appear'
# Wait for the remaining startup callbacks before sending shortcuts.
sleep 0.5
xdotool getwindowname "$window"
xdotool windowfocus "$window" key F9
wait_file "$sample_dir/hello"
# The linker creates its output before it finishes writing and marks it executable.
compiled_ok=false
for i in {1..100}; do
  if [[ -x "$sample_dir/hello" ]] && \
     [[ "$(cd "$test_dir/cli" && "$sample_dir/hello" 2>/dev/null)" == NOI_GUI_RUN_OK ]]; then
    compiled_ok=true
    break
  fi
  kill -0 "$ide_pid" 2>/dev/null || fail 'IDE exited during compilation'
  sleep 0.1
done
[[ "$compiled_ok" == true ]] || fail 'compiled executable produced unexpected output'
xdotool windowfocus "$window" key F10
wait_file "$sample_dir/ran.txt"
[[ "$(cat "$sample_dir/ran.txt")" == NOI_GUI_RUN_OK ]] || fail 'F10 run failed'
rm "$sample_dir/ran.txt"
xdotool windowfocus "$window" key F11
wait_file "$sample_dir/ran.txt"

launch "$sample_dir/second.cpp"
sleep 0.5
[[ $(xdotool search --onlyvisible --name 'Dev-C\+\+' | wc -l) -eq 1 ]] || \
  fail 'file forwarding opened an extra main window'
xdotool windowfocus "$window" key F9
wait_file "$sample_dir/second"
for i in {1..100}; do
  [[ ! -x "$sample_dir/second" ]] || break
  kill -0 "$ide_pid" 2>/dev/null || fail 'IDE exited during the second compilation'
  sleep 0.1
done
[[ -x "$sample_dir/second" ]] || fail 'second compilation did not finish'
echo 'PASS: source open, F9 compile, F10 run, F11 compile/run, UTF-8 and spaced paths, single-instance forwarding.'
