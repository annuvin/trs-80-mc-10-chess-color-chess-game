; Compact native MC6803 chess for a stock 4K MC-10.
; Inspired by Peter Jennings' MicroChess and the supplied 6502 source.
; Native 0x88 board / legal moves / negamax with Jennings-derived features.
; Original piece values, queen-weighted mobility, capture counts and bonus.
; Not a translation of the original JANUS/TREE/STRATGY state machine.
; MicroChess (c) 1996-2002 Peter Jennings, peterj@benlo.com
; Telemark: tasm -68 -x3 -b -g3 microchess-4k.asm microchess-4k.bin
; CLEAR 0,17407 : CLOADM : EXEC 17408. Stock MICROCOLOR BASIC ROM.
; Piece codes: P=1 N=2 B=3 R=4 Q=5 K=6; black adds 8.
; FRAME offsets: type=0 from=1 to=2 piece=3 captured=4 dir=5 limit=6,
; table=7..8 best=9 found=10 depth=11 bonus=12 bestfrom=13 bestto=14.
        .MSFIRST
        .ORG $4400
START:  TPA
        STAA OLDCC
        STS OLDSP
        SEI
        LDS #$4FFF
PRIVATE_STACK:
        LDAA #2
        STAA LEVEL
        JSR NEWGAME
UI_MAIN:
        JSR DRAW
UI_WAIT:
        JSR $F883
        TSTA
        BEQ UI_WAIT
        CMPA #$61
        BCS UI_KEY
        SUBA #$20
UI_KEY: CMPA #$51
        BNE UI_NQ
UI_QUIT:
        LDX #$4000
        STX $4280
        LDS OLDSP
        LDAA OLDCC
        TAP
        RTS
UI_NQ:  CMPA #$4E
        BNE UI_NN
        JSR NEWGAME
        BRA UI_MAIN
UI_NN:  CMPA #$53
        BNE UI_NS
        LDAA #3
        SUBA LEVEL
        STAA LEVEL
        CLR INPUTLEN
        BRA UI_MAIN
UI_NS:  CMPA #8
        BEQ UI_BACK
        CMPA #$15
        BEQ UI_BACK
        CMPA #$0D
        BNE UI_CHAR
        JMP UI_ENTER
UI_BACK:
        LDAA INPUTLEN
        BEQ UI_WAIT
        DEC INPUTLEN
        JSR DRAW_INPUT
        BRA UI_WAIT
UI_CHAR:
        LDAB INPUTLEN
        CMPB #4
        BCC UI_WAIT
        LDX #INPUTBUF
        ABX
        STAA 0,X
        INC INPUTLEN
        JSR DRAW_INPUT
        BRA UI_WAIT

NEWGAME:
        LDX #BOARD
        CLRA
NG_ZERO:
        STAA 0,X
        INX
        CPX #BOARD+128
        BNE NG_ZERO
        CLRB
NG_PIECES:
        LDX #INITIAL
        ABX
        LDAA 0,X
        LDX #BOARD
        ABX
        STAA 0,X
        ORAA #8
        STAA $70,X
        LDAA #1
        STAA $10,X
        LDAA #9
        STAA $60,X
        INCB
        CMPB #8
        BNE NG_PIECES
        LDAA #4
        STAA KINGW
        LDAA #$74
        STAA KINGB
        CLR INPUTLEN
        CLR GAMEOVER
        CLR HASLAST
        CLR SIDE
        LDX #FRAMES
        STX FRAMEPTR
        RTS

UI_ENTER:
        LDAA GAMEOVER
        BEQ UE_GO
        JMP UI_WAIT
