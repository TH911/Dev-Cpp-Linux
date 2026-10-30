#!/usr/bin/env bash
# Run under xvfb-run after build.sh. Uses the real editor and terminal.
set -euo pipefail
app_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../linux-noi-lazarus" && pwd)
test_dir=$(mktemp -d)
test_home="$test_dir/home"
source_dir="$test_dir/中文 source's"
run_dir="$test_dir/run data's"
mkdir -p "$test_home/.config" "$source_dir" "$run_dir"
ide_pid=''
holding_pid=''
app_sequence=0
instance_cache=''
cleanup() {
  local status=$?
  [[ -z "$ide_pid" ]] || kill "$ide_pid" 2>/dev/null || true
  [[ -z "$holding_pid" ]] || kill "$holding_pid" 2>/dev/null || true
  [[ -z "$ide_pid" ]] || wait "$ide_pid" 2>/dev/null || true
  [[ -z "$holding_pid" ]] || wait "$holding_pid" 2>/dev/null || true
  if [[ $status -eq 0 && ${KEEP_RUNTIME_FIXTURE:-0} != 1 ]]; then
    rm -rf -- "$test_dir"
  else
    echo "Runtime test fixture: $test_dir" >&2
  fi
}
trap cleanup EXIT
export LANG=C.UTF-8
cat > "$test_dir/program.cpp" <<'CPP'
#include <fstream>
#include <string>
#include <unistd.h>
int main(int argc, char **argv) {
    if (argc > 1 && std::string(argv[1]) == "--hold") {
        std::ofstream("holding.txt") << "started\n";
        sleep(30);
        return 0;
    }
    std::ofstream output("args.txt");
    for (int i = 1; i < argc; ++i)
        output << std::string(argv[i]).size() << ':' << argv[i] << '\n';
    output.close();
    std::ofstream("ran.txt") << "ran\n";
}
CPP
cp "$test_dir/program.cpp" "$source_dir/args.cpp"
write_config() {
  cat > "$test_home/.config/dev-cpp.ini" <<EOF
[Interface]
Language=en
[Compiler]
Cpp=$1
[Run]
Parameters=--name "two words" "" "\$(touch shell-marker)" "a'b" ";touch shell-marker-2;" "\`touch shell-marker-3\`" "中文 空格" "one\path"
WorkingDirectory=$run_dir
EOF
}
write_config g++
fail() {
  echo "FAIL: $*" >&2
  cat "$test_dir/runtime.log" >&2 || true
  if [[ -n ${RUNTIME_SCREENSHOT_DIR:-} ]]; then
    cp "$RUNTIME_SCREENSHOT_DIR/Xvfb_screen0" "$RUNTIME_SCREENSHOT_DIR/failure.xwd" 2>/dev/null || true
  fi
  exit 1
}
compare_args() {
  if ! cmp -s "$1" "$2"; then
    echo "Expected arguments ($2):" >&2
    cat "$2" >&2
    echo "Actual arguments ($1):" >&2
    cat "$1" >&2 || true
    diff -u "$2" "$1" >&2 || true
    fail "$3"
  fi
}
wait_file() {
  for i in {1..150}; do
    [[ ! -s "$1" ]] || return 0
    kill -0 "$ide_pid" 2>/dev/null || fail 'IDE exited unexpectedly'
    sleep 0.1
  done
  fail "timed out waiting for $1"
}
start_app() {
  app_sequence=$((app_sequence + 1))
  instance_cache="$test_home/.cache/$app_sequence"
  env HOME="$test_home" XDG_CACHE_HOME="$instance_cache" \
    "$app_dir/dev-cpp" --new-window "$1" > "$test_dir/runtime.log" 2>&1 &
  ide_pid=$!
  window=''
  for i in {1..100}; do
    window=$(xdotool search --onlyvisible --pid "$ide_pid" --name 'Dev-C\+\+' 2>/dev/null | head -1) || true
    [[ -z "$window" ]] || break
    kill -0 "$ide_pid" 2>/dev/null || fail 'IDE failed to start'
    sleep 0.1
  done
  [[ -n "$window" ]] || fail 'main window missing'
  sleep 0.3
  xdotool windowfocus "$window"
  xdotool key ctrl+alt+e
}
stop_app() {
  kill "$ide_pid" 2>/dev/null || true
  wait "$ide_pid" 2>/dev/null || true
  ide_pid=''
}
open_file() {
  env HOME="$test_home" XDG_CACHE_HOME="$instance_cache" \
    "$app_dir/dev-cpp" --forward-only "$1" || fail 'could not forward source to the running IDE'
  sleep 0.3
  xdotool windowfocus "$window" key ctrl+alt+e
}

start_app "$source_dir/args.cpp"
xdotool key F11
wait_file "$run_dir/ran.txt"
cat > "$test_dir/expected-args" <<'EOF'
6:--name
9:two words
0:
21:$(touch shell-marker)
3:a'b
22:;touch shell-marker-2;
22:`touch shell-marker-3`
13:中文 空格
8:one\path
EOF
compare_args "$run_dir/args.txt" "$test_dir/expected-args" 'quoted/empty/literal argv differed'
rm -f "$run_dir/ran.txt" "$run_dir/args.txt"
xdotool windowfocus "$window" key F10
wait_file "$run_dir/ran.txt"
compare_args "$run_dir/args.txt" "$test_dir/expected-args" 'F10 changed quoted/empty/literal argv'
[[ ! -e "$run_dir/shell-marker" ]] || fail 'program arguments were interpreted by a shell'
[[ ! -e "$run_dir/shell-marker-2" ]] || fail 'quoted punctuation was interpreted by a shell'
[[ ! -e "$run_dir/shell-marker-3" ]] || fail 'quoted backticks were interpreted by a shell'
echo 'PASS: F10/F11 preserve empty argv, spaces, apostrophes, Chinese, backslashes, and literal shell metacharacters.'

