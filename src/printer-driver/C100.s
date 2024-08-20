
;***********************************************************************
;
; This is the assembly code for the $C100 ROM - printer driver.
;
; This is just the entry point for the driver.  The real code is in the
; $C800 ROM for the printer driver.
;
;***********************************************************************

        .include "common.s"
;
; Entry points to the $C800 bank-switched ROM where the actual driver resides.
;
PRCHAR  .equ    $C800       ; Print a character.
PRGRAPH .equ    $C803       ; Print the graphics screen to the printer.
PREXIT  .equ    $C806       ; Restore registers and exit from the driver.
;
; $C100 is called when "PR#1" is executed to initialise the printer and to
; switch the global character output routine to the printer.
;
; $C102 is called for normal character printing.
;
; Special characters:
;
;       $91     Print the graphics screen to the (Epson) printer.
;       $94     Toggle inverse printing mode.
;       $97     Toggle graphics printing mode.
;
        .org    $C100
ENTRY0:
        clc
        .db     $B0         ; This causes the next instruction to be skipped.
ENTRY1:
        sec
        pha                 ; Save the registers on the stack.
        txa
        pha
        tya
        pha
        lda     TEMP0       ; Save some zero page locations on the stack
        pha                 ; as we will be using them as working variables.
        lda     TEMP1
        pha
        lda     TEMP2
        pha
        tsx
        lda     STACK+6,X   ; Move the original A to the top of the stack.
        pha
        bcs     PRINT
;
; Initialise variables for the printer driver.
;
        lda     #$94        ; DC4 character to toggle inverse mode.
        sta     CHRINV
        lda     #$97        ; ETB character to toggle graphics mode.
        sta     CHRGR
        lda     #0          ; Convert CR into CRLF by default.
        sta     CVTCRLF
        sta     PRHGR       ; Select graphics modes HGR1,2 by default.
        lda     CHORZ       ; Set the initial column number.
        jsr     SETCOL
        lda     WNDWTH      ; Set the paper width from the screen width.
        sta     PRWID
        lda     #1          ; Print graphics page 1 by default.
        sta     PRMOD
        lda     #$4B        ; "K" to select single-density bit image mode.
        sta     GRMODE
;
; Set the global character output routine to $C102 for printing characters.
;
        lda     #<ENTRY1
        sta     OUTSW
        lda     #>ENTRY1
        sta     OUTSW+1
        pla
        nop
        nop
        .db     $F0         ; This causes the next instruction to be skipped.
;
; Print a character.
;
PRINT:
        pla
        sta     $CFFF       ; Activate that $C800 ROM for the printer driver.
        sta     $C100
        cmp     #$91        ; DC1 character?
        bne     PRINT2
        jmp     PRGRAPH     ; Yes, print the graphics screen.
PRINT2:
        pha
        cmp     CHRINV      ; Check for the inverse control character.
        bne     PRINT3
        lda     INVFLG      ; Toggle inverse mode.
        eor     #$C0
        sta     INVFLG
        pla
        jmp     PREXIT
PRINT3:
        pla
        pha
        cmp     CHRGR
        bne     PRINT4
        lda     PRHGR       ; Toggle graphics printing modes.
        eor     #$FF
        sta     PRHGR 
        pla
        jmp     PREXIT
PRINT4:
        pla
        jmp     PRCHAR      ; Print a regular character.
;
        .db     $2F         ; Padding
;
; Set the current column for printing to A+1.
;
SETCOL:
        adc     #1
        sta     PRCOL
        rts
;
; Random garbage to pad the $C100 ROM to 256 bytes.  The real printer
; driver code is in the $C800 ROM.
;
        .db $00, $30
        .db $5A, $50, $33, $31, $20, $20, $00, $31
        .db $5A, $50, $33, $32, $20, $20, $00, $32
        .db $5A, $50, $33, $33, $20, $20, $00, $33
        .db $5A, $50, $33, $34, $20, $20, $00, $34
        .db $5A, $50, $33, $35, $20, $20, $00, $35
        .db $5A, $50, $33, $36, $20, $20, $00, $36
        .db $5A, $50, $33, $37, $20, $20, $00, $37
        .db $DA, $D0, $33, $B8, $A0, $20, $00, $38
        .db $DA, $D0, $B3, $B9, $A0, $20, $00, $39
        .db $5A, $50, $33, $41, $20, $20, $00, $3A
        .db $5A, $50, $33, $42, $20, $20, $00, $3B
        .db $5A, $50, $33, $43, $20, $20, $00, $3C
        .db $5A, $50, $33, $44, $20, $20, $00, $3D
        .db $5A, $50, $33, $45, $20, $20, $00, $00
        .db $0A, $00, $33, $46, $20, $20, $00, $3F