UE_GO:  LDAA INPUTLEN
        CMPA #4
        BNE UE_BAD
        LDX #INPUTBUF
        JSR PARSE_SQUARE
        BCS UE_BAD
        STAA WANTFROM
        LDX #INPUTBUF+2
        JSR PARSE_SQUARE
        BCS UE_BAD
        STAA WANTTO
        CLR SIDE
        LDAA #1
        STAA MODE
        JSR GEN
        LDX FRAMEPTR
        LDAA 10,X
        BEQ UE_BAD
        JSR MAKE
        CLR INPUTLEN
        JSR DRAW
        LDX #MSG_THINK
        JSR MESSAGE
        LDAA #8
        STAA SIDE
        LDAA #2
        STAA MODE
        JSR GEN
        LDX FRAMEPTR
        LDAA 10,X
        BNE UE_SEARCH
        JSR CHECK
        TSTA
        BEQ UE_DRAW
        LDAA #1
        BRA UE_FINISH
UE_BAD:
        CLR INPUTLEN
        JSR DRAW_INPUT
        LDX #MSG_BAD
        JSR MESSAGE
        JMP UI_WAIT
UE_SEARCH:
        CLR MODE
        LDX FRAMEPTR
        LDAA LEVEL
        STAA 11,X
        JSR SEARCH
        LDX FRAMEPTR
        LDAA 13,X
        STAA 1,X
        STAA LASTFROM
        LDAB 13,X
        LDAA 14,X
        STAA 2,X
        STAA LASTTO
        LDX #BOARD
        ABX
        LDAA 0,X
        LDX FRAMEPTR
        STAA 3,X
        ANDA #7
        STAA 0,X
        JSR MAKE
        LDAA #1
        STAA HASLAST
        CLR SIDE
        LDAA #2
        STAA MODE
        JSR GEN
        LDX FRAMEPTR
        LDAA 10,X
        BNE UE_CONTINUE
        JSR CHECK
        TSTA
        BEQ UE_DRAW
        LDAA #2
        BRA UE_FINISH
UE_DRAW:
        LDAA #3
UE_FINISH:
        STAA GAMEOVER
UE_CONTINUE:
        JMP UI_MAIN
PARSE_SQUARE:
        LDAA 0,X
        SUBA #$41
        CMPA #8
        BCC PS_BAD
        STAA UITMP
        LDAA 1,X
        SUBA #$31
        CMPA #8
        BCC PS_BAD
        ASLA
        ASLA
        ASLA
        ASLA
        ORAA UITMP
        CLC
        RTS
PS_BAD: SEC
        RTS

; GEN preserves each node's enumeration state in its own 16-byte frame.
; MODE: 0 search, 1 requested move, 2 any legal move, 3 enumeration,
; 4 pseudo-legal mobility/capture statistics (original counts omit some checks).
GEN:    LDX FRAMEPTR
        CLR 10,X
        CLR 12,X
        LDAA #$87              ; -121 (below checkmate score)
        STAA 9,X
        LDAA MODE
        BNE G_BEGIN
        LDAA 11,X
        BNE G_BEGIN
        JSR EVALUATE         ; stand pat at the capture-only frontier
        LDX FRAMEPTR
        STAA 9,X
        INC 10,X
G_BEGIN:
        LDAA #$FF
        STAA 1,X
G_NEXT: LDX FRAMEPTR
        INC 1,X
        LDAA 1,X
        BITA #8
        BEQ G_RANK
        ADDA #8
        STAA 1,X
G_RANK: BITA #$80
        BEQ LONG_0
        JMP G_EXIT
LONG_0:
        TAB
        LDX #BOARD
        ABX
        LDAA 0,X
        BEQ G_NEXT
        LDX FRAMEPTR
        STAA 3,X
        ANDA #8
        CMPA SIDE
        BNE G_NEXT
        LDAA MODE
        CMPA #1
        BNE G_TYPE
        LDAA 1,X
        CMPA WANTFROM
        BNE G_NEXT
G_TYPE: LDAA 3,X
        ANDA #7
        STAA 0,X
        CMPA #1
        BNE G_OTHER
        JSR G_PAWN
        JMP G_AFTER_PIECE
