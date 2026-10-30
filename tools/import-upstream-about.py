#!/usr/bin/env python3
"""Reproduce About resources and text from the immutable Orwell 5.11 source."""
from pathlib import Path
import hashlib,json,re,sys
root=Path(__file__).resolve().parent.parent
upstream=Path(sys.argv[1]);dfm=(upstream/'Source/AboutFrm.dfm').read_text(encoding='cp1252');pas=(upstream/'Source/AboutFrm.pas').read_text(encoding='cp1252')
def expression(value):
    result=''
    for token in re.findall(r"'(?:''|[^'])*'|#\d+",value):
        result+=chr(int(token[1:])) if token[0]=='#' else token[1:-1].replace("''", "'")
    return result
license_block=re.search(r'object txtLicense:.*?Lines.Strings = \((.*?)\)\s*ReadOnly =',dfm,re.S)
assert license_block,'original GPL memo must be present'
lines=[];continuing=False
for row in license_block[1].splitlines():
    row=row.strip()
    if not row:continue
    if continuing:lines[-1]+=expression(row)
    else:lines.append(expression(row))
    continuing=row.endswith('+')
license_text='\n'.join(lines)+'\n'
assert 'GNU GENERAL PUBLIC LICENSE' in license_text and '675 Mass Ave' in license_text and 'END OF TERMS AND CONDITIONS' in license_text
message=re.search(r'MessageText\s*=\s*(.*?);',pas,re.S)
authors=expression(message[1]);assert 'Johan Mes' in authors and 'Thomas Thron' in authors
manifest={'reference':'Orwell Dev-C++ 5.11, commit 0e4d598b172efd7df97b7ecc941d6aa08340cd70','resources':{}}
for object_name,target in [('imgBanner','about-banner'),('imgDonate','about-donate'),('btnAuthors','about-authors')]:
    block=re.search(r'object '+object_name+r':.*?(?:Picture|Glyph).Data = \{(.*?)\}',dfm,re.S)
    assert block,object_name
    raw=bytes.fromhex(block[1]);data=raw[raw.index(b'BM'):]
    assert len(data)==int.from_bytes(data[2:6],'little')
    path=root/'linux-noi-lazarus/icons'/(target+'.bmp');path.write_bytes(data)
    manifest['resources'][path.name]=hashlib.sha256(data).hexdigest()
def constant(name,text):
    return '  '+name+': string =\n'+ ' +\n'.join("    '"+row.replace("'","''")+"'"+('+#10' if i<len(text.split('\n'))-1 else '') for i,row in enumerate(text.split('\n')))+';\n'
module='''{ Generated from original AboutFrm.dfm / AboutFrm.pas by tools/import-upstream-about.py.
  Orwell Dev-C++ 5.11, 0e4d598b172efd7df97b7ecc941d6aa08340cd70.
  Original copyright Bloodshed Software; GPL-2.0-or-later. }
unit about_original;
{$mode objfpc}{$H+}
interface
const
'''+constant('OriginalGPLText',license_text)+constant('OriginalAuthorsText',authors.replace('\r\n','\n'))+'''implementation
end.
'''
(root/'linux-noi-lazarus/about_original.pas').write_text(module)
manifest['license_sha256']=hashlib.sha256(license_text.encode()).hexdigest();manifest['authors_sha256']=hashlib.sha256(authors.replace('\r\n','\n').encode()).hexdigest()
(root/'tools/upstream-about-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Extracted original banner, donation/authors glyphs, full GPL and',len(authors.splitlines()),'author lines')
