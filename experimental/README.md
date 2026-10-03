# Microchess Expanded for the Tandy MC-10

Native Motorola 6803 assembly based on the supplied Peter Jennings Microchess source adapted by Daryl Rictor. Requires the **16K RAM expansion (20K total RAM)**. The separate compact 4K version is unchanged.

## Loading

Mount `microchess-expanded.c10` in the emulator's cassette drive. From a fresh BASIC prompt enter:

```basic
CLEAR 0,17919
CLOADM
EXEC 20480
```

Start cassette playback when required by your emulator. The cassette loads and executes at $5000. The raw `.bin` also loads at $5000 in emulators with a binary loader; run CLEAR first. This CLEAR value reserves the graphics backup and other runtime workspaces below the program.

You play White; Black replies automatically. Enter coordinates such as `E2E4`, then Enter. Backspace corrects input. Moves leaving your king in check are rejected.

| Key | Action |
| --- | --- |
| N | New game |
| Q | Return to BASIC, restoring its screen/workspace |
| R | Switch MODERN/CLASSIC rules and restart |
| S | Cycle QUICK, DEEP, ORIGINAL in MODERN mode |
| L | Toggle the work limit for DEEP/ORIGINAL in MODERN mode |
| V | Claim an available repetition or 50-move draw |
| I | Show instructions; I or Enter returns to the board |
| T | Switch between piece graphics and letters |

The sidebar separates current settings from actions. `R CLASSIC` means press R to switch to CLASSIC and restart. **QUICK is the default**, showing `1 PLY` and `S DEEP`. The S label always names the next mode. DEEP/ORIGINAL show `LIMIT ON` or `LIMIT OFF`, with L's next action below it. QUICK omits L because it does not use this limit. CLASSIC toggles DEEP/ORIGINAL with S, displays UNLIMITED, and omits L. I HELP is displayed near the top. T LETTERS or T GRAPHICS at the bottom names the next piece view. Help preserves the game and any partly entered move. LAST identifies Black's last move.

Promote with a fifth letter: `A7A8Q`, `A7A8R`, `A7A8B`, or `A7A8N`, then Enter. Four coordinates alone select a queen. After entering a promotion move, Q/R/N are interpreted as promotion choices.

For an intended-move draw claim, enter the legal move and press **V instead of Enter**. A successful claim ends the game without playing that move. With empty input, V checks the current position. Black claims an available draw on its own turn.

## Rules and search modes

MODERN is the default. It adds castling, en passant, all four promotions, checkmate/stalemate, threefold/50-move claims, automatic fivefold/75-move draws, and common insufficient-material positions. Checkmate takes precedence over the 75-move rule. Repetition records exact boards, castling rights, side to move, and an en passant target only when a legal capture exists.

Insufficient-material detection covers bare kings, king plus a single minor against king, and bishops-only positions with every bishop on the same square color. There is no general dead-position solver for unusual blocked positions, no chess clocks, and no draw-agreement control. It therefore does not cover every tournament adjudication rule.

- **QUICK**: uses the opening book, then examines every legal move at one ply. Scores captures, promotions, development/centralization, castling, and whether the destination is attacked. It is deliberately simple and can miss tactics. It does not reproduce Jennings' original search or guarantee stronger play.
- **DEEP**: Jennings' capture-tree search and scoring, with some reply-legality checks skipped during analysis for speed. Played moves remain legal. It explores beyond QUICK's one ply, but is not a configurable fixed-depth search.
- **ORIGINAL**: Jennings' search with the original analysis checks. This is the slowest option and closest to the supplied source's engine behavior.

The advanced modes retain Jennings' JANUS/TREE/STRATGY/GO, translated into native 6803 instructions with explicit 6502 arithmetic/flag semantics. A native attack detector replaces trial attack generation. This is not a 6502 interpreter or the compact version's replacement negamax engine.

CLASSIC preserves the supplied source's rules and starting-slot layout, mapping file coordinates so the visible board remains conventional. It disables the added special moves and draw rules and always permits unbounded search. For the closest tested source behavior, use CLASSIC and ORIGINAL. The supplied adaptation disables its historical opening sequence; CLASSIC follows that choice.

Faithfulness is algorithmic, not an identical historical executable: the CKMATE X/Y comparison bug is fixed, zero-page indexed addresses wrap correctly, the interface is new, and a legal fallback is used if the historical evaluator fails to select a move. MODERN's extra rules can change analysis.

DEEP/ORIGINAL in MODERN mode default to a limit of 4096 generated-move analysis events. At the limit, the complete root position is restored and the best completed candidate, or a legal fallback, is played. L permits unrestricted search. CLASSIC ignores the limit. QUICK always enumerates its legal root moves and does not use this analysis-event limit.

