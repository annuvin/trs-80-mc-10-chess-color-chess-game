"""Wrap a raw MC-10 Microchess binary at $5000 in a cassette. Python 3."""
from pathlib import Path
import sys

def block(kind, data):
    return bytes((0x55,0x3C,kind,len(data)))+data+bytes(((kind+len(data)+sum(data))&255,0x55))

src=Path(sys.argv[1] if len(sys.argv)>1 else 'microchess-mc10.bin')
dst=Path(sys.argv[2]) if len(sys.argv)>2 else src.with_suffix('.c10')
data=src.read_bytes()
if not 0<len(data)<=0x3000:
    raise SystemExit('Program must fit $5000-$7FFF; $8000-$8FFF is reserved for the native stack.')
leader=b'\x55'*128
header=b'MICROCHS'+bytes((2,0,0,0x50,0,0x50,0))
tape=leader+block(0,header)+leader
for i in range(0,len(data),255):tape+=block(1,data[i:i+255])
tape+=block(255,b'')
dst.write_bytes(tape)
print(f'{dst}: {len(data)} bytes, load/execute $5000')