G_OTHER:
        LDD #DIRECTIONS
        STD 7,X
        CLR 5,X
        LDAB #8
        STAB 6,X
        LDAA 0,X
        CMPA #2
        BNE G_NOTKNIGHT
        LDD #KNIGHTDIRS
        STD 7,X
        BRA G_DIR
G_NOTKNIGHT:
        CMPA #3
        BNE G_NOTBISHOP
        LDAA #4
        STAA 5,X
        BRA G_DIR
G_NOTBISHOP:
        CMPA #4
        BNE G_DIR
        LDAB #4
        STAB 6,X
G_DIR:  LDX FRAMEPTR
        LDAA 1,X
        STAA 2,X
G_STEP: LDX FRAMEPTR
        LDAB 5,X
        LDX 7,X
        ABX
        LDAA 0,X
        LDX FRAMEPTR
        ADDA 2,X
        STAA 2,X
        BITA #$88
        BNE G_NEXTDIR
        TAB
        LDX #BOARD
        ABX
        LDAA 0,X
        BEQ G_CAND
        LDAB SIDE
        STAB TESTSIDE
        TAB
        ANDA #8
        CMPA TESTSIDE
        BEQ G_NEXTDIR
        TBA
        ANDA #7
        CMPA #6               ; King capture is never an actual chess move
        BEQ G_NEXTDIR
G_CAND: LDX FRAMEPTR
        LDAB 2,X
        LDX #BOARD
        ABX
        LDAA 0,X
        LDX FRAMEPTR
        STAA 4,X
        JSR TRY
        JSR STOP_EARLY
        TSTA
        BNE G_EXIT
        LDX FRAMEPTR
        LDAA 0,X
        CMPA #2
        BEQ G_NEXTDIR
        CMPA #6
        BEQ G_NEXTDIR
        LDAA 4,X
        BEQ G_STEP
G_NEXTDIR:
        LDX FRAMEPTR
        INC 5,X
        LDAA 5,X
        CMPA 6,X
        BNE G_DIR
G_AFTER_PIECE:
        JSR STOP_EARLY
        TSTA
        BNE G_EXIT
        JMP G_NEXT
G_EXIT: RTS
STOP_EARLY:
        LDAA MODE
        BEQ SE_NO
        CMPA #3
        BEQ SE_NO
        LDX FRAMEPTR
        LDAA 10,X
        RTS
SE_NO:  CLRA
        RTS

G_PAWN:
        LDAA #16
        LDAB SIDE
        BEQ GP_FORWARD
        NEGA
GP_FORWARD:
        LDX FRAMEPTR
        ADDA 1,X
        STAA 2,X
        BITA #$88
        BNE GP_CAP_START
        TAB
        LDX #BOARD
        ABX
        LDAA 0,X
        BNE GP_CAP_START
        JSR TRY
        JSR STOP_EARLY
        TSTA
        BNE GP_EXIT
        LDX FRAMEPTR
        LDAA 1,X
        ANDA #$70
        LDAB SIDE
        BNE GP_BLACK_START
        CMPA #$10
        BNE GP_CAP_START
        LDAA #32
        BRA GP_DOUBLE
GP_BLACK_START:
        CMPA #$60
        BNE GP_CAP_START
        LDAA #$E0
GP_DOUBLE:
        ADDA 1,X
        STAA 2,X
        TAB
        LDX #BOARD
        ABX
        LDAA 0,X
        BNE GP_CAP_START
        JSR TRY
        JSR STOP_EARLY
        TSTA
        BNE GP_EXIT
GP_CAP_START:
        LDX FRAMEPTR
        LDAA #5
        STAA 5,X
GP_CAP_LOOP:
        LDX FRAMEPTR
        LDAB 5,X
        LDX #DIRECTIONS
        ABX
        LDAA 0,X              ; directions 5/6 = +17/+15
        LDAB SIDE
        BEQ GP_CAP_WHITE
        NEGA
