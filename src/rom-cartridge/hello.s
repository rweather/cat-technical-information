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
; Fill most of the EEPROM with 128 byte banks consisting of the bank number.
;
        .org    $4280
    .macro BANK
        .fill   128,\1
    .endm
    .macro BANKS
        .fill   128,\1
        .fill   128,\1+1
        .fill   128,\1+2
        .fill   128,\1+3
        .fill   128,\1+4
        .fill   128,\1+5
        .fill   128,\1+6
        .fill   128,\1+7
        .fill   128,\1+8
        .fill   128,\1+9
        .fill   128,\1+10
        .fill   128,\1+11
        .fill   128,\1+12
        .fill   128,\1+13
        .fill   128,\1+14
        .fill   128,\1+15
    .endm
        BANKS   $00
        BANKS   $10
        BANKS   $20
        BANKS   $30
        BANKS   $40
        BANKS   $50
        BANKS   $60
        BANKS   $70
        BANKS   $80
        BANKS   $90
        BANKS   $A0
        BANKS   $B0
        BANKS   $C0
        BANKS   $D0
        BANKS   $E0
        BANK    $F0
        BANK    $F1
        BANK    $F2
        BANK    $F3
        BANK    $F4
        BANK    $F5
        BANK    $F6
        BANK    $F7
        BANK    $F8
        BANK    $F9
        BANK    $FA
        BANK    $FB
        BANK    $FC
        BANK    $FD
        BANK    $FE

;
; Put the actual code in the top-most 128-byte bank of the EEPROM.
; Should be able to run from either $C200 or $C500.
;
        .org    $C200
START:
        jsr     $FF58       ; Location of a "RTS" instruction in the kernel ROM.
        tsx
        lda     $0100,x     ; Should be $C2 or $C5 for the return address.
        sta     $FD
        ldy     #<MSG
        sty     $FC
        ldy     #0
PRINT:
        lda     ($FC),y
        beq     DONE
        ora     #$80
        jsr     $FDED
        iny
        bne     PRINT
DONE:
        lda     $FD
        ldx     #0
        jsr     $F941       ; Print A:X in hexadecimal.
        jmp     $FEC5       ; Print CR and exit.
MSG:
        .db     $0C, "Hello, World!", $0D, $0D
        .db     "Loaded from: $", 0
;
; Pad the EEPROM image to 32K.
;
        .fill   $C280-*,$FF
