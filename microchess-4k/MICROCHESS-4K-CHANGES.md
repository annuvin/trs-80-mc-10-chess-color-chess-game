# Refinement from the first compact build

The first release used 1/3/3/5/9 material values and an invented pawn/knight tie preference. The refined release uses the supplied source's 2/4/4/6/10 values, its exact positional bonus conditions, queen-weighted mobility and capture statistics, and one additional capture reply at the search frontier.

Size increases from 2,531 to 2,779 bytes. Stock 4K RAM remains sufficient: the private stack still has 256 bytes, with 37 bytes spare between the image and stack. In the tested eight-turn game, estimated two-ply thinking time increases from 4-11 seconds to 5-18 seconds; the move sequence also changes.

The refinement is closer in evaluation features, but does not reproduce the original JANUS/TREE state machine or STRATGY byte arithmetic. The separate 16K implementation remains the closer translation of the supplied source.

Loading and controls are unchanged. Telemark TASM 3.2b reports zero errors; its binary matches the independently assembled binary. The stock-RAM, move legality, keyboard, cassette loading, mate/stalemate, promotion, and BASIC-return tests pass. Independent scoring and positional/statistics checks cover the new behavior.
