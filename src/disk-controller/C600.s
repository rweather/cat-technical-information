
;***********************************************************************
;
; This is the assembly code for the C600 ROM for early versions of the
; Dick Smith Cat's disk controller cartridge.
;
; The code is very similar to the ROM in the official Apple Disk ][
; controller card: https://6502disassembly.com/a2-rom/C600ROM.html
; In fact, this is just the original code rearranged a bit to try to
; not look like the original.  But it is basically the original as-is.
;
;***********************************************************************

;
; Zero page locations.
;
PTR     .equ    $26         ; General-purpose pointer.
SLOT    .equ    $2B         ; Slot number: $60 = slot 6, $50 = slot 5.
TEMP    .equ    $3C         ; Temporary variable.
SECTOR  .equ    $3D         ; Sector number.
FOUND   .equ    $40         ; Found the track.
TRACK   .equ    $41         ; Track number.
;
; Main memory locations.
;
STACK   .equ    $0100       ; System stack.
BUFFER  .equ    $0300       ; Buffer to help decode sector data.
DECODER .equ    $0356       ; Address of the 6+2 decoder table.
BOOT1   .equ    $0800       ; Location for the loaded boot sector.
;
; I/O ports for the disk controller.  Add $60 or $50 for the slot number.
;
STEPOFF .equ    $C080       ; Stepper motor off.
STEPON  .equ    $C081       ; Stepper motor on.
MOTOR   .equ    $C089       ; Turn the main motor on.
DRIVE1  .equ    $C08A       ; Select drive 1.
READ1   .equ    $C08C       ; Read from the drive, control port 1.
READ2   .equ    $C08E       ; Read from the drive, control port 2.
;
; The Cat's monitor supports disk controller ROM's at both $C600 and $C500.
; The code is identical.  Later we figure out which slot we are running in.
;
; However, the Cat doesn't really have slots in the same way as the Apple ][.
; Slot address decoding is done on the disk controller cartridge, not on the
; motherboard.  So you would need a completely different cartridge to
; move the disk controller from slot 6 to slot 5.
;
        .org    $C600
;
; The ROM image starts with some signature bytes which are also code.
; Apple ]['s monitor requires that $20, $00, $03 appear at address $C601.
; The Cat's monitor requires that $00 appear at address $C603 and $3C
; appear at address $C607.  Both of these signatures are supported.
;
START:
        ldx     #$20
        ldy     #$00
        ldx     #$03
        stx     TEMP
;
; Initialize the variables we need.
;
        sty     TRACK       ; Set the track number to 0.
        sty     PTR         ; Set PTR to BOOT1 / $0800
        lda     #>BOOT1
        sta     PTR+1
;
; According to https://6502disassembly.com/a2-rom/C600ROM.html, the
; following code generates a decoder table for 6+2 encoded data.
; See that link for a description of what is happening here.
;
MKDEC:
        stx     TEMP
        txa
        asl     a
        bit     TEMP
        beq     MKDEC3
        ora     TEMP
        eor     #$FF
        and     #$7E
MKDEC2:
        bcs     MKDEC3
        lsr     a
        bne     MKDEC2
        tya
        sta     DECODER,x
        iny
MKDEC3:
        inx
        bpl     MKDEC
;
; Call into the monitor ROM at an address that is known to contain an
; "RTS" instruction.  This puts the address of the caller on the stack.
; The address is recovered to determine if we are running from slot 5 or 6.
;
        jsr     $FF58
        nop
        tsx
        lda     STACK,x
        asl     a
        asl     a
        asl     a
        asl     a
        tax
        sta     SLOT        ; X and SLOT is $60 for slot 6 and $50 for slot 5.
;
; Turn on drive 1 in read mode.  X is the slot offset - $60 or $50.
;
        lda     DRIVE1,x
        lda     READ1,x
        lda     READ2,x
        lda     MOTOR,x
;
; Seek to track 0.  Do this by moving the head back track by track for
; 40 tracks (or 80 "phases").  Since we don't know where the head starts
; off, the head will eventually hit the end and bounce off a few times.
;
        ldy     #80         ; 40 tracks = 80 phases
SEEK:
        lda     STEPOFF,x   ; Turn off the previous phases on the stepper motor.
        tya
        and     #$03        ; Get the stepper motor phase to set next.
        asl     a
        ora     SLOT
        tax                 ; Adjust X with the offset to the phase.
        lda     STEPON,x    ; Turn on the new phases on the stepper motor.
        lda     #$56
        jsr     $FCA8       ; Call a delay routine in the monitor ROM.
        beq     SEEK2       ; Z is always set on exit from $FCA8.
;
; Apple ][ DOS assumes that the read sector routine is placed at $C65C
; but the Disk Smith Cat's boot ROM has a different code arrangement.
; Place a jump instruction at $C65C to the real read sector routine.
;
; When this routine is called from DOS, the following is assumed on entry:
;
;   X           $60 or $50 for the slot.
;   PTR         Points to the buffer to read the sector data into.
;   SECTOR      Sector number to start reading at.
;   TRACK       Track number to read from.
;   (BOOT1)     Sector number to stop reading at.
;   BOOT1+1     Address to jump to once the sectors have been read.
;
; Multiple sectors from the same track can be read using this routine.
;
READSECT_ENTRY:
        clc
        bcc     READSECT
;
SEEK2:
        dey                 ; Move to the next phase.
        cpy     #$E6        ; Stop at phase -26.  A few more than 80.
        sta     SECTOR      ; A will be zero upon return from $FCA8.
        bmi     READSECT
;
; Read the sector address data to see if we have found the sector we wanted.
;
READADDR:
        ldy     #3
READADDR2:
        sta     FOUND
READA1:
        lda     READ1,x     ; Wait for a byte from the disk.
        bpl     READA1
        rol     a           ; Rotate the byte left by 1 and save it.
        sta     TEMP
READA2:
        lda     READ1,x     ; Wait for the next byte.
        bpl     READA2
        and     TEMP        ; AND this byte with the previious one.
        dey
        bne     READADDR2   ; Go back if more bytes needed.
        plp                 ; Balance out the "php" below.
        cmp     SECTOR
        bne     READSECT
        lda     FOUND
        cmp     TRACK
        beq     READSECT2
;
; Read a sector.  Read bytes until we find an address header (D5 AA 96)
; or a data header (D5 AA AD) depending upon the carry bit.  Carry clear
; to look for an address header, or carry set to look for a data header.
;
READSECT:
        clc
READSECT2:
        php                 ; Save the carry flag for later.
READB1:
        lda     READ1,x     ; Wait for the next byte.
        bpl     READB1
MATCHD5:
        cmp     #$D5        ; Is it $D5?
        bne     READB1      ; Keep looking if it isn't.
READB2:
        lda     READ1,x     ; Wait for the second byte.
        bpl     READB2
        cmp     #$AA        ; Is it $AA?
        bne     MATCHD5     ; If not, check for $D5 instead.
READB3:
        lda     READ1,x     ; Wait for the third byte.
        bpl     READB3
        cmp     #$96        ; Address header?
        beq     READADDR
        plp                 ; Recover the carry bit from the stack.
        bcc     READSECT    ; If we wanted an address, we shouldn't be here.
        eor     #$AD        ; Is the final byte $AD?
        bne     READSECT    ; If not, try looking for a data header again.
;
; Read the data from the sector into memory at BOOT1.
;
; A is assumed to be zero on entry to this code.
;
; Start by reading the 2 low bits of each byte into BUFFER.
;
READDATA:
        ldy     #86         ; Read 86 bytes of data.
READDATA2:
        sty     TEMP
READC1:
        ldy     READ1,x     ; Wait for a byte.
        bpl     READC1
        eor     DECODER-128,y ; Decode the byte and add its value to A.
        ldy     TEMP        ; Still more bytes to go?
        dey
        sta     BUFFER,y    ; Save the byte for later.
        bne     READDATA2
;
; Reads the 6 high bits of each byte from the sector into the buffer
; pointed to by (PTR).
;
READDATA3:
        sty     TEMP
READC2:
        ldy     READ1,x     ; Wait for a byte.
        bpl     READC2
        eor     DECODER-128,y ; Decode the byte and add its value to A.
        ldy     TEMP
        sta     (PTR),y     ; Save the byte in the caller-supplied buffer.
        iny                 ; Still more bytes to go?
        bne     READDATA3
;
READC3:
        ldy     READ1,x     ; Wait for the checksum byte.
        bpl     READC3
        eor     DECODER-128,y ; Decode the byte and compare it with A.
        bne     READSECT    ; If no match, try reading the sector again.
;
; The high 6 bits of each byte are now in the buffer pointed to by (PTR).
; The low 2 bits of each byte are in the buffer pointed to by BUFFER.
;
        ldy     #0
COMBINE:
        ldx     #86         ; There are 86 bytes in BUFFER.
COMBINE2:
        dex
        bmi     COMBINE     ; Wrap around if we go past the end of BUFFER.
        lda     (PTR),y     ; Get the high 6 bits (currently in the low 6 bits).
        lsr     BUFFER,x    ; Shift the low 2 bits into place.
        rol     a
        lsr     BUFFER,x
        rol     a
        sta     (PTR),y     ; We now have the full byte.
        iny                 ; More bytes left to go?
        bne     COMBINE2
;
; Are we done reading sectors?
;
        inc     PTR+1       ; Advance the data pointer by 256 bytes.
        inc     SECTOR
        lda     SECTOR
        cmp     BOOT1       ; Have we reached the sector number in (BOOT1)?
        ldx     SLOT
        bcc     READSECT    ; If not, go and read another sector.
;
; Boot sector has now been loaded, so jump to it.
;
; If we were reading sectors other than the boot sector, then (BOOT1) is
; the sector to stop reading at, and BOOT1+1 is the address to return to
; at the end of the sector read routine.
;
        jmp     BOOT1+1
