; ======================================================================
;  MICROCHESS for the Tandy/Radio Shack MC-10 with 16K RAM expansion
;  Native MC6803 rewrite of Peter Jennings' MicroChess search.
;
;  MicroChess (c) 1996-2002 Peter Jennings, peterj@benlo.com
;  (the evaluation/search algorithm - move generation order, JANUS,
;   counters, STRATGY, CKMATE - is Jennings'; the code is new)
;
;  Differences from the 4K-era program:
;    * 0x88 mailbox board, rules built into the move generator:
;      castling, en passant, auto-queen promotion, full legality
;    * 128x96 four-colour (CG3) display, 12x11 piece sprites
;    * play either colour (board flips when you play Black)
;    * own keyboard scanner (the BASIC ROM's workspace lives in the
;      video RAM that CG3 takes over); Q cold-starts BASIC again
;
;  Memory map (16K expansion):  $5000.. code+data   $7C00-$8060 variables
;                               $8FFF stack         $4000-$4BFF screen
;  Load:  CLEAR 100,20479 : CLOADM : EXEC 20480
;  Build: tasm6801 -sym microchess-mc10-16k.asm   (Telemark-compatible)
; ======================================================================
        .MSFIRST
RAM     .EQU $7C00
        .ORG $5000
        JMP START
; ======================================================================
;  ENGINE  -- native 6803 version of Peter Jennings' MicroChess search
;  0x88 mailbox board (absolute coordinates), O(1) REVERSE (frame flip),
;  full legality via attack detection, castling, en passant, auto-queen.
; ======================================================================

; ---- direct page variables ($80-$FF is the 6803's internal RAM) -------
PIECE   .EQU $80        ; current piece index 0-15 (in mover's list)
SQUARE  .EQU $81        ; current destination / working square (0x88 coords)
MOVEN   .EQU $82        ; direction index
STATE   .EQU $83        ; search state (0,4,8,12 counting; $FF.. capture tree)
MYC     .EQU $84        ; mover's colour bit: $00 white, $20 black
OPC     .EQU $85        ; opponent's colour bit
PFWD    .EQU $86        ; pawn forward step for mover ($10 / $F0)
DBLR    .EQU $87        ; rank nibble that triggers second pawn hop ($20 / $50)
PROMR   .EQU $88        ; promotion rank ($70 / $00)
MXP     .EQU $89        ; word: pointer to this frame's direction table
EPSQ    .EQU $8B        ; en-passant target square ($FF none)
VFLAG   .EQU $8C        ; 1 if candidate move captures
CAPID   .EQU $8D        ; captured piece id of candidate (opp colour | idx)
UPTR    .EQU $8E        ; word: undo stack pointer
LISTMODE .EQU $90       ; 1 = collect legal moves instead of searching
LISTPTR .EQU $91        ; word
LISTCNT .EQU $93
PTS     .EQU $94
TMPA    .EQU $95
TMPB    .EQU $96
TMPC    .EQU $97
FROMSQ  .EQU $98
PIDV    .EQU $99
FLAGS   .EQU $9A
CAPSQ   .EQU $9B
MCAP    .EQU $9C
OLDEP   .EQU $9D
EPNEW   .EQU $9E
WCAP0   .EQU $9F
BESTV   .EQU $A0
BESTP   .EQU $A1
BESTM   .EQU $A2
SCORE   .EQU $A3
ATC     .EQU $A5
ATS     .EQU $A6
ATI     .EQU $A7
ATD     .EQU $A8
ATQ     .EQU $A9
ATF     .EQU $AA
CAD     .EQU $AB
CAID    .EQU $AC
CAR     .EQU $AD
CAN     .EQU $AE
CAQ     .EQU $AF
CAC     .EQU $B0
CKH     .EQU $B1
SEARCHOK .EQU $B2
TMPW    .EQU $B3        ; word

; ---- data RAM (not part of the load image) -------------------------
SQ      .EQU RAM+$000   ; 48 : white ids $00-$0F, black ids $20-$2F ; $CC = captured
PTYPE   .EQU RAM+$030   ; 48 : R=1 B=2 Q=3 N=4 K=8 P=$10
PVAL    .EQU RAM+$060   ; 48 : capture values
MOVED   .EQU RAM+$090   ; 48 : piece has moved
MAIL    .EQU RAM+$0C0   ; 128: 0x88 board, 0 empty else $10|id
CAPS    .EQU RAM+$140   ; 21 : BCAP0,WCAP1,BCAP1,WCAP2,BCAP2 then 4 state groups
CNTS    .EQU CAPS+5     ;      group g at CNTS+STATE : MOB,MAXC,CC,PCAP
USTACK  .EQU RAM+$160   ; undo records, 8 bytes each (32 deep)
MLIST   .EQU RAM+$260   ; legal move list (from,to) pairs, up to 256
RAMEND  .EQU RAM+$460
CBONUS  .EQU 12         ; evaluation bonus for castling

BCAP0   .EQU CAPS+0
WCAP1   .EQU CAPS+1
BCAP1   .EQU CAPS+2
WCAP2   .EQU CAPS+3
BCAP2   .EQU CAPS+4
BMOB    .EQU CNTS+0
BMAXC   .EQU CNTS+1
BMCC    .EQU CNTS+2
BMAXP   .EQU CNTS+3
XMAXC   .EQU CNTS+5
WMOB    .EQU CNTS+8
WMAXC   .EQU CNTS+9
WCC     .EQU CNTS+10
WMAXP   .EQU CNTS+11
PMOB    .EQU CNTS+12
PMAXC   .EQU CNTS+13
PCC     .EQU CNTS+14

; ---------------------------------------------------------------------
;  frame handling:  REVERSE flips whose turn the engine "sees"
; ---------------------------------------------------------------------
SETFRAME:
        LDAA MYC
        EORA #$20
        STAA OPC
        TST MYC
        BNE SF_BLK
        LDAA #$10
        STAA PFWD
        LDAA #$20
        STAA DBLR
        LDAA #$70
        STAA PROMR
        LDX #MOVEX0
        STX MXP
        RTS
SF_BLK: LDAA #$F0
        STAA PFWD
        LDAA #$50
        STAA DBLR
        CLR PROMR
        LDX #MOVEX1
        STX MXP
        RTS
REVERSE:
        LDAA MYC
        EORA #$20
        STAA MYC
        BRA SETFRAME

; ---------------------------------------------------------------------
;  position setup
; ---------------------------------------------------------------------
COPYB:                          ; copy B bytes from (X) to (TMPW)
        LDAA 0,X
        INX
        PSHX
        LDX TMPW
        STAA 0,X
        INX
        STX TMPW
        PULX
        DECB
        BNE COPYB
        RTS
NEWPOS:                         ; standard starting position, white to move
        LDX #SQ
        STX TMPW
        LDX #SETW
        LDAB #16
        JSR COPYB
        LDX #SQ+$20
        STX TMPW
        LDX #SETB
        LDAB #16
        JSR COPYB
        LDX #PTYPE
        STX TMPW
        LDX #TYPEINIT
        LDAB #16
        JSR COPYB
        LDX #PTYPE+$20
        STX TMPW
        LDX #TYPEINIT
        LDAB #16
        JSR COPYB
        LDX #PVAL
        STX TMPW
        LDX #POINTS
        LDAB #16
        JSR COPYB
        LDX #PVAL+$20
        STX TMPW
        LDX #POINTS
        LDAB #16
        JSR COPYB
        LDX #MOVED
        LDAB #48
        CLRA
NP_MV:  STAA 0,X
        INX
        DECB
        BNE NP_MV
        LDAA #$FF
        STAA EPSQ
        CLR MYC
        JSR SETFRAME
        LDX #USTACK
        STX UPTR
        CLR LISTMODE
        ; fall into BUILD_MAIL
BUILD_MAIL:
        LDX #MAIL
        CLRA
BM_C:   STAA 0,X
        INX
        CPX #MAIL+128
        BNE BM_C
        LDAB #0
BM_L:   STAB TMPA
        LDX #SQ
        ABX
        LDAA 0,X
        CMPA #$CC
        BEQ BM_N
        TAB
        LDX #MAIL
        ABX
        LDAA TMPA
        ORAA #$10
        STAA 0,X
BM_N:   LDAB TMPA
        INCB
        CMPB #16
        BNE BM_L2
        LDAB #$20
BM_L2:  CMPB #$30
        BNE BM_L
        RTS

; ---------------------------------------------------------------------
;  CMOVE: step SQUARE by MOVEX[MOVEN].  A = 0 empty, 1 capture (CAPID set),
;         2 blocked (off board or own piece)
; ---------------------------------------------------------------------
CMOVE:  LDX MXP
        LDAB MOVEN
        ABX
        LDAA SQUARE
        ADDA 0,X
        STAA SQUARE
        BITA #$88
        BNE CM_BLK
        TAB
        LDX #MAIL
        ABX
        LDAA 0,X
        BEQ CM_RET              ; empty: A=0
        TAB
        ANDB #$20
        CMPB MYC
        BEQ CM_BLK
        ANDA #$2F
        STAA CAPID
        LDAA #1
CM_RET: RTS
CM_BLK: LDAA #2
        RTS

RESET:  LDAB MYC
        ORAB PIECE
        LDX #SQ
        ABX
        LDAA 0,X
        STAA SQUARE
        RTS

; ---------------------------------------------------------------------
;  CHKLEG: legality test of the candidate (PIECE,SQUARE) for states 0-7.
;          returns Z set if legal.
; ---------------------------------------------------------------------
CHKLEG: LDAA STATE
        CMPA #8
        BCC CL_OK
        JSR MOVE
        LDAB MYC
        LDX #SQ
        ABX
        LDAB 0,X                ; my king's square
        LDAA OPC
        JSR ATTACKED
        PSHA
        JSR UMOVE
        PULA
        TSTA
        RTS
CL_OK:  CLRA
        RTS
EMIT:   JSR CHKLEG
        BNE EM_RET
        JMP JANUS
EM_RET: RTS

; ---------------------------------------------------------------------
;  MOVE / UMOVE : make and unmake PIECE -> SQUARE (handles capture, en
;  passant, castling, auto-queen, moved flags, ep square)
; ---------------------------------------------------------------------
MOVE:   LDAB MYC
        ORAB PIECE
        STAB PIDV
        LDX #SQ
        ABX
        LDAA 0,X
        STAA FROMSQ
        CLR FLAGS
        LDAA EPSQ
        STAA OLDEP
        LDAA #$FF
        STAA EPNEW
        LDAA SQUARE
        STAA CAPSQ
        LDAB SQUARE
        LDX #MAIL
        ABX
        LDAA 0,X
        BNE MV_CAP
        LDAB PIDV               ; empty target: en passant?
        LDX #PTYPE
        ABX
        LDAA 0,X
        CMPA #$10
        BNE MV_NOCAP
        LDAA SQUARE
        CMPA EPSQ
        BNE MV_NOCAP
        LDAA FROMSQ
        EORA SQUARE
        ANDA #$0F
        BEQ MV_NOCAP
        LDAA FROMSQ
        ANDA #$F0
        STAA TMPA
        LDAA SQUARE
        ANDA #$0F
        ORAA TMPA
        STAA CAPSQ
        LDAA #4
        STAA FLAGS
        LDAB CAPSQ
        LDX #MAIL
        ABX
        LDAA 0,X
MV_CAP: ANDA #$2F
        STAA MCAP
        TAB
        LDX #SQ
        ABX
        LDAA #$CC
        STAA 0,X
        LDAB CAPSQ
        LDX #MAIL
        ABX
        CLR 0,X
        BRA MV_CAP2
MV_NOCAP: LDAA #$FF
        STAA MCAP
MV_CAP2: LDAB FROMSQ
        LDX #MAIL
        ABX
        CLR 0,X
        LDAB SQUARE
        LDX #MAIL
        ABX
        LDAA PIDV
        ORAA #$10
        STAA 0,X
        LDAB PIDV
        LDX #SQ
        ABX
        LDAA SQUARE
        STAA 0,X
        LDAB PIDV
        LDX #MOVED
        ABX
        LDAA 0,X
        BEQ MV_M0
        LDAA FLAGS
        ORAA #8
        STAA FLAGS
MV_M0:  LDAA #1
        STAA 0,X
        LDAB PIDV
        LDX #PTYPE
        ABX
        LDAA 0,X
        CMPA #$08
        BEQ MV_KING
        CMPA #$10
        BNE MV_RECJ
        LDAA SQUARE             ; pawn: promotion?
        ANDA #$F0
        CMPA PROMR
        BNE MV_PDBL
        LDAA #3
        STAA 0,X                ; PTYPE = queen
        LDAB PIDV
        LDX #PVAL
        ABX
        LDAA #10
        STAA 0,X
        LDAA FLAGS
        ORAA #1
        STAA FLAGS
        BRA MV_RECJ
MV_PDBL: LDAA SQUARE            ; double step -> ep square
        SUBA FROMSQ
        CMPA #$20
        BEQ MV_DB
        CMPA #$E0
        BNE MV_RECJ
MV_DB:  LDAA SQUARE
        ADDA FROMSQ
        LSRA
        STAA EPNEW
MV_RECJ: JMP MV_REC
MV_KING: LDAA SQUARE            ; king two squares = castling
        SUBA FROMSQ
        CMPA #2
        BEQ MV_CK
        CMPA #$FE
        BNE MV_RECJ
MV_CK:  LDAA FLAGS
        ORAA #2
        STAA FLAGS
        LDAA SQUARE
        SUBA FROMSQ
        CMPA #2
        BEQ MV_KS
        LDAA FROMSQ             ; queen side: a-rook -> d
        ANDA #$F0
        STAA TMPA
        LDAA FROMSQ
        DECA
        STAA TMPB
        LDAA #2
        BRA MV_RK
MV_KS:  LDAA FROMSQ             ; king side: h-rook -> f
        ANDA #$F0
        ORAA #7
        STAA TMPA
        LDAA FROMSQ
        INCA
        STAA TMPB
        LDAA #3
MV_RK:  ORAA MYC
        STAA TMPC               ; rook id
        TAB
        LDX #SQ
        ABX
        LDAA TMPB
        STAA 0,X
        LDAB TMPC
        LDX #MOVED
        ABX
        LDAA #1
        STAA 0,X
        LDAB TMPA
        LDX #MAIL
        ABX
        LDAA 0,X                ; rook's mailbox code
        CLR 0,X
        PSHA
        LDAB TMPB
        LDX #MAIL
        ABX
        PULA
        STAA 0,X
MV_REC: LDX UPTR
        LDAA SQUARE
        STAA 0,X
        LDAA MCAP
        STAA 1,X
        LDAA FROMSQ
        STAA 2,X
        LDAA PIECE
        STAA 3,X
        LDAA MOVEN
        STAA 4,X
        LDAA FLAGS
        STAA 5,X
        LDAA OLDEP
        STAA 6,X
        LDAB #8
        ABX
        STX UPTR
        LDAA EPNEW
        STAA EPSQ
        RTS

UMOVE:  LDD UPTR
        SUBD #8
        STD UPTR
        LDX UPTR
        LDAA 4,X
        STAA MOVEN
        LDAA 3,X
        STAA PIECE
        LDAA 6,X
        STAA EPSQ
        LDAA 2,X
        STAA FROMSQ
        LDAA 5,X
        STAA FLAGS
        LDAA 0,X
        STAA SQUARE
        LDAA 1,X
        STAA MCAP
        LDAB MYC
        ORAB PIECE
        STAB PIDV
        LDAA FLAGS              ; promotion undo
        ANDA #1
        BEQ UM_1
        LDX #PTYPE
        ABX
        LDAA #$10
        STAA 0,X
        LDAB PIDV
        LDX #PVAL
        ABX
        LDAA #2
        STAA 0,X
UM_1:   LDAB PIDV               ; restore moved flag
        LDX #MOVED
        ABX
        LDAA FLAGS
        ANDA #8
        LSRA
        LSRA
        LSRA
        STAA 0,X
        LDAA FLAGS              ; castling rook back
        ANDA #2
        BEQ UM_2
        LDAA SQUARE
        SUBA FROMSQ
        CMPA #2
        BEQ UM_KS
        LDAA FROMSQ             ; queen side: rook d -> a
        ANDA #$F0
        STAA TMPA               ; rook home
        LDAA FROMSQ
        DECA
        STAA TMPB               ; rook now
        LDAA #2
        BRA UM_RK
UM_KS:  LDAA FROMSQ
        ANDA #$F0
        ORAA #7
        STAA TMPA
        LDAA FROMSQ
        INCA
        STAA TMPB
        LDAA #3
UM_RK:  ORAA MYC
        STAA TMPC
        TAB
        LDX #SQ
        ABX
        LDAA TMPA
        STAA 0,X
        LDAB TMPC
        LDX #MOVED
        ABX
        CLR 0,X
        LDAB TMPB
        LDX #MAIL
        ABX
        LDAA 0,X
        CLR 0,X
        PSHA
        LDAB TMPA
        LDX #MAIL
        ABX
        PULA
        STAA 0,X
UM_2:   LDAB SQUARE             ; clear dest, put mover back
        LDX #MAIL
        ABX
        CLR 0,X
        LDAB FROMSQ
        LDX #MAIL
        ABX
        LDAA PIDV
        ORAA #$10
        STAA 0,X
        LDAB PIDV
        LDX #SQ
        ABX
        LDAA FROMSQ
        STAA 0,X
        LDAA MCAP               ; captured piece back
        CMPA #$FF
        BEQ UM_RET
        LDAA SQUARE
        STAA CAPSQ
        LDAA FLAGS
        ANDA #4
        BEQ UM_C1
        LDAA FROMSQ
        ANDA #$F0
        STAA TMPA
        LDAA SQUARE
        ANDA #$0F
        ORAA TMPA
        STAA CAPSQ
UM_C1:  LDAB MCAP
        LDX #SQ
        ABX
        LDAA CAPSQ
        STAA 0,X
        LDAB CAPSQ
        LDX #MAIL
        ABX
        LDAA MCAP
        ORAA #$10
        STAA 0,X
UM_RET: RTS

; ---------------------------------------------------------------------
;  ATTACKED: A = attacker colour bit, B = target square.
;            returns A = 1 if attacked else 0 (flags set accordingly)
; ---------------------------------------------------------------------
ATTACKED:
        STAA ATC
        STAB ATS
        LDAA #7
        STAA ATI
AT_N:   LDX #MOVEX0+9           ; knight offsets
        LDAB ATI
        ABX
        LDAA ATS
        ADDA 0,X
        BITA #$88
        BNE AT_N2
        TAB
        LDX #MAIL
        ABX
        LDAA 0,X
        BEQ AT_N2
        TAB
        ANDB #$20
        CMPB ATC
        BNE AT_N2
        ANDA #$2F
        TAB
        LDX #PTYPE
        ABX
        LDAA 0,X
        BITA #4
        BNE AT_YES
AT_N2:  DEC ATI
        BPL AT_N
        LDAA #7
        STAA ATI
AT_R:   LDX #RAYDIR
        LDAB ATI
        ABX
        LDAA 0,X
        STAA ATD
        LDAA ATS
        STAA ATQ
        LDAA #1
        STAA ATF
AT_S:   LDAA ATQ
        ADDA ATD
        STAA ATQ
        BITA #$88
        BNE AT_R2
        TAB
        LDX #MAIL
        ABX
        LDAA 0,X
        BNE AT_HIT
        CLR ATF
        BRA AT_S
AT_HIT: TAB
        ANDB #$20
        CMPB ATC
        BNE AT_R2
        ANDA #$2F
        TAB
        LDX #PTYPE
        ABX
        LDAA 0,X
        LDAB ATI
        CMPB #4
        BCC AT_DG
        BITA #1
        BNE AT_YES
        BRA AT_ADJ
AT_DG:  BITA #2
        BNE AT_YES
        TST ATF
        BEQ AT_R2
        BITA #$10
        BEQ AT_ADJ
        LDAB ATD
        TST ATC
        BEQ AT_PW
        TSTB
        BPL AT_YES
        BRA AT_ADJ
AT_PW:  TSTB
        BMI AT_YES
AT_ADJ: TST ATF
        BEQ AT_R2
        BITA #8
        BNE AT_YES
AT_R2:  DEC ATI
        BPL AT_R
        CLRA
        RTS
AT_YES: LDAA #1
        RTS

INCHECK:                        ; A=1 if side to move is in check
        LDAB MYC
        LDX #SQ
        ABX
        LDAB 0,X
        LDAA OPC
        JMP ATTACKED

; ---------------------------------------------------------------------
;  move generation (order is Jennings': pieces 15..0, his direction order)
; ---------------------------------------------------------------------
GNMX:   LDX #CAPS
        LDAB #21
        BRA GZ_CLR
GNMZ:   LDX #CAPS
        LDAB #17
GZ_CLR: CLRA
GZ_L:   STAA 0,X
        INX
        DECB
        BNE GZ_L
GNM:    LDAA #16
        STAA PIECE
NEWP:   DEC PIECE
        BPL NEX
        RTS
NEX:    LDAB MYC
        ORAB PIECE
        LDX #SQ
        ABX
        LDAA 0,X
        CMPA #$CC
        BEQ NEWP
        STAA SQUARE
        LDX #PTYPE
        LDAB MYC
        ORAB PIECE
        ABX
        LDAA 0,X
        CMPA #$10
        BEQ G_PAWN
        CMPA #4
        BEQ G_KNIGHT
        CMPA #2
        BEQ G_BISHOP
        CMPA #3
        BEQ G_QUEEN
        CMPA #1
        BEQ G_ROOK
        LDAA #8                 ; king
        STAA MOVEN
G_KING: JSR SNGMV
        BNE G_KING
        JSR CASTLES
        BRA NEWP
G_QUEEN: LDAA #8
        STAA MOVEN
        BRA GQ1
G_ROOK: LDAA #4
        STAA MOVEN
GQ1:    JSR LINE
        BNE GQ1
        BRA NEWP
G_BISHOP: LDAA #8
        STAA MOVEN
GB1:    JSR LINE
        LDAA MOVEN
        CMPA #4
        BNE GB1
        BRA NEWP
G_KNIGHT: LDAA #16
        STAA MOVEN
GN1:    JSR SNGMV
        LDAA MOVEN
        CMPA #8
        BNE GN1
        BRA NEWP
G_PAWN: LDAA #6
        STAA MOVEN
P1:     JSR CMOVE
        TSTA
        BEQ P1E
        CMPA #2
        BEQ P2
        LDAA #1
        STAA VFLAG
        JSR EMIT
        BRA P2
P1E:    TST STATE
        BMI P2
        LDAA EPSQ
        CMPA SQUARE
        BNE P2
        LDAA SQUARE
        SUBA PFWD
        TAB
        LDX #MAIL
        ABX
        LDAA 0,X
        BEQ P2
        ANDA #$2F
        STAA CAPID
        LDAA #1
        STAA VFLAG
        JSR EMIT
P2:     JSR RESET
        DEC MOVEN
        LDAA MOVEN
        CMPA #5
        BEQ P1
P3:     JSR CMOVE
        TSTA
        BNE P3END
        CLR VFLAG
        JSR EMIT
        LDAA SQUARE
        ANDA #$F0
        CMPA DBLR
        BEQ P3
P3END:  JMP NEWP

SNGMV:  JSR CMOVE
        TSTA
        BEQ SN_E
        CMPA #2
        BEQ SN_X
        LDAA #1
        STAA VFLAG
        BRA SN_EM
SN_E:   CLR VFLAG
SN_EM:  JSR EMIT
SN_X:   JSR RESET
        DEC MOVEN
        RTS

LINE:   JSR CMOVE
        TSTA
        BEQ LN_E
        CMPA #2
        BEQ LN_END
        LDAA #1
        STAA VFLAG
        JSR EMIT
        BRA LN_END
LN_E:   CLR VFLAG
        JSR EMIT
        BRA LINE
LN_END: JSR RESET
        DEC MOVEN
        RTS

; ---------------------------------------------------------------------
;  castling candidates (king piece only, called after its 8 steps)
; ---------------------------------------------------------------------
CASTLES:
        TST STATE
        BMI CA_RET
        LDAB MYC
        LDX #MOVED
        ABX
        LDAA 0,X
        BNE CA_RET              ; king has moved
        LDAB MYC
        LDX #SQ
        ABX
        LDAA 0,X
        LDAB #$04
        TST MYC
        BEQ CA_H
        LDAB #$74
CA_H:   STAB CKH
        CBA
        BNE CA_RET              ; king not on its home square
        LDAA #1                 ; king side
        STAA CAD
        LDAA #3
        ORAA MYC
        STAA CAID
        LDAA CKH
        ADDA #3
        STAA CAR
        LDAA #2
        STAA CAN
        JSR CA_TRY
        LDAA #$FF               ; queen side
        STAA CAD
        LDAA #2
        ORAA MYC
        STAA CAID
        LDAA CKH
        SUBA #4
        STAA CAR
        LDAA #3
        STAA CAN
        JSR CA_TRY
        CLR PIECE
CA_RET: RTS
CA_TRY: LDAB CAID
        LDX #MOVED
        ABX
        LDAA 0,X
        BNE CT_RET              ; rook has moved
        LDAB CAID
        LDX #SQ
        ABX
        LDAA 0,X
        CMPA CAR
        BNE CT_RET              ; rook not at home
        LDAA CKH
        STAA CAQ
        LDAA CAN
        STAA CAC
CT_E:   LDAA CAQ
        ADDA CAD
        STAA CAQ
        TAB
        LDX #MAIL
        ABX
        TST 0,X
        BNE CT_RET              ; square between is occupied
        DEC CAC
        BNE CT_E
        LDAA OPC
        LDAB CKH
        JSR ATTACKED
        BNE CT_RET              ; king in check
        LDAA CKH
        ADDA CAD
        TAB
        LDAA OPC
        JSR ATTACKED
        BNE CT_RET              ; passes through attacked square
        LDAA CKH
        ADDA CAD
        ADDA CAD
        STAA SQUARE
        TAB
        LDAA OPC
        JSR ATTACKED
        BNE CT_RET              ; lands on attacked square
        CLR PIECE
        LDAA #$40
        STAA MOVEN
        CLR VFLAG
        JSR JANUS
        CLR PIECE
CT_RET: RTS

; ---------------------------------------------------------------------
;  JANUS: count / evaluate a generated move  (PIECE, SQUARE, VFLAG, CAPID)
; ---------------------------------------------------------------------
JANUS:  TST LISTMODE
        BEQ JN_GO
        JMP LIST_ADD
JN_GO:  LDAA STATE
        BMI JN_TREE
        LDX #CNTS
        TAB
        ABX                     ; X -> MOB[STATE]
        INC 0,X
        LDAA PIECE
        CMPA #1
        BNE JN_NQ
        INC 0,X                 ; queen counts twice
JN_NQ:  TST VFLAG
        BEQ JN_NC
        LDAB CAPID
        PSHX
        LDX #PVAL
        ABX
        LDAA 0,X
        PULX
        STAA PTS
        CMPA 1,X                ; MAXC
        BCS JN_LS
        STAA 1,X
JN_LS:  LDAA PTS
        ADDA 2,X                ; CC
        STAA 2,X
JN_NC:  LDAA STATE
        BEQ JN_TREE
        CMPA #4
        BEQ ON4
        RTS
JN_TREE: TST VFLAG
        BEQ TR_RET
        LDAA CAPID              ; capture of a piece idx 1..7 only
        ANDA #$0F
        BEQ TR_RET
        CMPA #8
        BCC TR_RET
        LDAB CAPID
        LDX #PVAL
        ABX
        LDAA 0,X
        STAA PTS
        LDAB STATE
        NEGB
        LDX #CAPS
        ABX
        LDAA PTS
        CMPA 0,X
        BCS TR_NM
        STAA 0,X
TR_NM:  DEC STATE
        LDAA STATE
        CMPA #$FB
        BEQ TR_UP
        JSR GENRM
TR_UP:  INC STATE
TR_RET: RTS
GENRM:  JSR MOVE
        JSR REVERSE
        JSR GNM
        JSR REVERSE
        JMP UMOVE

ON4:    LDAA XMAXC
        STAA WCAP0
        CLR STATE
        JSR MOVE
        JSR REVERSE
        JSR GNMZ
        JSR REVERSE
        LDAA #8
        STAA STATE
        JSR UMOVE
STRATGY:
        LDAA #$80
        ADDA WMOB
        ADCA WMAXC
        ADCA WCC
        ADCA WCAP1
        ADCA WCAP2
        SUBA PMAXC
        SBCA PCC
        SBCA BCAP0
        SBCA BCAP1
        SBCA BCAP2
        SBCA PMOB
        SBCA BMOB
        BCC ST_POS
        CLRA
ST_POS: LSRA
        ADDA #$40
        ADCA WMAXC
        ADCA WCC
        SUBA BMAXC
        LSRA
        ADDA #$90
        ADCA WCAP0
        ADCA WCAP0
        ADCA WCAP0
        ADCA WCAP0
        ADCA WCAP1
        SUBA BMAXC
        SBCA BMAXC
        SBCA BMCC
        SBCA BMCC
        SBCA BCAP1
        STAA SCORE
        LDAA SQUARE
        TST MYC
        BEQ ST_R1
        LDAB #$77
        SUBB SQUARE
        TBA
ST_R1:  CMPA #$33
        BEQ ST_BON
        CMPA #$34
        BEQ ST_BON
        CMPA #$22
        BEQ ST_BON
        CMPA #$25
        BEQ ST_BON
        TST PIECE
        BEQ ST_CK
        LDX #SQ
        LDAB MYC
        ORAB PIECE
        ABX
        LDAA 0,X
        TST MYC
        BEQ ST_R2
        LDAB #$77
        SUBB 0,X
        TBA
ST_R2:  CMPA #$10
        BCC ST_CK
ST_BON: LDAA SCORE
        ADDA #2
        STAA SCORE
ST_CK:  LDAA MOVEN              ; castling bonus (root move flagged $40)
        CMPA #$40
        BNE CKMATE
        LDAA SCORE
        ADDA #CBONUS
        BCC ST_CB
        LDAA #$FE
ST_CB:  STAA SCORE
CKMATE: LDAA SCORE
        LDAB BMAXC
        CMPB #$0B
        BNE CK_N
        CLRA
        BRA RETV
CK_N:   TST BMOB
        BNE RETV
        TST WMAXP
        BNE RETV
        LDAA #$FF
RETV:   LDAB #4
        STAB STATE
        CMPA BESTV
        BLS RETP
        STAA BESTV
        LDAB PIECE
        STAB BESTP
        LDAB SQUARE
        STAB BESTM
RETP:   RTS

GO:     CLR SEARCHOK
        LDAA #$0C
        STAA STATE
        STAA BESTV
        JSR GNMX
        LDAA #4
        STAA STATE
        JSR GNMZ
        LDAA BESTV
        CMPA #$0F
        BCS GO_NO
        LDAA #1
        STAA SEARCHOK
GO_NO:  RTS

; ---------------------------------------------------------------------
;  legal move list for the side to move: returns count in A, pairs in MLIST
; ---------------------------------------------------------------------
LISTMOVES:
        LDX #MLIST
        STX LISTPTR
        CLR LISTCNT
        LDAA #1
        STAA LISTMODE
        LDAA #4
        STAA STATE
        JSR GNM
        CLR LISTMODE
        LDAA LISTCNT
        RTS
LIST_ADD:
        LDX #SQ
        LDAB MYC
        ORAB PIECE
        ABX
        LDAA 0,X
        LDX LISTPTR
        STAA 0,X
        LDAA SQUARE
        STAA 1,X
        INX
        INX
        STX LISTPTR
        INC LISTCNT
        RTS

; ---------------------------------------------------------------------
;  tables
; ---------------------------------------------------------------------
MOVEX0: .BYTE $00,$F0,$FF,$01,$10,$11,$0F,$EF,$F1
        .BYTE $DF,$E1,$EE,$F2,$12,$0E,$1F,$21
MOVEX1: .BYTE $00,$10,$01,$FF,$F0,$EF,$F1,$11,$0F
        .BYTE $21,$1F,$12,$0E,$EE,$F2,$E1,$DF
RAYDIR: .BYTE $01,$FF,$10,$F0,$0F,$F1,$11,$EF
SETW:   .BYTE $04,$03,$00,$07,$02,$05,$01,$06
        .BYTE $10,$17,$11,$16,$12,$15,$14,$13
SETB:   .BYTE $74,$73,$70,$77,$72,$75,$71,$76
        .BYTE $60,$67,$61,$66,$62,$65,$64,$63
TYPEINIT: .BYTE $08,$03,$01,$01,$02,$02,$04,$04
        .BYTE $10,$10,$10,$10,$10,$10,$10,$10
POINTS: .BYTE $0B,$0A,$06,$06,$04,$04,$04,$04
        .BYTE $02,$02,$02,$02,$02,$02,$02,$02
; ======================================================================
;  USER INTERFACE : 128x96 4-colour (CG3) board, sprites, 3x5 font,
;  keyboard scanner, game flow
; ======================================================================
HUMAN   .EQU $B8        ; $00 = you play White, $20 = you play Black
FLIP    .EQU $B9        ; 1 = board drawn from Black's side
LASTF   .EQU $BA        ; last move from/to (abs 0x88) for highlight, $FF none
LASTT   .EQU $BB
INLEN   .EQU $BC        ; characters typed so far (0-4)
INBUF   .EQU $BD        ; 4 bytes
HLF     .EQU $C1        ; square highlighted while typing ($FF none)
GSTATE  .EQU $C2
TCOL    .EQU $C3        ; text cursor: byte column 0-31
TROW    .EQU $C4        ;              pixel row 0-95
FGB     .EQU $C5        ; text foreground/background colour bytes
BGB     .EQU $C6
TPTR    .EQU $C7        ; word
DQ      .EQU $C9        ; square being drawn
DSCR    .EQU $CA        ; word: screen pointer
SQB0    .EQU $CC        ; square colour bytes (even / odd pixel rows)
SQB1    .EQU $CD
TMB     .EQU $CE        ; team colour byte
SPRP    .EQU $CF        ; word: sprite pointer
DROWS   .EQU $D1
KEYC    .EQU $D2
MCNT    .EQU $D3
U1      .EQU $D4
U2      .EQU $D5
U3      .EQU $D6
R0      .EQU $D7
R1      .EQU $D8
R2      .EQU $D9
MSGID   .EQU $DA
FROMF   .EQU $DB
TOF     .EQU $DC
CTRLF   .EQU $DD
LBLI    .EQU $DE
CHKF    .EQU $DF
GKC     .EQU $E0
LASTK   .EQU $E1

HTXT    .EQU RAM+$470   ; "U:E2E4",0
CTXT    .EQU RAM+$478   ; "C:E7E5",0
INTXT   .EQU RAM+$480   ; typed move echo

GFXMODE .EQU $24        ; CG3 128x96x4, CSS0 palette (green/yellow/blue/red)
TXTMODE .EQU $00        ; (verified against ROM at test time)
C_YEL   .EQU $55
C_RED   .EQU $FF
C_BLU   .EQU $AA
C_GRN   .EQU $00

; ---------------------------------------------------------------------
;  program entry
; ---------------------------------------------------------------------
START:  SEI
        CLR LASTK
        LDS #$8FFF
        LDAA #$FF
        STAA $00                ; port 1 = keyboard strobe outputs
        LDAA #GFXMODE
        STAA $BFFF
TITLE:  JSR TITLESCR
NEWGAME: JSR NEWPOS
        LDAA #$FF
        STAA LASTF
        STAA LASTT
        STAA HLF
        CLR INLEN
        CLR GSTATE
        LDAA HUMAN
        BEQ NG_F
        LDAA #1
NG_F:   STAA FLIP
        CLR BGB
        JSR CLS
        LDX #HTXT
        JSR INITTXT
        LDX #CTXT
        JSR INITTXT
        LDAA #$43
        STAA CTXT
        JSR DRAWSTATIC
        JSR DRAWBOARD
        JSR DRAWMOVES
GLOOP:  JSR LISTMOVES
        STAA MCNT
        BNE GL_HAVE
        JSR INCHECK             ; no legal moves: mate or stalemate
        TSTA
        BEQ GL_STALE
        LDAA MYC
        CMPA HUMAN
        BEQ GL_LOSE
        LDAA #4                 ; you win
        BRA GL_END
GL_LOSE: LDAA #5
        BRA GL_END
GL_STALE: LDAA #6
GL_END: STAA MSGID
        JSR STATUS
        LDAA #1
        STAA GSTATE
GL_WAIT: JSR GETKEY
        CMPA #$4E               ; N
        BEQ TITLE
        CMPA #$51               ; Q
        BNE GL_WAIT
        JMP QUIT
GL_HAVE: JSR INCHECK
        STAA CHKF
        LDAA MYC
        CMPA HUMAN
        BEQ HUMANTURN
; ------------------------------------------------------------------ CPU
CPUTURN: LDAA #1
        TST CHKF
        BEQ CT_M
        LDAA #7
CT_M:   STAA MSGID
        JSR STATUS
        JSR GO
        TST SEARCHOK
        BEQ CT_FB
        LDAB MYC                ; best piece's from-square
        ORAB BESTP
        LDX #SQ
        ABX
        LDAA 0,X
        STAA FROMF
        LDAA BESTM
        STAA TOF
        BRA CT_GO
CT_FB:  LDX #MLIST              ; evaluator would resign: play first legal move
        LDAA 0,X
        STAA FROMF
        LDAA 1,X
        STAA TOF
CT_GO:  JSR DOMOVE
        LDX #CTXT+2
        JSR SETTXT
        JSR DRAWBOARD
        JSR DRAWMOVES
        JMP GLOOP
; ------------------------------------------------------------------ human
HUMANTURN: LDAA #0
        TST CHKF
        BEQ HT_M
        LDAA #2
HT_M:   STAA MSGID
        JSR STATUS
        CLR INLEN
        LDAA #$FF
        STAA HLF
        JSR DRAWINPUT
HT_KEY: JSR GETKEY
        CMPA #$4E
        BEQ HT_NEW
        CMPA #$51
        BNE HT_K2
        JMP QUIT
HT_K2:  CMPA #27
        BEQ HT_CLR
        CMPA #8
        BEQ HT_BS
        CMPA #$30
        BEQ HT_BS
        CMPA #13
        BEQ HT_ENT
        LDAB INLEN
        CMPB #4
        BCC HT_KEY
        STAA U1                 ; candidate character
        BITB #1
        BNE HT_RANK
        CMPA #$41               ; file A-H
        BCS HT_KEY
        CMPA #$49
        BCC HT_KEY
        BRA HT_ADD
HT_RANK: CMPA #$31              ; rank 1-8
        BCS HT_KEY
        CMPA #$39
        BCC HT_KEY
HT_ADD: LDX #INBUF
        ABX
        LDAA U1
        STAA 0,X
        INC INLEN
        LDAA INLEN
        CMPA #2
        BNE HT_REDR
        JSR PARSEFROM           ; highlight the from-square
        LDAA FROMF
        STAA HLF
        STAA DQ
        JSR DRAWSQ
HT_REDR: JSR DRAWINPUT
        BRA HT_KEY
HT_NEW: JMP TITLE
HT_CLR: JSR UNHL
        CLR INLEN
        JSR DRAWINPUT
        BRA HT_KEY
HT_BS:  LDAA INLEN
        BEQ HT_KEY
        DEC INLEN
        LDAA INLEN
        CMPA #1
        BNE HT_REDR
        JSR UNHL
        BRA HT_REDR
HT_ENT: LDAA INLEN
        CMPA #4
        BEQ HT_E2
        JMP HT_KEY
HT_E2:
        JSR UNHL
        JSR PARSEFROM
        LDAA INBUF+2
        SUBA #$41
        STAA U1
        LDAA INBUF+3
        SUBA #$31
        ASLA
        ASLA
        ASLA
        ASLA
        ORAA U1
        STAA TOF
        LDX #MLIST              ; is it in the legal list?
        LDAB MCNT
HT_FND: LDAA 0,X
        CMPA FROMF
        BNE HT_NX
        LDAA 1,X
        CMPA TOF
        BEQ HT_OK
HT_NX:  INX
        INX
        DECB
        BNE HT_FND
        LDAA #3                 ; not legal
        STAA MSGID
        JSR STATUS
        CLR INLEN
        JSR DRAWINPUT
        JMP HT_KEY
HT_OK:  JSR DOMOVE
        LDX #HTXT+2
        JSR SETTXT
        CLR INLEN
        JSR DRAWINPUT
        JSR DRAWBOARD
        JSR DRAWMOVES
        JMP GLOOP
UNHL:   LDAA HLF
        CMPA #$FF
        BEQ UH_R
        STAA DQ
        LDAA #$FF
        STAA HLF
        JSR DRAWSQ
UH_R:   RTS
PARSEFROM:
        LDAA INBUF
        SUBA #$41
        STAA U1
        LDAA INBUF+1
        SUBA #$31
        ASLA
        ASLA
        ASLA
        ASLA
        ORAA U1
        STAA FROMF
        RTS
QUIT:   LDAA #TXTMODE
        STAA $BFFF
        LDX $FFFE               ; cold start BASIC
        JMP 0,X

; ---------------------------------------------------------------------
;  DOMOVE: play FROMF -> TOF for the side to move, switch sides.
; ---------------------------------------------------------------------
DOMOVE: LDAB MYC
        LDX #SQ
        ABX
        CLRB                    ; find piece index standing on FROMF
DM_F:   LDAA 0,X
        CMPA FROMF
        BEQ DM_G
        INX
        INCB
        CMPB #16
        BNE DM_F
DM_G:   STAB PIECE
        LDAA TOF
        STAA SQUARE
        CLR MOVEN
        JSR MOVE
        LDX #USTACK
        STX UPTR
        LDAA FROMF
        STAA LASTF
        LDAA TOF
        STAA LASTT
        JMP REVERSE
; X -> 4 chars, text of FROMF/TOF
SETTXT: LDAA FROMF
        JSR SQCH
        STAA 0,X
        STAB 1,X
        LDAA TOF
        JSR SQCH
        STAA 2,X
        STAB 3,X
        RTS
SQCH:   TAB                     ; A = square -> A file char, B rank char
        ANDA #7
        ADDA #$41
        LSRB
        LSRB
        LSRB
        LSRB
        ADDB #$31
        RTS
INITTXT: LDAA #$55              ; "U:----"
        STAA 0,X
        LDAA #$3A
        STAA 1,X
        LDAA #$2D
        STAA 2,X
        STAA 3,X
        STAA 4,X
        STAA 5,X
        CLR 6,X
        RTS

; ---------------------------------------------------------------------
;  keyboard
; ---------------------------------------------------------------------
;  SCAN: A = ASCII of a pressed key (letters, digits, ENTER=13, BREAK=27,
;        CTRL-A = 8) or 0.  Matrix: strobe a column low on port 1, read the
;        six row bits at $BFFF (active low).  CTRL/BREAK read via port 2.
SCAN:   LDAA #$FE               ; column 0 strobe: CTRL state
        STAA $02
        NOP
        NOP
        LDAB $03
        ANDB #2
        STAB CTRLF              ; 0 = CTRL held
        LDAA #$FB               ; column 2 strobe: BREAK state
        STAA $02
        NOP
        NOP
        LDAB $03
        BITB #2
        BNE SC_NB
        LDAA #27
        RTS
SC_NB:  LDAA #$FE
        STAA U2
        CLR U3
SC_COL: LDAA U2
        STAA $02
        NOP
        NOP
        LDAA $BFFF
        COMA
        ANDA #$3F
        BNE SC_HIT
SC_NX:  LDAA U2
        SEC
        ROLA
        STAA U2
        INC U3
        LDAB U3
        CMPB #8
        BNE SC_COL
        CLRA
        RTS
SC_HIT: CLRB                    ; B = row of lowest set bit
SC_R:   LSRA
        BCS SC_F
        INCB
        BRA SC_R
SC_F:   STAB U1                 ; row
        LDAA U1
        ASLA
        ASLA
        ASLA
        ADDA U3                 ; row*8+col
        LDX #KEYTAB
        TAB
        ABX
        LDAA 0,X
        BEQ SC_NX
        TST CTRLF
        BNE SC_R2
        CMPA #$41               ; CTRL-A = backspace
        BNE SC_R2
        LDAA #8
SC_R2:  RTS
GETKEY: CLR GKC
GK_L:   JSR SCAN
        TSTA
        BNE GK_D
        LDAB GKC                ; key up: after 8 empty scans forget last key
        CMPB #8
        BCC GK_L
        INCB
        STAB GKC
        CMPB #8
        BNE GK_L
        CLR LASTK
        BRA GK_L
GK_D:   CLR GKC
        CMPA LASTK              ; still holding the previous key?
        BEQ GK_L
        STAA KEYC
        JSR SCAN                ; confirm
        CMPA KEYC
        BNE GK_L
        STAA LASTK
        RTS
GETKEY_E:

; ---------------------------------------------------------------------
;  drawing
; ---------------------------------------------------------------------
CLS:    LDX #$4000
        LDAA BGB
CL_L:   STAA 0,X
        INX
        CPX #$4C00
        BNE CL_L
        RTS

; PUTC: A = ASCII ($20-$5F), draws 3x5 glyph at (TCOL,TROW) in FGB on BGB
PUTC:   SUBA #$20
        CMPA #64
        BCS PC_OK
        CLRA
PC_OK:  LDAB #5
        MUL
        ADDD #FONT
        STD TPTR
        LDAA TROW
        LDAB #32
        MUL
        ADDD #$4000
        ADDB TCOL
        STD DSCR
        LDAA #5
        STAA U1
PC_L:   LDX TPTR
        LDAA 0,X
        INX
        STX TPTR
        TAB
        ANDA FGB
        COMB
        ANDB BGB
        ABA
        LDX DSCR
        STAA 0,X
        LDAB #32
        ABX
        STX DSCR
        DEC U1
        BNE PC_L
        LDAA BGB
        LDX DSCR
        STAA 0,X
        INC TCOL
        RTS
; PUTS: X -> zero-terminated string
PUTS:   LDAA 0,X
        BEQ PS_R
        PSHX
        JSR PUTC
        PULX
        INX
        BRA PUTS
PS_R:   RTS
; PUT6: X -> exactly six characters
PUT6:   LDAB #6
        STAB U3
P6_L:   LDAA 0,X
        PSHX
        JSR PUTC
        PULX
        INX
        DEC U3
        BNE P6_L
        RTS
; PRTAT: A=col B=row X=string(zero-terminated)
PRTAT:  STAA TCOL
        STAB TROW
        BRA PUTS

; BLIT a 12x11 tile: DSCR, SPRP, TMB, SQB0/SQB1 set up by caller
BLIT:   LDAA #11
        STAA DROWS
BL_ROW: LDX SPRP
        LDAA 0,X
        TAB
        ANDA TMB
        COMB
        ANDB SQB0
        ABA
        STAA R0
        LDAA 1,X
        TAB
        ANDA TMB
        COMB
        ANDB SQB0
        ABA
        STAA R1
        LDAA 2,X
        TAB
        ANDA TMB
        COMB
        ANDB SQB0
        ABA
        STAA R2
        LDX DSCR
        LDAA R0
        STAA 0,X
        LDAA R1
        STAA 1,X
        LDAA R2
        STAA 2,X
        LDAB #32
        ABX
        STX DSCR
        LDD SPRP
        ADDD #3
        STD SPRP
        LDAA SQB0
        LDAB SQB1
        STAB SQB0
        STAA SQB1
        DEC DROWS
        BNE BL_ROW
        RTS

; DRAWSQ: draw square DQ (0x88) according to the position in MAIL
DRAWSQ: LDAA DQ
        ANDA #7
        STAA U1                 ; file
        LDAA DQ
        LSRA
        LSRA
        LSRA
        LSRA
        STAA U2                 ; rank
        ADDA U1
        ANDA #1
        STAA U3                 ; 1 = light square
        TST FLIP
        BNE DS_FL
        LDAA #7
        SUBA U2
        STAA U2
        BRA DS_P
DS_FL:  LDAA #7
        SUBA U1
        STAA U1
DS_P:   LDAA U1
        ASLA
        ADDA U1
        ADDA #2
        STAA U1                 ; byte column
        LDAA U2
        LDAB #11
        MUL
        ASLD
        ASLD
        ASLD
        ASLD
        ASLD
        ADDD #$4000
        ADDB U1
        STD DSCR
        LDAA #C_GRN
        TST U3
        BEQ DS_C
        LDAA #C_YEL
DS_C:   STAA SQB0
        STAA SQB1
        LDAA DQ
        CMPA LASTF
        BEQ DS_HL
        CMPA LASTT
        BEQ DS_HL
        CMPA HLF
        BNE DS_NH
DS_HL:  LDAA #$44
        STAA SQB0
        LDAA #$11
        STAA SQB1
DS_NH:  LDAB DQ
        LDX #MAIL
        ABX
        LDAA 0,X
        BNE DS_PC
        LDX #ZEROS
        STX SPRP
        CLR TMB
        JMP BLIT
DS_PC:  ANDA #$2F
        PSHA
        TAB
        LDX #PTYPE
        ABX
        LDAB 0,X
        LDX #GMAP
        ABX
        LDAA 0,X
        LDAB #33
        MUL
        ADDD #SPRITES
        STD SPRP
        PULA
        ANDA #$20
        BNE DS_BK
        LDAA #C_RED
        BRA DS_W
DS_BK:  LDAA #C_BLU
DS_W:   STAA TMB
        JMP BLIT

DRAWBOARD:
        CLR DQ
DB_L:   JSR DRAWSQ
        INC DQ
        LDAA DQ
        BITA #8
        BEQ DB_L
        ADDA #8
        STAA DQ
        CMPA #$80
        BNE DB_L
        RTS

; labels around the board and static text of the side panel
DRAWSTATIC:
        LDAA #C_YEL
        STAA FGB
        CLR LBLI
DL_R:   LDAA LBLI               ; rank digits, one per screen row
        TST FLIP
        BNE DL_R1
        LDAA #7
        SUBA LBLI               ; A = 7 - row
        ADDA #$31
        BRA DL_R2
DL_R1:  ADDA #$31
DL_R2:  PSHA
        LDAA LBLI
        LDAB #11
        MUL
        ADDB #3
        STAB TROW
        CLR TCOL
        PULA
        JSR PUTC
        INC LBLI
        LDAA LBLI
        CMPA #8
        BNE DL_R
        CLR LBLI
DL_F:   LDAA LBLI               ; file letters under the board
        TST FLIP
        BNE DL_F1
        ADDA #$41
        BRA DL_F2
DL_F1:  LDAA #$48
        SUBA LBLI
DL_F2:  PSHA
        LDAA LBLI
        ASLA
        ADDA LBLI
        ADDA #3
        STAA TCOL
        LDAA #89
        STAA TROW
        PULA
        JSR PUTC
        INC LBLI
        LDAA LBLI
        CMPA #8
        BNE DL_F
        LDAA #26
        LDAB #0
        LDX #T_MICRO
        JSR PRTAT
        LDAA #26
        LDAB #6
        LDX #T_CHESS
        JSR PRTAT
        LDAA #26
        LDAB #12
        LDX #T_16K
        JSR PRTAT
        LDAA #26
        LDAB #18
        LDX #T_YOUW
        TST HUMAN
        BEQ DSP1
        LDX #T_YOUB
DSP1:   JSR PRTAT
        LDAA #26
        LDAB #78
        LDX #T_NEW
        JSR PRTAT
        LDAA #26
        LDAB #84
        LDX #T_QUIT
        JSR PRTAT
        RTS

DRAWMOVES:
        LDAA #C_YEL
        STAA FGB
        LDAA #26
        LDAB #30
        LDX #HTXT
        JSR PRTAT
        LDAA #26
        LDAB #36
        LDX #CTXT
        JMP PRTAT

; typed-move echo
DRAWINPUT:
        LDAA #C_YEL
        STAA FGB
        CLRB
DI_L:   CMPB INLEN
        BCS DI_CH
        BNE DI_BL
        CMPB #4
        BCC DI_BL
        LDAA #$5F
        BRA DI_ST
DI_BL:  LDAA #$20
        BRA DI_ST
DI_CH:  LDX #INBUF
        ABX
        LDAA 0,X
DI_ST:  LDX #INTXT
        ABX
        STAA 0,X
        INCB
        CMPB #6
        BNE DI_L
        CLR 1,X
        LDAA #26
        LDAB #66
        LDX #INTXT
        JMP PRTAT

; status message: three 6-char lines from MSGTAB
STATUS: LDAA MSGID
        LDAB #18
        MUL
        ADDD #MSGTAB
        STD TPTR
        LDAA #C_RED
        STAA FGB
        LDAA #26
        STAA TCOL
        LDAA #48
        STAA TROW
        LDX TPTR
        JSR PUT6
        LDAA #26
        STAA TCOL
        LDAA #54
        STAA TROW
        JSR PUT6
        LDAA #26
        STAA TCOL
        LDAA #60
        STAA TROW
        JSR PUT6
        RTS

; ---------------------------------------------------------------------
;  title screen / colour choice
; ---------------------------------------------------------------------
TITLESCR:
        CLR BGB
        JSR CLS
        CLR LBLI
TS_B:   LDAA #5
        SUBA LBLI
        LDAB #33
        MUL
        ADDD #SPRITES
        STD SPRP
        LDAA LBLI
        ANDA #1
        BNE TS_ODD
        LDAA #C_RED
        STAA TMB
        LDAA #C_YEL
        BRA TS_P
TS_ODD: LDAA #C_BLU
        STAA TMB
        LDAA #C_GRN
TS_P:   STAA SQB0
        STAA SQB1
        LDAA LBLI
        ASLA
        ADDA LBLI
        ADDA #7
        STAA U1
        LDD #$4100
        ADDB U1
        STD DSCR
        JSR BLIT
        INC LBLI
        LDAA LBLI
        CMPA #6
        BNE TS_B
        LDAA #C_RED
        STAA FGB
        LDAA #11
        LDAB #26
        LDX #T_TITLE
        JSR PRTAT
        LDAA #C_YEL
        STAA FGB
        LDAA #8
        LDAB #34
        LDX #T_SUB1
        JSR PRTAT
        LDAA #4
        LDAB #42
        LDX #T_SUB2
        JSR PRTAT
        LDAA #12
        LDAB #60
        LDX #T_PLAY
        JSR PRTAT
        LDAA #C_RED
        STAA FGB
        LDAA #8
        LDAB #68
        LDX #T_CHOOSE
        JSR PRTAT
        LDAA #C_YEL
        STAA FGB
        LDAA #12
        LDAB #84
        LDX #T_QUIT2
        JSR PRTAT
TS_K:   JSR GETKEY
        CMPA #$57               ; W
        BEQ TS_W
        CMPA #$42               ; B
        BEQ TS_BL
        CMPA #$51               ; Q
        BNE TS_K
        JMP QUIT
TS_W:   CLR HUMAN
        RTS
TS_BL:  LDAA #$20
        STAA HUMAN
        RTS

; ---------------------------------------------------------------------
;  data
; ---------------------------------------------------------------------
T_MICRO: .strz "MICRO"
T_CHESS: .strz "CHESS"
T_16K:  .strz "16K"
T_YOUW: .strz "YOU=W"
T_YOUB: .strz "YOU=B"
T_NEW:  .strz "N=NEW"
T_QUIT: .strz "Q=QUIT"
T_TITLE: .strz "MICROCHESS"
T_SUB1: .strz "TANDY MC-10 16K"
T_SUB2: .strz "BASED ON PETER JENNINGS"
T_PLAY: .strz "PLAY AS:"
T_CHOOSE: .strz "W=WHITE  B=BLACK"
T_QUIT2: .strz "Q = QUIT"
MSGTAB: .text "YOUR  MOVE        "
        .text "THINK ING...      "
        .text "CHECK!YOUR  MOVE  "
        .text "BAD   MOVE!       "
        .text "MATE! YOU   WIN!  "
        .text "MATE! CPU   WINS  "
        .text "STALE-MATE! DRAW  "
        .text "CHECK!THINK       "
GMAP:   .BYTE 0,3,2,4,1,0,0,0,5,0,0,0,0,0,0,0,0
KEYTAB: .BYTE $00,$41,$42,$43,$44,$45,$46,$47
        .BYTE $48,$49,$4A,$4B,$4C,$4D,$4E,$4F
        .BYTE $50,$51,$52,$53,$54,$55,$56,$57
        .BYTE $58,$59,$5A,$00,$00,$00,$0D,$20
        .BYTE $30,$31,$32,$33,$34,$35,$36,$37
        .BYTE $38,$39,$3A,$3B,$2C,$2D,$2E,$2F
ZEROS:  .fill 33
        .strz "MICROCHESS (C) 1996-2002 PETER JENNINGS PETERJ@BENLO.COM"
        .strz "MC-10 16K NATIVE 6803 PORT: CASTLING, EN PASSANT, 128X96 GRAPHICS"
SPRITES:
        .BYTE $00,$00,$00,$00,$00,$00,$00,$3C,$00,$00,$FF,$00,$00,$FF,$00,$00,$3C,$00,$00,$FF,$00,$03,$FF,$C0,$00,$FF,$00,$03,$FF,$C0,$0F,$FF,$F0
        .BYTE $00,$3C,$00,$00,$FF,$00,$03,$FF,$C0,$0F,$FF,$C0,$3C,$FF,$C0,$30,$3F,$F0,$00,$3F,$F0,$00,$FF,$F0,$00,$FF,$F0,$03,$FF,$F0,$0F,$FF,$FC
        .BYTE $00,$3C,$00,$00,$FF,$00,$03,$FF,$C0,$03,$F3,$C0,$03,$CF,$C0,$00,$FF,$00,$00,$3C,$00,$00,$FF,$00,$03,$FF,$C0,$0F,$FF,$F0,$3F,$FF,$FC
        .BYTE $3C,$FF,$3C,$3F,$FF,$FC,$0F,$FF,$F0,$03,$FF,$C0,$03,$FF,$C0,$03,$FF,$C0,$03,$FF,$C0,$03,$FF,$C0,$0F,$FF,$F0,$3F,$FF,$FC,$3F,$FF,$FC
        .BYTE $C3,$3C,$C3,$F3,$FF,$FC,$3F,$FF,$FC,$0F,$FF,$F0,$03,$FF,$C0,$03,$FF,$C0,$00,$FF,$00,$03,$FF,$C0,$0F,$FF,$F0,$3F,$FF,$FC,$3F,$FF,$FC
        .BYTE $00,$3C,$00,$03,$3C,$C0,$0F,$F3,$F0,$03,$3C,$C0,$0F,$FF,$F0,$03,$FF,$C0,$03,$FF,$C0,$00,$FF,$00,$03,$FF,$C0,$0F,$FF,$F0,$3F,$FF,$FC
FONT:
        .BYTE $00,$00,$00,$00,$00,$30,$30,$30,$00,$30,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$30,$C0,$C0,$C0,$30
        .BYTE $30,$0C,$0C,$0C,$30,$CC,$30,$FC,$30,$CC,$00,$30,$FC,$30,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$FC,$00,$00,$00,$00,$00,$00,$30
        .BYTE $0C,$0C,$30,$C0,$C0,$FC,$CC,$CC,$CC,$FC,$30,$F0,$30,$30,$FC
        .BYTE $F0,$0C,$30,$C0,$FC,$F0,$0C,$30,$0C,$F0,$CC,$CC,$FC,$0C,$0C
        .BYTE $FC,$C0,$F0,$0C,$F0,$3C,$C0,$F0,$CC,$30,$FC,$0C,$30,$30,$30
        .BYTE $FC,$CC,$FC,$CC,$FC,$FC,$CC,$FC,$0C,$F0,$00,$30,$00,$30,$00
        .BYTE $00,$00,$00,$00,$00,$0C,$30,$C0,$30,$0C,$00,$FC,$00,$FC,$00
        .BYTE $C0,$30,$0C,$30,$C0,$F0,$0C,$30,$00,$30,$00,$00,$00,$00,$00
        .BYTE $30,$CC,$FC,$CC,$CC,$F0,$CC,$F0,$CC,$F0,$3C,$C0,$C0,$C0,$3C
        .BYTE $F0,$CC,$CC,$CC,$F0,$FC,$C0,$F0,$C0,$FC,$FC,$C0,$F0,$C0,$C0
        .BYTE $3C,$C0,$CC,$CC,$3C,$CC,$CC,$FC,$CC,$CC,$FC,$30,$30,$30,$FC
        .BYTE $0C,$0C,$0C,$CC,$30,$CC,$CC,$F0,$CC,$CC,$C0,$C0,$C0,$C0,$FC
        .BYTE $CC,$FC,$FC,$CC,$CC,$F0,$CC,$CC,$CC,$CC,$30,$CC,$CC,$CC,$30
        .BYTE $F0,$CC,$F0,$C0,$C0,$30,$CC,$CC,$FC,$3C,$F0,$CC,$F0,$CC,$CC
        .BYTE $3C,$C0,$30,$0C,$F0,$FC,$30,$30,$30,$30,$CC,$CC,$CC,$CC,$FC
        .BYTE $CC,$CC,$CC,$CC,$30,$CC,$CC,$FC,$FC,$CC,$CC,$CC,$30,$CC,$CC
        .BYTE $CC,$CC,$30,$30,$30,$FC,$0C,$30,$C0,$FC,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$00,$00,$FC
        .END $5000