# The currently running old inode must not prevent publishing a new build.
(cd "$run_dir" && exec "$source_dir/args" --hold) &
holding_pid=$!
wait_file "$run_dir/holding.txt"
old_inode=$(stat -c %i "$source_dir/args")
xdotool windowfocus "$window" key F9
for i in {1..150}; do
  [[ $(stat -c %i "$source_dir/args") == "$old_inode" ]] || break
  sleep 0.1
done
[[ $(stat -c %i "$source_dir/args") != "$old_inode" ]] || fail 'rebuild could not replace a running executable'
kill -0 "$holding_pid" || fail 'rebuild terminated the old running program'
kill "$holding_pid" 2>/dev/null || true
wait "$holding_pid" 2>/dev/null || true
holding_pid=''
echo 'PASS: a running executable can be atomically rebuilt without stopping the old process.'

# A failed compilation preserves the prior public file but F10 must reject it.
old_sum=$(sha256sum "$source_dir/args")
xdotool windowfocus "$window" key ctrl+alt+e ctrl+a
xdotool type --clearmodifiers --delay 5 'this is not valid C++'
xdotool key ctrl+s F9
sleep 0.7
[[ $(sha256sum "$source_dir/args") == "$old_sum" ]] || fail 'failed compile replaced the valid executable'
rm -f "$run_dir/ran.txt" "$run_dir/args.txt"
xdotool windowfocus "$window" key F10
sleep 0.3
[[ ! -e "$run_dir/ran.txt" ]] || fail 'F10 ran a stale target after compilation failed'
dialog_count=$(xdotool search --onlyvisible --pid "$ide_pid" --name 'Dev-C\+\+' | wc -l)
[[ $dialog_count -ge 2 ]] || fail 'F10 did not explain that compilation is required'
echo 'PASS: failed compilation preserves the old file and blocks F10 with an explanation.'
stop_app

# Project CommandLine and a relative project working folder override global settings.
project_dir="$test_dir/project"
mkdir -p "$project_dir/project data"
cp "$test_dir/program.cpp" "$project_dir/main.cpp"
cat > "$project_dir/example.dev" <<EOF
[Project]
Name=example
Type=1
IsCpp=1
UnitCount=1
CommandLine="project two" ""
RunWorkingDirectory=project data
[Unit1]
FileName=$project_dir/main.cpp
Compile=1
EOF
start_app "$project_dir/example.dev"
xdotool key F11
wait_file "$project_dir/project data/ran.txt"
printf '11:project two\n0:\n' > "$test_dir/expected-project-args"
compare_args "$project_dir/project data/args.txt" "$test_dir/expected-project-args" 'project arguments or run directory were ignored'
echo 'PASS: project argv and relative working directory override global settings.'

# Keeping the project open must not lend its settings to an unrelated source.
cp "$test_dir/program.cpp" "$test_dir/isolation.cpp"
rm -f "$run_dir/ran.txt" "$run_dir/args.txt"
open_file "$test_dir/isolation.cpp"
xdotool key F11
wait_file "$run_dir/ran.txt"
compare_args "$run_dir/args.txt" "$test_dir/expected-args" 'project settings leaked into an unrelated source'
echo 'PASS: an unrelated source uses global run settings while a project remains open.'
stop_app

# Compilation runs in an isolated session. F10 is blocked while busy; Abort
# must stop both the compiler wrapper and its waiting child.
cp "$test_dir/program.cpp" "$source_dir/args.cpp"
cat > "$test_dir/compiler wrapper.sh" <<'SH'
#!/usr/bin/env bash
root=$(dirname -- "$0")
printf '%s\n' "$$" > "$root/compiler.pid"
sleep 30 &
child=$!
printf '%s\n' "$child" > "$root/compiler-child.pid"
wait "$child"
exec /usr/bin/g++ "$@"
SH
chmod +x "$test_dir/compiler wrapper.sh"
write_config "$test_dir/compiler wrapper.sh"
rm -f "$run_dir/ran.txt"
start_app "$source_dir/args.cpp"
xdotool key F9
wait_file "$test_dir/compiler-child.pid"
xdotool key F10
sleep 0.2
[[ ! -e "$run_dir/ran.txt" ]] || fail 'F10 ran a target while the compiler was active'
xdotool key alt+x a
pid_is_live() {
  local pid="$1" stat_line='' state=''
  [[ -r "/proc/$pid/stat" ]] || return 1
  read -r stat_line < "/proc/$pid/stat" || return 1
  stat_line=${stat_line##*) }
  state=${stat_line%% *}
  [[ "$state" != Z ]]
}
compiler_pid=$(cat "$test_dir/compiler.pid")
child_pid=$(cat "$test_dir/compiler-child.pid")
for i in {1..100}; do
  if ! pid_is_live "$compiler_pid" && ! pid_is_live "$child_pid"; then break; fi
  sleep 0.1
done
if pid_is_live "$compiler_pid" || pid_is_live "$child_pid"; then
  fail 'Abort left a compiler or child process running'
fi
echo 'PASS: literal/empty argv, run folders, project parameters, atomic rebuild, failed-target guard, compile reentrancy, session cancellation.'