GP_CAP_WHITE:
        LDX FRAMEPTR
        ADDA 1,X
        STAA 2,X
        BITA #$88
        BNE GP_CAP_NEXT
        TAB
        LDX #BOARD
        ABX
        LDAA 0,X
        BEQ GP_CAP_NEXT
        TAB
        ANDA #8
        CMPA SIDE
        BEQ GP_CAP_NEXT
        TBA
        ANDA #7
        CMPA #6
        BEQ GP_CAP_NEXT
        JSR TRY
        JSR STOP_EARLY
        TSTA
        BNE GP_EXIT
GP_CAP_NEXT:
        LDX FRAMEPTR
        INC 5,X
        LDAA 5,X
        CMPA #7
        BNE GP_CAP_LOOP
GP_EXIT:
        RTS

TRY:    LDAA MODE
        CMPA #4
        BNE T_NORMAL
        JMP COUNT_MOVE
T_NORMAL:
        LDX FRAMEPTR
        LDAA MODE
        CMPA #1
        BNE T_MATCH
        LDAA 2,X
        CMPA WANTTO
        BEQ LONG_4
        JMP T_EXIT
LONG_4:
T_MATCH:
        LDAA MODE
        BNE T_MAKE
        LDAA 11,X
        BNE T_MAKE
        LDAB 2,X
        LDX #BOARD
        ABX
        LDAA 0,X
        BNE LONG_5
        JMP T_EXIT
LONG_5:
T_MAKE:
        JSR MAKE
        JSR CHECK
        TSTA
        BNE T_UNDO
        LDX FRAMEPTR
        LDAA #1
        STAA 10,X
LEGAL_FOUND:
        LDAA MODE
        BNE T_UNDO
        LDAA 11,X
        TSTA
        BEQ T_STATIC
        CMPA #1
        BNE T_CHILD
        LDAB 4,X
        BNE T_CHILD           ; answer a reply capture with one more capture ply
T_STATIC:
        JSR EVALUATE
        BRA T_SCORE
T_CHILD:
        DECA
        PSHA
        LDD FRAMEPTR
        ADDD #16
        STD FRAMEPTR
        LDX FRAMEPTR
        PULA
        STAA 11,X
        LDAA SIDE
        EORA #8
        STAA SIDE
        JSR SEARCH
        PSHA
        LDAA SIDE
        EORA #8
        STAA SIDE
        LDD FRAMEPTR
        SUBD #16
        STD FRAMEPTR
        PULA
        NEGA
T_SCORE:
        LDX FRAMEPTR
        CPX #FRAMES
        BNE T_COMPARE
        CMPA #115
        BGE T_COMPARE
        CMPA #$8D             ; -115: leave mate scores untouched
        BLE T_COMPARE
        JSR STRATEGY
        PSHA
        JSR BONUS
        TAB
        PULA
        ABA
T_COMPARE:
        CMPA 9,X
        BLE T_UNDO
        STAA 9,X
        LDAA 1,X
        STAA 13,X
        LDAA 2,X
        STAA 14,X
T_UNDO: JSR UNMAKE
T_EXIT: RTS
SEARCH: JSR GEN
        LDX FRAMEPTR
        LDAA 10,X
        BEQ S_NONE
        LDAA 9,X
        RTS
S_NONE: JSR CHECK
        TSTA
        BEQ S_DRAW
        LDAA #$88              ; -120: checkmate
        RTS
S_DRAW: CLRA
        RTS

MAKE:   LDX FRAMEPTR
        LDAB 2,X
        LDX #BOARD
        ABX
        LDAA 0,X
        LDX FRAMEPTR
        STAA 4,X
        LDAB 1,X
        LDX #BOARD
        ABX
        CLR 0,X
        LDX FRAMEPTR
        LDAB 2,X
        LDAA 3,X
        PSHA
        ANDA #7
        CMPA #1
        BNE M_NORMAL
        LDAA 2,X
        ANDA #$70
        BEQ M_PROMOTE
        CMPA #$70
        BNE M_NORMAL
M_PROMOTE:
        PULA
        ANDA #8
        ORAA #5
        BRA M_PUT
M_NORMAL:
        PULA
