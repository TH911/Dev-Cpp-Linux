#!/usr/bin/env python3
"""Extract the actual New Look image list used by Windows Dev-C++ 5.11.

The standalone Images/newlook BMPs differ from the compiled DataFrm image list.
Decode the Delphi ImageList color/mask planes, preserving visible RGB pixels.
Usage: python3 tools/import-upstream-icons.py /path/to/orwell-5.11
"""
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parent.parent
ICONS = {
    'newproj':0, 'newsrc':1, 'resrc':2, 'opnproj':4, 'clrhist':5,
    'save':6, 'saveas':7, 'saveall':8, 'closefl':9, 'print':10, 'close':11,
    'stop-debug':11, 'export':12, 'undo':13, 'redo':14, 'cut':15, 'copy':16,
    'paste':17, 'insert':18, 'addbook':19, 'gobook':20, 'search':21,
    'srchrep':22, 'goto':24, 'addsrc':25, 'remsrc':26, 'projopt':27,
    'compile':28, 'rebuild':30, 'run':31, 'debug':32, 'comprun':33,
    'compopt':34, 'envopt':35, 'editopt':36, 'tools':37, 'screen':38,
    'next':39, 'previous':40, 'compres':43, 'packman':48, 'syntcheck':49,
    'clsall':50,
}

def extract(upstream):
    text = (upstream/'Source/DataFrm.dfm').read_text(encoding='cp1252')
    match = re.search(r'object MenuImages_NewLook:.*?Bitmap = \{(.*?)\}', text, re.S)
    data = bytes.fromhex(match[1])
    assert data[:2] == b'IL' and struct.unpack_from('<H',data,4)[0] == 54
    color = 28
    width,height = struct.unpack_from('<ii',data,color+18)
    assert (width,height,struct.unpack_from('<H',data,color+28)[0]) == (64,240,32)
    color_pixels = color+struct.unpack_from('<I',data,color+10)[0]
    mask = color_pixels+width*height*4
    assert data[mask:mask+2] == b'BM'
    assert struct.unpack_from('<H',data,mask+28)[0] == 1
    mask_pixels = mask+struct.unpack_from('<I',data,mask+10)[0]
    mask_stride = (width+31)//32*4
    def bitmap(index):
        pixels = bytearray()
        for row in range(15,-1,-1):
            y=height-1-(index//4*16+row)
            for col in range(16):
                x=index%4*16+col
                transparent = data[mask_pixels+y*mask_stride+x//8] & (128>>(x%8))
                at=color_pixels+(y*width+x)*4
                pixels.extend(b'\xff\x00\xff' if transparent else data[at:at+3])
        return (b'BM'+struct.pack('<IHHI',54+len(pixels),0,0,54)+
                struct.pack('<IiiHHIIiiII',40,16,16,1,24,0,len(pixels),0,0,0,0)+pixels)
    output=ROOT/'linux-noi-lazarus/icons'
    hashes={}
    for name,index in ICONS.items():
        value=bitmap(index);(output/(name+'.bmp')).write_bytes(value)
        hashes[name+'.bmp']={'index':index,'sha256':hashlib.sha256(value).hexdigest()}
    (ROOT/'tools/upstream-icon-manifest.json').write_text(json.dumps({
        'reference':'Orwell Dev-C++ 5.11, commit 0e4d598b172efd7df97b7ecc941d6aa08340cd70',
        'source':'Source/DataFrm.dfm:MenuImages_NewLook',
        'source_sha256':hashlib.sha256(data).hexdigest(),'icons':hashes},indent=2)+'\n')
    print('Extracted',len(hashes),'original image-list icons')

if __name__=='__main__':extract(Path(sys.argv[1]))
