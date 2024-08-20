
;***********************************************************************
;
; This is the assembly code for the $C800 ROM - printer driver.
;
; The $C800 ROM is bank-switched in by the code in the $C100 ROM.
;
;***********************************************************************

        .include "common.s"
        .org    $C800
;
; Temporary variables and buffers that are used by graphics printing mode.
;
VPAGE   .equ    $0280       ; Page to print: 1=$20, 2=$40, both=$60.
VOPTS   .equ    $0281       ; Printing options.
BUF1    .equ    $0282       ; Temporary buffer.
BUF2    .equ    $028A       ; Temporary buffer.
TEMP4   .equ    $0292       ; Temporary variable.
VOPTS2  .equ    $0293       ; More printing options.
TEMP5   .equ    $0294       ; Temporary variable.
VWIDTH  .equ    $07FF       ; Width of the graphics page in bytes (40 or 80).
;
; Jump table for the entry points to the ROM.
;
        jmp     PRCHAR      ; Print a character.
        jmp     PRGRAPH     ; Print the graphics screen.
        jmp     PREXIT      ; Restore registers and exit.
;
; Print the character in A.
;
PRCHAR:
        nop
        pha
        lda     PRWID       ; Is the printer page 80 columns or less in width?
        cmp     #81
        bcs     NOECHO      ; If not, do not echo to the screen.
        pla
        pha
        jsr     $F80F       ; If yes, then echo the character to the screen.
NOECHO:
        pla
        pha
        pha
SPCLOOP:
        lda     PRCOL       ; Is the print column less than the screen column?
        cmp     CHORZ
        pla
        bcs     COLOK
        pha
        lda     #$A0        ; Set up to print spaces to advance the column.
COLOK:
        php                 ; Save the result of the comparison above.
        cmp     #$88        ; Backspace character?
        bne     NOTBS
        dec     PRCOL       ; Move the printer column back one place.
        jmp     PRCHAR2
NOTBS:
;
; The "bit" instruction here AND's the A register with a $60 byte and
; then tests if the result is zero.  This checks if A is in the range
; $00-$1F or $80-$9F; i.e. is this a control character?
;
        bit     PREND       ; Determine if A is a control character.
        beq     PRCHAR2
        inc     PRCOL       ; Move the printer column forward one place.
PRCHAR2:
        jsr     PRASCII     ; Print the current character.
        plp                 ; Have we reached the right print column yet?
        pla                 ; Recover the original character we were printing.
        pha
        bcc     SPCLOOP     ; Go and print more spaces if not the right column.
        eor     #$8D        ; Did we print a CR?
        asl     a           ; Check for either $8D or $0D.
        bne     PRCHAR3
        lda     #1          ; Reset the print head to column 1.
        sta     PRCOL
        lda     CVTCRLF     ; Should we convert CR into CRLF?
        bne     PRCHAR3
        lda     #$8A        ; Print a LF.
        jsr     PRASCII
PRCHAR3:
        lda     PRCOL       ; Are we in column 1 just after a CR?
        cmp     #1
        beq     PRCHAR4     ; If yes, then reset the screen column.
        sbc     PRWID       ; Have we reached the right margin plus 8?
        sbc     #$F8
        jmp     CHKMARGIN
;
; Unused code?
;
        rts
        bne     PRCEXIT
;
PRCHAR4:
        lda     #0
PRCEXIT:
        sta     CHORZ       ; Update the screen column to match the printer.
PRCEXIT2:
        pla                 ; Discard the character we were printing.
        jmp     PREXIT      ; Return back to the caller.
;
; Print a character as ASCII.
;
PRASCII:
        php
        pha
        lda     PRHGR       ; Are we printing graphics (MSB set to 1)?
        bpl     PRASCII2
        pla
        ora     #$20        ; Add bit 5 if we are printing graphics.
        bne     PRASCII3    ; Branch always taken.
PRASCII2:
        pla                 ; Recover the character to be printed.
PRASCII3:
        and     #$7F        ; Mask off the high bit to convert into real ASCII.
        pha