M_PUT:  LDX #BOARD
        ABX
        STAA 0,X
        LDX FRAMEPTR
        LDAA 0,X
        CMPA #6
        BNE M_DONE
        LDAA 2,X
        LDAB SIDE
        BEQ M_WHITE
        STAA KINGB
        RTS
M_WHITE:
        STAA KINGW
M_DONE: RTS
UNMAKE: LDX FRAMEPTR
        LDAB 2,X
        LDAA 4,X
        LDX #BOARD
        ABX
        STAA 0,X
        LDX FRAMEPTR
        LDAB 1,X
        LDAA 3,X
        LDX #BOARD
        ABX
        STAA 0,X
        LDX FRAMEPTR
        LDAA 0,X
        CMPA #6
        BNE U_DONE
        LDAA 1,X
        LDAB SIDE
        BEQ U_WHITE
        STAA KINGB
        RTS
U_WHITE:
        STAA KINGW
U_DONE: RTS

; Return 1 iff SIDE's king is attacked. No trial move generation is needed.
CHECK:  LDAA SIDE
        EORA #8
        STAA ENEMY
        LDAA KINGW
        LDAB SIDE
        BEQ K_START
        LDAA KINGB
K_START:
        STAA KINGSQ
        LDAA #15
        LDAB SIDE
        BEQ K_PAWN
        NEGA
K_PAWN: ADDA KINGSQ
        JSR K_GET
        LDAB ENEMY
        ORAB #1
        CBA
        BNE LONG_2
        JMP K_YES
LONG_2:
        LDAA #17
        LDAB SIDE
        BEQ K_PAWN2
        NEGA
K_PAWN2:
        ADDA KINGSQ
        JSR K_GET
        LDAB ENEMY
        ORAB #1
        CBA
        BNE LONG_3
        JMP K_YES
LONG_3:
        CLR KDIR
K_KNIGHT:
        LDAB KDIR
        LDX #KNIGHTDIRS
        ABX
        LDAA 0,X
        ADDA KINGSQ
        JSR K_GET
        LDAB ENEMY
        ORAB #2
        CBA
        BEQ K_YES
        INC KDIR
        LDAA KDIR
        CMPA #8
        BNE K_KNIGHT
        CLR KDIR
K_RAY:  LDAA KINGSQ
        STAA KTO
        CLR KSTEP
K_ALONG:
        LDAB KDIR
        LDX #DIRECTIONS
        ABX
        LDAA 0,X
        ADDA KTO
        STAA KTO
        BITA #$88
        BNE K_NEXT
        INC KSTEP
        JSR K_GET
        BEQ K_ALONG
        TAB
        ANDA #8
        CMPA ENEMY
        BNE K_NEXT
        TBA
        ANDA #7
        CMPA #5
        BEQ K_YES
        CMPA #6
        BNE K_NOTKING
        LDAB KSTEP
        CMPB #1
        BEQ K_YES
        BRA K_NEXT
K_NOTKING:
        LDAB KDIR
        CMPB #4
        BCC K_DIAG
        CMPA #4
        BEQ K_YES
        BRA K_NEXT
K_DIAG: CMPA #3
        BEQ K_YES
K_NEXT: INC KDIR
        LDAA KDIR
        CMPA #8
        BNE K_RAY
        CLRA
        RTS
K_YES:  LDAA #1
        RTS
K_GET:  BITA #$88
        BNE KG_OFF
        TAB
        LDX #BOARD
        ABX
        LDAA 0,X
        RTS
KG_OFF: CLRA
        RTS

COUNT_MOVE:
        INC MOBILITY
        LDX FRAMEPTR
        LDAA 0,X
        CMPA #5
        BNE CM_CAP
        INC MOBILITY
CM_CAP: LDAB 2,X
        LDX #BOARD
        ABX
        LDAA 0,X
        ANDA #7
        TAB
        LDX #VALUES
        ABX
        LDAA 0,X
        CMPA MAXCAP
        BLS CM_SUM
        STAA MAXCAP
