; Native MC6803 translation of Peter Jennings MicroChess engine.
; MicroChess (c) 1996-2002 Peter Jennings, peterj@benlo.com
; Source supplied by user: Daryl Rictor serial-terminal adaptation (2002).
; Private modified copy; retain author notice in source and binary.
; Requires MC-10 with 16K expansion. All execution is native 6803 code.
; VA/VX/VY and VF retain 6502 register/flag semantics across native calls.
; VF stores native CC bits: C=1, V=2, Z=4, N=8.
; No 6502 bytecode interpreter is used.
        .MSFIRST
        .ORG $5000
START:  STS OLDSP
        TPA
        STAA OLDCC
        SEI
        LDS #$8FFF             ; Private native stack (16K expansion)
        JSR SAVE_SCREEN
        LDAA #1
        STAA FASTMODE
        STAA QUICKMODE
        CLR LETTERMODE
        JSR NEWGAME
UI_MAIN:
        JSR DRAW
UI_WAIT:
        JSR KEY_SCAN           ; Native debounced scan; no BASIC RAM writes
        TSTA
        BNE UI_KEY
        LDAA AUTOMODE
        CMPA #1
        BNE UI_WAIT
        LDAA GAMEOVER
        BNE UI_WAIT
        INC AUTOTICKS
        LDAA AUTOTICKS
        CMPA #64              ; Allow a full debounce window between plies
        BCS UI_WAIT
        CLR AUTOTICKS
        JSR AUTO_MOVE
        JMP UI_MAIN
UI_KEY:
        CLR AUTOTICKS
        CMPA #$61
        BCS UI_UPPER
        SUBA #$20
UI_UPPER:
        LDAB INPUTLEN
        CMPB #4
        BNE UI_COMMAND
        LDAB FULLRULES
        BEQ UI_COMMAND
        LDAB INPUTBUF+3
        CMPB #$38
        BNE UI_COMMAND
        CMPA #$51
        BNE LONG_20
        JMP UI_CHAR
LONG_20:
        CMPA #$52
        BNE LONG_21
        JMP UI_CHAR
LONG_21:
        CMPA #$42
        BNE LONG_22
        JMP UI_CHAR
LONG_22:
        CMPA #$4E
        BNE LONG_23
        JMP UI_CHAR
LONG_23:
UI_COMMAND:
        CMPA #$54             ; T = toggle piece graphics / letters
        BNE UI_NOTSTYLE
        LDAA LETTERMODE
        EORA #1
        STAA LETTERMODE
        JMP UI_MAIN           ; Keep input, game and self-play state
UI_NOTSTYLE:
        CMPA #$5A              ; Hidden Z self-play / pause
        BNE UI_NOTAUTO
        LDAA AUTOMODE
        CMPA #1
        BNE UI_AUTO_ON
        LDAA #2
        BRA UI_AUTO_SET
UI_AUTO_ON:
        LDAA #1
UI_AUTO_SET:
        STAA AUTOMODE
        CLR INPUTLEN
        JMP UI_MAIN
UI_NOTAUTO:
        CMPA #$52             ; R switches historical/full rules and restarts
        BNE UI_NOTHISTORY
        LDAA FULLRULES
        EORA #1
        STAA FULLRULES
        STAA QUICKMODE
        STAA FASTMODE
        JSR NEWGAME
        JMP UI_MAIN
UI_NOTHISTORY:
        CMPA #$56             ; V claims current or entered prospective position
        BNE UI_NOTDRAW
        LDAA INPUTLEN
        CMPA #4
        BCS UI_CURRENT_CLAIM
        LDAA #1
        STAA CLAIMING
        JMP UI_ENTER
UI_CURRENT_CLAIM:
        LDAA DRAW_AVAILABLE
        BEQ UI_NOCLAIM
        LDAA FULLRULES
        BEQ UI_NOCLAIM
        LDAA #4
        STAA GAMEOVER
        JMP UI_MAIN
UI_NOCLAIM:
        LDX #MSG_NOCLAIM
        JSR MESSAGE
        JMP UI_WAIT
UI_NOTDRAW:
        CMPA #$4C             ; L toggles the modern analysis-work limit
        BNE UI_NOTLIMIT
        LDAA LIMITMODE
        EORA #1
        STAA LIMITMODE
        CLR INPUTLEN
        JMP UI_MAIN
UI_NOTLIMIT:
        CMPA #$53              ; S cycles QUICK / DEEP / ORIGINAL
        BNE UI_NOSPEED
        LDAA FULLRULES
        BEQ UI_LEGACY_SPEED
        LDAA QUICKMODE
        BEQ UI_ADVANCED_SPEED
        CLR QUICKMODE
        LDAA #1
        STAA FASTMODE
        BRA UI_SPEED_DONE
UI_ADVANCED_SPEED:
        LDAA FASTMODE
        BEQ UI_QUICK_SPEED
        CLR FASTMODE
        BRA UI_SPEED_DONE
UI_QUICK_SPEED:
        LDAA #1
        STAA QUICKMODE
        BRA UI_SPEED_DONE
UI_LEGACY_SPEED:
        LDAA FASTMODE
        EORA #1
        STAA FASTMODE
UI_SPEED_DONE:
        CLR INPUTLEN
        JMP UI_MAIN
UI_NOSPEED:
        CMPA #$51              ; Q = quit to BASIC
        BEQ UI_QUIT
        CMPA #$4E              ; N = new game
        BNE UI_NOTNEW
        JSR NEWGAME
        JMP UI_MAIN
UI_NOTNEW:
        CMPA #$49              ; I = instructions (A-H remain move coordinates)
        BNE UI_NOTHELP
        JSR DRAW_HELP
UI_HELP_WAIT:
        JSR KEY_SCAN
        CMPA #$49
        BEQ UI_HELP_BACK
        CMPA #$0D
        BNE UI_HELP_WAIT
UI_HELP_BACK:
        JMP UI_MAIN            ; Preserve the game and any partially entered move
UI_NOTHELP:
        CMPA #8                ; Backspace or left arrow
        BEQ UI_BACK
        CMPA #$15
        BEQ UI_BACK
        CMPA #$0D
        BNE UI_CHAR
        CLR CLAIMING
        JMP UI_ENTER
UI_BACK:
        LDAA INPUTLEN
        BNE LONG_13
        JMP UI_WAIT
LONG_13:
        DEC INPUTLEN
        JSR DRAW_INPUT
        JMP UI_WAIT
UI_CHAR:
        LDAB INPUTLEN
        CMPB #5
        BCS LONG_15
        JMP UI_WAIT
LONG_15:
        LDX #INPUTBUF
        ABX
        STAA 0,X
        INC INPUTLEN
        JSR DRAW_INPUT
        JMP UI_WAIT
UI_QUIT:
        JSR RESTORE_SCREEN
        LDS OLDSP
        LDAA OLDCC
        TAP
        RTS

NEWGAME:
        LDAA #1
        STAA DRAWFULL
        CLR AUTOMODE
        CLR AUTOSIDE
        CLR AUTOTICKS
        LDX #VMEM
        CLRA
NG_ZERO:
        STAA 0,X
        INX
        CPX #VMEM+256
        BNE NG_ZERO
        LDX #SETW
        LDAA FULLRULES
        BNE NG_STANDARD
        LDX #HISTSETW
NG_STANDARD:
        STX TEXTSOURCE
        LDX #BOARD
        LDAB #32
NG_COPY:
        PSHX
        LDX TEXTSOURCE
        LDAA 0,X
        INX
        STX TEXTSOURCE
        PULX
        STAA 0,X
        INX
        DECB
        BNE NG_COPY
        LDX #PROMOTED
        CLRA
NG_PROMO:
        STAA 0,X
        INX
        CPX #PROMOTED+32
        BNE NG_PROMO
        LDX #POINTVAL
        CLRB
NG_POINTS:
        PSHX
        LDX #POINTS
        ANDB #15
        ABX
        LDAA 0,X
        PULX
        STAA 0,X
        STAA 16,X
        INX
        INCB
        CMPB #16
        BNE NG_POINTS
        LDAA #$FF
        STAA OMOVE             ; Search from move one; disable old opening book
        CLR GAMEOVER
        CLR INPUTLEN
        CLR TURNCOUNT
        JSR RESET_STACKS
        JSR RULES_NEW
        JSR HISTORY_NEW
        RTS
RESET_STACKS:
        LDX #DSTACK
        STX DPTR
        LDX #USTACK
        STX UPTR
        RTS

UI_ENTER:
        LDAA GAMEOVER
        BEQ UE_ACTIVE
        JMP UI_WAIT
UE_ACTIVE:
        LDAA AUTOSIDE
        BEQ UE_HUMAN
        LDX #MSG_BLACKTURN
        JSR MESSAGE
        JMP UI_WAIT
UE_HUMAN:
        LDAA INPUTLEN
        CMPA #4
        BEQ UE_PARSE
        CMPA #5
        BEQ UE_PARSE
        JMP BAD_INPUT
UE_PARSE:
        LDAA #1
        STAA WANTPROM
        STAA PROMCHOICE
        LDAA INPUTLEN
        CMPA #5
        BNE UE_COORDS
        LDAA FULLRULES
        BEQ UE_BAD
        LDAA INPUTBUF+4
        LDAB #1
UE_PROMOTION:
        LDX #PROMOLETTERS
        ABX
        CMPA 0,X
        BEQ UE_SET_PROM
        INCB
        CMPB #5
        BNE UE_PROMOTION
        JMP BAD_INPUT
UE_SET_PROM:
        STAB WANTPROM
UE_COORDS:
        LDX #INPUTBUF
        JSR PARSE_SQUARE
        BCS UE_BAD
        STAA WANTFROM
        LDX #INPUTBUF+2
        JSR PARSE_SQUARE
        BCS UE_BAD
        STAA WANTTO
        CLRB
UE_FIND:
        LDX #BOARD
        ABX
        LDAA 0,X
        CMPA WANTFROM
        BEQ UE_FOUND
        INCB
        CMPB #16
        BNE UE_FIND
UE_BAD: JMP BAD_INPUT
UE_FOUND:
        STAB WANTPIECE
        JSR CHECK_LEGAL        ; Includes own-king check
        LDAA VALIDMOVE
        BEQ UE_BAD
        LDAA WANTPIECE
        STAA PIECE
        LDAA WANTTO
        STAA SQUARE
        CLR MOVEN
        LDAA WANTPROM
        STAA PROMCHOICE
        LDAA CLAIMING
        BEQ UE_REAL_MOVE
        CLR CLAIMING
        JSR CLAIM_TRIAL
        TSTA
        BNE LONG_19
        JMP UI_NOCLAIM
LONG_19:
        LDAA #4
        STAA GAMEOVER
        JMP UI_MAIN
UE_REAL_MOVE:
        JSR MOVE
        JSR RECORD_POSITION
        JSR RESET_STACKS
        CLR INPUTLEN
        JSR DRAW
        LDX #MSG_THINK
        JSR MESSAGE
        JSR REVERSE
        JSR FIND_LEGAL
        LDAA VALIDMOVE
        BNE LONG_16
        JMP UE_END
LONG_16:
        JSR CHECK_DRAW
        LDAA GAMEOVER
        BEQ UE_THINK
        JSR REVERSE
        JSR RESET_STACKS
        JMP UI_MAIN
UE_THINK:
        JSR ENGINE_MOVE
UE_REPLY:
        JSR RECORD_POSITION
        LDAA #$77
        SUBA BESTV             ; GO puts engine-relative from-square in BESTV
        LDAB FULLRULES
        BNE UE_STANDARD_FROM
        EORA #7
UE_STANDARD_FROM:
        STAA LASTFROM
        LDAA #$77
        SUBA BESTM
        LDAB FULLRULES
        BNE UE_STANDARD_TO
        EORA #7
UE_STANDARD_TO:
        STAA LASTTO
        JSR REVERSE
        INC TURNCOUNT
        BNE UE_COUNTED
        INC TURNCOUNT
UE_COUNTED:
        JSR RESET_STACKS
        JSR FIND_LEGAL
        LDAA VALIDMOVE
        BNE UE_CHECKDRAW
        JSR CHECK_CURRENT
        TSTA
        BEQ UE_WHITE_DRAW
        LDAA #2
        BRA UE_WHITE_END
UE_WHITE_DRAW:
        LDAA #3
UE_WHITE_END:
        STAA GAMEOVER
        BRA UE_CONTINUE
UE_CHECKDRAW:
        JSR CHECK_DRAW
UE_CONTINUE:
        JMP UI_MAIN
UE_END: JSR CHECK_CURRENT
        TSTA
        BEQ UE_BLACK_DRAW
        LDAA #1
        BRA UE_BLACK_END
UE_BLACK_DRAW:
        LDAA #3
UE_BLACK_END:
        STAA GAMEOVER
        JSR REVERSE
        JSR RESET_STACKS
        JMP UI_MAIN
BAD_INPUT:
        CLR CLAIMING
        CLR INPUTLEN
        JSR DRAW_INPUT
        LDX #MSG_ILLEGAL
        JSR MESSAGE
        JMP UI_WAIT

PARSE_SQUARE:
        LDAA 0,X
        CMPA #$41
        BCS PS_BAD
        CMPA #$48
        BHI PS_BAD
        SUBA #$41
        STAA UITMP
        LDAA 1,X
        CMPA #$31
        BCS PS_BAD
        CMPA #$38
        BHI PS_BAD
        SUBA #$31
        ASLA
        ASLA
        ASLA
        ASLA
        ORAA UITMP
        LDAB FULLRULES
        BNE PS_STANDARD
        EORA #7
PS_STANDARD:
        CLC
        RTS
PS_BAD: SEC
        RTS
VALIDATE_CANDIDATE:
        LDAA QUICKSCAN
        BEQ VC_NORMAL
        JMP QUICK_CANDIDATE
VC_NORMAL:
        LDAA WANTPIECE
        CMPA #$FF
        BNE VC_COMPARE
        LDAA VALIDMOVE
        BNE VC_DONE
        LDAA PIECE
        STAA FIRSTPIECE
        LDAA SQUARE
        STAA FIRSTTO
        LDAA PROMCHOICE
        STAA FIRSTPROM
        BRA VC_SUCCESS
VC_COMPARE:
        LDAA PIECE
        CMPA WANTPIECE
        BNE VC_DONE
        LDAA SQUARE
        CMPA WANTTO
        BNE VC_DONE
        LDAA PROMCHOICE
        CMPA WANTPROM
        BNE VC_DONE
VC_SUCCESS:
        LDAA #1
        STAA VALIDMOVE
        JSR RESET_STACKS       ; Stop enumeration once a match is found
        CLR VALIDATING
        LDS VALIDSP            ; Board trials already undone by CMOVE
        RTS                    ; Return directly from CHECK_LEGAL
VC_DONE:
        RTS
FIND_LEGAL:
        LDAA #$FF
        STAA WANTPIECE
CHECK_LEGAL:
        JSR RESET_STACKS
        CLR VALIDMOVE
        LDAA #1
        STAA VALIDATING
        LDAA #4
        STAA STATE
        STS VALIDSP
        JSR GENERATE_TARGET
        CLR VALIDATING
        RTS
GENERATE_TARGET:
        LDAA WANTPIECE
        CMPA #$FF
        BNE GT_PIECE
        JMP GNM
GT_PIECE:
        TSTA
        BNE GT_START
        JSR GENERATE_CASTLES
GT_START:
        LDAA WANTPIECE
        INCA
        STAA PIECE
        JMP NEWP
CHECK_CURRENT:
        JSR RESET_STACKS
        JMP NATIVE_CHECK
; 128x96 monochrome bitmap at $4000, white/black palette (VDG mode 14).
; BASIC's whole overlapping $4000-$45FF region is saved and restored.
SAVE_SCREEN:
        LDX #SCREENBACKUP
        STX COPYDEST
        LDX #$4000
SS_LOOP:
        LDAA 0,X
        INX
        STX COPYSOURCE
        LDX COPYDEST
        STAA 0,X
        INX
        STX COPYDEST
        LDX COPYSOURCE
        CPX #$4600
        BNE SS_LOOP
        LDAA $00
        STAA OLDDDR
        LDAA $02
        STAA OLDSTROBE
        LDAA #$FF
        STAA $00
        LDAA #$78
        STAA $BFFF
        RTS
RESTORE_SCREEN:
        LDX #$4000
        STX COPYDEST
        LDX #SCREENBACKUP
RS_LOOP:
        LDAA 0,X
        INX
        STX COPYSOURCE
        LDX COPYDEST
        STAA 0,X
        INX
        STX COPYDEST
        LDX COPYSOURCE
        CPX #SCREENBACKUP+1536
        BNE RS_LOOP
        LDAA OLDDDR
        STAA $00
        LDAA OLDSTROBE
        STAA $02
        CLRA
        STAA $BFFF
        RTS
KEY_SCAN:
        JSR KEY_RAW
        CMPA KEYCAND
        BEQ KS_STABLE
        STAA KEYCAND
        LDAB #16
        STAB KEYCOUNT
        CLRA
        RTS
