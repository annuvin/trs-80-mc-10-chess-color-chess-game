"""Package the stock-4K MC-10 build as a cassette; Python 3 standard library."""
from pathlib import Path
import sys
def block(t,d):return bytes((0x55,0x3c,t,len(d)))+d+bytes(((t+len(d)+sum(d))&255,0x55))
p=Path(sys.argv[1] if len(sys.argv)>1 else 'microchess-4k.bin')
out=Path(sys.argv[2]) if len(sys.argv)>2 else p.with_suffix('.c10')
d=p.read_bytes()
if not 0<len(d)<=0xb00:raise SystemExit('Image must fit $4400-$4EFF, leaving $4F00-$4FFF for the stack.')
leader=b'\x55'*128
tape=leader+block(0,b'UCHESS4K'+bytes((2,0,0,0x44,0,0x44,0)))+leader
for i in range(0,len(d),255):tape+=block(1,d[i:i+255])
out.write_bytes(tape+block(255,b''));print(f'{out}: {len(d)} bytes at $4400')