PRWAIT:
        lda     PRBUSY      ; Wait for the printer to not be busy.
        bmi     PRWAIT
        pla
        sta     PRWRITE     ; Write the character to the printer.
        plp
PREND:
        rts
;
; Print the graphics screen to the printer using Epson dot matrix
; graphics drawing commands.  The commands are described here:
;
; https://support2.epson.net/manuals/english/page/epl_n4000plus/ref_g/APCOM_3.HTM#FX%20mode%20B
;
PRGRAPH:
        lda     CHORZ       ; Save the screen cursor position before we start.
        pha
        lda     CVERT
        pha
        lda     #0
        sta     VOPTS2      ; Bit zero = 0 for normal-size mode.
;
; Output "ESC A 0x08" to set the line spacing to 8/72 of an inch for graphics.
;
        lda     #CH_ESC
        jsr     PROUT
        lda     #$41
        jsr     PROUT
        lda     #$08
        jsr     PROUT
;
; Determine which graphics page to print.  Bit 0 of PRMOD indicates page 1,
; bit 1 indicates page 2.  If both bits are set, then print both pages as
; the left and right halves of the same image.  If neither are set, then
; nothing to print.
;
        lda     PRMOD
        lsr     a
        bcs     GRPAGE1     ; Print page 1.
        lsr     a
        bcs     GRPAGE2     ; Print page 2.
        jmp     GREXIT      ; Neither page should be printed.
GRPAGE1:
        lsr     a
        bcs     GRPAGE12    ; Print both pages.
        ldy     #$20
        bne     GROPTS      ; Branch always taken.
GRPAGE12:
        ldy     #$60
        bne     GROPTS      ; Branch always taken.
GRPAGE2:
        ldy     #$40
;
; Process the printing options.
;
GROPTS:
        sty     VPAGE
        lsr     a           ; Bit 2 means AND mode.
        bcs     GRAND
        lsr     a           ; Bit 3 means OR mode.
        bcs     GROR
        lsr     a           ; Bit 4 means EOR mode.
        bcs     GREOR
        ldy     #$00        ; Normal mode.
        .db     $2C         ; Skip the next instruction.
GRAND:
        ldy     #$80        ; Activate AND mode.
        .db     $2C         ; Skip the next instruction.
GROR:
        ldy     #$40        ; Activate OR mode.
        .db     $2C         ; Skip the next instruction.
GREOR:
        ldy     #$C0        ; Activate EOR mode.
        sty     VOPTS
        lda     PRMOD       ; Is inverse printing mode active?
        and     #MINV
        beq     GROPTS2
        lda     #1          ; Add bit 1 to the printing options.
        ora     VOPTS
        sta     VOPTS
GROPTS2:
        lda     #$C0        ; Is bit 6 or 7 of PRMOD set?
        and     PRMOD
        beq     GRPRINT
        asl     a           ; Is bit 7 set?  Noting to do if it is.
        bcs     GREXIT2
        jmp     GRENLARGE
GREXIT2:
        jmp     GREXIT
;
; Print the selected graphics page.
;
GRPRINT:
        lda     #CH_LF      ; Print a line feed before starting the print.
        jsr     PROUT
        lda     VPAGE       ; Are we printing both pages?
        cmp     #$60
        beq     GRBOTH
        lda     #0          ; Set up to print 24 "lines" of graphics data.
GRLINE:
        sta     CVERT
        jsr     GRPLINE
        lda     #CH_LF      ; Terminate the line with a line feed.
        jsr     PROUT
        jsr     CHECKBRK    ; Check for CTRL-C to abort printing.
        inc     CVERT       ; Advance to the next line.
        lda     CVERT
        cmp     #24
        bne     GRLINE
;
; Output "ESC 2" to return to 1/6 inch line spacing for regular text printing.
;
GREXIT:
        lda     #CH_ESC
        jsr     PROUT
        lda     #$32
        jsr     PROUT
;
; Clean up and exit.
;
        pla
        sta     CVERT
        pla
        sta     CHORZ