KS_STABLE:
        LDAB KEYCOUNT
        BEQ KS_READY
        DEC KEYCOUNT
        CLRA
        RTS
KS_READY:
        CMPA LASTKEY
        BEQ KS_NONE
        STAA LASTKEY
        RTS
KS_NONE: CLRA
        RTS
KEY_RAW:
        CLR KEYCOL
KR_COL:
        LDAB KEYCOL
        LDX #COLUMNMASKS
        ABX
        LDAA 0,X
        STAA $02
        LDAA $BFFF
        COMA
        ANDA #$3F
        BEQ KR_NEXT
        CLRB
KR_ROW:
        LSRA
        BCS KR_FOUND
        INCB
        BRA KR_ROW
KR_FOUND:
        ASLB
        ASLB
        ASLB
        ADDB KEYCOL
        LDX #KEYMAP
        ABX
        LDAA 0,X
        RTS
KR_NEXT:
        INC KEYCOL
        LDAA KEYCOL
        CMPA #8
        BNE KR_COL
        CLRA
        RTS

AUTO_MOVE:
        LDX #MSG_AUTO_THINK
        JSR MESSAGE
        JSR RESET_STACKS
        LDAA AUTOSIDE
        BEQ AM_READY
        JSR REVERSE
AM_READY:
        JSR FIND_LEGAL
        LDAA VALIDMOVE
        BNE AM_DRAW
        JSR CHECK_CURRENT
        TSTA
        BEQ AM_STALEMATE
        LDAA #2               ; White is mated
        SUBA AUTOSIDE         ; Black is mated -> 1
        BRA AM_END
AM_STALEMATE:
        LDAA #3
AM_END:
        STAA GAMEOVER
        BRA AM_STOP
AM_DRAW:
        JSR CHECK_DRAW
        LDAA GAMEOVER
        BNE AM_STOP
        LDAA FULLRULES
        BEQ AM_PLAY
        LDAA DRAW_AVAILABLE    ; Both computer colors claim available draws
        BEQ AM_PLAY
        LDAA #4
        STAA GAMEOVER
        BRA AM_STOP
AM_PLAY:
        JSR ENGINE_MOVE
        JSR RECORD_POSITION
        LDAA BESTV
        LDAB AUTOSIDE
        BEQ AM_FROM
        EORA #$77
AM_FROM:
        LDAB FULLRULES
        BNE AM_FROM_STANDARD
        EORA #7
AM_FROM_STANDARD:
        STAA LASTFROM
        LDAA BESTM
        LDAB AUTOSIDE
        BEQ AM_TO
        EORA #$77
AM_TO:
        LDAB FULLRULES
        BNE AM_TO_STANDARD
        EORA #7
AM_TO_STANDARD:
        STAA LASTTO
        LDAA AUTOSIDE
        BEQ AM_TOGGLE
        JSR REVERSE           ; Display and pause always retain White orientation
AM_TOGGLE:
        LDAA AUTOSIDE
        EORA #1
        STAA AUTOSIDE
        INC TURNCOUNT
        BNE AM_RETURN
        INC TURNCOUNT
AM_RETURN:
        JMP RESET_STACKS
AM_STOP:
        LDAA #2
        STAA AUTOMODE
        LDAA AUTOSIDE
        BEQ AM_RETURN
        JSR REVERSE
        BRA AM_RETURN
ENGINE_MOVE:
        CLR BOOKHIT
        LDAA FULLRULES
        BEQ EM_ORIGINAL
        LDAA QUICKMODE
        BEQ EM_ORIGINAL
        JSR BOOK_TRY
        LDAA SEARCHOK
        BNE ENGINE_DONE
        JSR QUICK_GO
        LDAA SEARCHOK
        BNE ENGINE_DONE
        BRA EM_FALLBACK
EM_ORIGINAL:
        LDAA #$FF
        STAA OMOVE
        CLR SEARCHOK
        JSR GO
        LDAA SEARCHOK
        BNE ENGINE_DONE
EM_FALLBACK:
        LDAA FIRSTPIECE        ; Legal fallback if old evaluator resigns
        STAA PIECE
        STAA BESTP
        LDAB PIECE
        LDX #BOARD
        ABX
        LDAA 0,X
        STAA BESTV
        LDAA FIRSTTO
        STAA SQUARE
        STAA BESTM
        LDAA FIRSTPROM
        STAA PROMCHOICE
        JSR MOVE
ENGINE_DONE: RTS

DRAW:
        LDAA DRAWFULL
        BEQ GD_START
        LDX #$4000
        LDAA #$FF
GD_CLEAR:
        STAA 0,X
        INX
        CPX #$4600
        BNE GD_CLEAR
GD_START:
        CLR UIROW
GD_ROW:
        CLR UICOL
GD_COL:
        LDAA UICOL
        LDAB #10
        MUL
        ADDB #8
        STAB TILEX
        LDAA UIROW
        LDAB #10
        MUL
        ADDB #8
        STAB TILEY
        LDAA UIROW
        EORA UICOL
        ANDA #1
        STAA TILEBG
        CLR HIGHLIGHT
        LDAA TURNCOUNT
        BEQ GD_NO_HIGHLIGHT
        LDAA #7
        SUBA UIROW
        ASLA
        ASLA
        ASLA
        ASLA
        ORAA UICOL
        CMPA LASTFROM
        BEQ GD_HIGHLIGHT
        CMPA LASTTO
        BNE GD_NO_HIGHLIGHT
GD_HIGHLIGHT:
        INC HIGHLIGHT
GD_NO_HIGHLIGHT:
        LDAA #7
        SUBA UIROW
        ASLA
        ASLA
        ASLA
        ASLA
        ORAA UICOL
        LDAB FULLRULES
        BNE GD_CACHE_STANDARD
        EORA #7
GD_CACHE_STANDARD:
        JSR LOOKUP
        STAA DRAWPIECE
        CMPA #$FF
        BEQ GD_EMPTY_KEY
        TAB
        JSR TYPE_OF
        LDAB DRAWPIECE
        CMPB #16
        BCS GD_STYLE_KEY
        ORAA #8
GD_STYLE_KEY:
        LDAB LETTERMODE
        BEQ GD_STYLE_READY
        ORAA #32              ; Appearance cache includes the piece style
GD_STYLE_READY:
        BRA GD_VISUAL_KEY
GD_EMPTY_KEY:
        CLRA
GD_VISUAL_KEY:
        LDAB HIGHLIGHT
        BEQ GD_KEY_READY
        ORAA #16
GD_KEY_READY:
        PSHA
        LDAA UIROW
        ASLA
        ASLA
        ASLA
        ORAA UICOL
        TAB
        LDX #TILECACHE
        ABX
        PULA
        CMPA 0,X
        BNE GD_DIRTY
        LDAB DRAWFULL
        BNE GD_DIRTY
        JMP GD_NEXT
GD_DIRTY:
        STAA 0,X
        CLR PIXROW
GD_TILE_ROW:
        CLR PIXCOL
GD_TILE_COL:
        LDAA TILEX
        ADDA PIXCOL
        STAA GX
        LDAA TILEY
        ADDA PIXROW
        STAA GY
        LDAA #1
        LDAB TILEBG
        BEQ GD_BG
        LDAA GX
        EORA GY
        ANDA #1
GD_BG:
        LDAB HIGHLIGHT
        BEQ GD_BG_PLOT
        LDAB PIXROW
        BEQ GD_BG_FLIP
        CMPB #9
        BEQ GD_BG_FLIP
        LDAB PIXCOL
        BEQ GD_BG_FLIP
        CMPB #9
        BNE GD_BG_PLOT
GD_BG_FLIP:
        EORA #1
GD_BG_PLOT:
        JSR PLOT
        INC PIXCOL
        LDAA PIXCOL
        CMPA #10
        BNE GD_TILE_COL
        INC PIXROW
        LDAA PIXROW
        CMPA #10
        BNE GD_TILE_ROW
        LDAA DRAWPIECE
        CMPA #$FF
        BNE LONG_30
        JMP GD_NEXT
LONG_30:
        TAB
        JSR TYPE_OF
        DECA
        LDAB #16
        LDX #SPRITES
        TST LETTERMODE
        BEQ GD_SPR_POINTER
        LDAB #8
        LDX #LETTERSPRITES-8   ; Reuse the sprite interior/color drawing path
GD_SPR_POINTER:
        STX SPRITEPTR
        MUL
        ADDD SPRITEPTR
        STD SPRITEPTR
        CLR PIXROW
GD_SPR_ROW:
        CLR PIXCOL
GD_SPR_COL:
        LDAB PIXCOL
        LDX #BITMASKS
        ABX
        LDAA 0,X
        STAA SPRMASK
        LDAB PIXROW
        LDX SPRITEPTR
        ABX
        TST LETTERMODE
        BNE GD_SPR_INTERIOR    ; Letter tiles have a solid 8x8 background
        LDAA 0,X
        ANDA SPRMASK
        BEQ GD_SPR_NEXT
GD_SPR_INTERIOR:
        LDAA 8,X
        ANDA SPRMASK
        BEQ GD_OUTLINE
        LDAA #1
        BRA GD_COLOR
GD_OUTLINE:
        CLRA
GD_COLOR:
        LDAB DRAWPIECE
        CMPB #16
        BCS GD_PAINT
        EORA #1
GD_PAINT:
        PSHA
        LDAA TILEX
        INCA
        ADDA PIXCOL
        STAA GX
        LDAA TILEY
        INCA
        ADDA PIXROW
        STAA GY
        PULA
        JSR PLOT
GD_SPR_NEXT:
        INC PIXCOL
        LDAA PIXCOL
        CMPA #8
        BNE GD_SPR_COL
        INC PIXROW
        LDAA PIXROW
        CMPA #8
        BNE GD_SPR_ROW
GD_NEXT:
        INC UICOL
        LDAA UICOL
        CMPA #8
        BEQ LONG_4
        JMP GD_COL
LONG_4:
        INC UIROW
        LDAA UIROW
        CMPA #8
        BEQ LONG_5
        JMP GD_ROW
LONG_5:
        LDAA DRAWFULL
        BNE GD_STATIC
        JMP GD_SIDEBAR
GD_STATIC:
        CLR UIROW
GD_LABEL:
        LDAA UIROW
        LDAB #10
        MUL
        ADDB #12
        STAB CHARX
        LDAA #1
        STAA CHARY
        LDAA UIROW
        ADDA #$41
        JSR G_CHAR
        LDAA #1
        STAA CHARX
        LDAA UIROW
        LDAB #10
        MUL
        ADDB #11
        STAB CHARY
        LDAA #$38
        SUBA UIROW
        JSR G_CHAR
        INC UIROW
        LDAA UIROW
        CMPA #8
        BNE GD_LABEL
        CLR DRAWFULL
GD_SIDEBAR:
        LDX #TITLE
        LDAA #5
        JSR G_SIDE
        LDX #RULELABEL
        LDAA #13
        JSR G_SIDE
        LDX #RULETITLE
        LDAA FULLRULES
        BNE GD_RULE
        LDX #HISTTITLE
GD_RULE:
        LDAA #19
        JSR G_SIDE
        LDX #RULECLASSIC
        LDAA FULLRULES
        BNE GD_RULE_KEY
        LDX #RULEMODERN
GD_RULE_KEY:
        LDAA #25
        JSR G_SIDE
        LDX #SEARCHLABEL
        LDAA #33
        JSR G_SIDE
        LDX #QUICKTITLE
        LDAA FULLRULES
        BEQ GD_LEGACY_SPEED
        LDAA QUICKMODE
        BNE GD_SPEED
GD_LEGACY_SPEED:
        LDX #ORIGTITLE
        LDAA FASTMODE
        BEQ GD_SPEED
        LDX #FASTTITLE
GD_SPEED:
        LDAA #39
        JSR G_SIDE
        LDX #SEARCHDEEP
        LDAA FULLRULES
        BEQ GD_LEGACY_KEY
        LDAA QUICKMODE
        BNE GD_SPEED_KEY
        LDX #SEARCHQUICK
        LDAA FASTMODE
        BEQ GD_SPEED_KEY
GD_LEGACY_KEY:
        LDX #SEARCHDEEP
        LDAA FASTMODE
        BEQ GD_SPEED_KEY
        LDX #SEARCHORIG
GD_SPEED_KEY:
        LDAA #45
        JSR G_SIDE
        LDX #QUICKLIMIT
        LDAA FULLRULES
        BEQ GD_NORMAL_LIMIT
        LDAA QUICKMODE
        BNE GD_LIMIT
GD_NORMAL_LIMIT:
        LDX #LIMITOFF
        LDAA FULLRULES
        BEQ GD_HIST_LIMIT
        LDAA LIMITMODE
        BEQ GD_LIMIT
        LDX #LIMITON
        BRA GD_LIMIT
GD_HIST_LIMIT:
        LDX #UNLIMITED
GD_LIMIT:
        LDAA #53
        JSR G_SIDE
        LDX #QUICKLIMIT+5      ; Blank L action when QUICK or CLASSIC is selected
        LDAA FULLRULES
        BEQ GD_LIMIT_KEY
        LDAA QUICKMODE
        BNE GD_LIMIT_KEY
        LDX #LIMITKEYON
        LDAA LIMITMODE
        BEQ GD_LIMIT_KEY
        LDX #LIMITKEYOFF
GD_LIMIT_KEY:
        LDAA #59
        JSR G_SIDE
GD_HELP:
        LDX #HELP
        LDAA #65
        JSR G_SIDE
        LDX #HELP4
        LDAA #71
        JSR G_SIDE
        LDX #STYLELETTERS
        LDAA LETTERMODE
        BEQ GD_STYLE_ACTION
        LDX #STYLEGRAPHICS
GD_STYLE_ACTION:
        LDAA #77
        JSR G_SIDE
        LDX #HELP3
        LDAA #83
        JSR G_SIDE
        LDAA GAMEOVER
        BEQ DRAW_INPUT
        CMPA #1
        BNE GD_LOSE
        LDX #MSG_WIN
        JMP MESSAGE
GD_LOSE:
        CMPA #2
        BNE GD_DRAW
        LDX #MSG_LOSE
        JMP MESSAGE
GD_DRAW:
        LDX #MSG_DRAW
        JMP MESSAGE
DRAW_INPUT:
        JSR CLEAR_FOOTER
        LDAA AUTOMODE
        BEQ GI_MANUAL
        LDX #AUTO_PAUSED
        CMPA #2
        BEQ GI_PROMPT
        LDX #AUTO_WHITE
        LDAA AUTOSIDE
        BEQ GI_PROMPT
        LDX #AUTO_BLACK
        BRA GI_PROMPT
GI_MANUAL:
        JSR NATIVE_CHECK
        TSTA
        BEQ GI_READY
        LDX #CHECKPROMPT
        BRA GI_PROMPT
GI_READY:
        LDX #PROMPT
GI_PROMPT:
        JSR G_TEXT
        LDX #INPUTBUF
        STX TEXTSOURCE
        CLR INPUTINDEX
GI_LOOP:
        LDAA INPUTINDEX
        CMPA INPUTLEN
        BEQ GI_DONE
        TAB
        LDX #INPUTBUF
        ABX
        LDAA 0,X
        JSR G_CHAR
        LDAA CHARX
        ADDA #4
        STAA CHARX
        INC INPUTINDEX
        BRA GI_LOOP
GI_DONE:
        LDAA #89
        STAA PADEND
        JSR G_PAD
        LDAA TURNCOUNT
        BEQ GI_RETURN
        LDX #LASTLABEL
        LDAA #90
        STAA CHARY
        LDAA #89
        STAA CHARX
        JSR G_TEXT
        LDAA LASTFROM
        JSR G_COORD
        LDAA LASTTO
        JSR G_COORD
GI_RETURN:
        LDAA #128
        STAA PADEND
        JMP G_PAD
MESSAGE:
        PSHX
        JSR CLEAR_FOOTER
        PULX
        JSR G_TEXT
        LDAA #128
        STAA PADEND
        JMP G_PAD
CLEAR_FOOTER:
        LDAA #1
        STAA CHARX
        LDAA #90
        STAA CHARY
        RTS
G_SIDE:
        STAA CHARY
        LDAA #89
        STAA CHARX
        JSR G_TEXT
        LDAA #128
        STAA PADEND
G_PAD:
        LDAA CHARX
        CMPA PADEND
        BCC GPAD_DONE
        LDAA #32
        JSR G_CHAR
        LDAA CHARX
        ADDA #4
        STAA CHARX
        BRA G_PAD
GPAD_DONE: RTS
DRAW_HELP:
        LDAA #1
        STAA DRAWFULL
        LDX #$4000
        LDAA #$FF
GH_CLEAR:
        STAA 0,X
        INX
        CPX #$4600
        BNE GH_CLEAR
        CLR CHARY
        LDX #INSTRUCTIONS
GH_LINE:
        LDAA #1
        STAA CHARX
        JSR G_TEXT
        LDX TEXTSOURCE
        INX
        LDAA CHARY
        ADDA #6
        STAA CHARY
        CMPA #96
        BNE GH_LINE
        RTS