CM_SUM: ADDA CAPSUM
        STAA CAPSUM
        RTS

; Original quarter-weight mobility/capture sum and half-weight max capture.
; Eight-bit counters wrap like JANUS. Search combines these differences with
; original material values, rather than reproducing STRATGY's carry chain.
STATISTICS:
        CLR MOBILITY
        CLR CAPSUM
        CLR MAXCAP
        JSR GEN
        LDAA MOBILITY
        LSRA
        LSRA
        STAA STATVALUE
        LDAA CAPSUM
        LSRA
        LSRA
        ADDA STATVALUE
        STAA STATVALUE
        LDAA MAXCAP
        LSRA
        ADDA STATVALUE
        RTS

EVALUATE:
        CLR EVSCORE
        CLR EVSQ
E_LOOP: LDAB EVSQ
        LDX #BOARD
        ABX
        LDAA 0,X
        BEQ E_NEXT
        STAA EVPIECE
        ANDA #7
        TAB
        LDX #VALUES
        ABX
        LDAA 0,X
        LDAB EVPIECE
        BITB #8
        BEQ E_ADD
        NEGA
E_ADD:  ADDA EVSCORE
        STAA EVSCORE
E_NEXT: INC EVSQ
        LDAA EVSQ
        BITA #8
        BEQ E_RANK
        ADDA #8
        STAA EVSQ
E_RANK: BITA #$80
        BEQ E_LOOP
        LDAA EVSCORE
        LDAB SIDE
        BEQ E_DONE
        NEGA
E_DONE: RTS

; STRATGY-style static features at each root candidate, not every reply.
; A carries the material-search score, in the candidate mover's perspective.
STRATEGY:
        TAB
        CLRA
        TSTB
        BPL E_SAVE
        COMA
E_SAVE: STD EVALTOTAL
        LDD FRAMEPTR
        ADDD #16
        STD FRAMEPTR
        LDAA #4
        STAA MODE
        JSR STATISTICS
        STAA OWNSTAT
        LDAA SIDE
        EORA #8
        STAA SIDE
        JSR STATISTICS
        TAB
        CLRA
        STD OPPSTAT
        LDAB OWNSTAT
        CLRA
        SUBD OPPSTAT
E_TOTAL:
        ADDD EVALTOTAL
        STD EVALTOTAL
        LDAA SIDE
        EORA #8
        STAA SIDE
        CLR MODE
        LDD FRAMEPTR
        SUBD #16
        STD FRAMEPTR
        LDD EVALTOTAL
        TSTA
        BMI E_NEGATIVE
        BNE E_HIGH
        CMPB #115
        BLS E_RETURN
E_HIGH: LDAA #115
        RTS
E_NEGATIVE:
        CMPA #$FF
        BNE E_LOW
        CMPB #$8D
        BCC E_RETURN
E_LOW:  LDAA #$8D
        RTS
E_RETURN:
        TBA
        RTS
 ; Jennings bonus: own-relative squares $33/$34/$22/$25, or
; a non-king leaving the back rank. Mirror files for his king-on-$03 layout.
BONUS:  LDX FRAMEPTR
        LDAA 2,X
        LDAB SIDE
        BEQ B_WHITE
        EORA #$77
B_WHITE:
        EORA #7
        CMPA #$33
        BEQ B_YES
        CMPA #$34
        BEQ B_YES
        CMPA #$22
        BEQ B_YES
        CMPA #$25
        BEQ B_YES
        LDAA 0,X
        CMPA #6
        BEQ B_NO
        LDAA 1,X
        ANDA #$70
        LDAB SIDE
        BEQ B_RANK
        EORA #$70
B_RANK: TSTA
        BNE B_NO
B_YES:  LDAA #2
        RTS
B_NO:   CLRA
        RTS

DRAW:   LDX #$4000
        LDAA #$60