;
; Restore the registers from the stack and exit from the printer driver.
;
PREXIT:
        pla
        sta     TEMP2
        pla
        sta     TEMP1
        pla
        sta     TEMP0
        pla
        tay
        pla
        tax
        pla
        rts
;
; Print both graphics pages with page 1 on the left and page 2 on the right.
;
GRBOTH:
        lda     #40         ; Width of a graphics page in bytes.
        sta     VWIDTH
        lda     #0          ; Set up to print 24 "lines" of graphics data.
GRLINE2:
        sta     CVERT
;
; Output "ESC K n m" where n + m*256 is the width of the line in pixels.
;
        lda     #CH_ESC
        jsr     PROUT
        lda     GRMODE      ; "K"
        jsr     PROUT
        lda     #<560       ; We will be printing 560 pixels.
        jsr     PROUT
        lda     #>560
        jsr     PROUT
;
; Print page 1 in the left half.
;
        ldy     #$20
        sty     VPAGE
        lda     #0
        jsr     GROUTLN
;
; Print page 2 in the right half.
;
        ldy     #$40
        sty     VPAGE
        lda     #0
        jsr     GROUTLN
;
; End of the current line of pixels.
;
        lda     #CH_LF      ; Print a line feed to terminate the line.
        jsr     PROUT
        jsr     CHECKBRK    ; Check for CTRL-C to abort printing.
        inc     CVERT       ; Advance to the next line.
        lda     CVERT
        cmp     #24
        bne     GRLINE2
        beq     GREXIT      ; Done!
;
; Print a single line from either page 1 or page 2.
;
GRPLINE:
        lda     PRHGR       ; Are we printing double-wide graphics (PRHGR=2)?
        lsr     a
        lsr     a
        bcs     GRDBL
        lda     #40         ; Width of a graphics page in bytes.
        sta     VWIDTH
;
; Output "ESC K n m" where n + m*256 is the width of the line in pixels.
;
        lda     #CH_ESC
        jsr     PROUT
        lda     GRMODE      ; "K"
        jsr     PROUT
        lda     #<280       ; We will be printing 280 pixels.
        jsr     PROUT
        lda     #>280
        jsr     PROUT
        bne     GRPLINE2
GRDBL:
        lda     #CH_ESC
        jsr     PROUT
        lda     GRMODE      ; "K"
        jsr     PROUT
        lda     #<560       ; We will be printing 560 pixels.
        jsr     PROUT
        lda     #>560
        jsr     PROUT
        lda     #80         ; Width of a double-wide graphics page in bytes.
        sta     VWIDTH
GRPLINE2:
        lda     #0
;
; Output a line of pixels.
;
GROUTLN:
        sta     CHORZ
        jsr     GROUTLN2
        jsr     GRPRINTCOL
        inc     CHORZ       ; Are we done with this line?
        lda     CHORZ
        cmp     VWIDTH
        bcc     GROUTLN     ; No, then go back for the next line.
        rts
;
; Compute the address of the line we are currently printing.
;
GROUTLN2:
        lda     CVERT       ; Get the line we are currently printing.
        and     #$1F
        pha
        and     #$18        ; TEMP1 = (A & 0x18) * 10
        sta     TEMP1
        asl     a
        asl     a
        ora     TEMP1
        asl     a
        sta     TEMP1
        pla
        and     #$07
        lsr     a
        ror     TEMP1
        ora     #$20
        sta     TEMP2
        txa
        pha
        clc
;
; Convert the 7 pixels in the current byte and apply AND/OR/EOR if necessary.
;
        ldx     #7
GROUTLN3:
        ldy     CHORZ       ; Get the byte we are currently printing.
;
; The following tests a byte in the monitor ROM for non-zero.  If it is
; non-zero then we continue at GROUTLN4.  However, the byte in question at
; $FB4A is zero!
;
; My guess is that when the alternate Pascal ROM's are loaded into the
; emulator / language card, that $FB4A is non-zero.
;
; The kernel monitor uses a different memory bank mapping for Pascal, which
; would affect the memory addresses of graphics pages.  So I guess this
; is the Pascal version of screen printing, with the BASIC version later.
;
        lda     $FB4A       ; Load a zero byte from the monitor ROM.
        bne     GROUTLN4    ; Branch never taken!
        jmp     GROUTPAS
