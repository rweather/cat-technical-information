;***********************************************************************
;
; Common definitions for the $C100 and $C800 printer driver ROM's.
;
;***********************************************************************
;
; Zero page locations.
;
TEMP0   .equ    $00         ; Temporary variable.
TEMP1   .equ    $01         ; Temporary variable.
TEMP2   .equ    $02         ; Temporary variable.
WNDLFT  .equ    $20         ; Left-most column of the text window (0-79).
WNDWTH  .equ    $21         ; Width of the text window (1-80).
WNDBTM  .equ    $22         ; Height of the text window (1-24).
CHORZ   .equ    $24         ; Horizontal offset of the cursor (0-WNDWTH-1).
CVERT   .equ    $25         ; Vertical offset of the cursor (0-WNDBTM-1).
INVFLG  .equ    $32         ; Inverse flag: $FF = normal, $3F = inverse.
OUTSW   .equ    $36         ; Address of the global character output routine.
;
; Main memory locations.
;
STACK   .equ    $0100       ; System stack.
GRMODE  .equ    $0479       ; Epson graphics bit image mode, default is "K".
CHRINV  .equ    $04F9       ; Character to use to toggle inverse mode.
CHRGR   .equ    $0579       ; Character to use to toggle graphics mode.
CVTCRLF .equ    $05F9       ; 0 to convert CR into CRLF, 1 to not do that.
PRWID   .equ    $0679       ; Width of the page for printing.
PRHGR   .equ    $06F9       ; Graphics mode: 0=HGR1,2 1=HGR5,6 2=HGR3,4
PRMOD   .equ    $0779       ; Graphics printing mode bits.
PRCOL   .equ    $07F9       ; Current column for printing.
;
; I/O ports for the printer.
;
PRWRITE .equ    $C090       ; Write data to printer.
PRACK   .equ    $C1C0       ; Read printer acknowledge.
PRBUSY  .equ    $C1C1       ; Read printer busy.
;
; ASCII characters.
;
CH_LF   .equ    $0A
CH_CR   .equ    $0D
CH_ESC  .equ    $1B
;
; Bits in "PRMOD" that control graphics print options.
;
MPAGE1  .equ    $01         ; Print graphics page 1.
MPAGE2  .equ    $02         ; Print graphics page 2.
MAND    .equ    $04         ; AND the two pages together to get the result.
MOR     .equ    $08         ; OR  the two pages together to get the result.
MEOF    .equ    $10         ; EOR the two pages together to get the result.
MINV    .equ    $20         ; Inverse printing.
MLARGE  .equ    $40         ; Enlarged printing.
MOPTION .equ    $80         ; Select option (used by text printing mode).
