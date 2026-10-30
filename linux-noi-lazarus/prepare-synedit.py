#!/usr/bin/env python3
"""Isolate the Lazarus 2.0.6 SynEdit startup fix in ignored build output.

The installed SynEdit source/license remain intact. Only InitSynDefaultFont is
replaced: every IDE editor receives its actual font from editor_preferences.
"""
from pathlib import Path
import os
import re
import subprocess
root=Path(__file__).resolve().parent
version=subprocess.check_output(['lazbuild','--version'],text=True).strip()
if not re.match(r'^2\.0\.6(?:[+\s-]|$)',version):
    raise SystemExit('This startup compatibility patch requires Lazarus 2.0.6.')
candidates=[Path(os.environ.get('LAZARUS_DIR','/usr/lib/lazarus/2.0.6')),
            Path('/usr/share/lazarus/2.0.6')]
source=next((p/'components/synedit' for p in candidates if (p/'components/synedit/synedit.pp').is_file()),None)
if source is None:
    raise SystemExit('Install lazarus-src-2.0 (SynEdit sources) before building.')
original=(source/'synedit.pp').read_text()
pattern=r'procedure InitSynDefaultFont;\s*begin\s*if SynDefaultFontName.*?(?=\{ TCustomSynEdit \})'
replacement="""procedure InitSynDefaultFont;
begin
  { Dev-C++: avoid enumerating all Pango font families before main(). }
  SynDefaultFontName := 'Monospace';
  SynDefaultFontHeight := -13;
end;

"""
patched,count=re.subn(pattern,replacement,original,count=1,flags=re.S)
if count!=1:
    raise SystemExit('Unexpected SynEdit source; refusing an unverified patch.')
out=root/'lib/synedit-fast';out.mkdir(parents=True,exist_ok=True)
for name,content in [('synedit.pp',patched),('synedit.inc',(source/'synedit.inc').read_text())]:
    target=out/name
    if not target.exists() or target.read_text()!=content:target.write_text(content)