D_CLEAR:
        STAA 0,X
        INX
        CPX #$4200
        BNE D_CLEAR
        LDX #$4000
        STX SCREENPTR
        LDX #TITLE
        JSR TEXT
        LDAA LEVEL
        ORAA #$70
        STAA $4020
        LDX #$4022
        STX SCREENPTR
        LDX #SUBTITLE
        JSR TEXT
        LDX #$4040
        STX SCREENPTR
        LDX #FILES
        JSR TEXT
        CLR UIROW
D_ROW:  CLR UICOL
        LDAA UIROW
        LDAB #32
        MUL
        ADDD #$4060
        STD SCREENPTR
        LDAA #$38
        SUBA UIROW
        ORAA #$40
        LDX SCREENPTR
        STAA 0,X
        LDAB #4
        ABX
        STX SCREENPTR
D_COL:  LDAA UIROW
        EORA UICOL
        ANDA #1
        BEQ D_LIGHT
        LDAA #$20
        BRA D_EMPTY
D_LIGHT:
        LDAA #$60
D_EMPTY:
        STAA SQUAREBG
        LDAA #7
        SUBA UIROW
        ASLA
        ASLA
        ASLA
        ASLA
        ORAA UICOL
        TAB
        LDX #BOARD
        ABX
        LDAA 0,X
        BEQ D_SPACE
        STAA UITMP
        ANDA #7
        TAB
        LDX #PIECECHARS
        ABX
        LDAA 0,X
        LDAB UITMP
        BITB #8
        BEQ D_PUT
        ANDA #$3F
        BRA D_PUT
D_SPACE:
        LDAA SQUAREBG
D_PUT:  LDX SCREENPTR
        STAA 0,X
        LDAA SQUAREBG
        STAA 1,X
        INX
        INX
        STX SCREENPTR
        INC UICOL
        LDAA UICOL
        CMPA #8
        BNE D_COL
        INC UIROW
        LDAA UIROW
        CMPA #8
        BEQ D_ROWS_DONE
        JMP D_ROW
D_ROWS_DONE:
        LDX #$4160
        STX SCREENPTR
        LDX #FILES
        JSR TEXT
        LDX #$4180
        STX SCREENPTR
        LDX #HELP
        JSR TEXT
        LDX #MSG_READY
        LDAA GAMEOVER
        BEQ D_STATUS
        LDX #MSG_WIN
        CMPA #1
        BEQ D_STATUS
        LDX #MSG_LOSE
        CMPA #2
        BEQ D_STATUS
        LDX #MSG_DRAW
D_STATUS:
        JSR MESSAGE
        JSR DRAW_INPUT
        LDAA HASLAST
        BEQ D_DONE
        LDX #$41E0
        STX SCREENPTR
        LDX #LASTLABEL
        JSR TEXT
        LDAA LASTFROM
        JSR PRINT_SQUARE
        LDAA LASTTO
        JSR PRINT_SQUARE
D_DONE: RTS
MESSAGE:
        STX TEXTSOURCE
        LDX #$41A0
        LDAB #32
        LDAA #$60
MSG_CLR:
        STAA 0,X
        INX
        DECB
        BNE MSG_CLR
        LDX #$41A0
        STX SCREENPTR
        LDX TEXTSOURCE
        BRA TEXT
DRAW_INPUT:
        LDX #$41C0
        STX SCREENPTR
        LDX #PROMPT
        JSR TEXT
        LDX #$41C6
        LDAB #4
        LDAA #$60
DI_CLR: STAA 0,X
        INX
        DECB
        BNE DI_CLR
        LDX #INPUTBUF
        STX TEXTSOURCE
        LDX #$41C6
        STX SCREENPTR
        LDAB INPUTLEN
        BEQ DI_DONE
DI_COPY:
        LDX TEXTSOURCE
        LDAA 0,X
        ORAA #$40
        INX
        STX TEXTSOURCE
        LDX SCREENPTR
        STAA 0,X
        INX
        STX SCREENPTR
        DECB
        BNE DI_COPY
DI_DONE:
        RTS