G_TEXT:
        STX TEXTSOURCE
GT_LOOP:
        LDX TEXTSOURCE
        LDAA 0,X
        BEQ GT_DONE
        INX
        STX TEXTSOURCE
        JSR G_CHAR
        LDAA CHARX
        ADDA #4
        STAA CHARX
        BRA GT_LOOP
GT_DONE: RTS
G_COORD:
        PSHA
        ANDA #7
        ADDA #$41
        JSR G_CHAR
        LDAA CHARX
        ADDA #4
        STAA CHARX
        PULA
        LSRA
        LSRA
        LSRA
        LSRA
        ADDA #$31
        JSR G_CHAR
        LDAA CHARX
        ADDA #4
        STAA CHARX
        RTS
G_CHAR:
; All font callers use fixed, checked positions (x<=125, y<=90).
        SUBA #32
        LDAB #5
        MUL
        ADDD #SMALLFONT
        STD FONTPTR
        LDAA CHARX
        ANDA #7
        STAA FONTCOL
        LDD #$E000
GF_MASK:
        TST FONTCOL
        BEQ GF_ADDRESS
        LSRD
        DEC FONTCOL
        BRA GF_MASK
GF_ADDRESS:
        STD GLYPHMASK
        LDAA CHARY
        LDAB #16
        MUL
        ADDD #$4000
        STD PIXPTR
        LDAA CHARX
        LSRA
        LSRA
        LSRA
        TAB
        CLRA
        ADDD PIXPTR
        STD PIXPTR
        CLR FONTROW
GF_ROW:
        LDX FONTPTR
        LDAA 0,X
        INX
        STX FONTPTR
        ASLA
        ASLA
        ASLA
        ASLA
        ASLA
        CLRB
        PSHA
        LDAA CHARX
        ANDA #7
        STAA FONTCOL
        PULA
GF_BITS:
        TST FONTCOL
        BEQ GF_PAINT
        LSRD
        DEC FONTCOL
        BRA GF_BITS
GF_PAINT:
        COMA
        COMB
        STD GLYPHWHITE
        LDX PIXPTR
        LDD 0,X
        ORAA GLYPHMASK
        ORAB GLYPHMASK+1
        ANDA GLYPHWHITE
        ANDB GLYPHWHITE+1
        CMPA 0,X
        BEQ GF_LOW
        STAA 0,X
GF_LOW:
        CMPB 1,X
        BEQ GF_NEXT
        STAB 1,X
GF_NEXT:
        LDD PIXPTR
        ADDD #16
        STD PIXPTR
        INC FONTROW
        LDAA FONTROW
        CMPA #5
        BNE GF_ROW
GF_DONE: RTS
; GX/GY pixel; A=0 black or 1 white. Safe clipping.
PLOT:
        STAA PLOTCOLOR
        LDAA GX
        CMPA #128
        BCC GP_DONE
        ANDA #7
        TAB
        LDX #BITMASKS
        ABX
        LDAA 0,X
        STAA PLOTMASK
        LDAA GY
        CMPA #96
        BCC GP_DONE
        LDAB #16
        MUL
        ADDD #$4000
        STD PIXPTR
        LDAB GX
        LSRB
        LSRB
        LSRB
        LDX PIXPTR
        ABX
        LDAA PLOTCOLOR
        BEQ GP_BLACK
        LDAA 0,X
        ORAA PLOTMASK
        BRA GP_STORE
GP_BLACK:
        LDAA PLOTMASK
        COMA
        ANDA 0,X
GP_STORE:
        CMPA 0,X              ; Avoid writes to unchanged pixels/text bytes
        BEQ GP_DONE
        STAA 0,X
GP_DONE: RTS
TITLE: .TEXT "MICROCHESS"
        .BYTE 0
RULELABEL: .TEXT "I HELP"
        .BYTE 0
RULETITLE: .TEXT "MODERN"
        .BYTE 0
HISTTITLE: .TEXT "CLASSIC"
        .BYTE 0
RULECLASSIC: .TEXT "R CLASSIC"
        .BYTE 0
RULEMODERN: .TEXT "R MODERN"
        .BYTE 0
SEARCHLABEL: .TEXT "SEARCH"
        .BYTE 0
ORIGTITLE: .TEXT "ORIGINAL"
        .BYTE 0
FASTTITLE: .TEXT "DEEP"
        .BYTE 0
SEARCHDEEP: .TEXT "S DEEP"
        .BYTE 0
QUICKTITLE: .TEXT "QUICK"
        .BYTE 0
SEARCHQUICK: .TEXT "S QUICK"
        .BYTE 0
QUICKLIMIT: .TEXT "1 PLY"
        .BYTE 0
QUICKMODE: .BYTE 1
SEARCHORIG: .TEXT "S ORIGINAL"
        .BYTE 0
LIMITON: .TEXT "LIMIT ON"
        .BYTE 0
LIMITOFF: .TEXT "LIMIT OFF"
        .BYTE 0
UNLIMITED: .TEXT "UNLIMITED"
        .BYTE 0
LIMITKEYOFF: .TEXT "L OFF"
        .BYTE 0
LIMITKEYON: .TEXT "L ON"
        .BYTE 0
HELP: .TEXT "N NEW"
        .BYTE 0
HELP3: .TEXT "Q BASIC"
        .BYTE 0
HELP4: .TEXT "V CLAIM"
        .BYTE 0
STYLELETTERS: .TEXT "T LETTERS"
        .BYTE 0
STYLEGRAPHICS: .TEXT "T GRAPHICS"
        .BYTE 0
LETTERMODE: .BYTE 0
LASTLABEL: .TEXT "LAST "
        .BYTE 0
INSTRUCTIONS:
        .TEXT "MICROCHESS: YOU ARE WHITE"
        .BYTE 0
        .TEXT "MOVE: E2E4 THEN ENTER"
        .BYTE 0
        .TEXT "PROMOTE: A7A8Q/R/B/N"
        .BYTE 0
        .TEXT "BACKSPACE: EDIT"
        .BYTE 0
        .TEXT "R: RULES / RESTART"
        .BYTE 0
        .TEXT "MODERN: FULL CHESS RULES"
        .BYTE 0
        .TEXT "CLASSIC: OLD RULES"
        .BYTE 0
        .TEXT "S: QUICK / DEEP / ORIGINAL"
        .BYTE 0
        .TEXT "QUICK: BOOK / 1 PLY"
        .BYTE 0
        .TEXT "L: LIMIT ON/OFF"
        .BYTE 0
        .TEXT "LIMIT ON: SHORTER SEARCH"
        .BYTE 0
        .TEXT "T: LETTERS / GRAPHICS"
        .BYTE 0
        .TEXT "N: NEW  Q: BASIC"
        .BYTE 0
        .TEXT "V: DRAW CLAIM / MOVE THEN V"
        .BYTE 0
        .TEXT "P N B R Q K: PIECE LETTERS"
        .BYTE 0
        .TEXT "I / ENTER: RETURN"
        .BYTE 0
MSG_THINK: .TEXT "BLACK THINKING..."
        .BYTE 0
MSG_ILLEGAL: .TEXT "ILLEGAL MOVE"
        .BYTE 0
MSG_WIN: .TEXT "MATE - YOU WIN"
        .BYTE 0
MSG_LOSE: .TEXT "MATE - BLACK WINS"
        .BYTE 0
MSG_DRAW: .TEXT "DRAW - N NEW GAME"
        .BYTE 0
PROMPT: .TEXT "MOVE: "
        .BYTE 0
BITMASKS: .BYTE $80,$40,$20,$10,8,4,2,1
FONTBITS: .BYTE 4,2,1
COLUMNMASKS: .BYTE $FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F
KEYMAP: .BYTE 0,65,66,67,68,69,70,71
        .BYTE 72,73,74,75,76,77,78,79
        .BYTE 80,81,82,83,84,85,86,87
        .BYTE 88,89,90,0,0,0,13,32
        .BYTE 48,49,50,51,52,53,54,55
        .BYTE 56,57,0,8,0,0,0,0
COPYDEST: .WORD 0
COPYSOURCE: .WORD 0
OLDDDR: .BYTE 0
OLDSTROBE: .BYTE 0
KEYCOL: .BYTE 0
KEYCAND: .BYTE 0
KEYCOUNT: .BYTE 0
LASTKEY: .BYTE 0
GX: .BYTE 0
GY: .BYTE 0
PLOTCOLOR: .BYTE 0
PLOTMASK: .BYTE 0
PIXPTR: .WORD 0
TILEX: .BYTE 0
TILEY: .BYTE 0
TILEBG: .BYTE 0
PIXROW: .BYTE 0
PIXCOL: .BYTE 0
DRAWPIECE: .BYTE 0
SPRITEPTR: .WORD 0
SPRMASK: .BYTE 0
CHARX: .BYTE 0
CHARY: .BYTE 0
FONTROW: .BYTE 0
FONTCOL: .BYTE 0
FONTMASK: .BYTE 0
FONTPTR: .WORD 0
INPUTINDEX: .BYTE 0

JANUS:  JSR BUDGET_TICK
        LDAA VALIDATING
        BEQ JANUS_ENGINE
        LDAA STATE
        CMPA #4
        BNE JANUS_ENGINE
        JMP VALIDATE_CANDIDATE
JANUS_ENGINE:
; 6502: LDX STATE
        LDAA VMEM+$B5
        JSR H_NZ
        STAA VX
; 6502: BMI NOCOUNT
        LDAA VF
        ANDA #8
        BEQ SKIP_1
        JMP NOCOUNT
SKIP_1:
COUNTS:
; 6502: LDA PIECE
        LDAA VMEM+$B0
        JSR H_NZ
        STAA VA
; 6502: BEQ OVER
        LDAA VF
        ANDA #4
        BEQ SKIP_2
        JMP OVER
SKIP_2:
; 6502: CPX #$08
        LDAA #$08
        STAA OPERAND
        JSR H_CPX
; 6502: BNE OVER
        LDAA VF
        ANDA #4
        BNE SKIP_3
        JMP OVER
SKIP_3:
; 6502: CMP BMAXP
        LDAA VMEM+$E6
        STAA OPERAND
        JSR H_CMP
; 6502: BEQ XRT
        LDAA VF
        ANDA #4
        BEQ SKIP_4
        JMP XRT
SKIP_4:
OVER:
; 6502: INC MOB,X
        LDX #VMEM+$E3
        LDAB VX
        ABX
        LDAA 0,X
        INCA
        JSR H_NZ
        LDX #VMEM+$E3
        LDAB VX
        ABX
        STAA 0,X
; 6502: CMP #$01
        LDAA #$01
        STAA OPERAND
        JSR H_CMP
; 6502: BNE NOQ
        LDAA VF
        ANDA #4
        BNE SKIP_5
        JMP NOQ
SKIP_5:
; 6502: INC MOB,X
        LDX #VMEM+$E3
        LDAB VX
        ABX
        LDAA 0,X
        INCA
        JSR H_NZ
        LDX #VMEM+$E3
        LDAB VX
        ABX
        STAA 0,X
NOQ:
; 6502: BVC NOCAP
        LDAA VF
        ANDA #2
        BNE SKIP_6
        JMP NOCAP
SKIP_6:
; 6502: LDY #$0F
        LDAA #$0F
        JSR H_NZ
        STAA VY
; 6502: LDA SQUARE
        LDAA VMEM+$B1
        JSR H_NZ
        STAA VA
ELOOP:  JSR EP_CAPTURE
        CMPA #$FF
        BEQ ELOOP_NORMAL
        SUBA #16
        STAA VY
        JMP FOUN
ELOOP_NORMAL:
; 6502: CMP BK,Y
        LDX #VMEM+$60
        LDAB VY
        ABX
        LDAA 0,X
        STAA OPERAND
        JSR H_CMP
; 6502: BEQ FOUN
        LDAA VF
        ANDA #4
        BEQ SKIP_7
        JMP FOUN
SKIP_7:
; 6502: DEY 
        LDAA VY
        DECA
        JSR H_NZ
        STAA VY
; 6502: BPL ELOOP
        LDAA VF
        ANDA #8
        BNE SKIP_8
        JMP ELOOP
SKIP_8:
FOUN:
; 6502: LDA POINTS,Y
        LDX #POINTVAL+16
        LDAB VY
        ABX
        LDAA 0,X
        JSR H_NZ
        STAA VA
; 6502: CMP MAXC,X
        LDX #VMEM+$E4
        LDAB VX
        ABX
        LDAA 0,X
        STAA OPERAND
        JSR H_CMP
; 6502: BCC LESS
        LDAA VF
        ANDA #1
        BNE SKIP_9
        JMP LESS
SKIP_9:
; 6502: STY PCAP,X
        LDAA VY
        LDX #VMEM+$E6
        LDAB VX
        ABX
        STAA 0,X
; 6502: STA MAXC,X
        LDAA VA
        LDX #VMEM+$E4
        LDAB VX
        ABX
        STAA 0,X
LESS:
; 6502: CLC 
        LDAA VF
        ANDA #$FE
        STAA VF
; 6502: PHP 
        LDAA VF
        JSR DATA_PUSH
; 6502: ADC CC,X
        LDX #VMEM+$E5
        LDAB VX
        ABX
        LDAA 0,X
        STAA OPERAND
        JSR H_ADC
; 6502: STA CC,X
        LDAA VA
        LDX #VMEM+$E5
        LDAB VX
        ABX
        STAA 0,X
; 6502: PLP 
        JSR DATA_POP
        STAA VF
NOCAP:
; 6502: CPX #$04
        LDAA #$04
        STAA OPERAND
        JSR H_CPX
; 6502: BEQ ON4
        LDAA VF
        ANDA #4
        BEQ SKIP_10
        JMP ON4
SKIP_10:
; 6502: BMI TREE
        LDAA VF
        ANDA #8
        BEQ SKIP_11
        JMP TREE
SKIP_11:
XRT:
; 6502: RTS 
        RTS
ON4:
; 6502: LDA XMAXC
        LDAA VMEM+$E8
        JSR H_NZ
        STAA VA
; 6502: STA WCAP0
        LDAA VA
        STAA VMEM+$DD
; 6502: LDA #$00
        LDAA #$00
        JSR H_NZ
        STAA VA
; 6502: STA STATE
        LDAA VA
        STAA VMEM+$B5
; 6502: JSR MOVE
        JSR MOVE
; 6502: JSR REVERSE
        JSR REVERSE
; 6502: JSR GNMZ
        JSR GNMZ
; 6502: JSR REVERSE
        JSR REVERSE
; 6502: LDA #$08
        LDAA #$08
        JSR H_NZ
        STAA VA
; 6502: STA STATE
        LDAA VA
        STAA VMEM+$B5
; 6502: JSR UMOVE
        JSR UMOVE
; 6502: JMP STRATGY
        JMP STRATGY
NOCOUNT:
; 6502: CPX #$F9
        LDAA #$F9
        STAA OPERAND
        JSR H_CPX
; 6502: BNE TREE
        LDAA VF
        ANDA #4
        BNE SKIP_12
        JMP TREE
SKIP_12:
; 6502: LDA BK
        LDAA VMEM+$60
        JSR H_NZ
        STAA VA
; 6502: CMP SQUARE
        LDAA VMEM+$B1
        STAA OPERAND
        JSR H_CMP
; 6502: BNE RETJ
        LDAA VF
        ANDA #4
        BNE SKIP_13
        JMP RETJ
SKIP_13:
; 6502: LDA #$00
        LDAA #$00
        JSR H_NZ
        STAA VA
; 6502: STA INCHEK
        LDAA VA
        STAA VMEM+$B4
RETJ:
; 6502: RTS 
        RTS
TREE:
; 6502: BVC RETJ
        LDAA VF
        ANDA #2
        BNE SKIP_14
        JMP RETJ
SKIP_14:
; 6502: LDY #$07
        LDAA #$07
        JSR H_NZ
        STAA VY
; 6502: LDA SQUARE
        LDAA VMEM+$B1
        JSR H_NZ
        STAA VA
LOOPX:
; 6502: CMP BK,Y
        LDX #VMEM+$60
        LDAB VY
        ABX
        LDAA 0,X
        STAA OPERAND
        JSR H_CMP
; 6502: BEQ FOUNX
        LDAA VF
        ANDA #4
        BEQ SKIP_15
        JMP FOUNX
SKIP_15:
; 6502: DEY 
        LDAA VY
        DECA
        JSR H_NZ
        STAA VY
; 6502: BEQ RETJ
        LDAA VF
        ANDA #4
        BEQ SKIP_16
        JMP RETJ
SKIP_16:
; 6502: BPL LOOPX
        LDAA VF
        ANDA #8
        BNE SKIP_17
        JMP LOOPX
SKIP_17:
FOUNX:
; 6502: LDA POINTS,Y
        LDX #POINTVAL+16
        LDAB VY
        ABX
        LDAA 0,X
        JSR H_NZ
        STAA VA