;
GROUTLN4:
        lda     (TEMP1),y   ; Read a byte from page 1.
        sta     BUF1,X
        lda     TEMP2
        and     #$1F
        ora     #$40        ; Switch to the other page in a double-wide setup.
        sta     TEMP2
        lda     (TEMP1),y   ; Read a byte from page 2.
        sta     BUF2,x
GROUT_2000:
        lda     TEMP2
        and     #$1F
        ora     #$20
        clc
        adc     #4
        sta     TEMP2
        bit     VOPTS       ; Normal, AND, OR, or EOR mode?
        bmi     GRMODECHK
        bvs     GROR2
;
; Normal mode.
;
        lda     VPAGE       ; Are we printing page 1 or 2?
        cmp     #$40
        bne     GROUTLN5
        lda     BUF2,x      ; We are printing page 2, so copy BUF2 to BUF1.
        sta     BUF1,x
        jmp     GROUTLN5
;
; OR mode.
;
GROR2:
        lda     BUF2,x
        ora     BUF1,x
        sta     BUF1,x
        jmp     GROUTLN5
;
; Figure out which of AND or EOR mode we are using.
;
GRMODECHK:
        bvs     GREOR2
;
; AND mode.
;
        lda     BUF2,x
        and     BUF1,x
        sta     BUF1,x
        jmp     GROUTLN5
;
; EOR mode.
;
GREOR2:
        lda     BUF2,x
        eor     BUF1,x
        sta     BUF1,x
;
GROUTLN5:
        dex
        bpl     GROUTLN3
        pla
        tax
        rts
;
; Print seven columns of 8 pixels in graphics mode.
;
GRPRINTCOL:
        ldy     #7
GRSHIFT:                    ; Shift the pixel bits up by one.
        lda     BUF1,y      ; The top-most bit of each byte is for colour,
        asl     a           ; so it isn't an actual pixel.
        sta     BUF1,y
        dey
        bpl     GRSHIFT
        txa                 ; Save the original X,
        pha
;
        ldx     #6          ; Combine the 8 vertical columns in BUF1
GRCOMBINE:                  ; into seven bytes in BUF2.
        ldy     #7
GRCOMBINE2:
        lda     BUF1,y
        asl     a
        sta     BUF1,y
        rol     BUF2,x
        dey
        bpl     GRCOMBINE2
        dex
        bpl     GRCOMBINE
        pla                 ; Restore the original X.
        tax
;
        ldy     #0
        sty     TEMP4
GRPRINTCOL2:
        ldy     TEMP4
        lda     VOPTS       ; Is inverse printing mode active?
        and     #$01
        beq     GRNORMAL
        lda     BUF2,y      ; If yes, invert the byte to be printed.
        eor     #$FF
        jmp     GRINVERSE
GRNORMAL:
        lda     BUF2,y
GRINVERSE:
        pha
        lda     VOPTS2      ; Is double-size mode active?  Bit 0.
        beq     GRPRINTCOL5
        pla
        bit     VOPTS2      ; Are we printing the high or low 4 pixels of
        bmi     GRPRINTCOL3 ; this row in double-size mode?  Bit 7.
        jsr     GRHIGHDBL   ; Expand the high 4 pixels.
        jmp     GRPRINTCOL4
GRPRINTCOL3:
        jsr     GRLOWDBL    ; Expand the low 4 pixels.
GRPRINTCOL4:
        pha
        jsr     PROUT       ; Double-print the current column.
GRPRINTCOL5:
        pla
        jsr     PROUT       ; Print the current column.
        inc     TEMP4
        lda     TEMP4
        cmp     #7          ; Finished all 7 columns yet?
        bne     GRPRINTCOL2
        rts
