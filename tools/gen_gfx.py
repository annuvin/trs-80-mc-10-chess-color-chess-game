from gfx_art import ART, ORDER, FONT
def sprites():
    out=[]
    for k in ORDER:
        rows=[r for r in ART[k].strip('\n').split('\n')]
        assert len(rows)==11, (k,len(rows))
        for r in rows:
            assert len(r)==12,(k,r)
            for b in range(3):
                v=0
                for p in range(4):
                    v=(v<<2)|(3 if r[b*4+p]=='#' else 0)
                out.append(v)
    return out
def font():
    out=[]
    for c in range(0x20,0x60):
        ch=chr(c); g=FONT.get(ch,"0"*15)
        for r in range(5):
            bits=g[r*3:r*3+3]
            v=0
            for p in range(3): v=(v<<2)|(3 if bits[p]=='1' else 0)
            v<<=2
            out.append(v)
    return out
def fmt(name,data,per=12):
    s=name+':\n'
    for i in range(0,len(data),per):
        s+='        .BYTE '+','.join('$%02X'%x for x in data[i:i+per])+'\n'
    return s
if __name__=='__main__':
    open('gfx.inc','w').write(fmt('SPRITES',sprites(),33)+fmt('FONT',font(),15))
