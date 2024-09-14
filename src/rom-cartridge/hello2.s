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

        .org    $0300
START:
        ldx     #0
PRINT:
        lda     MSG,x
        beq     DONE
        ora     #$80
        jsr     $FDED
        inx
        bne     PRINT
DONE:
        lda     #>START
        ldx     #<START
        jsr     $F941       ; Print A:X in hexadecimal.
        jsr     $FEC5       ; Print CR.
        jmp     $E003       ; Jump into BASIC at the end.
MSG:
        .db     $0C, "Hello, World!", $0D, $0D
        .db     "Loaded into RAM at: $", 0
