#!/usr/bin/env bash
# Exercise real GTK2/SynEdit shortcuts after build.sh; run under xvfb-run.
# Fixtures and preferences are isolated, and checks compare saved file bytes.
set -euo pipefail
app_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../linux-noi-lazarus" && pwd)
test_dir=$(mktemp -d)
app_pid=''
window=''
case_dir=''
export LANG=C.UTF-8

stop_case() {
  if [[ -n "$app_pid" ]]; then
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
    app_pid=''
  fi
}
cleanup() {
  local status=$?
  stop_case
  if [[ $status -eq 0 || ${KEEP_UI_FIXTURE:-0} != 1 ]]; then
    rm -rf -- "$test_dir"
  else
    echo "UI test fixture: $test_dir" >&2
  fi
}
trap cleanup EXIT
fail() {
  echo "FAIL: $*" >&2
  if [[ -n "$case_dir" && -f "$case_dir/runtime.log" ]]; then
    cat "$case_dir/runtime.log" >&2
  fi
  exit 1
}
alive() {
  kill -0 "$app_pid" 2>/dev/null || fail 'IDE exited unexpectedly'
}
press() {
  alive
  xdotool windowfocus "$window" key --clearmodifiers --delay 45 "$@"
  sleep 0.1
}
type_text() {
  alive
  xdotool type --clearmodifiers --delay 12 -- "$1"
  sleep 0.1
}
start_case() {
  stop_case
  case_dir="$test_dir/$1"
  mkdir -p "$case_dir/home/.config"
  printf '[Interface]\nLanguage=en\n' > "$case_dir/home/.config/dev-cpp-linux.ini"
  printf '%s' "$2" > "$case_dir/sample.cpp"
  local -a startup_files=("$case_dir/sample.cpp")
  if [[ $# -ge 3 ]]; then
    printf '%s' "$3" > "$case_dir/second.cpp"
    startup_files+=("$case_dir/second.cpp")
  fi
  env HOME="$case_dir/home" XDG_CACHE_HOME="$case_dir/home/.cache" \
    XDG_DATA_HOME="$case_dir/home/.local/share" \
    "$app_dir/dev-cpp-linux" --new-window "${startup_files[@]}" > "$case_dir/runtime.log" 2>&1 &
  app_pid=$!
  window=''
  for i in {1..100}; do
    window=$(xdotool search --all --onlyvisible --pid "$app_pid" --name 'dev-cpp-linux' 2>/dev/null | head -1) || true
    [[ -z "$window" ]] || break
    alive
    sleep 0.1
  done
  [[ -n "$window" ]] || fail 'main window did not appear'
  sleep 0.3
  xdotool windowfocus "$window"
  press ctrl+alt+e
}
expect_file() {
  local path=$1 expected=$2
  printf '%s' "$expected" > "$case_dir/expected.txt"
  for i in {1..100}; do
    if cmp -s "$path" "$case_dir/expected.txt"; then return 0; fi
    alive
    sleep 0.05
  done
  echo "Unexpected contents of $path:" >&2
  diff -u "$case_dir/expected.txt" "$path" >&2 || true
  fail 'saved file did not match the expected text'
}
save_expect() {
  press ctrl+s
  expect_file "$case_dir/sample.cpp" "$1"
}
wait_named_window() {
  local name=$1 found=''
  for i in {1..100}; do
    found=$(xdotool search --all --onlyvisible --pid "$app_pid" --name "$name" 2>/dev/null | head -1) || true
    if [[ -n "$found" ]]; then printf '%s\n' "$found"; return 0; fi
    alive
    sleep 0.1
  done
  fail "window did not appear: $name"
}
wait_message_window() {
  local found=''
  for i in {1..100}; do
    while read -r candidate; do
      if [[ -n "$candidate" && "$candidate" != "$window" ]]; then
        found=$candidate
        break
      fi
    done < <(xdotool search --all --onlyvisible --pid "$app_pid" --name 'dev-cpp-linux' 2>/dev/null || true)
    if [[ -n "$found" ]]; then printf '%s\n' "$found"; return 0; fi
    alive
    sleep 0.1
  done
  fail 'expected a save conflict message'
}
undo_case() {
  local name=$1 original=$2 changed=$3
  shift 3
  start_case "$name" "$original"
  press "$@"
  save_expect "$changed"
  press ctrl+z
  save_expect "$original"
  echo "PASS: $name changes text and one Undo restores it."
}
home_case() {
  local name=$1 original=$2 changed=$3
  shift 3
  start_case "$name" "$original"
  press "$@"
  type_text 'X'
  press Escape
  save_expect "$changed"
  press ctrl+z
  save_expect "$original"
  echo "PASS: $name places/replaces text correctly and one Undo restores it."
}

[[ -x "$app_dir/dev-cpp-linux" ]] || fail 'run linux-noi-lazarus/build.sh first'
base=$'one\ntwo\nthree\n'
if [[ ${1:-} != --save-as-conflict ]]; then
undo_case delete-line "$base" $'two\nthree\n' ctrl+Home ctrl+d
undo_case duplicate-line "$base" $'one\none\ntwo\nthree\n' ctrl+Home ctrl+e
undo_case delete-utf8-line $'中文\tone\nβtwo\nthree\n' $'βtwo\nthree\n' ctrl+Home ctrl+d
undo_case duplicate-utf8-line $'中文\tone\nβtwo\nthree\n' \
  $'中文\tone\n中文\tone\nβtwo\nthree\n' ctrl+Home ctrl+e
undo_case comment-lines "$base" $'//one\n//two\nthree\n' \
  ctrl+Home shift+Down shift+Down ctrl+period
undo_case uncomment-lines $'//one\n//two\nthree\n' "$base" \
  ctrl+Home shift+Down shift+Down ctrl+comma
undo_case toggle-comment "$base" $'//one\n//two\nthree\n' \
  ctrl+Home shift+Down shift+Down ctrl+slash
undo_case inline-comment "$base" $'/*one*/\ntwo\nthree\n' \
  ctrl+Home shift+End ctrl+semicolon
undo_case move-lines-down "$base" $'three\none\ntwo\n' \
  ctrl+Home shift+Down shift+Down ctrl+shift+Down
undo_case move-lines-up "$base" $'two\none\nthree\n' \
  ctrl+Home Down shift+Down ctrl+shift+Up

home_case home-after-up-selection $'    alpha\n    bravo\n' \
  $'    Xalpha\n    bravo\n' ctrl+Home Down Home shift+Up Home
home_case home-utf8-tab $' \t中文 alpha\n' $' \tX中文 alpha\n' \
  ctrl+Home End Home
home_case home-toggle $' \t中文 alpha\n' $'X \t中文 alpha\n' \
  ctrl+Home End Home Home
home_case home-reset-after-arrow $' \t中文 alpha\n' $' \tX中文 alpha\n' \
  ctrl+Home End Home Right Left Home
home_case shift-home-anchor $'    alpha\n    bravo\n' $'    X\n' \
  ctrl+Home Down End shift+Up shift+Home
home_case shift-home-toggle $'    alpha\n    bravo\n' $'X\n' \
  ctrl+Home Down End shift+Up shift+Home shift+Home

start_case bookmarks "$base"
press ctrl+Home Down ctrl+1 ctrl+End alt+1
type_text 'X'
press Escape
save_expect $'one\nXtwo\nthree\n'
press ctrl+z
save_expect "$base"
echo 'PASS: Ctrl+1 sets a bookmark and Alt+1 returns to its source location.'

start_case log-focus $'int main() { return 0; }\n'
press ctrl+End Return
type_text '// KEEP'
press Escape
saved_source=$'int main() { return 0; }\n// KEEP\n'
save_expect "$saved_source"
press F9
for i in {1..100}; do
  [[ ! -x "$case_dir/sample" ]] || break
  alive
  sleep 0.1
done
[[ -x "$case_dir/sample" ]] || fail 'log-focus fixture did not compile'
sleep 0.2
# Test Cut and Paste separately: cutting then pasting could hide a focus bug.
press ctrl+alt+l ctrl+a ctrl+c ctrl+x ctrl+alt+e
save_expect "$saved_source"
press ctrl+alt+l ctrl+v ctrl+alt+e
save_expect "$saved_source"
press ctrl+alt+l ctrl+z ctrl+alt+e
save_expect "$saved_source"
echo 'PASS: clipboard and Undo shortcuts in the read-only log do not alter source.'

start_case save-as-cancel $'first\n'
press ctrl+End Return
type_text '// unsaved'
press Escape ctrl+shift+s
dialog=$(wait_named_window '^Save$')
xdotool windowfocus "$dialog" key --clearmodifiers Escape
sleep 0.2
press ctrl+alt+e
save_expect $'first\n// unsaved\n'
echo 'PASS: cancelling Save As preserves the original document identity and edits.'
fi

start_case save-as-open-path $'first\n' $'second\n'
press ctrl+alt+e ctrl+Tab ctrl+Home
type_text 'X'
press Escape
save_expect $'Xfirst\n'
press ctrl+z
save_expect $'first\n'
press ctrl+End Return
type_text '// unsaved'
press Escape ctrl+shift+s
dialog=$(wait_named_window '^Save$')
sleep 0.3
xdotool windowfocus "$dialog" key --clearmodifiers alt+n
sleep 0.1
xdotool key --clearmodifiers ctrl+a
xdotool type --clearmodifiers --delay 3 -- "$case_dir/second.cpp"
xdotool key --clearmodifiers Return
message=$(wait_message_window)
echo "Save conflict dialog: $(xdotool getwindowname "$message")"
xdotool windowfocus "$message" key --clearmodifiers Return
sleep 0.2
press ctrl+alt+e
save_expect $'first\n// unsaved\n'
expect_file "$case_dir/second.cpp" $'second\n'
echo 'PASS: Save As cannot overwrite another open buffer or change the original identity.'

echo 'PASS: UI interaction regression suite completed.'
