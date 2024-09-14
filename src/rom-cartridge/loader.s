;
; Copyright (C) 2024 Rhys Weatherley
;
; Permission is hereby granted, free of charge, to any person obtaining a
; copy of this software and associated documentation files (the "Software"),
; to deal in the Software without restriction, including without limitation
; the rights to use, copy, modify, merge, publish, distribute, sublicense,
; and/or sell copies of the Software, and to permit persons to whom the
; Software is furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included
; in all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
; OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
; DEALINGS IN THE SOFTWARE.
;

;
; Zero page variables.
;
SLOT    .equ    $42         ; Points to the start of the slot ROM.
LOAD    .equ    $34         ; Saved load address.
PTR     .equ    $3C         ; Temporary pointer variable.
SIZE    .equ    $3E         ; Size of the program to load.
BANK    .equ    $2F         ; Number of the next bank to load from.
;
; Other memory locations.
;
STACK   .equ    $0100       ; Location of the stack.
SLOTSV  .equ    $047A       ; Saved slot number for use by other programs.
;
; The origin is specified as $C500, but it can also be run from $C200.
;
        .org    $C500
;
; Signature bytes to make this an autoboot ROM for slot 5.  The kernel
; ROM will think that this is a secondary disk controller.
;
; Equivalent instructions:
;
;       ldx     #$20
;       ldy     #$00
;       ldx     #$03
;       stx     $3C
;
    .ifdef AUTOBOOT
        .db     $A2, $20, $A0, $00, $A2, $03, $86, $3C
    .endif
;
; Make it so that "PR#N" will activate the ROM, but leave the input
; and output devices alone.
;
        jsr     $FE93       ; Reset the output device with "PR#0".
        jsr     $FE89       ; Reset the input device with "IN#0".
;
; Figure out which slot we are located in.
;
        jsr     $FF58       ; Location of a "RTS" instruction in the kernel ROM.
        tsx
        lda     STACK,x     ; Should be $C2 or $C5 for the return address.
        sta     SLOT+1
        sta     SLOTSV
        lda     #0
        sta     SLOT        ; SLOT is now $C200 or $C500.
;
; Get the load address and size of the primary boot program in the ROM.
; These are stored in the last 4 bytes of the 128-byte loader program.
;
        ldy     #$7C
        lda     (SLOT),y
        sta     PTR
        sta     LOAD
        iny
        lda     (SLOT),y
        sta     PTR+1
        sta     LOAD+1
        iny
        lda     (SLOT),y
        sta     SIZE
        iny
        lda     (SLOT),y
        sta     SIZE+1
;
; Offset PTR by -128 to account for the offset in Y below.
;
        lda     PTR
        sec
        sbc     #$80
        sta     PTR
        lda     PTR+1
        sbc     #0
        sta     PTR+1
;
; Copy the primary boot program from the start of the ROM to its load address.
;
        ldy     #0
        sty     BANK
NEXTBANK:
        lda     BANK
        sta     (SLOT),y
        ldy     #$80        ; Offset Y by 128.
COPYBANK:
        lda     (SLOT),y    ; Load from $CN80 - $CNFF.
        sta     (PTR),y
        iny
        bne     COPYBANK
;
; Move onto the next bank.
;
        inc     BANK
        lda     PTR
        clc
        adc     #$80
        sta     PTR
        lda     PTR+1
        adc     #0
        sta     PTR+1
;
; Are we done yet?  Subtract 128 from SIZE and check for < 0.
;
; It is assumed that the actual size of the primary boot program is
; SIZE plus 1.  That is, SIZE is deliberately one byte short.
; We also copy entire 128 byte banks, so SIZE % 128 should be 127.
;
        lda     SIZE
        sec
        sbc     #$80
        sta     SIZE
        bcs     NEXTBANK
        lda     SIZE+1
        sbc     #0
        sta     SIZE+1
        bcs     NEXTBANK
;
; Jump to the primary boot program's load address.
;
        jmp     (LOAD)
;
; End of the loader code.  This is followed by the load address and size
; of the primary boot program.
;
        .org    $C57C
