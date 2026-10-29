#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
export LANG=C.UTF-8
# Keep the virtual desktop alive when a regression closes/restarts its last app.
python3 tests/launcher-migration-test.py
python3 - <<'PY'
from pathlib import Path
import re
version = Path('VERSION').read_text().strip()
source = Path('linux-noi-lazarus/app_version.pas').read_text()
assert re.search(r"AppVersion\s*=\s*'" + re.escape(version) + r"'", source), 'Application and package versions differ'
assert Path('linux-noi-lazarus/PORT_REVISION').read_text().strip() == 'v' + version, 'Legacy revision marker differs from application version'
PY
[[ $(fpc -iV) == 3.0.4 ]]
[[ $(gcc -dumpfullversion) == 9.3.0 ]]
[[ $(g++ -dumpfullversion) == 9.3.0 ]]
lazbuild --version | grep '^2\.0\.6'
gdb --version | sed -n '1p' | grep '9\.1'
bash linux-noi-lazarus/build.sh
env -u DISPLAY linux-noi-lazarus/dev-cpp --version | grep -F "$(cat VERSION)"
env -u DISPLAY bash linux-noi-lazarus/run.sh --version > "$test_dir/source-version.log" 2>&1
grep -Fx "dev-cpp $(cat VERSION)" "$test_dir/source-version.log"
if grep -F 'v1.0.0' "$test_dir/source-version.log"; then
  echo 'Source launcher printed an obsolete release version.' >&2
  exit 1
fi

mkdir -p "$test_dir/documents" "$test_dir/profiles"
fpc -Fulinux-noi-lazarus -FU"$test_dir/documents" -FE"$test_dir/documents" \
  tests/document-files-test.pas > "$test_dir/documents-build.log" 2>&1 || {
  cat "$test_dir/documents-build.log" >&2; exit 1;
}
"$test_dir/documents/document-files-test" "$test_dir/files"
fpc -Fulinux-noi-lazarus -FU"$test_dir/profiles" -FE"$test_dir/profiles" \
  tests/compiler-profiles-test.pas > "$test_dir/profiles-build.log" 2>&1 || {
  cat "$test_dir/profiles-build.log" >&2; exit 1;
}
"$test_dir/profiles/compiler-profiles-test"
bash tests/runtime-support-smoke.sh
timeout 60s bash tests/gdb-session-smoke.sh
for name in editor-actions editor-themes ui-language command-state classic-layout editor-preferences brackets shortcuts; do
  lazbuild --widgetset=gtk2 "tests/$name-test.lpi" > "$test_dir/$name-build.log" 2>&1 || {
    cat "$test_dir/$name-build.log" >&2; exit 1;
  }
  timeout 60s xvfb-run -a -s "-screen 0 1280x1024x24 -noreset" "linux-noi-lazarus/lib/$name-test"
done
for name in noi-linux ui-interaction runtime-ui gdb-ui preferences-ui input-colors-ui about-ui project-ui; do
  timeout 180s xvfb-run -a -s "-screen 0 1280x1024x24 -noreset" bash "tests/$name-smoke.sh"
done

CLASSIC_UI_ARTIFACT_DIR="$PWD/dist/ui-preview" timeout 90s xvfb-run -a -s "-screen 0 1920x1080x24 -noreset" bash tests/classic-ui-smoke.sh

timeout 60s xvfb-run -a -s "-screen 0 1280x1024x24 -noreset" python3 tests/startup-smoke.py

CLASSIC_UI_ARTIFACT_DIR="$PWD/dist/ui-preview" timeout 90s xvfb-run -a -s "-screen 0 1920x1080x24 -noreset" bash tests/tools-ui-smoke.sh

CLASSIC_UI_ARTIFACT_DIR="$PWD/dist/ui-preview" timeout 100s xvfb-run -a -s "-screen 0 1920x1080x24 -noreset" bash tests/editor-options-ui-smoke.sh

timeout 120s xvfb-run -a -s "-screen 0 1600x1000x24 -noreset" bash tests/brackets-ui-smoke.sh

timeout 150s xvfb-run -a -s "-screen 0 1600x1000x24 -noreset" bash tests/save-shortcuts-ui-smoke.sh

timeout 120s xvfb-run -a -s "-screen 0 1600x1000x24 -noreset" bash tests/tab-order-ui-smoke.sh
