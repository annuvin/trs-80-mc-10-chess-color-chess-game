# MicroChess for the MC-10, 16K edition

A rewrite of the earlier MC-10 port that uses the 16K RAM expansion instead of
fighting to fit in 4K. It keeps Peter Jennings' MicroChess search and
evaluation, but the program around it is new:

- **Castling and en passant** (plus automatic queen promotion), built into the
  move generator, so the computer uses them too
- **Play either colour.** Press **B** on the title screen and the board flips so
  you are at the bottom, with the computer moving first
- **128x96 four-colour graphics** (CG3 mode): 12x11 piece sprites, a small
  built-in font, rank/file labels, and a dithered highlight on the last move
  and on the square you are typing from
- **Draw rules:** threefold repetition, the 50-move rule (100 plies without a
  pawn move or capture) and bare-minimum material (K vs K, or K plus one minor
  piece vs K) end the game automatically
- **Takeback and hint** keys (see below)
- A single legality rule everywhere (no FAST/ORIGINAL toggle any more): moves
  that leave your king in check are rejected, mate and stalemate are reported

Needs the **16K RAM expansion**. 7,648 bytes at $5000, variables at $7C00,
stack at $8FFF.

## Load and play

```
CLEAR 100,20479
CLOADM            (play microchess-mc10-16k.c10)
EXEC 20480
```

Press **W** or **B** to choose your colour. Type a move as four characters and
press **Enter**, for example `E2E4`.

| Key | Action |
|---|---|
| A-H, 1-8 | type a move (file, rank, file, rank) |
| Enter | play it (illegal moves are refused, nothing changes) |
| CTRL-A or `0` | erase the last character |
| BREAK | clear the whole entry |
| T | take back: undoes your last move and the computer's reply (up to 16 plies; works after mate or a draw too) |
| / | hint: shows the move the computer would play for you, as `H:E2E4` |
| N | new game (back to colour choice) |
| Q | quit: cold-starts BASIC again |

Castling: move the king two squares (`E1G1`, `E1C1`; `E8G8`, `E8C8` as Black).
En passant: type the capturing pawn's move to the empty square (`E5D6`).
Promotion: the pawn always becomes a queen; there is no underpromotion.

**Q is a cold start**, not a return to your BASIC program. CG3 mode takes over
the video RAM at $4000-$4BFF, which is where BASIC keeps its own variables, so
there is nothing to return to.

## Opening book

The computer plays its first two moves from a small book (79 lines covering
1.e4, 1.d4, 1.Nf3 and 1.c4 and the usual replies), choosing at random among
the lines that match, so games don't all start alike. Book moves are instant
and are only played if they are legal in the position; once you leave the
book, or after its second move, the search takes over. The book is generated
by `tools/gen_book.py` (every line is checked with python-chess); edit the
lines there and rebuild.

## Draws

The game stops with a red message: **DRAW! REPEAT** (same position, same side
to move, for the third time), **DRAW! 50 MOVE RULE**, or **DRAW! NO MATERIAL**.
Mate and stalemate take priority. Positions are compared by a 32-bit hash that
includes castling rights; en passant is ignored (it can't matter, since a pawn
move resets the repetition window). "No material" is deliberately narrow: K+N
vs K and K+B vs K, but not two bishops, so it never ends a game that could
still be won.

## Hidden self-play mode

