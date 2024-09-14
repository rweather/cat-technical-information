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
INSW    .equ    $38         ; Address of the keyboard input routine.
PTR     .equ    $FE         ; Temporary 16-bit pointer variable.
;
; Other memory locations.
;
STACK   .equ    $0100       ; Location of the stack.
SLOT    .equ    $047A       ; Saved slot number: $C2 or $C5.
BANK    .equ    $04FA       ; Number of the next bank to load from.
OFFSET  .equ    $057A       ; Offset into the current bank.
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
; Make it so that "PR#N" will activate the ROM, but leave the output
; device alone.
;
        jsr     $FE93       ; Reset the output device with "PR#0".
;
; Figure out which slot we are located in.
;
        jsr     $FF58       ; Location of a "RTS" instruction in the kernel ROM.
        tsx
        lda     STACK,x     ; Should be $C2 or $C5 for the return address.
        sta     SLOT
        ldx     #0          ; Start reading from bank 0.
        stx     BANK
        ldx     #$80        ; Offset into the bank plus 128.
        stx     OFFSET
;
; Redirect keyboard input to call us for characters.
;
        sta     INSW+1
        lda     #<KEYIN
        sta     INSW
;
; Jump into BASIC and start loading the program.
;
        jmp     $E003
;
; Fake keyboard input routine to feed the contents of the BASIC program
; into the BASIC interpreter character by character.
;
KEYIN:
        tya                 ; Save the Y register on the stack.
        pha
        lda     #0          ; Get a pointer to the slot ROM.
        sta     PTR
        lda     SLOT
        sta     PTR+1
        ldy     #0
        lda     BANK
        sta     (PTR),y     ; Set the bank to read from.
        ldy     OFFSET
        lda     (PTR),y     ; Read from the current position in the bank.
        beq     FINISHED    ; We are finished when we see a NUL.
        iny                 ; Advance to the next position in the ROM.
        bne     KEYIN2
        inc     BANK
        ldy     #$80
KEYIN2:
        sty     OFFSET
        sta     PTR
        lda     $C000       ; Has BREAK been pressed on the keyboard?
        cmp     #$FF
        beq     BREAK
        pla
        tay
        lda     PTR
        ora     #$80        ; Convert into "High ASCII".
        rts
BREAK:
        bit     $C010       ; Clear the BREAK from the keyboard buffer.
;
; When we get here, we have encountered a NUL byte or BREAK, so we are done.
; Restore the standard keyboard input routine and jump to it.
;
FINISHED:
        pla                 ; Restore the value of Y.
        tay
        jsr     $FE89       ; Reset the input device with "IN#0".
        jmp     (INSW)

;
; End of the loader code.  Pad to a full 128 bytes.
;
        .org    $C580