; 6502: CMP BCAP0,X
        LDAB VX
        ADDB #$E2             ; 6502 zero-page indexing wraps at $FF
        LDX #VMEM
        ABX
        LDAA 0,X
        STAA OPERAND
        JSR H_CMP
; 6502: BCC NOMAX
        LDAA VF
        ANDA #1
        BNE SKIP_18
        JMP NOMAX
SKIP_18:
; 6502: STA BCAP0,X
        LDAA VA
        LDAB VX
        ADDB #$E2             ; 6502 zero-page indexing wraps at $FF
        LDX #VMEM
        ABX
        STAA 0,X
NOMAX:
; 6502: DEC STATE
        LDAA VMEM+$B5
        DECA
        JSR H_NZ
        STAA VMEM+$B5
; 6502: LDA #$FB
        LDAA #$FB
        JSR H_NZ
        STAA VA
; 6502: CMP STATE
        LDAA VMEM+$B5
        STAA OPERAND
        JSR H_CMP
; 6502: BEQ UPTREE
        LDAA VF
        ANDA #4
        BEQ SKIP_19
        JMP UPTREE
SKIP_19:
; 6502: JSR GENRM
        JSR GENRM
UPTREE:
; 6502: INC STATE
        LDAA VMEM+$B5
        INCA
        JSR H_NZ
        STAA VMEM+$B5
; 6502: RTS 
        RTS
GNMZ:
; 6502: LDX #$10
        LDAA #$10
        JSR H_NZ
        STAA VX
GNMX:
; 6502: LDA #$00
        LDAA #$00
        JSR H_NZ
        STAA VA
CLEAR:
; 6502: STA COUNT,X
        LDAA VA
        LDX #VMEM+$DE
        LDAB VX
        ABX
        STAA 0,X
; 6502: DEX 
        LDAA VX
        DECA
        JSR H_NZ
        STAA VX
; 6502: BPL CLEAR
        LDAA VF
        ANDA #8
        BNE SKIP_20
        JMP CLEAR
SKIP_20:
GNM:    JSR GENERATE_CASTLES
; 6502: LDA #$10
        LDAA #$10
        JSR H_NZ
        STAA VA
; 6502: STA PIECE
        LDAA VA
        STAA VMEM+$B0
NEWP:
        LDAA VALIDATING
        BEQ NP_ENUMERATE
        LDAA QUICKSCAN
        BNE NP_ENUMERATE
        LDAA WANTPIECE
        CMPA #$FF
        BEQ NP_ENUMERATE
        CMPA PIECE
        BNE NP_ENUMERATE
        RTS
NP_ENUMERATE:
; 6502: DEC PIECE
        LDAA VMEM+$B0
        DECA
        JSR H_NZ
        STAA VMEM+$B0
; 6502: BPL NEX
        LDAA VF
        ANDA #8
        BNE SKIP_21
        JMP NEX
SKIP_21:
; 6502: RTS 
        RTS
NEX:
        LDX #PROMOTED
        LDAB PIECE
        ABX
        LDAA 0,X
        BEQ NEX_NORMAL
        PSHA
        JSR RESET
        PULA
        LDAA #8
        STAA MOVEN
        LDX #PROMOTED
        LDAB PIECE
        ABX
        LDAA 0,X
        CMPA #1
        BEQ NP_QUEEN
        CMPA #2
        BEQ NP_ROOK
        CMPA #3
        BEQ NP_BISHOP
        JMP KNIGHT
NP_QUEEN: JMP QUEEN
NP_ROOK: JMP ROOK
NP_BISHOP: JMP BISHOP
NEX_NORMAL:
; 6502: JSR RESET
        JSR RESET
; 6502: LDY PIECE
        LDAA VMEM+$B0
        JSR H_NZ
        STAA VY
; 6502: LDX #$08
        LDAA #$08
        JSR H_NZ
        STAA VX
; 6502: STX MOVEN
        LDAA VX
        STAA VMEM+$B6
; 6502: CPY #$08
        LDAA #$08
        STAA OPERAND
        JSR H_CPY
; 6502: BPL PAWN
        LDAA VF
        ANDA #8
        BNE SKIP_22
        JMP PAWN
SKIP_22:
; 6502: CPY #$06
        LDAA #$06
        STAA OPERAND
        JSR H_CPY
; 6502: BPL KNIGHT
        LDAA VF
        ANDA #8
        BNE SKIP_23
        JMP KNIGHT
SKIP_23:
; 6502: CPY #$04
        LDAA #$04
        STAA OPERAND
        JSR H_CPY
; 6502: BPL BISHOP
        LDAA VF
        ANDA #8
        BNE SKIP_24
        JMP BISHOP
SKIP_24:
; 6502: CPY #$01
        LDAA #$01
        STAA OPERAND
        JSR H_CPY
; 6502: BEQ QUEEN
        LDAA VF
        ANDA #4
        BEQ SKIP_25
        JMP QUEEN
SKIP_25:
; 6502: BPL ROOK
        LDAA VF
        ANDA #8
        BNE SKIP_26
        JMP ROOK
SKIP_26:
KING:
; 6502: JSR SNGMV
        JSR SNGMV
; 6502: BNE KING
        LDAA VF
        ANDA #4
        BNE SKIP_27
        JMP KING
SKIP_27:
; 6502: BEQ NEWP
        LDAA VF
        ANDA #4
        BEQ SKIP_28
        JMP NEWP
SKIP_28:
QUEEN:
; 6502: JSR LINE
        JSR LINE
; 6502: BNE QUEEN
        LDAA VF
        ANDA #4
        BNE SKIP_29
        JMP QUEEN
SKIP_29:
; 6502: BEQ NEWP
        LDAA VF
        ANDA #4
        BEQ SKIP_30
        JMP NEWP
SKIP_30:
ROOK:
; 6502: LDX #$04
        LDAA #$04
        JSR H_NZ
        STAA VX
; 6502: STX MOVEN
        LDAA VX
        STAA VMEM+$B6
AGNR:
; 6502: JSR LINE
        JSR LINE
; 6502: BNE AGNR
        LDAA VF
        ANDA #4
        BNE SKIP_31
        JMP AGNR
SKIP_31:
; 6502: BEQ NEWP
        LDAA VF
        ANDA #4
        BEQ SKIP_32
        JMP NEWP
SKIP_32:
BISHOP:
; 6502: JSR LINE
        JSR LINE
; 6502: LDA MOVEN
        LDAA VMEM+$B6
        JSR H_NZ
        STAA VA
; 6502: CMP #$04
        LDAA #$04
        STAA OPERAND
        JSR H_CMP
; 6502: BNE BISHOP
        LDAA VF
        ANDA #4
        BNE SKIP_33
        JMP BISHOP
SKIP_33:
; 6502: BEQ NEWP
        LDAA VF
        ANDA #4
        BEQ SKIP_34
        JMP NEWP
SKIP_34:
KNIGHT:
; 6502: LDX #$10
        LDAA #$10
        JSR H_NZ
        STAA VX
; 6502: STX MOVEN
        LDAA VX
        STAA VMEM+$B6
AGNN:
; 6502: JSR SNGMV
        JSR SNGMV
; 6502: LDA MOVEN
        LDAA VMEM+$B6
        JSR H_NZ
        STAA VA
; 6502: CMP #$08
        LDAA #$08
        STAA OPERAND
        JSR H_CMP
; 6502: BNE AGNN
        LDAA VF
        ANDA #4
        BNE SKIP_35
        JMP AGNN
SKIP_35:
; 6502: BEQ NEWP
        LDAA VF
        ANDA #4
        BEQ SKIP_36
        JMP NEWP
SKIP_36:
PAWN:
; 6502: LDX #$06
        LDAA #$06
        JSR H_NZ
        STAA VX
; 6502: STX MOVEN
        LDAA VX
        STAA VMEM+$B6
P1:
; 6502: JSR CMOVE
        JSR CMOVE
; 6502: BVC P2
        LDAA VF
        ANDA #2
        BNE SKIP_37
        JMP P2
SKIP_37:
; 6502: BMI P2
        LDAA VF
        ANDA #8
        BEQ SKIP_38
        JMP P2
SKIP_38:
; 6502: JSR PROMOTION_JANUS
        JSR PROMOTION_JANUS
P2:
; 6502: JSR RESET
        JSR RESET
; 6502: DEC MOVEN
        LDAA VMEM+$B6
        DECA
        JSR H_NZ
        STAA VMEM+$B6
; 6502: LDA MOVEN
        LDAA VMEM+$B6
        JSR H_NZ
        STAA VA
; 6502: CMP #$05
        LDAA #$05
        STAA OPERAND
        JSR H_CMP
; 6502: BEQ P1
        LDAA VF
        ANDA #4
        BEQ SKIP_39
        JMP P1
SKIP_39:
P3:
; 6502: JSR CMOVE
        JSR CMOVE
; 6502: BVS NEWP
        LDAA VF
        ANDA #2
        BEQ SKIP_40
        JMP NEWP
SKIP_40:
; 6502: BMI NEWP
        LDAA VF
        ANDA #8
        BEQ SKIP_41
        JMP NEWP
SKIP_41:
; 6502: JSR PROMOTION_JANUS
        JSR PROMOTION_JANUS
; 6502: LDA SQUARE
        LDAA VMEM+$B1
        JSR H_NZ
        STAA VA
; 6502: AND #$F0
        LDAA #$F0
        STAA OPERAND
        JSR H_AND
; 6502: CMP #$20
        LDAA #$20
        STAA OPERAND
        JSR H_CMP
; 6502: BEQ P3
        LDAA VF
        ANDA #4
        BEQ SKIP_42
        JMP P3
SKIP_42:
; 6502: JMP NEWP
        JMP NEWP
SNGMV:
; 6502: JSR CMOVE
        JSR CMOVE
; 6502: BMI ILL1
        LDAA VF
        ANDA #8
        BEQ SKIP_43
        JMP ILL1
SKIP_43:
; 6502: JSR JANUS
        JSR JANUS
ILL1:
; 6502: JSR RESET
        JSR RESET
; 6502: DEC MOVEN
        LDAA VMEM+$B6
        DECA
        JSR H_NZ
        STAA VMEM+$B6
; 6502: RTS 
        RTS
LINE:
; 6502: JSR CMOVE
        JSR CMOVE
; 6502: BCC OVL
        LDAA VF
        ANDA #1
        BNE SKIP_44
        JMP OVL
SKIP_44:
; 6502: BVC LINE
        LDAA VF
        ANDA #2
        BNE SKIP_45
        JMP LINE
SKIP_45:
OVL:
; 6502: BMI ILL
        LDAA VF
        ANDA #8
        BEQ SKIP_46
        JMP ILL
SKIP_46:
; 6502: PHP 
        LDAA VF
        JSR DATA_PUSH
; 6502: JSR JANUS
        JSR JANUS
; 6502: PLP 
        JSR DATA_POP
        STAA VF
; 6502: BVC LINE
        LDAA VF
        ANDA #2
        BNE SKIP_47
        JMP LINE
SKIP_47:
ILL:
; 6502: JSR RESET
        JSR RESET
; 6502: DEC MOVEN
        LDAA VMEM+$B6
        DECA
        JSR H_NZ
        STAA VMEM+$B6
; 6502: RTS 
        RTS
REVERSE:
        JSR RULES_REVERSE
        JSR SWAP_PROMOTIONS
; 6502: LDX #$0F
        LDAA #$0F
        JSR H_NZ
        STAA VX
ETC:
; 6502: SEC 
        LDAA VF
        ORAA #1
        STAA VF
; 6502: LDY BK,X
        LDX #VMEM+$60
        LDAB VX
        ABX
        LDAA 0,X
        JSR H_NZ
        STAA VY
; 6502: LDA #$77
        LDAA #$77
        JSR H_NZ
        STAA VA
; 6502: SBC BOARD,X
        LDX #VMEM+$50
        LDAB VX
        ABX
        LDAA 0,X
        STAA OPERAND
        JSR H_SBC
; 6502: STA BK,X
        LDAA VA
        LDX #VMEM+$60
        LDAB VX
        ABX
        STAA 0,X
; 6502: STY BOARD,X
        LDAA VY
        LDX #VMEM+$50
        LDAB VX
        ABX
        STAA 0,X
; 6502: SEC 
        LDAA VF
        ORAA #1
        STAA VF
; 6502: LDA #$77
        LDAA #$77
        JSR H_NZ
        STAA VA
; 6502: SBC BOARD,X
        LDX #VMEM+$50
        LDAB VX
        ABX
        LDAA 0,X
        STAA OPERAND
        JSR H_SBC
; 6502: STA BOARD,X
        LDAA VA
        LDX #VMEM+$50
        LDAB VX
        ABX
        STAA 0,X
; 6502: DEX 
        LDAA VX
        DECA
        JSR H_NZ
        STAA VX
; 6502: BPL ETC
        LDAA VF
        ANDA #8
        BNE SKIP_48
        JMP ETC
SKIP_48:
; 6502: RTS 
        RTS
CMOVE:
; 6502: LDA SQUARE
        LDAA VMEM+$B1
        JSR H_NZ
        STAA VA
; 6502: LDX MOVEN
        LDAA VMEM+$B6
        JSR H_NZ
        STAA VX
; 6502: CLC 
        LDAA VF
        ANDA #$FE
        STAA VF
; 6502: ADC MOVEX,X
        LDX #MOVEX
        LDAB VX
        ABX
        LDAA 0,X
        STAA OPERAND
        JSR H_ADC
; 6502: STA SQUARE
        LDAA VA
        STAA VMEM+$B1
; 6502: AND #$88
        LDAA #$88
        STAA OPERAND
        JSR H_AND
; 6502: BNE ILLEGAL
        LDAA VF
        ANDA #4
        BNE SKIP_49
        JMP ILLEGAL
SKIP_49:
; 6502: LDA SQUARE
        LDAA VMEM+$B1
        JSR H_NZ
        STAA VA
; 6502: LDX #$20
        LDAA #$20
        JSR H_NZ
        STAA VX
LOOP:
; 6502: DEX 
        LDAA VX
        DECA
        JSR H_NZ
        STAA VX
; 6502: BMI NO
        LDAA VF
        ANDA #8
        BEQ SKIP_50
        JMP NO
SKIP_50:
; 6502: CMP BOARD,X
        LDX #VMEM+$50
        LDAB VX
        ABX
        LDAA 0,X
        STAA OPERAND
        JSR H_CMP
; 6502: BNE LOOP
        LDAA VF
        ANDA #4
        BNE SKIP_51
        JMP LOOP
SKIP_51:
; 6502: CPX #$10
        LDAA #$10
        STAA OPERAND
        JSR H_CPX
; 6502: BMI ILLEGAL
        LDAA VF
        ANDA #8
        BEQ SKIP_52
        JMP ILLEGAL
SKIP_52:
; 6502: LDA #$7F
        LDAA #$7F
        JSR H_NZ
        STAA VA
; 6502: ADC #$01
        LDAA #$01
        STAA OPERAND
        JSR H_ADC
; 6502: BVS SPX
        LDAA VF
        ANDA #2
        BEQ SKIP_53
        JMP SPX
SKIP_53:
NO:     JSR EP_CAPTURE
        CMPA #$FF
        BEQ NO_EP
        LDAA VF
        ORAA #2
        STAA VF
        JMP SPX
NO_EP:
; 6502: CLV 
        LDAA VF
        ANDA #$FD
        STAA VF
SPX:
; 6502: LDA STATE
        LDAA VMEM+$B5
        JSR H_NZ
        STAA VA
; 6502: BMI RETL
        LDAA VF
        ANDA #8
        BEQ SKIP_54
        JMP RETL
SKIP_54:
; 6502: CMP #$08
        LDAA #$08
        STAA OPERAND
        JSR H_CMP
; 6502: BPL RETL
        LDAA VF
        ANDA #8
        BNE SKIP_55
        JMP RETL
SKIP_55:
CHKCHK:
        LDAA FASTMODE
        BEQ DO_CHECK
        LDAA STATE
        BNE DO_CHECK
        JMP RETL
DO_CHECK:
        LDAA VA
        PSHA
        LDAA VF
        PSHA
        JSR MOVE
        JSR NATIVE_CHECK
        STAA CHECKRESULT
        JSR UMOVE
        PULA
        STAA VF
        PULA
        STAA VA
        LDAA CHECKRESULT
        BEQ NC_SAFE
        CLR INCHEK
        LDAA VF
        ORAA #1
        STAA VF
        LDAA #$FF
        JSR H_NZ
        STAA VA
        RTS
NC_SAFE:
        LDAA #$F9
        STAA INCHEK
        JMP RETL
RETL:
; 6502: CLC 
        LDAA VF
        ANDA #$FE
        STAA VF
; 6502: LDA #$00
        LDAA #$00
        JSR H_NZ
        STAA VA
; 6502: RTS 
        RTS
ILLEGAL:
; 6502: LDA #$FF
        LDAA #$FF
        JSR H_NZ
        STAA VA
; 6502: CLC 
        LDAA VF
        ANDA #$FE
        STAA VF