On the title screen press **S** (it isn't shown). A setup screen lets you tune
the two sides before the engine plays itself, game after game:

| Row | Setting | Default |
|---|---|---|
| 1, 2 | A: castling bonus, centre/development bonus (0-60) | 12, 2 |
| 3, 4 | B: castling bonus, centre/development bonus (0-60) | 12, 2 |
| 5 | score jitter, a random 0..n added to each root move's score (0-10) | 0 |
| 6 | opening book on/off | on |
| 7 | swap A/B colours every game | off |

Press **1-7** to pick a row, **,** and **.** to lower/raise it, **Enter** to
start, **BREAK** to go back. With swap off, A plays White and B plays Black;
with swap on they alternate, so the tallies compare the two settings fairly.
The panel shows **A:** wins for setting A, **B:** wins for B, **D:** draws and
**P:** the current ply (tallies stop at 255). Games also end by the draw rules
above, or at 250 plies. Hold **BREAK** (or **Q**) until the current move
finishes to stop. With jitter 0 and the book off every game is identical, so
use some jitter or the book (the book's choice is reseeded each game).

## Speed

The computer's reply is much faster than the earlier port: about **2 seconds**
for typical opening moves, around **6-9 seconds** on average, and up to about
**50 seconds** in the worst positions I measured. (The old FAST mode took 27
seconds for its first reply.) These are emulator cycle counts at the MC-10's
0.894 MHz clock, not a stopwatch on real hardware.

## What changed in the engine

Same algorithm, rewritten as straight 6803 code on a 0x88 board:

- Jennings' search is intact: the same move-generation order, the same
  mobility/capture counters, the same STRATGY scoring and check/mate test.
  With castling and en passant switched off, it picks the **same move as a
  Python model of the old engine in all 190 positions tested**, and that model
  matches the old binary in all 140 positions tested.
- Moves are checked by looking for attacks on the king, instead of the old
  nested reply generation. The old engine's "king in check" test was the
  slowest part.
- Castling is generated only when the king and rook haven't moved, the squares
  between are empty, and the king is not in check, doesn't pass through check
  and doesn't land in check.
- The old port dropped the zero-page wrap for its capture-tree counters, so
  several of them were always zero. The new engine does what the 6502 original
  does, which makes it play a little differently from the old port.
- The original evaluation gives no reason to castle, so castling gets a small
  bonus (+12 by default; the self-play setup screen can change it). In
  self-play against the unmodified version it castled in 13 of 24 games and
  scored the same.

## Not included

Underpromotion (pawns always become queens), difficulty levels, sound.

## Files

- `microchess-mc10-16k.c10` is the cassette image; `.bin` is the raw program
  (load address and start at $5000)
- `microchess-mc10-16k.asm` is the full source (assembles with tasm6801 or
  Telemark TASM: `tasm6801 -sym microchess-mc10-16k.asm`); `.sym` and `.lst`
  are the symbols and listing
- `tools/microchess_bin_to_c10.py` wraps a .bin into a cassette image;
  `tools/gfx_art.py` + `gen_gfx.py` hold the piece sprites and font as editable
  ASCII art and regenerate the data tables
- `previews/` are screens rendered from emulator memory

## How it was tested

All in a headless emulator (Mike Tinnes' MC-10 core with the stock ROM), with
**python-chess as the referee**:

- Legal move lists for 311 positions (standard perft test positions plus random
  game positions with castling rights, en passant and promotions) match exactly,
  and perft to depth 3 matches python-chess's counts (promotions limited to
  queens on both sides)
- Full games played through the real keyboard matrix as both colours, after
  every move the program's board matches python-chess; illegal entries are
  refused; mate and stalemate are reported correctly. The games included human
  and computer castling, en passant, promotions and the computer being mated
  (the earlier 85-game run, plus 30 more with the draw code in)
- Draws: repetition, 50-move and no-material endings were driven from set-up
  positions and fired on exactly the same ply as python-chess. Testing caught a
  weak first position hash that confused two different rook placements; it was
  replaced before release
- Takeback and hint: 12 games up to 16 plies deep and 10 played to the end,
  both colours: after each takeback the board, side to move, clock and the
  U:/C: texts match python-chess; hints are always legal and change nothing;
  takeback works after mate
- Self-play: 40 consecutive games with jitter and colour swap: every move legal,
  board identical after every ply, A/B/D tallies correct for each game
- The finished cassette image loads through BASIC's own `CLEAR`/`CLOADM`/`EXEC`
  and comes out byte-identical to the .bin; `Q` returns to the BASIC banner

**Not tested on real hardware** (no physical MC-10, real cassette playback or
real VDG). The video mode value ($24 at $BFFF: CG3 with the green/yellow/blue/red
palette) and the keyboard matrix reads follow the emulator's model, so a
real-machine difference there would be the first place to look.

MicroChess (c) 1996-2002 Peter Jennings, peterj@benlo.com. The original's
copyright notice and distribution terms still apply.