TEXT:   STX TEXTSOURCE
TX_LOOP:
        LDX TEXTSOURCE
        LDAA 0,X
        BEQ TX_DONE
        INX
        STX TEXTSOURCE
        ORAA #$40
        LDX SCREENPTR
        STAA 0,X
        INX
        STX SCREENPTR
        BRA TX_LOOP
TX_DONE:
        RTS
PRINT_SQUARE:
        PSHA
        ANDA #7
        ADDA #$41
        LDX SCREENPTR
        STAA 0,X
        INX
        PULA
        LSRA
        LSRA
        LSRA
        LSRA
        INCA
        ORAA #$70
        STAA 0,X
        INX
        STX SCREENPTR
        RTS

INITIAL: .BYTE 4,2,3,5,6,3,2,4
DIRECTIONS: .BYTE $F0,$FF,1,16,$EF,17,15,$F1
KNIGHTDIRS: .BYTE $DF,$E1,$EE,$F2,14,18,31,33
VALUES: .BYTE 0,2,4,4,6,10,0
PIECECHARS: .TEXT " PNBRQK"
TITLE: .TEXT "MICROCHESS / JENNINGS"
        .BYTE 0
SUBTITLE: .TEXT "PLY / YOU PLAY WHITE"
        .BYTE 0
FILES: .TEXT "    A B C D E F G H"
        .BYTE 0
HELP: .TEXT "N NEW  Q QUIT  S 1/2 PLY"
        .BYTE 0
MSG_READY: .TEXT "E2E4 ENTER / BACKSPACE TO EDIT"
        .BYTE 0
MSG_THINK: .TEXT "BLACK IS THINKING..."
        .BYTE 0
MSG_BAD: .TEXT "ILLEGAL MOVE - TRY AGAIN"
        .BYTE 0
MSG_WIN: .TEXT "CHECKMATE - YOU WIN. N NEW"
        .BYTE 0
MSG_LOSE: .TEXT "CHECKMATE - BLACK WINS. N NEW"
        .BYTE 0
MSG_DRAW: .TEXT "STALEMATE - DRAW. N NEW"
        .BYTE 0
PROMPT: .TEXT "MOVE: "
        .BYTE 0
LASTLABEL: .TEXT "BLACK: "
        .BYTE 0
COPYRIGHT: .TEXT "MicroChess (c) 1996-2002 Peter Jennings, peterj@benlo.com"
        .BYTE 0
CODE_END:
OLDCC: .BYTE 0
OLDSP: .WORD 0
LEVEL: .BYTE 2
SIDE: .BYTE 0
MODE: .BYTE 0
INPUTLEN: .BYTE 0
INPUTBUF: .FILL 4,0
GAMEOVER: .BYTE 0
WANTFROM: .BYTE 0
WANTTO: .BYTE 0
HASLAST: .BYTE 0
LASTFROM: .BYTE 0
LASTTO: .BYTE 0
KINGW: .BYTE 4
KINGB: .BYTE $74
ENEMY: .BYTE 0
KINGSQ: .BYTE 0
KDIR: .BYTE 0
KTO: .BYTE 0
KSTEP: .BYTE 0
TESTSIDE: .BYTE 0
OPPSTAT: .WORD 0
EVALTOTAL: .WORD 0
MOBILITY: .BYTE 0
CAPSUM: .BYTE 0
MAXCAP: .BYTE 0
STATVALUE: .BYTE 0
OWNSTAT: .BYTE 0
EVSCORE: .BYTE 0
EVSQ: .BYTE 0
EVPIECE: .BYTE 0
UITMP: .BYTE 0
UIROW: .BYTE 0
UICOL: .BYTE 0
SQUAREBG: .BYTE 0
SCREENPTR: .WORD 0
TEXTSOURCE: .WORD 0
FRAMEPTR: .WORD FRAMES
FRAMES: .FILL 48,0
BOARD: .FILL 64,0
       .FILL 64,0
IMAGE_END:
        .END START