;
; Modify a byte for double-size mode.  Low 4 pixels.
;
GRLOWDBL:
        sta     TEMP5
        lda     #$00
        ror     TEMP5
        bcc     GRLOWDBL2
        ora     #$03
GRLOWDBL2:
        ror     TEMP5
        bcc     GRLOWDBL3
        ora     #$0C
GRLOWDBL3:
        ror     TEMP5
        bcc     GRLOWDBL4
        ora     #$30
GRLOWDBL4:
        ror     TEMP5
        bcc     GRLOWDBL5
        ora     #$C0
GRLOWDBL5:
        rts
;
; Modify a byte for double-size mode.  High 4 pixels.
;
GRHIGHDBL:
        sta     TEMP5
        lda     #$00
        asl     TEMP5
        bcc     GRHIGHDBL2
        ora     #$C0
GRHIGHDBL2:
        asl     TEMP5
        bcc     GRHIGHDBL3
        ora     #$30
GRHIGHDBL3:
        asl     TEMP5
        bcc     GRHIGHDBL4
        ora     #$0C
GRHIGHDBL4:
        asl     TEMP5
        bcc     GRHIGHDBL5
        ora     #$03
GRHIGHDBL5:
        rts
;
; Enlarged / double-size printing mode.
;
GRENLARGE:
        lda     #CH_LF
        jsr     PROUT
        lda     #0
GRENLARGE2:
        sta     CVERT
        jsr     GRLARGELN
        jsr     CHECKBRK
        inc     CVERT
        lda     CVERT
        cmp     #24
        bne     GRENLARGE2
        jmp     GREXIT
;
; Print a line of enlarged pixels.
;
GRLARGELN:
;
; Print the top 4 bits of each column in double-height mode.
;
        lda     #CH_ESC     ; Output the length of the line in pixels.
        jsr     PROUT
        lda     GRMODE      ; "K"
        jsr     PROUT
        lda     #<560       ; Double-wide is 560 pixels.
        jsr     PROUT
        lda     #>560
        jsr     PROUT
        lda     #0          ; Make sure we are left-aligned in the text window.
GRLARGELN2:
        sta     WNDLFT      ; (I think this should be CHORZ instead - bug?)
        lda     #$01        ; Set double-size printing.
        sta     VOPTS2
        jsr     GROUTLN2    ; Get the address of the current line.
        jsr     GRPRINTCOL
        inc     CHORZ       ; Move to the next column.
        lda     CHORZ
        cmp     #40
        bcc     GRLARGELN2
        lda     #CH_LF      ; End of the current line.
        jsr     PROUT
;
; Print the bottom 4 bits of each column in double-height mode.
;
        lda     #CH_ESC     ; Output the length of the line in pixels.
        jsr     PROUT
        lda     GRMODE      ; "K"
        jsr     PROUT
        lda     #<560       ; Double-wide is 560 pixels.
        jsr     PROUT
        lda     #>560
        jsr     PROUT
        lda     #0          ; Make sure we are left-aligned in the text window.
GRLARGELN3:
        sta     CHORZ
        lda     #$81        ; Set double-size printing, bottom 4 bits.
        sta     VOPTS2
        jsr     GROUTLN2    ; Get the address of the current line.
        jsr     GRPRINTCOL
        inc     CHORZ       ; Move to the next column.
        lda     CHORZ
        cmp     #40
        bcc     GRLARGELN3
        lda     #0          ; Disabvle double-size printing.
        sta     VOPTS2
        lda     #CH_LF      ; End of the current line.
        jsr     PROUT
        rts
;
; Output the byte in A to the printer.  Preserves all registers.
;
PROUT:
        php
        pha
PRWAIT2:
        lda     PRBUSY      ; Wait for the printer to not be busy.
        bmi     PRWAIT2
        pla
        sta     PRWRITE     ; Write the character to the printer.
        plp
        rts
;
; Check if CTRL-C has been pressed and abort the print if it has.
;
CHECKBRK:
        lda     $C000       ; Get the next keypress.
        cmp     #$83        ; Was it CTRL-C?
        beq     CHECKBRK2
        bit     $C010       ; If not, clear the key buffer and return.
        rts
