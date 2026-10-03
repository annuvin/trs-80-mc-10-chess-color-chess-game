"""Generate book.inc: 2-move opening book (UCI prefixes -> candidate replies). Verified legal with python-chess."""
import chess
def sq(s): return ((int(s[1])-1)<<4)|(ord(s[0])-97)
W="e2e4 d2d4 g1f3 c2c4".split()
BOOK=[]
def add(prefix,replies):
    BOOK.append((prefix.split(),replies.split()))
# CPU as White: first move, then second move given Black's reply
add("", "e2e4 d2d4 g1f3 c2c4")
add("e2e4 e7e5","g1f3 f1c4 b1c3"); add("e2e4 c7c5","g1f3 b1c3"); add("e2e4 e7e6","d2d4"); add("e2e4 c7c6","d2d4")
add("e2e4 d7d5","e4d5"); add("e2e4 g8f6","e4e5 b1c3"); add("e2e4 d7d6","d2d4")
add("d2d4 d7d5","c2c4 g1f3"); add("d2d4 g8f6","c2c4 g1f3"); add("d2d4 e7e6","e2e4 c2c4"); add("d2d4 f7f5","g1f3 c2c4")
add("g1f3 d7d5","d2d4 c2c4"); add("g1f3 g8f6","c2c4 g2g3"); add("g1f3 c7c5","c2c4 e2e4"); add("g1f3 e7e6","d2d4 c2c4")
add("c2c4 e7e5","b1c3 g2g3"); add("c2c4 g8f6","b1c3 g1f3"); add("c2c4 c7c5","g1f3 b1c3"); add("c2c4 e7e6","d2d4 g1f3")
# CPU as Black: first reply, then second reply
add("e2e4","e7e5 c7c5 e7e6 c7c6"); add("d2d4","d7d5 g8f6"); add("g1f3","d7d5 g8f6"); add("c2c4","e7e5 g8f6")
add("e2e4 e7e5 g1f3","b8c6 g8f6"); add("e2e4 e7e5 b1c3","g8f6 b8c6"); add("e2e4 e7e5 f1c4","g8f6 f8c5"); add("e2e4 e7e5 d2d4","e5d4")
add("e2e4 c7c5 g1f3","b8c6 d7d6 e7e6"); add("e2e4 c7c5 b1c3","b8c6"); add("e2e4 e7e6 d2d4","d7d5"); add("e2e4 c7c6 d2d4","d7d5")
add("d2d4 d7d5 c2c4","e7e6 c7c6"); add("d2d4 d7d5 g1f3","g8f6"); add("d2d4 g8f6 c2c4","e7e6 g7g6"); add("d2d4 g8f6 g1f3","e7e6 g7g6")
add("g1f3 d7d5 d2d4","g8f6"); add("g1f3 d7d5 c2c4","e7e6"); add("g1f3 g8f6 c2c4","e7e6 g7g6"); add("g1f3 g8f6 g2g3","d7d5")
add("c2c4 e7e5 b1c3","g8f6"); add("c2c4 e7e5 g1f3","b8c6"); add("c2c4 e7e5 g2g3","g8f6"); add("c2c4 g8f6 b1c3","e7e5"); add("c2c4 g8f6 g1f3","e7e6")
lines=[]; n=0
for pre,reps in BOOK:
    b=chess.Board()
    for m in pre: b.push_uci(m)
    for r in reps:
        mv=chess.Move.from_uci(r); assert mv in b.legal_moves,(pre,r)
        bytes_=[len(pre)]+[sq(m[:2]) if i%2==0 else sq(m[2:4]) for m in pre for i in (0,1)]+[sq(r[:2]),sq(r[2:4])]
        lines.append('        .BYTE '+','.join('$%02X'%x for x in bytes_)+'    ; '+' '.join(pre)+(' ' if pre else '')+'-> '+r); n+=1
open('book.inc','w').write('BOOK:\n'+'\n'.join(lines)+'\n        .BYTE $FF\n')
print(n,'entries')