; 6502: CLV 
        LDAA VF
        ANDA #$FD
        STAA VF
; 6502: RTS 
        RTS
RESET:
; 6502: LDX PIECE
        LDAA VMEM+$B0
        JSR H_NZ
        STAA VX
; 6502: LDA BOARD,X
        LDX #VMEM+$50
        LDAB VX
        ABX
        LDAA 0,X
        JSR H_NZ
        STAA VA
; 6502: STA SQUARE
        LDAA VA
        STAA VMEM+$B1
; 6502: RTS 
        RTS
GENRM:
; 6502: JSR MOVE
        JSR MOVE
GENR2:
; 6502: JSR REVERSE
        JSR REVERSE
; 6502: JSR GNM
        JSR GNM
RUM:
; 6502: JSR REVERSE
        JSR REVERSE
        JMP UMOVE
CKMATE:
; 6502: LDY BMAXC
        LDAA VMEM+$E4
        JSR H_NZ
        STAA VY
; 6502: CPX POINTS
        LDAA POINTS
        STAA OPERAND
        JSR H_CPY
; 6502: BNE NOCHEK
        LDAA VF
        ANDA #4
        BNE SKIP_57
        JMP NOCHEK
SKIP_57:
; 6502: LDA #$00
        LDAA #$00
        JSR H_NZ
        STAA VA
; 6502: BEQ RETV
        LDAA VF
        ANDA #4
        BEQ SKIP_58
        JMP RETV
SKIP_58:
NOCHEK:
; 6502: LDX BMOB
        LDAA VMEM+$E3
        JSR H_NZ
        STAA VX
; 6502: BNE RETV
        LDAA VF
        ANDA #4
        BNE SKIP_59
        JMP RETV
SKIP_59:
; 6502: LDX WMAXP
        LDAA VMEM+$EE
        JSR H_NZ
        STAA VX
; 6502: BNE RETV
        LDAA VF
        ANDA #4
        BNE SKIP_60
        JMP RETV
SKIP_60:
; 6502: LDA #$FF
        LDAA #$FF
        JSR H_NZ
        STAA VA
RETV:
; 6502: LDX #$04
        LDAA #$04
        JSR H_NZ
        STAA VX
; 6502: STX STATE
        LDAA VX
        STAA VMEM+$B5
PUSH:
; 6502: CMP BESTV
        LDAA VMEM+$FA
        STAA OPERAND
        JSR H_CMP
; 6502: BCC RETP
        LDAA VF
        ANDA #1
        BNE SKIP_61
        JMP RETP
SKIP_61:
; 6502: BEQ RETP
        LDAA VF
        ANDA #4
        BEQ SKIP_62
        JMP RETP
SKIP_62:
        LDAA PROMCHOICE
        STAA BESTPROM
; 6502: STA BESTV
        LDAA VA
        STAA VMEM+$FA
; 6502: LDA PIECE
        LDAA VMEM+$B0
        JSR H_NZ
        STAA VA
; 6502: STA BESTP
        LDAA VA
        STAA VMEM+$FB
; 6502: LDA SQUARE
        LDAA VMEM+$B1
        JSR H_NZ
        STAA VA
; 6502: STA BESTM
        LDAA VA
        STAA VMEM+$F9
RETP:
; 6502: LDA #"."
        LDAA #$2E
        JSR H_NZ
        STAA VA
; 6502: JMP syschout
        RTS
GO:     JSR SEARCH_BEGIN
; The supplied adaptation always disables the old opening sequence.
; Omit its unreachable native wrapper; retain the original table for reference.
NOOPEN:
; 6502: LDX #$0C
        LDAA #$0C
        JSR H_NZ
        STAA VX
; 6502: STX STATE
        LDAA VX
        STAA VMEM+$B5
; 6502: STX BESTV
        LDAA VX
        STAA VMEM+$FA
; 6502: LDX #$14
        LDAA #$14
        JSR H_NZ
        STAA VX
; 6502: JSR GNMX
        JSR GNMX
; 6502: LDX #$04
        LDAA #$04
        JSR H_NZ
        STAA VX
; 6502: STX STATE
        LDAA VX
        STAA VMEM+$B5
; 6502: JSR GNMZ
        JSR GNMZ
; 6502: LDX BESTV
        LDAA VMEM+$FA
        JSR H_NZ
        STAA VX
; 6502: CPX #$0F
        LDAA #$0F
        STAA OPERAND
        JSR H_CPX
; 6502: BCC MATE
        LDAA VF
        ANDA #1
        BNE SKIP_66
        JMP MATE
SKIP_66:
MV2:    CLR BUDGETACTIVE
        LDAA #1
        STAA SEARCHOK
; 6502: LDX BESTP
        LDAA VMEM+$FB
        JSR H_NZ
        STAA VX
; 6502: LDA BOARD,X
        LDX #VMEM+$50
        LDAB VX
        ABX
        LDAA 0,X
        JSR H_NZ
        STAA VA
; 6502: STA BESTV
        LDAA VA
        STAA VMEM+$FA
; 6502: STX PIECE
        LDAA VX
        STAA VMEM+$B0
; 6502: LDA BESTM
        LDAA VMEM+$F9
        JSR H_NZ
        STAA VA
; 6502: STA SQUARE
        LDAA VA
        STAA VMEM+$B1
; 6502: JSR MOVE
        LDAA BESTPROM
        STAA PROMCHOICE
        JSR MOVE
; 6502: JMP CHESS
        RTS
MATE:   CLR BUDGETACTIVE
; 6502: LDA #$FF
        LDAA #$FF
        JSR H_NZ
        STAA VA
; 6502: RTS 
        RTS
STRATGY:
; 6502: CLC 
        LDAA VF
        ANDA #$FE
        STAA VF
; 6502: LDA #$80
        LDAA #$80
        JSR H_NZ
        STAA VA
; 6502: ADC WMOB
        LDAA VMEM+$EB
        STAA OPERAND
        JSR H_ADC
; 6502: ADC WMAXC
        LDAA VMEM+$EC
        STAA OPERAND
        JSR H_ADC
; 6502: ADC WCC
        LDAA VMEM+$ED
        STAA OPERAND
        JSR H_ADC
; 6502: ADC WCAP1
        LDAA VMEM+$E1
        STAA OPERAND
        JSR H_ADC
; 6502: ADC WCAP2
        LDAA VMEM+$DF
        STAA OPERAND
        JSR H_ADC
; 6502: SEC 
        LDAA VF
        ORAA #1
        STAA VF
; 6502: SBC PMAXC
        LDAA VMEM+$F0
        STAA OPERAND
        JSR H_SBC
; 6502: SBC PCC
        LDAA VMEM+$F1
        STAA OPERAND
        JSR H_SBC
; 6502: SBC BCAP0
        LDAA VMEM+$E2
        STAA OPERAND
        JSR H_SBC
; 6502: SBC BCAP1
        LDAA VMEM+$E0
        STAA OPERAND
        JSR H_SBC
; 6502: SBC BCAP2
        LDAA VMEM+$DE
        STAA OPERAND
        JSR H_SBC
; 6502: SBC PMOB
        LDAA VMEM+$EF
        STAA OPERAND
        JSR H_SBC
; 6502: SBC BMOB
        LDAA VMEM+$E3
        STAA OPERAND
        JSR H_SBC
; 6502: BCS POS
        LDAA VF
        ANDA #1
        BEQ SKIP_67
        JMP POS
SKIP_67:
; 6502: LDA #$00
        LDAA #$00
        JSR H_NZ
        STAA VA
POS:
; 6502: LSR 
        LDAA VA
        STAA SHIFTVAL
        JSR H_LSR
        STAA VA
; 6502: CLC 
        LDAA VF
        ANDA #$FE
        STAA VF
; 6502: ADC #$40
        LDAA #$40
        STAA OPERAND
        JSR H_ADC
; 6502: ADC WMAXC
        LDAA VMEM+$EC
        STAA OPERAND
        JSR H_ADC
; 6502: ADC WCC
        LDAA VMEM+$ED
        STAA OPERAND
        JSR H_ADC
; 6502: SEC 
        LDAA VF
        ORAA #1
        STAA VF
; 6502: SBC BMAXC
        LDAA VMEM+$E4
        STAA OPERAND
        JSR H_SBC
; 6502: LSR 
        LDAA VA
        STAA SHIFTVAL
        JSR H_LSR
        STAA VA
; 6502: CLC 
        LDAA VF
        ANDA #$FE
        STAA VF
; 6502: ADC #$90
        LDAA #$90
        STAA OPERAND
        JSR H_ADC
; 6502: ADC WCAP0
        LDAA VMEM+$DD
        STAA OPERAND
        JSR H_ADC
; 6502: ADC WCAP0
        LDAA VMEM+$DD
        STAA OPERAND
        JSR H_ADC
; 6502: ADC WCAP0
        LDAA VMEM+$DD
        STAA OPERAND
        JSR H_ADC
; 6502: ADC WCAP0
        LDAA VMEM+$DD
        STAA OPERAND
        JSR H_ADC
; 6502: ADC WCAP1
        LDAA VMEM+$E1
        STAA OPERAND
        JSR H_ADC
; 6502: SEC 
        LDAA VF
        ORAA #1
        STAA VF
; 6502: SBC BMAXC
        LDAA VMEM+$E4
        STAA OPERAND
        JSR H_SBC
; 6502: SBC BMAXC
        LDAA VMEM+$E4
        STAA OPERAND
        JSR H_SBC
; 6502: SBC BMCC
        LDAA VMEM+$E5
        STAA OPERAND
        JSR H_SBC
; 6502: SBC BMCC
        LDAA VMEM+$E5
        STAA OPERAND
        JSR H_SBC
; 6502: SBC BCAP1
        LDAA VMEM+$E0
        STAA OPERAND
        JSR H_SBC
; 6502: LDX SQUARE
        LDAA VMEM+$B1
        JSR H_NZ
        STAA VX
; 6502: CPX #$33
        LDAA #$33
        STAA OPERAND
        JSR H_CPX
; 6502: BEQ POSN
        LDAA VF
        ANDA #4
        BEQ SKIP_68
        JMP POSN
SKIP_68:
; 6502: CPX #$34
        LDAA #$34
        STAA OPERAND
        JSR H_CPX
; 6502: BEQ POSN
        LDAA VF
        ANDA #4
        BEQ SKIP_69
        JMP POSN
SKIP_69:
; 6502: CPX #$22
        LDAA #$22
        STAA OPERAND
        JSR H_CPX
; 6502: BEQ POSN
        LDAA VF
        ANDA #4
        BEQ SKIP_70
        JMP POSN
SKIP_70:
; 6502: CPX #$25
        LDAA #$25
        STAA OPERAND
        JSR H_CPX
; 6502: BEQ POSN
        LDAA VF
        ANDA #4
        BEQ SKIP_71
        JMP POSN
SKIP_71:
; 6502: LDX PIECE
        LDAA VMEM+$B0
        JSR H_NZ
        STAA VX
; 6502: BEQ NOPOSN
        LDAA VF
        ANDA #4
        BEQ SKIP_72
        JMP NOPOSN
SKIP_72:
; 6502: LDY BOARD,X
        LDX #VMEM+$50
        LDAB VX
        ABX
        LDAA 0,X
        JSR H_NZ
        STAA VY
; 6502: CPY #$10
        LDAA #$10
        STAA OPERAND
        JSR H_CPY
; 6502: BPL NOPOSN
        LDAA VF
        ANDA #8
        BNE SKIP_73
        JMP NOPOSN
SKIP_73:
POSN:
; 6502: CLC 
        LDAA VF
        ANDA #$FE
        STAA VF
; 6502: ADC #$02
        LDAA #$02
        STAA OPERAND
        JSR H_ADC
NOPOSN:
; 6502: JMP CKMATE
        JMP CKMATE
; Helpers preserve 6502 flag semantics (stores do not change VF).
H_NZ:   PSHA
        TPA
        ANDA #12
        STAA FLAGTMP
        LDAA VF
        ANDA #$F3
        ORAA FLAGTMP
        STAA VF
        PULA
        RTS
H_NZC:  PSHA
        TPA
        ANDA #13
        STAA FLAGTMP
        LDAA VF
        ANDA #$F2
        ORAA FLAGTMP
        STAA VF
        PULA
        RTS
H_FULL: PSHA
        TPA
        ANDA #15
        STAA VF
        PULA
        STAA VA
        RTS
H_SUBFULL:
        PSHA
        TPA
        EORA #1
        ANDA #15
        STAA VF
        PULA
        STAA VA
        RTS
H_CMP:  LDAA VA
        BRA H_COMPARE
H_CPX:  LDAA VX
        BRA H_COMPARE
H_CPY:  LDAA VY
H_COMPARE:
        SUBA OPERAND
        TPA
        EORA #1
        ANDA #13
        STAA FLAGTMP
        LDAA VF
        ANDA #$F2
        ORAA FLAGTMP
        STAA VF
        RTS
H_ADC:  LDAA VF
        ORAA #$10            ; keep IRQ masked while bitmap overlays BASIC RAM
        TAP
        LDAA VA
        ADCA OPERAND
        JMP H_FULL
H_SBC:  LDAA VF
        EORA #1
        ORAA #$10
        TAP
        LDAA VA
        SBCA OPERAND
        JMP H_SUBFULL
H_AND:  LDAA VA
        ANDA OPERAND
        JSR H_NZ
        STAA VA
        RTS
H_ORA:  LDAA VA
        ORAA OPERAND
        JSR H_NZ
        STAA VA
        RTS
H_ASL:  LDAA SHIFTVAL
        ASLA
        JMP H_NZC
H_LSR:  LDAA SHIFTVAL
        LSRA
        JMP H_NZC
H_ROL:  LDAA VF
        ORAA #$10
        TAP
        LDAA SHIFTVAL
        ROLA
        JMP H_NZC
DATA_PUSH:
        LDX DPTR
        STAA 0,X
        INX
        STX DPTR
        RTS
DATA_POP:
        LDX DPTR
        DEX
        STX DPTR
        LDAA 0,X
        RTS

; Dedicated undo records replace the 6502's switched hardware stacks.
MOVE:   JSR RULES_SAVE
        LDX UPTR
        LDAA SQUARE
        STAA 0,X
        STAA VY
        LDAB #31
M_FIND: LDX #BOARD
        ABX
        LDAA 0,X
        CMPA SQUARE
        BEQ M_CAPTURE
        DECB
        BPL M_FIND
        JSR MOVE_EP
        BRA M_RECORD
M_CAPTURE:
        LDAA #$CC
        STAA 0,X
M_RECORD:
        LDX UPTR
        STAB 1,X
        LDX #BOARD
        LDAB PIECE
        ABX
        LDAA 0,X
        STAA FROMTEMP
        LDAA SQUARE
        STAA 0,X
        LDX UPTR
        LDAB 1,X
        JSR RULES_MOVE
        LDX UPTR
        LDAA FROMTEMP
        STAA 2,X
        LDAA PIECE
        STAA 3,X
        LDAA MOVEN
        STAA 4,X
        LDX #PROMOTED
        LDAB PIECE
        ABX
        LDAA 0,X
        LDX UPTR
        STAA 5,X
        LDAB #16
        ABX
        STX UPTR
        JSR UPDATE_PROMOTION
        LDAA MOVEN
        TSTA
        JSR H_NZ
        STAA VA
        RTS
UMOVE:  LDD UPTR
        SUBD #16
        STD UPTR
        LDX UPTR
        LDAA 4,X
        STAA MOVEN
        LDAA 3,X
        STAA PIECE
        LDAA 5,X
        LDX #PROMOTED
        LDAB PIECE
        ABX
        STAA 0,X
        JSR RESTORE_VALUE
        LDX UPTR
        LDAB 3,X
        LDAA 2,X
        LDX #BOARD
        ABX
        STAA 0,X
        LDX UPTR
        LDAB 1,X
        LDAA 0,X
        STAA SQUARE
        STAB VX
        CMPB #$FF
        BEQ U_NOCAP
        LDAA 11,X
        LDX #BOARD
        ABX
        STAA 0,X
U_NOCAP:
        JSR RULES_UNDO
        LDAA SQUARE
        TSTA
        JSR H_NZ
        STAA VA
        RTS

UPDATE_PROMOTION:
        LDAA FULLRULES
        BEQ PR_DONE
        LDAB PIECE
        CMPB #8
        BCS PR_DONE
        LDX #PROMOTED
        ABX
        LDAA 0,X
        BNE PR_DONE
        LDAA SQUARE
        ANDA #$70
        CMPA #$70
        BNE PR_DONE
        LDAA PROMCHOICE
        STAA 0,X
        JSR RESTORE_VALUE
PR_DONE: RTS
RESTORE_VALUE:
        LDAB PIECE
        CMPB #8
        BCS RV_DONE
        LDX #PROMOTED
        ABX
        LDAA 0,X
        PSHB
        TAB
        LDX #PROMOVALS
        ABX
        LDAA 0,X
        PULB
        LDX #POINTVAL
        ABX
        STAA 0,X
