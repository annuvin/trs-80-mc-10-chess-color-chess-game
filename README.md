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
- A single legality rule everywhere (no FAST/ORIGINAL toggle any more): moves
  that leave your king in check are rejected, mate and stalemate are reported

Needs the **16K RAM expansion**. 4,785 bytes at $5000, variables at $7C00,
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
| N | new game (back to colour choice) |
| Q | quit: cold-starts BASIC again |

Castling: move the king two squares (`E1G1`, `E1C1`; `E8G8`, `E8C8` as Black).
En passant: type the capturing pawn's move to the empty square (`E5D6`).
Promotion: the pawn always becomes a queen; there is no underpromotion.

**Q is a cold start**, not a return to your BASIC program. CG3 mode takes over
the video RAM at $4000-$4BFF, which is where BASIC keeps its own variables, so
there is nothing to return to.

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
  bonus (`CBONUS` in the source, +12). In self-play against the unmodified
  version it castled in 13 of 24 games and scored the same (4 wins each, the
  rest drawn).

## Not included

Underpromotion, the 50-move and repetition draw rules, automatic
insufficient-material draws, takeback and hints. The supplied opening book is
still unused.

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
- 85 full games played through the real keyboard matrix, as both colours: after
  every move the program's board matches python-chess; illegal entries are
  refused; mate and stalemate are reported correctly. The games included human
  and computer castling, en passant, promotions, and the computer being mated
- The finished cassette image loads through BASIC's own `CLEAR`/`CLOADM`/`EXEC`
  and comes out byte-identical to the .bin; `Q` returns to the BASIC banner

**Not tested on real hardware** (no physical MC-10, real cassette playback or
real VDG). The video mode value ($24 at $BFFF: CG3 with the green/yellow/blue/red
palette) and the keyboard matrix reads follow the emulator's model, so a
real-machine difference there would be the first place to look.

MicroChess (c) 1996-2002 Peter Jennings, peterj@benlo.com. The original's
copyright notice and distribution terms still apply.
