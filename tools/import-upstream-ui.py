#!/usr/bin/env python3
"""Import Orwell Dev-C++ 5.11 themes and decode its Windows language files.

Usage: python3 tools/import-upstream-ui.py /path/to/orwell-5.11
The input is the source tree documented in docs/DEVCPP-5.11-PARITY.md.
No network access or third-party Python modules are required.
"""
import argparse
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
LOCALES = [
    ('Chinese', 'zh', 'gbk'), ('English', 'en', 'cp1252'),
    ('Bulgarian', 'bg', 'cp1251'), ('Catalan', 'ca', 'cp1252'),
    ('Chinese_TC', 'zh_TW', 'big5'), ('Croatian', 'hr', 'cp1250'),
    ('Czech', 'cs', 'cp1250'), ('Danish', 'da', 'cp1252'),
    ('Dutch', 'nl', 'cp1252'), ('Estonian', 'et', 'cp1252'),
    ('French', 'fr', 'cp1252'), ('Galego', 'gl', 'cp1252'),
    ('German', 'de', 'cp1252'), ('Greek', 'el', 'cp1253'),
    ('Hebrew', 'he', 'cp1255'), ('Hungarian', 'hu', 'cp1250'),
    ('Italian', 'it', 'cp1252'), ('Japanese', 'ja', 'cp932'),
    ('Korean', 'ko', 'cp949'), ('Latvian', 'lv', 'cp1257'),
    ('Norwegian', 'nb', 'cp1252'), ('Polish', 'pl', 'cp1250'),
    ('Portuguese', 'pt_BR', 'cp1252'), ('Romanian', 'ro', 'cp1250'),
    ('Russian', 'ru', 'cp1251'), ('Slovak', 'sk', 'cp1250'),
    ('Slovenian', 'sl', 'cp1250'), ('Spanish', 'es_419', 'cp1252'),
    ('SpanishCastellano', 'es', 'cp1252'), ('SpanishColombia', 'es_CO', 'cp1252'),
    ('Swedish', 'sv', 'cp1252'), ('Turkish', 'tr', 'cp1254'),
    ('Ukrainian', 'uk', 'cp1251'),
]


NATIVE_NAMES = {'zh': '简体中文', 'en': 'English', 'bg': 'Български', 'ca': 'Català', 'zh_TW': '繁體中文', 'hr': 'Hrvatski', 'cs': 'Čeština', 'da': 'Dansk', 'nl': 'Nederlands', 'et': 'Eesti', 'fr': 'Français', 'gl': 'Galego', 'de': 'Deutsch', 'el': 'Ελληνικά', 'he': 'עברית', 'hu': 'Magyar', 'it': 'Italiano', 'ja': '日本語', 'ko': '한국어', 'lv': 'Latviešu', 'nb': 'Norsk bokmål', 'pl': 'Polski', 'pt_BR': 'Português (Brasil)', 'ro': 'Română', 'ru': 'Русский', 'sk': 'Slovenčina', 'sl': 'Slovenščina', 'es_419': 'Español (Latinoamérica)', 'es': 'Español (Castellano)', 'es_CO': 'Español (Colombia)', 'sv': 'Svenska', 'tr': 'Türkçe', 'uk': 'Українська'}

def pascal(value):
    return "'" + value.replace("'", "''") + "'"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('upstream', type=Path)
    args = parser.parse_args()
    upstream = args.upstream
    version = (upstream / 'Source/Version.pas').read_text(encoding='cp1252')
    if not re.search(r"DEVCPP_VERSION\s*=\s*'5\.11'", version):
        parser.error('Expected the Orwell Dev-C++ 5.11 reference tree')
    data = (upstream / 'Source/DefaultFiles.rc').read_text(encoding='cp1252')
    values = {int(k): v for k, v in re.findall(r'(\d+),\s*"([^"\r\n]*)"', data)}
    # Keep the existing port's first four menu positions and default preference.
    themes = [('Classic Plus', 1000), ('Twilight', 2000), ('Visual Studio', 4000),
              ('Obsidian', 7000), ('Classic', 0), ('Ocean', 3000),
              ('Borland', 5000), ('Matrix', 6000), ('GSS Hacker', 8000),
              ('Oblivion', 9000), ('PlasticCodeWrap', 10000)]
    out = ['{ Generated from Orwell 5.11 Source/DefaultFiles.rc; GPL-2.0-or-later. }',
           'ThemeNames: array[0..EditorThemeCount - 1] of string =',
           '  (' + ', '.join(pascal(n) for n, _ in themes) + ');',
           'ThemeData: array[0..EditorThemeCount - 1, 1..22] of string = (']
    for index, (_, base) in enumerate(themes):
        out.append('  (' + ',\n   '.join(pascal(values[base + n]) for n in range(1, 23)) +
                   ')' + (',' if index + 1 < len(themes) else ''))
    out.append(');\n')
    (ROOT / 'linux-noi-lazarus/editor_theme_data.inc').write_text('\n'.join(out))
    languages = ROOT / 'linux-noi-lazarus/languages'
    languages.mkdir(exist_ok=True)
    records = []
    for filename, code, encoding in LOCALES:
        text = (upstream / 'Lang' / (filename + '.lng')).read_bytes().decode(encoding)
        text = text.replace('\r\n', '\n').replace('\r', '\n')
        assert '\ufffd' not in text, filename
        (languages / (filename + '.lng')).write_text(text, encoding='utf-8')
        match = re.search(r'^Lang=(.*)$', text, re.M)
        name = match.group(1).strip() if match else filename
        name = NATIVE_NAMES[code]
        records.append('  (Code: ' + pascal(code) + '; Name: ' + pascal(name) +
                       '; FileName: ' + pascal(filename + '.lng') + ')')
    (ROOT / 'linux-noi-lazarus/language_data.inc').write_text(
        '{ Generated from Orwell 5.11 Lang/*.lng; original translations, UTF-8. }\n' +
        'Languages: array[0..UiLanguageCount - 1] of TLanguageInfo = (\n' +
        ',\n'.join(records) + '\n);\n')
    # The 5.11 Hebrew catalog still uses Bloodshed 4.9.9.2 numeric IDs.
    # Match semantic constant names, never coincidentally equal numeric IDs.
    legacy = json.loads((ROOT / 'tools/legacy-lang-symbols.json').read_text())
    current = {name: int(number) for name, number in re.findall(
        r'^\s*(ID_\w+)\s*=\s*(\d+)\s*;',
        (upstream / 'Source/LangIDs.inc').read_text(encoding='cp1252'), re.M)}
    remap = {current[name]: old for name, old in legacy['symbols'].items() if name in current}
    (languages / 'legacy_ids.ini').write_text(
        '; Generated by tools/import-upstream-ui.py; GPL-2.0-or-later\n' +
        '; Bloodshed source SHA256: ' + legacy['source_sha256'] + '\n' +
        '[Hebrew.lng]\n' + '\n'.join(f'{new}={old}' for new, old in sorted(remap.items())) + '\n')
    print(f'Imported {len(themes)} themes and {len(records)} UTF-8 language files')


if __name__ == '__main__':
    main()