RV_DONE: RTS
SWAP_PROMOTIONS:
        LDX #PROMOTED
        LDAB #16
SP_LOOP:
        LDAA 0,X
        PSHA
        LDAA 16,X
        STAA 0,X
        PULA
        STAA 16,X
        INX
        DECB
        BNE SP_LOOP
        LDX #POINTVAL
        LDAB #16
SV_LOOP:
        LDAA 0,X
        PSHA
        LDAA 16,X
        STAA 0,X
        PULA
        STAA 16,X
        INX
        DECB
        BNE SV_LOOP
        RTS

SETW:
        .BYTE $04,$03,$00,$07,$02,$05,$01,$06
        .BYTE $10,$17,$11,$16,$12,$15,$14,$13
        .BYTE $74,$73,$70,$77,$72,$75,$71,$76
        .BYTE $60,$67,$61,$66,$62,$65,$64,$63
MOVEX:
        .BYTE $00, $F0, $FF, $01, $10, $11, $0F, $EF, $F1
        .BYTE $DF, $E1, $EE, $F2, $12, $0E, $1F, $21
POINTS:
        .BYTE $0B, $0A, $06, $06, $04, $04, $04, $04
        .BYTE $02, $02, $02, $02, $02, $02, $02, $02
; The unused historical OPNING table is omitted from the loaded image.
; The supplied adaptation disables it; QUICK uses BOOKLINES instead.
COPYRIGHT: .TEXT "MicroChess (c) 1996-2002 Peter Jennings, peterj@benlo.com"
        .BYTE 0
VA:     .BYTE 0
VX:     .BYTE 0
VY:     .BYTE 0
VF:     .BYTE 0
OPERAND: .BYTE 0
SHIFTVAL: .BYTE 0
FLAGTMP: .BYTE 0
FROMTEMP: .BYTE 0
DPTR:   .WORD DSTACK
UPTR:   .WORD USTACK
OLDSP:  .WORD 0
OLDCC:  .BYTE 0
VALIDATING: .BYTE 0
VALIDMOVE: .BYTE 0
VALIDSP: .WORD 0
SEARCHOK: .BYTE 0
FASTMODE: .BYTE 0
INPUTLEN: .BYTE 0
INPUTBUF: .FILL 5,0
WANTPIECE: .BYTE 0
WANTFROM: .BYTE 0
WANTTO: .BYTE 0
FIRSTPIECE: .BYTE 0
FIRSTTO: .BYTE 0
GAMEOVER: .BYTE 0
TURNCOUNT: .BYTE 0
LASTFROM: .BYTE 0
LASTTO: .BYTE 0
UITMP: .BYTE 0
UIROW: .BYTE 0
UICOL: .BYTE 0
UISQUARE: .BYTE 0
UIPIECE: .BYTE 0
SQUAREBG: .BYTE 0
SCREENPTR: .WORD 0
TEXTSOURCE: .WORD 0
GLYPHMASK .EQU $4E9A
GLYPHWHITE .EQU $4E9C
VMEM .EQU $4E80             ; Cleared by NEWGAME; originally a loaded 256-byte page
PROMOTED .EQU $4F80         ; 32 promotion types
POINTVAL .EQU $4FA0         ; 32 values initialized from POINTS by NEWGAME
BOOKPATH .EQU VMEM          ; First four canonical moves (8 bytes)
BOOKPLY .EQU VMEM+8
BOOKOFFSET .EQU VMEM+9
BOOKINDEX .EQU VMEM+10
BOOKROWS .EQU VMEM+11
BOOKPTR .EQU VMEM+12
BOOKBYTE .EQU VMEM+14
QUICKSCAN .EQU VMEM+15
QSCORE .EQU VMEM+16
QBEST .EQU VMEM+18
QVALUE .EQU VMEM+20
QTYPE .EQU VMEM+22
QFROM .EQU VMEM+23
BOOKHIT .EQU VMEM+24
TILECACHE .EQU $4C00         ; 64 visual keys: type, color and highlight
USTACK .EQU $4C40            ; 512-byte undo storage in reserved low RAM
DSTACK .EQU $4E40            ; 64-byte virtual data stack
DRAWFULL: .BYTE 1
PADEND: .BYTE 128
AUTOMODE: .BYTE 0            ; 0 normal, 1 self-play, 2 paused
AUTOSIDE: .BYTE 0            ; Next side: 0 White, 1 Black
AUTOTICKS: .BYTE 0
AUTO_WHITE: .TEXT "SELF PLAY WHITE"
        .BYTE 0
AUTO_BLACK: .TEXT "SELF PLAY BLACK"
        .BYTE 0
AUTO_PAUSED: .TEXT "PAUSED: "
        .BYTE 0
MSG_AUTO_THINK: .TEXT "SELF PLAY THINKING"
        .BYTE 0
MSG_BLACKTURN: .TEXT "BLACK TO MOVE - PRESS Z"
        .BYTE 0

BOARD .EQU VMEM+$50
BK .EQU VMEM+$60
PIECE .EQU VMEM+$B0
SQUARE .EQU VMEM+$B1
SP2 .EQU VMEM+$B2
SP1 .EQU VMEM+$B3
INCHEK .EQU VMEM+$B4
STATE .EQU VMEM+$B5
MOVEN .EQU VMEM+$B6
REV .EQU VMEM+$B7
OMOVE .EQU VMEM+$DC
WCAP0 .EQU VMEM+$DD
COUNT .EQU VMEM+$DE
BCAP2 .EQU VMEM+$DE
WCAP2 .EQU VMEM+$DF
BCAP1 .EQU VMEM+$E0
WCAP1 .EQU VMEM+$E1
BCAP0 .EQU VMEM+$E2
MOB .EQU VMEM+$E3
MAXC .EQU VMEM+$E4
CC .EQU VMEM+$E5
PCAP .EQU VMEM+$E6
BMOB .EQU VMEM+$E3
BMAXC .EQU VMEM+$E4
BMCC .EQU VMEM+$E5
BMAXP .EQU VMEM+$E6
XMAXC .EQU VMEM+$E8
WMOB .EQU VMEM+$EB
WMAXC .EQU VMEM+$EC
WCC .EQU VMEM+$ED
WMAXP .EQU VMEM+$EE
PMOB .EQU VMEM+$EF
PMAXC .EQU VMEM+$F0
PCC .EQU VMEM+$F1
PCP .EQU VMEM+$F2
OLDKY .EQU VMEM+$F3
BESTP .EQU VMEM+$FB
BESTV .EQU VMEM+$FA
BESTM .EQU VMEM+$F9
DIS1 .EQU VMEM+$FB
DIS2 .EQU VMEM+$FA
DIS3 .EQU VMEM+$F9
temp .EQU VMEM+$FC

; Native attack detector. Preserves all virtual engine registers and BOARD.
; A=1 if the side in BOARD[0..15] is in check, otherwise zero.
NATIVE_CHECK:
        LDAA BOARD
        STAA TARGETKING
NATIVE_ATTACK:
        JSR BUILD_OCCUPANCY
        LDAA #16
        STAA ATTACKPIECE
NC_PIECE:
        LDAB ATTACKPIECE
        LDX #BOARD
        ABX
        LDAA 0,X
        BITA #$88
        BEQ LONG_1
        JMP NC_NEXT
LONG_1:
        STAA ATTACKFROM
        JSR TYPE_OF
        STAA ATTACKTYPE
        CMPA #1
        BNE NC_NOTPAWN
        LDAA TARGETKING
        SUBA ATTACKFROM
        CMPA #$EF
        BNE LONG_2
        JMP NC_FOUND
LONG_2:
        CMPA #$F1
        BNE LONG_3
        JMP NC_FOUND
LONG_3:
        BRA NC_NEXT
NC_NOTPAWN:
        CLR ATTACKDIR
        CMPA #2
        BEQ NC_KNIGHT
        CMPA #3
        BNE NC_RAY
        LDAA #4
        STAA ATTACKDIR
NC_RAY:
        LDAA ATTACKFROM
        STAA ATTACKTO
NC_STEP:
        LDAB ATTACKDIR
        LDX #RAYDIRS
        ABX
        LDAA 0,X
        ADDA ATTACKTO
        BITA #$88
        BNE NC_RAYNEXT
        STAA ATTACKTO
        CMPA TARGETKING
        BEQ NC_FOUND
        LDAB ATTACKTYPE
        CMPB #6
        BEQ NC_RAYNEXT
        JSR LOOKUP
        CMPA #$FF
        BEQ NC_STEP
NC_RAYNEXT:
        INC ATTACKDIR
        LDAA ATTACKDIR
        LDAB ATTACKTYPE
        CMPB #4
        BNE NC_EIGHT
        CMPA #4
        BNE NC_RAY
        BRA NC_NEXT
NC_EIGHT:
        CMPA #8
        BNE NC_RAY
        BRA NC_NEXT
NC_KNIGHT:
        LDAB ATTACKDIR
        LDX #JUMPDIRS
        ABX
        LDAA 0,X
        ADDA ATTACKFROM
        CMPA TARGETKING
        BEQ NC_FOUND
        INC ATTACKDIR
        LDAA ATTACKDIR
        CMPA #8
        BNE NC_KNIGHT
NC_NEXT:
        INC ATTACKPIECE
        LDAA ATTACKPIECE
        CMPA #32
        BEQ LONG_0
        JMP NC_PIECE
LONG_0:
        CLRA
        CLR OCCUPANCYFLAG
        RTS
NC_FOUND:
        LDAA #1
        CLR OCCUPANCYFLAG
        RTS
; B=piece slot, A=standard type P1/N2/B3/R4/Q5/K6.
TYPE_OF:
        LDX #PROMOTED
        ABX
        LDAA 0,X
        BEQ TO_NORMAL
        TAB
        LDX #PROMOTYPES
        ABX
        LDAA 0,X
        RTS
TO_NORMAL:
        ANDB #15
        LDX #NATIVETYPES
        ABX
        LDAA 0,X
        RTS
; A=square; A returns piece slot or $FF. No virtual-register changes.
LOOKUP:
        STAA PROBESQ
        LDAB OCCUPANCYFLAG
        BEQ LU_SCAN
        ANDA #7
        STAA UITMP
        LDAA PROBESQ
        ANDA #$70
        LSRA
        ADDA UITMP
        TAB
        LDX #OCCUPANCY
        ABX
        LDAA 0,X
        RTS
LU_SCAN:
        LDAB #31
LU_LOOP:
        LDX #BOARD
        ABX
        LDAA 0,X
        CMPA PROBESQ
        BEQ LU_FOUND
        DECB
        BPL LU_LOOP
        LDAA #$FF
        RTS
LU_FOUND:
        TBA
        RTS
RAYDIRS: .BYTE $F0,$FF,1,16,$EF,17,15,$F1
JUMPDIRS: .BYTE $DF,$E1,$EE,$F2,14,18,31,33
NATIVETYPES: .BYTE 6,5,4,4,3,3,2,2,1,1,1,1,1,1,1,1
PROMOTYPES: .BYTE 0,5,4,3,2
CHECKRESULT: .BYTE 0
TARGETKING: .BYTE 0
ATTACKPIECE: .BYTE 0
ATTACKFROM: .BYTE 0
ATTACKTO: .BYTE 0
ATTACKTYPE: .BYTE 0
ATTACKDIR: .BYTE 0
PROBESQ: .BYTE 0

; Complete-move state is saved in every 16-byte trial undo record.
RULES_NEW:
        CLR ACTIVEBLACK
        LDAA #3
        STAA RIGHTSF
        STAA RIGHTSE
        LDAA #$FF
        STAA EPTARGET
        LDAA #1
        STAA PROMCHOICE
        STAA WANTPROM
        CLR HALFMOVE
        CLR HALFMOVE+1
        RTS
RULES_SAVE:
        LDX UPTR
        LDAA EPTARGET
        STAA 6,X
        LDAA RIGHTSF
        STAA 7,X
        LDAA RIGHTSE
        STAA 8,X
        LDAA #$FF
        STAA 9,X
        LDAA SQUARE
        STAA 11,X
        LDD HALFMOVE
        STD 12,X
        LDAA PROMCHOICE
        STAA 14,X
        RTS
RULES_REVERSE:
        LDAA ACTIVEBLACK
        EORA #1
        STAA ACTIVEBLACK
        LDAA RIGHTSF
        LDAB RIGHTSE
        STAB RIGHTSF
        STAA RIGHTSE
        LDAA EPTARGET
        CMPA #$FF
        BEQ RR_DONE
        LDAB #$77
        SBA
        NEGA
        STAA EPTARGET
RR_DONE: RTS
EP_CAPTURE:
        LDAA FULLRULES
        BEQ EP_NO
        LDAA SQUARE
        CMPA EPTARGET
        BNE EP_NO
        LDAB PIECE
        CMPB #8
        BCS EP_NO
        CMPB #16
        BCC EP_NO
        LDX #PROMOTED
        ABX
        LDAA 0,X
        BNE EP_NO
        LDX #BOARD
        ABX
        LDAA SQUARE
        SUBA 0,X
        CMPA #15
        BEQ EP_PROBE
        CMPA #17
        BNE EP_NO
EP_PROBE:
        LDAA SQUARE
        SUBA #16
        JSR LOOKUP
        CMPA #24
        BCS EP_NO
        CMPA #32
        BCC EP_NO
        TAB
        LDX #PROMOTED
        ABX
        LDAA 0,X
        BNE EP_NO
        TBA                    ; captured pawn slot (24..31)
        RTS
EP_NO:  LDAA #$FF
        RTS
; Called after finding no normal capture, before changing the board.
MOVE_EP:
        JSR EP_CAPTURE
        CMPA #$FF
        BEQ ME_NONE
        TAB
        LDX #BOARD
        ABX
        LDAA 0,X
        LDX UPTR
        STAA 11,X
        LDAA #$CC
        LDX #BOARD
        ABX
        STAA 0,X
        RTS
ME_NONE: LDAB #$FF
        RTS
; B=captured slot, FROMTEMP and PIECE still describe the original mover.
RULES_MOVE:
        STAB CAPTURED_SLOT
        LDD HALFMOVE
        ADDD #1
        STD HALFMOVE
        CMPB #$FF              ; B was changed by LDD, use saved slot
        LDAA CAPTURED_SLOT
        CMPA #$FF
        BEQ RM_PAWN
        CLR HALFMOVE
        CLR HALFMOVE+1
        CMPA #18
        BNE RM_CAPKINGROOK
        LDAA RIGHTSE
        ANDA #$FE
        STAA RIGHTSE
RM_CAPKINGROOK:
        LDAA CAPTURED_SLOT
        CMPA #19
        BNE RM_PAWN
        LDAA RIGHTSE
        ANDA #$FD
        STAA RIGHTSE
RM_PAWN:
        LDAB PIECE
        CMPB #8
        BCS RM_RIGHTS
        LDX #PROMOTED
        ABX
        LDAA 0,X
        BNE RM_RIGHTS
        CLR HALFMOVE
        CLR HALFMOVE+1
RM_RIGHTS:
        LDAA #$FF
        STAA EPTARGET
        LDAB PIECE
        CMPB #8
        BCS RM_ROOK
        LDX #PROMOTED
        ABX
        LDAA 0,X
        BNE RM_ROOK
        LDAA SQUARE
        SUBA FROMTEMP
        CMPA #32
        BNE RM_ROOK
        LDAA FROMTEMP
        ADDA #16
        STAA EPTARGET
RM_ROOK:
        LDAA PIECE
        CMPA #2
        BNE RM_R3
        LDAA RIGHTSF
        ANDA #$FE
        STAA RIGHTSF
RM_R3:  LDAA PIECE
        CMPA #3
        BNE RM_KING
        LDAA RIGHTSF
        ANDA #$FD
        STAA RIGHTSF
RM_KING:
        LDAA PIECE
        BNE RM_DONE
        CLR RIGHTSF
        LDAA FULLRULES
        BEQ RM_DONE
        LDAA SQUARE
        SUBA FROMTEMP
        CMPA #2
        BEQ RM_KRIGHT
        CMPA #$FE
        BNE RM_DONE
        LDAA #2
        BRA RM_KROOK
RM_KRIGHT:
        LDAA #3
RM_KROOK:
        EORA ACTIVEBLACK       ; reverse board swaps left/right geometries
        TAB
        LDX UPTR
        STAB 9,X
        LDX #BOARD
        ABX
        LDAA 0,X
        LDX UPTR
        STAA 10,X
        LDAA SQUARE
        ADDA FROMTEMP
        LSRA
        LDX #BOARD
        ABX
        STAA 0,X
RM_DONE: LDAB CAPTURED_SLOT
        RTS
RULES_UNDO:
        LDX UPTR
        LDAA 6,X
        STAA EPTARGET
        LDAA 7,X
        STAA RIGHTSF
        LDAA 8,X
        STAA RIGHTSE
        LDD 12,X
        STD HALFMOVE
        LDAA 14,X
        STAA PROMCHOICE
        LDAB 9,X
        CMPB #$FF
        BEQ RU_DONE
        LDAA 10,X
        LDX #BOARD
        ABX
        STAA 0,X
