# Compact native MC-10 chess - stock 4K build

This playable 6803 rewrite occupies 2,779 bytes, including its board and search workspace. It runs on an unexpanded MC-10. You play White; the computer plays Black.

This refinement uses features taken directly from the supplied Jennings/Rictor 6502 source:

- POINTS values: pawn 2, knight/bishop 4, rook 6, queen 10. King safety is handled separately.
- JANUS-style move counts: queen moves count twice, with capture-value totals and the highest available capture. Statistics use pseudo-legal moves and byte counters, as the original does in some analysis states.
- Quarter-weight mobility/capture totals and half-weight maximum captures, derived from STRATGY. These features are compared between the two sides for each candidate move.
- STRATGY's exact +2 positional conditions: own-relative $33/$34/$22/$25, or a non-king leaving the back rank. Coordinates are mapped to this build's conventional board orientation.
- A bounded capture extension: at the last normal search ply, a capture triggers one further capture-only reply, with material as the fallback. This addresses exchanges in the spirit of TREE.

It remains a native rewrite, not a faithful translation. The original JANUS state sequence, capture maxima at multiple TREE levels, pre-move counters, and STRATGY's exact byte arithmetic/carry sequence are not reproduced. This build combines a material negamax search with the strategic features above and clamps the strategic score below mate scores. It can choose different moves from Jennings' program.

The displayed piece letters and algebraic move entry remain adapted for the MC-10. Automatic queen promotion and explicit mate/stalemate messages are retained. The supplied source initializes OMOVE to $FF, disabling its opening table; this build does not add an opening book.

The earlier 16K version and the first compact release (microchess-4k-v1.zip) are retained separately.

## Load and play

Select a stock MC-10 with 4K RAM in your emulator. Mount microchess-4k.c10 as a cassette and use:

```basic
CLEAR 0,17407
CLOADM
EXEC 17408
```

Start cassette playback as required by your emulator. On real hardware, convert the C10 tape image using your usual cassette tooling. Hardware loading has not been tested.

Type a move such as E2E4 and press Enter. The computer replies automatically. Backspace or left arrow edits the move. N starts a new game, Q returns to BASIC, and S switches between one-ply and two-ply search. Two ply is the default. Repeating EXEC starts a new game.

The board uses letters for pieces, with the two sides displayed in different character video modes. Moves that leave your king in check are rejected. Checkmate and stalemate end the game. Pawns promote automatically to queens.

Castling, en passant, underpromotion, repetition, the fifty-move rule, and insufficient-material draws are not implemented.

## Stock 4K memory budget

| Address range | Bytes | Use |
| --- | ---: | --- |
| $4000-$41FF | 512 | Screen |
| $4200-$43FF | 512 | BASIC and reserved low RAM |
| $4400-$4EDA | 2,779 | Program, constants, board, search workspace |
| $4EDB-$4EFF | 37 | Spare |
| $4F00-$4FFF | 256 | Private machine-code stack |

Entry address is $4400 (17408). The loaded image includes all persistent workspace. CLEAR reserves the program area before loading. The program restores BASIC's stack on exit.

## Build

Telemark TASM 3.2b assembled this source with zero errors using TASM68.TAB:

```
tasm -68 -x3 -b -g3 microchess-4k.asm microchess-4k.bin microchess-4k-tasm.lst
py -3 pack-microchess-4k.py microchess-4k.bin microchess-4k.c10
```

build-microchess-4k.cmd runs these commands. TASM and its tables must be available in your environment; the assembler is not bundled. The packer uses Python 3's standard library. The raw BIN has no address header and loads at $4400.

## Verification

Tested in the MC10.js CPU/ROM emulator with RAM limited to $4FFF, including actual BASIC CLOADM cassette-bit loading, EXEC, a complete turn, and return to BASIC. A physical keyboard-matrix test used the ROM key scanner. No expansion RAM writes occurred; code/constants were protected against game writes.

Legal moves were compared with python-chess for the supported rule subset: the starting position, eight complete turns, pinned pieces, king safety, promotions, checkmate and stalemate. Seven further positions matched an independent Python implementation of the refined search, including capture extensions, strategic counts and board restoration. Mobility/capture statistics were checked independently, and 768 positional-bonus cases covered both colors, king/non-king moves, and starting ranks. Human and computer checkmate and human stalemate were exercised through the interface.

The deepest measured stack usage was 28 bytes of the 256-byte reserve. Estimated two-ply response times in the eight-turn test were 5.0-18.2 seconds at 0.89 MHz; these are CPU-cycle estimates, not measurements on hardware. One ply searches less deeply and responds faster. This is a modest chess opponent.

microchess-4k-preview.png is rendered from the tested emulator screen memory after E2E4 / E7E5.