CHECKBRK2:
        bit     $C010       ; Clear the CTRL-C from the key buffer.
        lda     #CH_LF      ; End the current in-progress line.
        jsr     PROUT
        pla                 ; Pop the return address.
        pla
        jmp     GREXIT      ; Abort the print and return.
;
; Output a graphics line when the Pascal memory map is active.
;
GROUTPAS:
        lda     PRHGR       ; Which graphics mode are we printing?
        lsr     a
        bcc     GROUTPAS2
        jmp     GROUTPAS7
GROUTPAS2:
        lsr     a
        bcs     GROUTPAS3
;
; Handle HGR1 and HGR2 in Pascal mode.
;
        jsr     GETMAP
        pha
        lda     #0
        jsr     REMAP
        lda     TEMP2
        pha
        and     #$1F
        ora     #$60        ; Adjust the address for the Pascal memory map.
        sta     TEMP2
        lda     (TEMP1),y
        sta     BUF1,x
        lda     #1
        jsr     REMAP
        lda     TEMP2
        and     #$1F
        ora     #$40
        sta     TEMP2
        lda     (TEMP1),y
        sta     BUF2,x
        pla
        sta     TEMP2
        pla
        jsr     REMAP
        jmp     GROUT_2000
;
; Handle HGR3 and HGR4 in Pascal mode.
;
GROUTPAS3:
        jsr     GETMAP
        pha
        lda     #1
        jsr     REMAP
        lda     TEMP2
        pha
        cpy     #40         ; Is the graphics mode double-wide?
        bcs     GROUTPAS4
        and     #$1F
        ora     #$40
        jsr     GROUTPAS6
        jmp     GROUTPAS5
GROUTPAS4:
        tya
        pha
        sbc     #40
        tay
        lda     TEMP2
        and     #$1F
        ora     #$60
        jsr     GROUTPAS6
        pla
        tay
GROUTPAS5:
        pla
        sta     TEMP2
        pla
        jsr     REMAP
        jmp     GROUT_2000
GROUTPAS6:
        sta     TEMP2
        lda     (TEMP1),y
        sta     BUF1,x
        lda     #2
        jsr     REMAP
        lda     (TEMP1),y
        sta     BUF2,x
        rts
;
; Handle HGR5 and HGR6 in Pascal mode.
;
GROUTPAS7:
        jsr     GETMAP
        pha
        lda     #1
        jsr     REMAP
        lda     TEMP2
        pha
        and     #$1F
        ora     #$40
        pha
        sta     TEMP2
        lda     (TEMP1),y
        sta     BUF1,x
        lda     TEMP2
        ora     #$60
        sta     TEMP2
        lda     (TEMP1),y
        ora     BUF1,x
        sta     BUF1,x
        lda     #2
        jsr     REMAP
        pla
        pha
        sta     TEMP2
        lda     (TEMP1),y
        ora     BUF1,x
        sta     BUF1,x
        lda     TEMP2
        ora     #$60
        lda     (TEMP1),y
        sta     BUF2,x
        lda     #3
        jsr     REMAP
        pla
        sta     TEMP2
        lda     (TEMP1),y
        ora     BUF2,x
        sta     BUF2,x
        lda     TEMP2
        ora     #$60
        sta     TEMP2
        lda     (TEMP1),y
        ora     BUF2,x
        sta     BUF2,x
        pla
        sta     TEMP2
        pla
        jsr     REMAP
        jmp     GROUT_2000
;
; Change the mapping for the memory window $4000 - $7FFF.
;
REMAP:
        php
        pha
        and     #$0F
        sta     $C07D
        pla
        plp
        rts
;
; Get the memory bank mapping for the memory window $4000 - $7FFF.
;
GETMAP:
        php
        lda     $C6
        plp
        rts
;
        db      $6E
;
; Check the margin.
;
CHKMARGIN:
        bcs     CHKMARGIN2
        jmp     PRCEXIT2
CHKMARGIN2:
        adc     PRWID
        sbc     #8
        jmp     PRCEXIT