RU_DONE: RTS

; Four promotion candidates feed the unmodified JANUS evaluator.
PROMOTION_JANUS:
        LDAA PROMCHOICE
        PSHA
        LDAA FULLRULES
        BEQ PJ_ONCE
        LDAB PIECE
        CMPB #8
        BCS PJ_ONCE
        LDX #PROMOTED
        ABX
        LDAA 0,X
        BNE PJ_ONCE
        LDAA SQUARE
        ANDA #$70
        CMPA #$70
        BNE PJ_ONCE
        LDAA #1
        STAA PROMCHOICE
PJ_LOOP:
        JSR JANUS
        INC PROMCHOICE
        LDAA PROMCHOICE
        CMPA #5
        BNE PJ_LOOP
        BRA PJ_DONE
PJ_ONCE: JSR JANUS
PJ_DONE: PULA
        STAA PROMCHOICE
        RTS

; Castling is generated only with rights, the original rook, an empty path,
; and an unattacked king start/transit/destination. Native trials undo fully.
GENERATE_CASTLES:
        LDAA FULLRULES
        BNE LONG_7
        JMP GC_DONE
LONG_7:
        LDAA STATE
        BPL LONG_8
        JMP GC_DONE
LONG_8:
        CLR CASTLEITER
GC_LOOP:
        LDAB CASTLEITER
        LDX #CASTLEBITS
        ABX
        LDAA 0,X
        ANDA RIGHTSF
        BNE LONG_9
        JMP GC_NEXT
LONG_9:
        LDAB ACTIVEBLACK
        ASLB
        ADDB CASTLEITER
        STAB CASTLEINDEX
        LDX #CASTLESTART
        ABX
        LDAA 0,X
        CMPA BOARD
        BEQ LONG_10
        JMP GC_NEXT
LONG_10:
        STAA CASTLEFROM
        LDX #CASTLEROOK
        ABX
        LDAA 0,X
        STAA CASTLERHOME
        JSR LOOKUP
        LDAB CASTLEITER
        LDX #CASTLESLOT
        ABX
        CMPA 0,X
        BEQ LONG_11
        JMP GC_NEXT
LONG_11:
        JSR NATIVE_CHECK
        TSTA
        BEQ LONG_12
        JMP GC_NEXT
LONG_12:
        LDAB CASTLEINDEX
        LDX #CASTLETO
        ABX
        LDAA 0,X
        STAA CASTLEDEST
        SUBA CASTLEFROM
        LDAA #1
        LDAB CASTLEDEST
        CMPB CASTLEFROM
        BHI GC_DIRECTION
        LDAA #$FF
GC_DIRECTION:
        STAA CASTLESTEP
        LDAA CASTLEFROM
GC_PATH:
        ADDA CASTLESTEP
        CMPA CASTLERHOME
        BEQ GC_TRANSIT
        STAA CASTLEPATH
        JSR LOOKUP
        CMPA #$FF
        BNE GC_NEXT
        LDAA CASTLEPATH
        BRA GC_PATH
GC_TRANSIT:
        LDAA CASTLEFROM
        ADDA CASTLESTEP
        STAA BOARD
        JSR NATIVE_CHECK
        STAA CHECKRESULT
        LDAA CASTLEFROM
        STAA BOARD
        LDAA CHECKRESULT
        BNE GC_NEXT
        CLR PIECE
        CLR MOVEN
        LDAA CASTLEDEST
        STAA SQUARE
        JSR MOVE
        JSR NATIVE_CHECK
        STAA CHECKRESULT
        JSR UMOVE
        LDAA CHECKRESULT
        BNE GC_NEXT
        LDAA CASTLEITER
        PSHA
        LDAA #4
        STAA VF                ; CMOVE successful non-capture flags
        CLR VA
        JSR JANUS
        PULA
        STAA CASTLEITER
GC_NEXT:
        INC CASTLEITER
        LDAA CASTLEITER
        CMPA #2
        BEQ LONG_6
        JMP GC_LOOP
LONG_6:
GC_DONE: RTS
CASTLEBITS: .BYTE 2,1
CASTLESLOT: .BYTE 3,2
CASTLESTART: .BYTE 4,4,3,3
CASTLEROOK: .BYTE 7,0,0,7
CASTLETO: .BYTE 6,2,1,5
PROMOVALS: .BYTE 2,10,6,4,4
PROMOLETTERS: .TEXT " QRBN"
FULLRULES: .BYTE 1
ACTIVEBLACK: .BYTE 0
RIGHTSF: .BYTE 3
RIGHTSE: .BYTE 3
EPTARGET: .BYTE $FF
HALFMOVE: .WORD 0
PROMCHOICE: .BYTE 1
WANTPROM: .BYTE 1
BESTPROM: .BYTE 1
FIRSTPROM: .BYTE 1
LASTPROM: .BYTE 0
CAPTURED_SLOT: .BYTE 0
CASTLEITER: .BYTE 0
CASTLEINDEX: .BYTE 0
CASTLEFROM: .BYTE 0
CASTLERHOME: .BYTE 0
CASTLEDEST: .BYTE 0
CASTLESTEP: .BYTE 0
CASTLEPATH: .BYTE 0


SMALLFONT:
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,7,0,0
        .BYTE 0,0,0,0,2
        .BYTE 1,1,2,4,4
        .BYTE 7,5,5,5,7
        .BYTE 2,6,2,2,7
        .BYTE 6,1,2,4,7
        .BYTE 6,1,2,1,6
        .BYTE 5,5,7,1,1
        .BYTE 7,4,6,1,6
        .BYTE 3,4,7,5,7
        .BYTE 7,1,2,2,2
        .BYTE 7,5,7,5,7
        .BYTE 7,5,7,1,6
        .BYTE 0,2,0,2,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 0,0,0,0,0
        .BYTE 2,5,7,5,5
        .BYTE 6,5,6,5,6
        .BYTE 3,4,4,4,3
        .BYTE 6,5,5,5,6
        .BYTE 7,4,6,4,7
        .BYTE 7,4,6,4,4
        .BYTE 3,4,5,5,3
        .BYTE 5,5,7,5,5
        .BYTE 7,2,2,2,7
        .BYTE 1,1,1,5,2
        .BYTE 5,5,6,5,5
        .BYTE 4,4,4,4,7
        .BYTE 5,7,7,5,5
        .BYTE 5,7,7,7,5
        .BYTE 2,5,5,5,2
        .BYTE 6,5,6,4,4
        .BYTE 2,5,5,7,3
        .BYTE 6,5,6,5,5
        .BYTE 3,4,2,1,6
        .BYTE 7,2,2,2,2
        .BYTE 5,5,5,5,7
        .BYTE 5,5,5,5,2
        .BYTE 5,5,7,7,5
        .BYTE 5,5,2,5,5
        .BYTE 5,5,2,2,2
        .BYTE 7,1,2,4,7
SPRITES:
        .BYTE 24,60,60,28,62,127,127,62,0,24,24,8,28,62,62,0
        .BYTE 24,60,118,240,56,60,126,126,0,16,32,32,16,24,60,0
        .BYTE 8,28,54,34,28,28,62,127,0,0,0,0,0,8,28,0
        .BYTE 42,127,127,62,62,127,127,62,0,42,62,28,28,62,62,0
        .BYTE 42,127,127,62,62,127,127,62,0,42,42,28,8,62,62,0
        .BYTE 8,28,62,28,62,127,127,62,0,8,28,8,28,62,62,0
; 5x7 P/N/B/R/Q/K glyphs in an 8x8 tile. White mask is complement of ink.
LETTERSPRITES:
        .BYTE 135,187,187,135,191,191,191,255 ; P
        .BYTE 187,155,155,171,179,179,187,255 ; N
        .BYTE 135,187,187,135,187,187,135,255 ; B
        .BYTE 135,187,187,135,175,183,187,255 ; R
        .BYTE 199,187,187,187,171,183,203,255 ; Q
        .BYTE 187,183,175,159,175,183,187,255 ; K
SCREENBACKUP .EQU $4600

; Exact repetition records: 32 packed board bytes + rights + effective EP + turn.
; 151 positions cover the complete 75-move reversible window, without hashing.
HISTORY_NEW:
        CLR HISTORYCOUNT
        CLR NEXTSIDE
        CLR DRAW_AVAILABLE
        CLR AUTODRAW
        JSR BUILD_POSITION
        JMP HIST_APPEND
RECORD_POSITION:
        JSR BOOK_RECORD
        LDAA FULLRULES
        BNE LONG_17
        JMP HP_DONE
LONG_17:
        LDAA ACTIVEBLACK
        EORA #1
        ASLA
        ASLA
        ASLA
        ASLA
        STAA NEXTSIDE
        LDD HALFMOVE
        BNE HP_KEEP
        CLR HISTORYCOUNT
HP_KEEP:
        JSR BUILD_POSITION
HP_TEST:
        CLR DRAW_AVAILABLE
        CLR AUTODRAW
        LDAA #1
        STAA REPEATS
        CLR HISTORYINDEX
        LDX #HISTORY
        STX HISTORYPTR
HP_LOOP:
        LDAA HISTORYINDEX
        CMPA HISTORYCOUNT
        BEQ HP_COUNTS
        CLRB
HP_COMPARE:
        LDX HISTORYPTR
        ABX
        LDAA 0,X
        PSHA
        LDX #POSITIONBUF
        ABX
        PULA
        CMPA 0,X
        BNE HP_NEXT
        INCB
        CMPB #34
        BNE HP_COMPARE
        INC REPEATS
HP_NEXT:
        LDD HISTORYPTR
        ADDD #34
        STD HISTORYPTR
        INC HISTORYINDEX
        BRA HP_LOOP
HP_COUNTS:
        LDAA REPEATS
        CMPA #3
        BCS HP_FIFTY
        LDAA #1
        STAA DRAW_AVAILABLE
        LDAA REPEATS
        CMPA #5
        BCS HP_FIFTY
        LDAA #1
        STAA AUTODRAW
HP_FIFTY:
        LDD HALFMOVE
        TSTA
        BNE HP_SEVENTYFIVE
        CMPB #100
        BCS HP_APPEND
        LDAA DRAW_AVAILABLE
        ORAA #2
        STAA DRAW_AVAILABLE
        LDAB HALFMOVE+1
        CMPB #150
        BCS HP_APPEND
HP_SEVENTYFIVE:
        LDAA #1
        STAA AUTODRAW
HP_APPEND:
        LDAA NO_APPEND
        BNE HP_DONE
        LDAA HISTORYCOUNT
        CMPA #151
        BCC HP_DONE
HIST_APPEND:
        LDAA HISTORYCOUNT
        LDAB #34
        MUL
        ADDD #HISTORY
        STD HISTORYPTR
        CLRB
HA_COPY:
        LDX #POSITIONBUF
        ABX
        LDAA 0,X
        PSHA
        LDX HISTORYPTR
        ABX
        PULA
        STAA 0,X
        INCB
        CMPB #34
        BNE HA_COPY
        INC HISTORYCOUNT
HP_DONE: RTS
BUILD_POSITION:
        LDX #POSITIONBUF
        CLRA
BP_CLEAR:
        STAA 0,X
        INX
        CPX #POSITIONBUF+34
        BNE BP_CLEAR
        CLR POSITIONPIECE
BP_PIECE:
        LDAB POSITIONPIECE
        LDX #BOARD
        ABX
        LDAA 0,X
        BITA #$88
        BNE BP_NEXT
        LDAB ACTIVEBLACK
        BEQ BP_CANONICAL
        EORA #$77
BP_CANONICAL:
        STAA POSITIONSQUARE
        ANDA #$70
        LSRA
        LSRA
        STAA POSITIONBYTE
        LDAA POSITIONSQUARE
        ANDA #7
        LSRA
        ADDA POSITIONBYTE
        STAA POSITIONBYTE
        LDAB POSITIONPIECE
        JSR TYPE_OF
        STAA POSITIONVALUE
        LDAA POSITIONPIECE
        LSRA
        LSRA
        LSRA
        LSRA
        EORA ACTIVEBLACK
        BEQ BP_WHITE
        LDAA POSITIONVALUE
        ORAA #8
        STAA POSITIONVALUE
BP_WHITE:
        LDAA POSITIONSQUARE
        BITA #1
        BNE BP_LOW_NIBBLE
        LDAA POSITIONVALUE
        ASLA
        ASLA
        ASLA
        ASLA
        BRA BP_NIBBLE
BP_LOW_NIBBLE:
        LDAA POSITIONVALUE
BP_NIBBLE:
        LDAB POSITIONBYTE
        LDX #POSITIONBUF
        ABX
        ORAA 0,X
        STAA 0,X
BP_NEXT:
        INC POSITIONPIECE
        LDAA POSITIONPIECE
        CMPA #32
        BNE BP_PIECE
        LDAA ACTIVEBLACK
        BEQ BP_NORMAL_RIGHTS
        LDAA RIGHTSE
        LDAB RIGHTSF
        BRA BP_RIGHTS
BP_NORMAL_RIGHTS:
        LDAA RIGHTSF
        LDAB RIGHTSE
BP_RIGHTS:
        ASLB
        ASLB
        ABA
        ORAA NEXTSIDE
        STAA POSITIONBUF+32
        JSR EFFECTIVE_EP
        STAA POSITIONBUF+33
        RTS
; EP changes repetition identity only when the next side has a legal EP move.
EFFECTIVE_EP:
        LDAA EPTARGET
        CMPA #$FF
        BNE LONG_18
        JMP EE_DONE
LONG_18:
        LDAA PIECE
        PSHA
        LDAA SQUARE
        PSHA
        LDAA MOVEN
        PSHA
        LDAA VA
        PSHA
        LDAA VX
        PSHA
        LDAA VY
        PSHA
        LDAA VF
        PSHA
        JSR REVERSE
        CLR EPVALID
        CLR EPITER
EE_TRY:
        LDAA EPTARGET
        LDAB EPITER
        BEQ EE_LEFT
        SUBA #15
        BRA EE_LOOK
EE_LEFT: SUBA #17
EE_LOOK:
        BITA #$88
        BNE EE_NEXT
        JSR LOOKUP
        CMPA #8
        BCS EE_NEXT
        CMPA #16
        BCC EE_NEXT
        STAA PIECE
        TAB
        LDX #PROMOTED
        ABX
        LDAA 0,X
        BNE EE_NEXT
        LDAA EPTARGET
        STAA SQUARE
        LDAA #5
        ADDA EPITER
        STAA MOVEN
        JSR MOVE
        JSR NATIVE_CHECK
        STAA CHECKRESULT
        JSR UMOVE
        LDAA CHECKRESULT
        BNE EE_NEXT
        INC EPVALID
        BRA EE_FINISH
EE_NEXT:
        INC EPITER
        LDAA EPITER
        CMPA #2
        BNE EE_TRY
EE_FINISH:
        JSR REVERSE
        LDAA #$FF
        LDAB EPVALID
        BEQ EE_STORE
        LDAA EPTARGET
        LDAB ACTIVEBLACK
        BEQ EE_STORE
        EORA #$77
EE_STORE:
        STAA EPHASH
        PULA
        STAA VF
        PULA
        STAA VY
        PULA
        STAA VX
        PULA
        STAA VA
        PULA
        STAA MOVEN
        PULA
        STAA SQUARE
        PULA
        STAA PIECE
        LDAA EPHASH
EE_DONE: RTS
; Insufficient material recognizes bare kings, K+minor vs K, and bishops
; only on one square color. Two knights and opposite-color bishops remain live.
DEAD_POSITION:
        CLR MINORS
        CLR KNIGHTS
        LDAA #$FF
        STAA BISHOPCOLOR
        CLR DEADPIECE
DP_LOOP:
        LDAB DEADPIECE
        LDX #BOARD
        ABX
        LDAA 0,X
        BITA #$88
        BNE DP_NEXT
        STAA DEADSQUARE
        JSR TYPE_OF
        CMPA #6
        BEQ DP_NEXT
        CMPA #1
        BEQ DP_LIVE
        CMPA #4
        BCC DP_LIVE
        INC MINORS
        CMPA #2
        BNE DP_BISHOP
        INC KNIGHTS
        BRA DP_NEXT
DP_BISHOP:
        LDAA DEADSQUARE
        LSRA
        LSRA
        LSRA
        LSRA
        EORA DEADSQUARE
        ANDA #1
        LDAB BISHOPCOLOR
        CMPB #$FF
        BEQ DP_SET_COLOR
        CMPA BISHOPCOLOR
        BNE DP_LIVE
DP_SET_COLOR:
        STAA BISHOPCOLOR
DP_NEXT:
        INC DEADPIECE
        LDAA DEADPIECE
        CMPA #32
        BNE DP_LOOP
        LDAA MINORS
        CMPA #2
        BCS DP_DEAD
        LDAA KNIGHTS
        BNE DP_LIVE
DP_DEAD: LDAA #1
        RTS
DP_LIVE: CLRA
        RTS