## Opening book

QUICK in MODERN mode has eight compact lines, each up to **two full moves (four plies)**:

```text
1. e4 e5 2. Nf3 Nc6
1. e4 e5 2. Bc4 Nf6
1. e4 e5 2. Nc3 Nf6
1. e4 e5 2. d4 exd4
1. d4 d5 2. c4 e6
1. d4 d5 2. Nf3 Nf6
1. c4 e5 2. Nc3 Nf6
1. Nf3 d5 2. d4 Nf6
```

It matches the moves actually played, verifies the expected board, piece types and castling rights, and checks the proposed move's legality. A deviation leaves the book for the rest of that game. After four plies, QUICK searches normally. The book also works for both colors in self-play. DEEP/ORIGINAL bypass it, preserving the historical evaluator for comparisons. New game resets the book and preserves the selected search setting.

## Measured speed

These are whole-turn CPU-cycle estimates, including input processing and drawing, at **0.89 MHz**. They are not real-hardware measurements or guarantees for every position.

| Mode / move | Approximate time |
| --- | --- |
| QUICK, E2E4 and book reply | 1.31 seconds |
| QUICK, G1F3 and second book reply | 1.27 seconds |
| QUICK, E2E3 outside the book | 2.14 seconds |
| QUICK, F1C4 after the book ends | 2.50 seconds |
| DEEP, E2E4 and reply | 11.34 seconds |
| ORIGINAL, E2E4 and reply | 21.26 seconds |

The previous default opening turn took about 23 seconds. Besides the new default evaluator and book, this build speeds up text drawing with byte-level glyph updates, uses a temporary square-occupancy map for attack checks, and generates only the requested piece's moves when validating typed coordinates. Advanced modes remain substantially slower; unrestricted searches can take considerably longer.

## Graphics and memory

The display uses the native **128 x 96 monochrome bitmap** with outlined White pieces, filled Black pieces, checkerboard squares, coordinates, last-move markings, and a check indicator. Press **T** to switch between graphics and larger 5x7 piece letters: **P** pawn, **N** knight, **B** bishop, **R** rook, **Q** queen, **K** king. White uses black letters on a white tile; Black uses white letters on a black tile. Both sides use uppercase letters. Graphics start as the default when executing the program; the selected view persists across new games and rules changes. The knight now has a horse-head silhouette and the bishop a narrower mitre, making the two more distinct.

The toggle preserves the position, move input, book/history, search settings, and paused self-play turn. It repaints occupied squares and its sidebar action, without clearing the screen. The renderer compares cached piece/color/highlight/style keys and paints changed squares. Captures, en passant, castling, promotions, and removal of previous highlights are included. Settings/footer text update without clearing their regions; unchanged pixel bytes are not written. Full-screen clearing is reserved for a new game and returning from help. The native keyboard scanner debounces keys and suppresses held-key repeats.

The bitmap temporarily overlays BASIC's workspace. All 1536 bytes are saved before switching modes and restored before returning to BASIC.

| Area | Address / size |
| --- | --- |
| Bitmap and original BASIC workspace | $4000-$45FF, 1536 bytes |
| Runtime BASIC backup, reserved by CLEAR | $4600-$4BFF, 1536 bytes |
| Square appearance cache | $4C00-$4C3F, 64 bytes |
| Trial undo storage | $4C40-$4E3F, 512 bytes |
| Virtual data stack | $4E40-$4E7F, 64 bytes |
| Virtual 6502 memory, board, book/search scratch and root snapshots | $4E80-$4F7F, 256 bytes |
| Promotion flags and piece values | $4F80-$4FBF, 64 bytes |
| Temporary attack occupancy map | $4FC0-$4FFF, 64 bytes |
| Loaded program and workspaces | $5000-$8DFB, **15,868 bytes** |
| Spare space before native stack | $8DFC-$8DFF, **4 bytes** |
| Private native stack | $8E00-$8FFF, 512 bytes |

The loaded image includes 151 exact repetition records and engine workspaces. Other runtime areas below $5000 are reserved separately, not stored in the binary. The promotion/value root snapshot now uses an unused part of the virtual-memory page; the disabled historical opening table is omitted from the image. These reclaim space for the display option without reducing repetition or stack capacity. The loading commands reserve them all. Almost all available memory is allocated; further sizeable additions require reorganizing storage, reducing another allocation, or using a larger expansion. Reserved stack space is not counted as free RAM.

## Hidden engine-testing mode

