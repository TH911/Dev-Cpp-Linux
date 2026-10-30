#!/usr/bin/env python3
"""Extract the original class-browser image list, including its transparency mask."""
import hashlib,json,re,struct,sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
text=(Path(sys.argv[1])/'Source/DataFrm.dfm').read_text(encoding='cp1252')
data=bytes.fromhex(re.search(r'object ClassImages:.*?Bitmap = \{(.*?)\}',text,re.S)[1])
assert data[:2]==b'IL' and struct.unpack_from('<H',data,4)[0]==12
color=28
width,height=struct.unpack_from('<ii',data,color+18)
assert (width,height,struct.unpack_from('<H',data,color+28)[0])==(64,64,32)
pixels=color+struct.unpack_from('<I',data,color+10)[0]
mask=pixels+width*height*4
assert data[mask:mask+2]==b'BM'
mask_pixels=mask+struct.unpack_from('<I',data,mask+10)[0]
stride=(width+31)//32*4
manifest={'reference':'Orwell Dev-C++ 5.11, commit 0e4d598b172efd7df97b7ecc941d6aa08340cd70','source':'Source/DataFrm.dfm:ClassImages','source_sha256':hashlib.sha256(data).hexdigest(),'icons':{}}
for index in range(12):
    raw=bytearray()
    for row in range(15,-1,-1):
        y=height-1-(index//4*16+row)
        for col in range(16):
            x=index%4*16+col
            transparent=data[mask_pixels+y*stride+x//8] & (128>>(x%8))
            at=pixels+(y*width+x)*4
            raw.extend(b'\xff\x00\xff' if transparent else data[at:at+3])
    bmp=b'BM'+struct.pack('<IHHI',54+len(raw),0,0,54)+struct.pack('<IiiHHIIiiII',40,16,16,1,24,0,len(raw),0,0,0,0)+raw
    name=f'browser-{index}.bmp'
    (root/'linux-noi-lazarus/icons'/name).write_bytes(bmp)
    manifest['icons'][name]={'index':index,'sha256':hashlib.sha256(bmp).hexdigest()}
(root/'tools/upstream-sidebar-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Extracted 12 original class-browser icons; watch rows reuse MenuImages_NewLook[21] (search.bmp)')