CHECK_DRAW:
        LDAA FULLRULES
        BEQ CD_DONE
        JSR DEAD_POSITION
        TSTA
        BNE CD_DRAW
        LDAA AUTODRAW
        BNE CD_DRAW
        LDAA ACTIVEBLACK
        BEQ CD_DONE
        LDAA DRAW_AVAILABLE     ; computer claims on its turn
        BEQ CD_DONE
CD_DRAW:
        LDAA #4
        STAA GAMEOVER
CD_DONE: RTS
NEXTSIDE: .BYTE 0
HISTORYCOUNT: .BYTE 0
HISTORYINDEX: .BYTE 0
HISTORYPTR: .WORD HISTORY
REPEATS: .BYTE 0
DRAW_AVAILABLE: .BYTE 0
AUTODRAW: .BYTE 0
POSITIONPIECE: .BYTE 0
POSITIONSQUARE: .BYTE 0
POSITIONBYTE: .BYTE 0
POSITIONVALUE: .BYTE 0
EPVALID: .BYTE 0
EPITER: .BYTE 0
EPHASH: .BYTE 0
MINORS: .BYTE 0
KNIGHTS: .BYTE 0
BISHOPCOLOR: .BYTE 0
DEADPIECE: .BYTE 0
DEADSQUARE: .BYTE 0
POSITIONBUF: .FILL 34,0

MSG_NOCLAIM: .TEXT "NO DRAW CLAIM"
        .BYTE 0
HISTORY:
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 64,0
        .FILL 14,0

; Claim an intended legal move without committing it or changing history.
CLAIM_TRIAL:
        LDAA DRAW_AVAILABLE
        PSHA
        LDAA AUTODRAW
        PSHA
        JSR MOVE
        LDAA #16              ; human is White, proposed position is Black to move
        STAA NEXTSIDE
        JSR BUILD_POSITION
        LDAA #1
        STAA NO_APPEND
        JSR HP_TEST
        LDAA DRAW_AVAILABLE
        STAA CLAIMRESULT
        JSR UMOVE
        CLR NEXTSIDE
        JSR BUILD_POSITION
        CLR NO_APPEND
        PULA
        STAA AUTODRAW
        PULA
        STAA DRAW_AVAILABLE
        LDAA CLAIMRESULT
        RTS
CLAIMING: .BYTE 0
NO_APPEND: .BYTE 0
CLAIMRESULT: .BYTE 0


; Original supplied SETW, with files mirrored by the historical UI adapter.
HISTSETW: .BYTE 3,4,0,7,2,5,1,6
        .BYTE $10,$17,$11,$16,$12,$15,$14,$13
        .BYTE $73,$74,$70,$77,$72,$75,$71,$76
        .BYTE $60,$67,$61,$66,$62,$65,$64,$63
CHECKPROMPT: .TEXT "CHECK: "
        .BYTE 0

HIGHLIGHT: .BYTE 0
; Modern play bounds work in JANUS move events. Historical mode is unbounded.
; On expiry, restore the complete root position and use the best completed
; candidate (or the existing legal fallback), never a partially examined move.
SEARCH_BEGIN:
        STS SEARCHSP
        LDD SEARCHSP
        ADDD #2                ; remove this helper's return address
        STD SEARCHSP
        CLR SEARCHCUT
        LDAA FULLRULES
        BEQ SB_INACTIVE
        LDAA LIMITMODE
SB_INACTIVE:
        STAA BUDGETACTIVE
        BEQ SB_DONE
        LDD #$1000             ; 4,096 generated-move analysis events
        STD SEARCHNODES
        LDX #ROOTBOARD
        STX COPYDEST
        LDX #BOARD
        LDAB #32
        JSR ROOT_COPY
        LDX #ROOTPROM
        STX COPYDEST
        LDX #PROMOTED
        LDAB #64               ; promotion kinds and their point values
        JSR ROOT_COPY
        LDX #ROOTSTATE
        STX UPTR
        JSR RULES_SAVE
        LDAA ACTIVEBLACK
        STAA ROOTSTATE+15
        JSR RESET_STACKS
SB_DONE: RTS
BUDGET_TICK:
        LDAA BUDGETACTIVE
        BEQ BT_DONE
        LDD SEARCHNODES
        SUBD #1
        STD SEARCHNODES
        BNE BT_DONE
        JMP SEARCH_ABORT
BT_DONE: RTS
SEARCH_ABORT:
        CLR BUDGETACTIVE
        LDAA #1
        STAA SEARCHCUT
        LDS SEARCHSP
        LDX #ROOTBOARD
        LDAB #32
        LDD #BOARD
        STD COPYDEST
        LDAB #32
        JSR ROOT_COPY
        LDX #ROOTPROM
        LDD #PROMOTED
        STD COPYDEST
        LDAB #64
        JSR ROOT_COPY
        LDX #ROOTSTATE
        STX UPTR
        JSR RULES_UNDO
        LDAA ROOTSTATE+15
        STAA ACTIVEBLACK
        JSR RESET_STACKS
        LDAA BESTV
        CMPA #15
        BCS SA_NONE
        JMP MV2
SA_NONE: JMP MATE
ROOT_COPY:
        LDAA 0,X
        INX
        STX COPYSOURCE
        LDX COPYDEST
        STAA 0,X
        INX
        STX COPYDEST
        LDX COPYSOURCE
        DECB
        BNE ROOT_COPY
        RTS
SEARCHSP: .WORD 0
SEARCHNODES: .WORD 0
BUDGETACTIVE: .BYTE 0
SEARCHCUT: .BYTE 0
ROOTBOARD .EQU VMEM+$20
ROOTPROM .EQU VMEM+$70       ; Unused virtual-memory region; 64-byte root snapshot
ROOTSTATE .EQU VMEM+$40

LIMITMODE: .BYTE 1
; QUICK enumerates all legal moves using the existing generator. No capture tree.
QUICK_GO:
        CLR SEARCHOK
        CLR BUDGETACTIVE
        LDD #$8000
        STD QBEST
        LDAA #$FF
        STAA BESTP
        LDAA #1
        STAA QUICKSCAN
        STAA VALIDATING
        STAA PROMCHOICE
        LDAA #4
        STAA STATE
        JSR GNM
        CLR QUICKSCAN
        CLR VALIDATING
        LDAA BESTP
        CMPA #$FF
        BEQ QG_DONE
        STAA PIECE
        TAB
        LDX #BOARD
        ABX
        LDAA 0,X
        STAA BESTV
        LDAA BESTM
        STAA SQUARE
        LDAA BESTPROM
        STAA PROMCHOICE
        CLR MOVEN
        LDAA #1
        STAA SEARCHOK
        JMP MOVE
QG_DONE: RTS
QUICK_CANDIDATE:
        LDAA VA
        PSHA
        LDAA VX
        PSHA
        LDAA VY
        PSHA
        LDAA VF
        PSHA
        LDAB PIECE
        JSR TYPE_OF
        STAA QTYPE
        LDAB PIECE
        LDX #BOARD
        ABX
        LDAA 0,X
        STAA QFROM
        JSR Q_POSITION
        TAB
        CLRA
        STD QVALUE
        LDAA SQUARE
        JSR Q_POSITION
        TAB
        CLRA
        SUBD QVALUE
        STD QSCORE
        LDAA QTYPE
        CMPA #6
        BNE QC_MOVE
        LDD QSCORE
        SUBD #8
        STD QSCORE
        LDAA SQUARE
        SUBA QFROM
        CMPA #2
        BEQ QC_CASTLE
        CMPA #$FE
        BNE QC_MOVE
QC_CASTLE:
        LDD QSCORE
        ADDD #24
        STD QSCORE
QC_MOVE:
        JSR MOVE
        LDD UPTR
        SUBD #16
        STD QVALUE
        LDX QVALUE
        LDAB 1,X
        CMPB #$FF
        BEQ QC_PROMO
        LDX #POINTVAL
        ABX
        LDAA 0,X
        ASLA
        ASLA
        ASLA
        ASLA
        TAB
        CLRA
        ADDD QSCORE
        STD QSCORE
QC_PROMO:
        LDAA QTYPE
        CMPA #1
        BNE QC_ATTACK
        LDAA SQUARE
        ANDA #$70
        CMPA #$70
        BNE QC_ATTACK
        LDAB PIECE
        LDX #POINTVAL
        ABX
        LDAA 0,X
        SUBA #2
        ASLA
        ASLA
        ASLA
        ASLA
        TAB
        CLRA
        ADDD QSCORE
        STD QSCORE
QC_ATTACK:
        LDAA SQUARE
        STAA TARGETKING
        JSR NATIVE_ATTACK
        TSTA
        BEQ QC_UNDO
        LDAB PIECE
        LDX #POINTVAL
        ABX
        LDAA 0,X
        ASLA
        ASLA
        ASLA
        ASLA
        TAB
        CLRA
        STD QVALUE
        LDD QSCORE
        SUBD QVALUE
        STD QSCORE
QC_UNDO:
        JSR UMOVE
        LDD QSCORE
        SUBD QBEST
        BLE QC_RETURN
        LDD QSCORE
        STD QBEST
        LDAA PIECE
        STAA BESTP
        LDAA SQUARE
        STAA BESTM
        LDAA PROMCHOICE
        STAA BESTPROM
QC_RETURN:
        PULA
        STAA VF
        PULA
        STAA VY
        PULA
        STAA VX
        PULA
        STAA VA
        RTS
; Native piece-square score, 0..24. Relative gain avoids repeated pawn pushes.
Q_POSITION:
        PSHA
        ANDA #7
        TAB
        LDX #QCENTER
        ABX
        LDAA 0,X
        STAA BOOKBYTE
        PULA
        LSRA
        LSRA
        LSRA
        LSRA
        LDAB QTYPE
        CMPB #1
        BNE QP_MINOR
        ASLA
        ADDA BOOKBYTE
        RTS
QP_MINOR:
        TAB
        LDX #QCENTER
        ABX
        LDAA 0,X
        ADDA BOOKBYTE
        ASLA
        LDAB QTYPE
        CMPB #5
        BEQ QP_RETURN
        CMPB #6
        BNE QP_DOUBLE
        CLRA
        RTS
QP_DOUBLE: ASLA
QP_RETURN: RTS
QCENTER: .BYTE 0,1,2,3,3,2,1,0

; Book uses 8 quiet-prefix lines, up to White/Black's second move.
; Only real moves advance BOOKPLY. Trials and search never affect the book.
BOOK_RECORD:
        LDAA BOOKPLY
        CMPA #4
        BCC BR_DONE
        ASLA
        TAB
        LDX #BOOKPATH
        ABX
        LDAA FROMTEMP
        LDAB ACTIVEBLACK
        BEQ BR_FROM
        EORA #$77
BR_FROM:
        STAA 0,X
        LDAA SQUARE
        LDAB ACTIVEBLACK
        BEQ BR_TO
        EORA #$77
BR_TO:
        STAA 1,X
        INC BOOKPLY
BR_DONE: RTS
BOOK_TRY:
        CLR SEARCHOK
        LDAA BOOKPLY
        CMPA #4
        BCS LONG_24
        JMP BOOK_DONE
LONG_24:
        ASLA
        STAA BOOKOFFSET
        LDX #BOOKLINES
        STX BOOKPTR
        LDAA #8
        STAA BOOKROWS
BT_ROW:
        CLR BOOKINDEX
BT_PREFIX:
        LDAB BOOKINDEX
        CMPB BOOKOFFSET
        BEQ BT_MATCH
        LDX BOOKPTR
        ABX
        LDAA 0,X
        LDX #BOOKPATH
        ABX
        CMPA 0,X
        BNE BT_NEXT
        INC BOOKINDEX
        BRA BT_PREFIX
BT_MATCH:
        JSR BOOK_VERIFY
        TSTA
        BEQ BT_FAILED
        LDX BOOKPTR
        LDAB BOOKOFFSET
        ABX
        LDAA 0,X
        LDAB ACTIVEBLACK
        BEQ BT_FROM
        EORA #$77
BT_FROM:
        JSR LOOKUP
        CMPA #16
        BCC BT_FAILED
        STAA WANTPIECE
        LDX BOOKPTR
        LDAB BOOKOFFSET
        ABX
        LDAA 1,X
        LDAB ACTIVEBLACK
        BEQ BT_TO
        EORA #$77
BT_TO:
        STAA WANTTO
        LDAA #1
        STAA WANTPROM
        JSR CHECK_LEGAL
        LDAA VALIDMOVE
        BEQ BT_FAILED
        LDAA WANTPIECE
        STAA PIECE
        STAA BESTP
        TAB
        LDX #BOARD
        ABX
        LDAA 0,X
        STAA BESTV
        LDAA WANTTO
        STAA SQUARE
        STAA BESTM
        LDAA #1
        STAA SEARCHOK
        STAA BOOKHIT
        STAA BESTPROM
        STAA PROMCHOICE
        CLR MOVEN
        JMP MOVE
BT_NEXT:
        LDD BOOKPTR
        ADDD #8
        STD BOOKPTR
        DEC BOOKROWS
        BEQ LONG_25
        JMP BT_ROW
LONG_25:
BT_FAILED:
        LDAA #$FF
        STAA BOOKPLY
BOOK_DONE: RTS
; Rebuild the expected canonical position and compare every piece slot.
BOOK_VERIFY:
        LDAA RIGHTSF
        CMPA #3
        BEQ LONG_28
        JMP BV_BAD
LONG_28:
        LDAA RIGHTSE
        CMPA #3
        BEQ LONG_29
        JMP BV_BAD
LONG_29:
        LDX #ROOTBOARD
        STX COPYDEST
        LDX #SETW
        LDAB #32
        JSR ROOT_COPY
        CLR BOOKINDEX
BV_MOVE:
        LDAB BOOKINDEX
        CMPB BOOKOFFSET
        BEQ BV_COMPARE
        LDX #BOOKPATH
        ABX
        LDAA 0,X
        STAA BOOKBYTE
        LDAB #31
BV_FIND:
        LDX #ROOTBOARD
        ABX
        LDAA 0,X
        CMPA BOOKBYTE
        BEQ BV_FOUND
        DECB
        BPL BV_FIND
        BRA BV_BAD
BV_FOUND:
        PSHX
        LDAB BOOKINDEX
        LDX #BOOKPATH
        ABX
        LDAA 1,X
        PULX
        STAA 0,X
        INC BOOKINDEX
        INC BOOKINDEX
        BRA BV_MOVE
BV_COMPARE:
        CLR BOOKINDEX
BV_PIECE:
        LDAB BOOKINDEX
        LDX #ROOTBOARD
        ABX
        LDAA 0,X
        STAA BOOKBYTE
        LDAB BOOKINDEX
        LDAA ACTIVEBLACK
        BEQ BV_WHITE
        EORB #16
BV_WHITE:
        LDX #PROMOTED
        ABX
        LDAA 0,X
        BNE BV_BAD
        LDX #BOARD
        ABX
        LDAA 0,X
        LDAB ACTIVEBLACK
        BEQ BV_CANONICAL
        EORA #$77
BV_CANONICAL:
        CMPA BOOKBYTE
        BNE BV_BAD
        INC BOOKINDEX
        LDAA BOOKINDEX
        CMPA #32
        BNE BV_PIECE
        LDAA #1
        RTS
BV_BAD: CLRA
        RTS
BOOKLINES:
        .BYTE $14,$34,$64,$44,$06,$25,$71,$52
        .BYTE $14,$34,$64,$44,$05,$32,$76,$55
        .BYTE $14,$34,$64,$44,$01,$22,$76,$55
        .BYTE $14,$34,$64,$44,$13,$33,$44,$33
        .BYTE $13,$33,$63,$43,$12,$32,$64,$54
        .BYTE $13,$33,$63,$43,$06,$25,$76,$55
        .BYTE $12,$32,$64,$44,$01,$22,$76,$55
        .BYTE $06,$25,$63,$43,$13,$33,$76,$55

; Temporary 64-square occupancy map, rebuilt for each native attack query.
; Highest slot wins, matching the original reverse-order LOOKUP scan.
BUILD_OCCUPANCY:
        LDX #OCCUPANCY
        LDAB #64
        LDAA #$FF
BO_CLEAR:
        STAA 0,X
        INX
        DECB
        BNE BO_CLEAR
        CLR ATTACKPIECE
BO_PIECE:
        LDAB ATTACKPIECE
        LDX #BOARD
        ABX
        LDAA 0,X
        BITA #$88
        BNE BO_NEXT
        STAA PROBESQ
        ANDA #7
        STAA UITMP
        LDAA PROBESQ
        ANDA #$70
        LSRA
        ADDA UITMP
        TAB
        LDX #OCCUPANCY
        ABX
        LDAA ATTACKPIECE
        STAA 0,X
BO_NEXT:
        INC ATTACKPIECE
        LDAA ATTACKPIECE
        CMPA #32
        BNE BO_PIECE
        LDAA #1
        STAA OCCUPANCYFLAG
        RTS
OCCUPANCY .EQU $4FC0
OCCUPANCYFLAG .EQU VMEM+25

IMAGE_END:
        .END START