**Z** starts computer-versus-computer play from the current position; Z pauses and resumes. It is intentionally absent from the sidebar and help. SELF PLAY WHITE/BLACK identifies the next color. PAUSED preserves the position and next side. Both colors use the selected search mode, including the book in QUICK/MODERN, and the same rules and applicable work-limit settings. The board remains in White's orientation.

Keys are checked between plies. During a search, hold Z until the current move finishes to pause; Q similarly returns to BASIC at the next input window. Unrestricted searches can delay this. A debounce window between moves recognizes held keys before another search starts. Release a key before pressing it again.

N stops self-play and starts an ordinary game. R switches rules and starts an ordinary game. I opens help and then resumes the previous mode. S and L change settings. Mate, stalemate, and detected/claimable draws stop self-play; both computer colors claim repetition/50-move draws in MODERN mode. CLASSIC retains its historical limitations.

Paused with White next, you may enter a normal human move; Black replies as usual, leaving self-play paused with White next. Paused with Black next, human White moves are rejected; Z resumes with Black, or N starts over.

The included `selfplay-test.pgn` records a tested **49-ply default QUICK game**, using the book and castling for both colors, ending in a repetition draw. Every move, resulting board, castling rights, effective en passant target, halfmove counter, and final result was checked against python-chess. This is a test sample, not a comprehensive strength assessment.

## Build

Use **Telemark TASM**, with `TASM68.TAB` available through its normal table path or TASMTABS. Borland's x86 assembler also named TASM is a different program.

```text
tasm -68 -x3 -b -g3 microchess-expanded.asm microchess-expanded.bin microchess-expanded-tasm.lst
py -3 pack-expanded.py microchess-expanded.bin microchess-expanded.c10
```

`build-expanded.cmd` performs these steps from its own directory and needs TASM and Python 3 on PATH. The packer uses only Python's standard library. The included TASM listing records zero errors; an independent assembler produced identical bytes.

## Validation and limits

Automated tests ran the native binary in a headless MC-10 emulator with the stock ROM and 20K RAM limit:

- Legal moves matched python-chess in 23 positions, including castling, pinned en passant, discovered checks and capture promotions. Initial-position perft depth 3 was 8902; Kiwipete depth 2 was 2039.
- Actual UI moves covered castling/en passant, all promotions, current/intended draw claims, mate/stalemate and mate precedence at 150 halfmoves. Draw identity, material and counters were checked separately.
- All eight book lines passed an independent legality oracle. Deviations, altered boards/types/rights and trial-history isolation were checked. QUICK selected legal moves and restored trial state in all 23 rule fixtures.
- Four original-search fixtures matched a corrected 6502 reference in selected move, board and counters. These are finite differential tests, not proof of identical choices in every position. Earlier arithmetic tests checked 262,144 ADC/SBC result/flag cases and interrupt masking.
- Fifteen forced search-limit exits restored state/stacks and returned legal moves. Complex searches reached the default limit naturally, including both-color self-play tests.
- Memory guards found no writes to protected code/tables or beyond installed RAM. Tested native-stack peak use was 54 bytes; undo storage 80/512 bytes; data stack 5/64 bytes.
- All 708 tested font character/offset combinations matched expected pixels and preserved adjacent pixels. Incremental frames matched fresh full renders for castling, en passant, promotions and settings changes. An unchanged draw performed zero framebuffer writes; typing changed only its input glyph.
- Physical keyboard input, held-key suppression, sidebar labels, help/game/input preservation, self-play pause/resume, both-color claims, reset, quit and subsequent BASIC commands passed. Native physical T toggles once while held and toggles again after release/repress.
- All six large letter glyphs and both side colors were checked against independent pixel patterns, including CLASSIC coordinates and promotions. Display toggles preserve game/input/book/history, repaint occupied squares only, and round-trip to the original frame. Letter-mode castling, en passant, promotions, and paused self-play passed.
- Actual BASIC CLOADM consumed the cassette through emulated tape-bit input, loading bytes identical to the binary, followed by EXEC, a full turn and BASIC return.

Preview PNGs come from the emulator's actual framebuffer. **Real MC-10 hardware has not yet been tested.**

## Files and attribution

The archive contains ASM, BIN, C10 cassette, TASM listing, build script, cassette packer, graphics/letters/help previews, this README and a verified self-play PGN. Keep earlier builds to compare engine behavior.

MicroChess (c) 1996-2002 Peter Jennings, peterj@benlo.com. The supplied source was adapted by Daryl Rictor in August 2002. Author notices remain in source and binary. The supplied source requests Peter Jennings' permission before redistributing modified copies to others; this package is the user's private modified copy.
