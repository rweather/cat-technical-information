
;;***********************************************************************
;;
;; Notes: This is a copy of the kernel 6502 assembly code from the
;; CAT Technical Reference Manual, formatted for vasm.  There are some
;; additions for code that is missing from the manual, based on Rhys
;; Weatherley's personal disassembly of the ROM's in the 1980's.
;;
;; http://sun.hasenbraten.de/vasm/
;;
;; Assembling with vasm:
;;
;; vasm6502_oldstyle -Fihex -i32hex -c02 -o kernel.hex kernel.s
;; vasm6502_oldstyle -quiet -DEPROM -Fbin -c02 -o kernel.bin kernel.s
;;
;; Some additional explanatory comments that were not in the manual
;; have been added by Rhys Weatherley.  They are prefixed with ";;".
;; The extra comments are placed into the public domain.
;;
;;***********************************************************************

;;***********************************************************************
;;
;; Memory map from Chapter 5 of the Technical Reference Manual.
;;
;; There is 256K of memory, consisting of space for RAM, ROM, and I/O.
;; The gate arrays on the board can remap 16K sections of the 6502's
;; 64K memory space to any of the pages in the full 256K memory space.
;;
;;      $00000      64K of system RAM
;;      $10000      64K of expansion RAM
;;      $20000      64K of expansion RAM
;;      $30000      Unused space
;;      $38000      BASIC interpreter in ROM
;;      $3C000      I/O space
;;      $3D000      BASIC interpreter and kernel in ROM
;;      $3FFFF      End of memory
;;
;; Some parts of the I/O space can be mapped to bank-switched ROM for
;; initialization routines and specialised firmware:
;;
;;      $3C100-$3C1FF   Printer driver initialization firmware
;;      $3C300-$3C3FF   80 column display initialization firmware
;;      $3C800-$3CFFF   Printer driver firmware (bank-switched)
;;      $3C800-$3CFFF   80 column display firmware (bank-switched)
;;
;; The kernel listing below includes the 80 column display firmware,
;; but not the printer driver firmware.  That is on a separate ROM.
;;
;; Two methods are described in the "CAT Technical Reference Manual" to
;; activate the 80 column display firmware.  The first under "I/O Map"
;; says to JSR to address $3C300.  The second under "Important Kernel
;; Routines" says to do the following sequence:
;;
;;          STA $CFFF       ; deselect all expansion ROM's
;;          STA $C300       ; select the expansion ROM for $C300
;;          JSR $CXXX       ; call a kernel routine within $C800-$CFFF
;;
;; Activating the printer driver firmware is similar, except use $C100.
;;
;;***********************************************************************
;;
;; The original kernel listing uses ORG and PHASE directives to
;; relocate the code from its proper location at $C000 to $0000.
;; This produces a binary image that is ready to flash into an EPROM
;; at the EPROM's $0000 address, but which executes at address $C000.
;;
;; The macro "FORIGIN" sets the first origin for the file and the
;; "ORIGIN" macro sets the subsequent origins.  We only do the
;; relocation if the "EPROM" symbol is defined on the command-line.
;;
;; Unused space is filled with $FF bytes.  This probably wasn't the
;; case with the original kernel ROM, but it makes it easier to flash
;; the binary image into a modern EEPROM and then overwrite the
;; intermediate sections with other code like the BASIC interpreter on
;; a second pass.  The fill value can be changed in the macros below.

    ifdef EPROM
        MACRO ORIGIN
                DEPHASE
                FILL    \1-$C000-*,$FF
                ORG     \1-$C000
                PHASE   \1
        ENDM
        MACRO FORIGIN
                ORG     $0000
                FILL    \1-$C000,$FF
                ORG     \1-$C000
                PHASE   \1
        ENDM
    else
        MACRO ORIGIN
                ORG     \1
        ENDM
        MACRO FORIGIN
                ORG     \1
        ENDM
    endif

;***********************************************************************
;
;       SYSTEM KERNEL
;
;       (C) COPYRIGHT
;       1984 :
;       V.T.L.
;
;***********************************************************************

        INCLUDE memmap.s
        INCLUDE iomap.s
;
;; Locations in other ROM's that the kernel uses.
;
; ROM EQUATES
;
BASICC      EQU     $E000   ;; BASIC ROM entry point for cold start
BASICW      EQU     $E003   ;; BASIC ROM entry point for warm start
HRSEXT      EQU     $F1BD   ;; Restore the mapping for memory bank 3
RENEW       EQU     $F229   ;; ???
NORMAL      EQU     $F23C   ;; Set text to normal
;
;; 80-column mode initialization routines.
;
            FORIGIN $C300
;
; SOME SIGNATURE BYTES EXIST HERE
; THEY ARE RECOGNIZED BY CP/M AND PASCAL
; REMARKS:
; CP/M AND PASCAL DISTINGUISH DEVICES BY
; CHECKING CN05 AND CN07
;
            BIT     IORTS       ; ENTER HERE AT THE FIRST TIME
            BVS     ENTER       ; BRANCH ALWAYS
INENT       SEC                 ; FROM SECOND TIME ON (CN05)
            DB      $90
OUTENT      CLC                 ; FROM SECOND TIME ON (CN07)
            CLV
ENTER       STA     ROMCLR      ; BRING C800 IN
            JSR     ROAD        ; MUST GO THROUGH THIS WAY
IORTS       RTS
;
;
ROAD        PHA                 ; SAVE EVERYTHING
            TXA
            PHA
            TYA
            PHA
            PHP                 ; INCLUDING STATUS
            TSX                 ; USED TO GET A FROM STACK
            LDA     STACK+4,X
            PLP                 ; RECOVER STATUS
            PHA                 ; SAVE CHARACTER
            BVS     *+5         ; FIRST TIME?
            JMP     IO          ; NO
            LDA     SIGNAT      ; WHO ARE YOU?
            BNE     WHO         ; VISITOR?  ;; non-zero = visitor, zero = us
;; Set up for BASIC
            JSR     SETUP
            LDA     #$00        ; BASIC, NOT
            STA     POWER       ; PASCAL OR CP/M
            LDA     #2          ; INFORM BASIC OF THE CHANGE
            STA     PBANK1      ;; Memory bank 1 @ $0000 = $08000 (RAM)
            LDA     #1
            STA     PBANK2      ;; Memory bank 2 @ $4000 = $04000 (RAM)
            LDA     #>OUTMED    ; FORM MEDIA
            STA     INSWH
            STA     OUTSWH      ;; Set character output routine to MCOUT1
            LDA     #<INMED
            STA     INSWL       ;; Set character input routine to MINKEY
            LDA     #<OUTMED
            STA     OUTSWL
            PLA                 ; RELEASE STACK
            PLA
            TAY
            PLA
            TAX
            PLA                 ; GET BACK CHARACTER ;; ... to be output
;
;
OUTMED      JMP     MCOUT1      ; MEDIA ONLY
INMED       JMP     MINKEY
;
;
WHO         JSR     TUGGLE      ; DO INITIALIZATION
            JSR     SETUP
            JSR     TUGGLE
            LDA     #>INENT     ;; Set character input routine to INENT
            STA     INSWH
            STA     OUTSWH
            LDA     #<INENT
            STA     INSWL
            LDA     #<OUTENT    ;; Set character output routine to OUTENT
            STA     OUTSWL
            CLC                 ; THEN DO OUTPUT
            JMP     IO
;
;
;*******************************************
;*** FOR RS232 INTERFACE USAGE           ***
;*** ICHRDIR: DISPLAY CHARACTER ON SCREEN***
;*** IENCUR: TURN ON CURSOR              ***
;*** DON'T RELOCATE THE FOLLOWING CODES  ***
;*******************************************
;
            ORIGIN  $C36E
ICHRDIS     PHP                 ; SAVE STATUS
            STA     ROMCLR      ; ENABLE C800 ROM
            JSR     CHRDIS      ; DISPLAY IT
            PLP                 ; RESUME STATUS
            RTS
;
;
IENCHR      PHP
            STA     ROMCLR      ; ENABLE C800 ROM
            JSR     ENCUR       ; TURN CURSOR ON
            PLP
            RTS
;
;
;; Start of the 80-column display firmware.
;
            ORIGIN  $C800
            RTS
;
;; Set up for 80-column text mode.
;
SETUP       JSR     WBANK       ; REFORM MEMORY ASSIGNMENT
            JSR     SETWND      ; SET UP SCREEN SIZE
            LDA     #$90
            STA     POWER       ; SETUP ONCE IS ENOUGH
            LDA     #$A0        ; CLEAR TEMPA
            STA     TEMPA
            BIT     VERTSC      ; CHANGE SCREEN DURING THE
            BMI     *-3         ; VERTICAL RETRACE PERIOD
            LDA     VZSELF      ; TURN TO
            LDA     VZTEXT      ; 80 COLUMN TEXT DISPLAY
            LDA     VZTX80
            JMP     CLSCRN      ; CLEAR SCREEN
;
;; Set the initial window size for 80-column text mode.
;
SETWND      LDA     #0          ; FULL SCREEN SIZE: 24*80
            STA     WNDTOP
            STA     WNDLFT
            LDA     #24
            STA     WNDBTM
            LDA     #80
            STA     WNDWTH
            LDA     #$10        ;; Tell the rest of the kernel that we
            STA     TXTMOD      ;; are now in 80-column text mode.
            RTS
;
;; Modify a screen base address to flip between the bank at $0000 and $4000.
;
COMPAT      PHP                 ; ALWAYS BE SAFE
            PHA
            LDA     SBASH
            EOR     #$40
            STA     SBASH
            PLA
            PLP
            RTS
;
; IN#8 ENTRY POINTS
;
            ORIGIN  $C847
            JMP     ESCX
            JMP     CLREOL
;
; PASCAL AND CP/M INPUT ENTRY POINT
;
KEYIN       JSR     RAM0IN      ; CHECK FUNCTION KEY FLAG
            LDA     KEYFLG
            JSR     RAM0OU
            CMP     #$99        ; GET FROM FUNCTION KEY BUFFER?
            BNE     KEYINH
            JSR     KEYINB      ; YES
            JMP     KEYHAB      ; TO BE CONTINUE
KEYINH      JSR     POLKBD      ; IF NO, GET FROM KEYBOARD
            CMP     #$9C        ; TAB?
            BNE     *+4
            LDA     #$89        ; YES, USE CTRL-I
            CMP     #$9B        ; IS IT ESC?
            BNE     *+5
            JSR     ESCHK       ; IF YES, GO ON FURTHER
KEYHAB      PHA                 ; SAVE THE CHARACTER GOT FIRST
            AND     #$7F        ; PASCAL LIKES MSB=0
            STA     BYTE
            PLA                 ; RECOVER CHARACTER WITH MSB=1
            RTS                 ; FOR BASIC
;
;; Poll the keyboard until a character arrives.
;
POLKBD      LDA     KEYBRD      ; POLL KEYBOARD UNTIL KEY GOT
            BMI     POLRTS
            INC     RNDNOL      ; MEANWHILE CREATE A RANDOM NO.
            BNE     POLKBD
            INC     RNDNOH
            JMP     POLKBD
POLRTS      BIT     KEYSTR      ; KEY GOT, CLEAR KEYBOARD
            RTS
;
;; Check for escape sequence.
;
ESCHK       LDA     #4          ; SET UP TIMER
            STA     RNDNOH
ESCHK1      LDA     KEYBRD      ; ANY KEY FOLLOWING THE ESC?
            BMI     ESCHK2
            INC     RNDNOL      ; A STRAIGHT TIMER
            BNE     ESCHK1
            DEC     RNDNOH
            BNE     ESCHK1
ESCKRT      LDA     #$9B        ; TIME IS UP, MUST BE ESC ONLY
            RTS
;
ESCHK2      BIT     KEYSTR      ; CLEAR KEYBOARD
            CMP     #$C4        ; UP ARROW?
            BNE     *+5
            LDA     #$9F        ; YES, REPLACE IT WITH A CTRL-KEY
            RTS                 ; AND RETURN
            CMP     #$B0        ; 0, 1, 2?
            BLT     ESCKRT      ; IF NOT, MUST BE ESC KEY
            CMP     #$B3
            BGE     ESCKRT
            AND     #$07
            ASL     A
            ASL     A
            ASL     A
            STA     FKEYPL      ; PREPARE COUNTER
            JSR     POLKBD
            CMP     #$B0        ; 0 TO 7?
            BLT     ESCKRT
            CMP     #$B8
            BGE     ESCKRT
            AND     #$07
            ORA     FKEYPL
            STA     SBAS2L      ; COUNTER COMPLETED
            STA     SBAS2H      ; THIS IS FOR IN#8
;; Search for a function key definition
            LDA     #$00        ; SET UP POINTER NOW
            TAY
            STA     FKEYPL
            LDA     #$48
            STA     FKEYPH      ; FUNCTION KEY STORED FROM $4800
            JSR     RAM0IN
FKFND1      DEC     SBAS2L
            BMI     FKFND4      ; REACH?
FKFND2      INC     FKEYPL      ; IF NOT, INCREMENT POINTER
            BNE     FKFND3
            INC     FKEYPH
FKFND3      LDA     (FKEYPL),Y
            BPL     FKFND2      ; END OF FUNCTION KEY?
            BMI     FKFND1      ; YES, UPDATE COUNTER
FKFND4      LDA     KEYFLG      ; HAS IN#8 HAPPENED?
            CMP     #$66
            BNE     FKFND5      ; NO, GOOD!
            JSR     RENEW       ; YES, GOTO BASIC
            JSR     ENCUR
            JMP     KEYIN
FKFND5      LDA     #$99        ; BEFORE EXIT, MAKE FUNCTION
            STA     KEYFLG      ; KEY ACTIVE
            JSR     RAM0OU
;
; GET THE FIRST CHARACTER FROM THE FUNCTION KEY BUFFER
;
KEYINB      INC     FKEYPL      ; FUNCTION KEY POINTER READY
            BNE     *+4
            INC     FKEYPH
            JSR     RAM0IN      ; MOVE RAM BLOCK 0 IN
            LDY     #$00
            LDA     (FKEYPL),Y  ; READ KEY FROM BUFFER
            BPL     KEYBRT      ; END OF A FUNCTION KEY STRING?
            STY     KEYFLG      ; IF YES, DISABLE FUNCTION KEY MODE
KEYBRT      JSR     RAM0OU      ; FUNCTION KEY BUFFER AREA
            ORA     #$80        ; ENSURE MSB=1
            RTS
;
;; Check for CTRL-S to stop video output scrolling.  Once encountered,
;; wait for any key to resume output.  If the next key is CTRL-C,
;; then do not clear it from the keyboard buffer.  Otherwise eat it.
;
VIDWAI      LDA     KEYBRD      ; CHECK STOP LIST
            CMP     #$93        ; CTRL-S
            BNE     VWDONE      ; IF NOT, EXIT
            BIT     KEYSTR      ; IF YES, CLEAR KEYBOARD
VWLOOP      LDA     KEYBRD      ; WAIT FOR ANOTHER KEY
            BPL     VWLOOP
            CMP     #$83        ; IF THE NEXT KEY CTRL-C?
            BEQ     VWDONE      ; IF YES, DON'T CLEAR IT
            BIT     KEYSTR      ; OTHERWISE, CLEAR KEYBOARD
VWDONE      RTS
;
; ROUTINE 'WBANK' IS USED TO CONVERT THE MEMORY
; ASSIGNMENT WHEN RUNNING 80 COLUMN CP/M OR PASCAL
; NEW MEMORY ASSIGNMENT WILL BE 2, 1, X, F
; RAM0, WHICH CONTAINS THE SCREEN MEMORY OF THE 80
; COLUMN TEXT, MUST BE OUTSIDE THE VIRTUAL MEMORY
; AREA
;
;; Because we are changing bank 0, we need to copy the data
;; that is currently in $0000-$3FFF to the new bank first.
;;
;; Should this be disabling interrupts to avoid corrupting
;; the zero page and the stack if an interrupt fires off?
;
WBANK       LDA     #2          ; COPY BLOCK 1 INTO RAM 2
            STA     SBANK2      ;; Set memory window 2 to bank 2
            LDY     #0          ; SAVE ZERO PAGE FIRST
WBANK1      LDA     $0,Y
            STA     $4000,Y
            INY
            BNE     WBANK1
;
            STY     $00         ; NOW WE CAN USE ZERO PAGE
            STY     $02         ; LOCATIONS
            LDA     #$01
            STA     $01
            LDA     #$41
            STA     $03
;
WBANK2      LDA     ($00),Y     ; NOW FOR THE NON-ZERO PAGE
            STA     ($02),Y     ; REGION
            INY
            BNE     WBANK2
            INC     $01
            INC     $03
            LDA     $03
            CMP     #$80        ; THE WHOLE 16K FINISHED?
            BLT     WBANK2      ; IF NOT, CONTINUE
;
WBANK3      LDA     $4000,Y     ; NOW RECOVER THE ZERO PAGE
            STA     $0,Y
            INY
            BNE     WBANK3
;
            LDA     #2          ; EVERY O.K., SHOT!
            STA     SBANK1      ;; Set memory window 1 to bank 2
            LDA     #1
            STA     SBANK2      ;; Set memory window 2 to bank 1
            RTS
;
;; Table of handlers for control characters.
;;
;; These are the low bytes of the addresses.  The high byte is always $CA.
;
SUBTBL      DB      <BELL-1     ; CTRL-G        ;; bell
            DB      <BS-1       ; CTRL-H        ;; backspace
            DB      <VIDRTS-1                   ;; ignore CTRL-I
            DB      <LF-1       ; CTRL-J        ;; line feed / move down
            DB      <CLREOP-1   ; CTRL-K        ;; clear to end of page
            DB      <CLSCRN-1   ; CTRL-L        ;; clear screen
            DB      <CR-1       ; CTRL-M        ;; carriage return
;
            DB      <HOME-1     ; CTRL-Y        ;; move to top-left of screen
            DB      <VIDRTS-1   ; CTRL-Z        ;; ignored
            DB      <VIDRTS-1   ; CTRL-[        ;; ignored
            DB      <ADVANC-1   ; CTRL-\        ;; move right
            DB      <CLREOL-1   ; CTRL-]        ;; clear to end of line
            DB      <GOTOXY-1   ; CTRL-^        ;; go to x,y co-ordinates
            DB      <UP-1       ; CTRL-_        ;; move up
;
;; Table of handlers for escape sequences.
;
ESCTBL      DB      <CLSCRN-1   ; ESC @         ;; clear screen
            DB      <ADVANC-1   ; ESC A         ;; move right
            DB      <BS-1       ; ESC B         ;; move left
            DB      <LF-1       ; ESC C         ;; move down
            DB      <UP-1       ; ESC D         ;; move up
            DB      <CLREOL-1   ; ESC E         ;; clear to end of line
            DB      <CLREOP-1   ; ESC F         ;; clear to end of page
            DB      <HOME-1     ; ESC G         ;; move to top-left of screen
;
ESCTB1      DB      $C4         ; ESC I = ESC D
            DB      $C2         ; ESC J = ESC B
            DB      $C1         ; ESC K = ESC A
            DB      $C8         ; ESC L = NOP
            DB      $C3         ; ESC M = ESC C
;
; TABLE OF SCREEN BASE ADDRESSES (LOW ORDER BYTES ONLY)
;
ADRESL      DB      $00,$80
            DB      $00,$80
            DB      $00,$80
            DB      $00,$80
            DB      $28,$A8
            DB      $28,$A8
            DB      $28,$A8
            DB      $28,$A8
            DB      $50,$D0
            DB      $50,$D0
            DB      $50,$D0
            DB      $50,$D0
;
; PASCAL AND CP/M OUTPUT ENTRY POINT
;
            ORIGIN  $C9AA
PASOUT      LDA     POWER       ;; IS IT THE FIRST TIME?
            AND     #$FC
            CMP     #$90
            BEQ     *+5
            JSR     SETUP       ; INITIALIZE 80 COLUMN DISPLAY
            JSR     DECUR       ; DISABLE THE CURSOR FIRST
            LDA     POWER       ; THEN CHECK IF IT IS GOTO XY
            AND     #$03
            BNE     GOXY        ; 2 OR 1 IF IT IS GOTO XY
            LDA     BYTE        ; IF NOT, DISPLAY THE CHARACTER
            JSR     VIDOUT
PSCORT      JMP     ENCUR       ; WHEN ALL FINISHED, TURN ON THE CURSOR
;
;; Processing a "GOTO XY" escape sequence to move the cursor to a
;; particular location on the screen.
;
GOXY        JSR     GOXY1
            JMP     PSCORT
;
GOXY1       LDA     BYTE        ; GOTO WHERE?
            AND     #$7F        ; SAFETY        ;; Make sure it is ASCII
            SBC     #$20        ; ASCII TO NUMBER
            PHA                 ; SAVE THIS NO. FIRST
            DEC     POWER       ; WHAT IS THIS NO, X OR Y?
            LDA     POWER
            AND     #$03
            BNE     GOTOX
            PLA                 ; IT IS Y!
            CMP     WNDBTM      ; Y > WINDOW BOTTOM?
            BGE     PODRY       ; IF YES, KEEP CVERT UNCHANGED
            STA     CVERT       ; OTHERWISE, PERFORM GOTOY
PODRY       LDA     TEMPX       ; NOW FOR GOTOX
            CMP     WNDWTH      ; X > WINDOW WIDTH?
            BGE     PODRX       ; IF YES, KEEP CHORZ UNCHANGED
            STA     CHORZ       ; OTHERWISE, PERFORM GOTOX
PODRX       JMP     VTAB        ; FINALISE GOTOXY
;
GOTOX       PLA                 ; THE NO. IS X!
            STA     TEMPX       ; SAVE IT UNTIL Y GOT
            RTS
;
;; Video output routine for text characters in 80-column text mode.
;
VIDOUT      CMP     #$20        ; A DISPLAYABLE CHARACTER?
            BLT     VIDOU1
            ORA     #$80        ; YES, THEN SET MSB=1 FIRST
            BMI     STORAD      ; ALWAYS
VIDOU1      CMP     #$07        ; CTRL-@ to CTRL-F DONT CARE
            BLT     VIDRTS
            CMP     #$0E        ; TAKE CARE OF CTRL-G to CTRL-M
            BLT     VIDCON
            CMP     #$19        ; CTRL-E to CTRL-X ARE DON'T CARE
            BLT     VIDRTS
            SBC     #11         ;; Move down so that CTRL-Y is now CTRL-N
VIDCON      TAY                 ; USE Y AS A POINTER TO GET THE
            LDA     #>BELL      ; ADDRESSES OF THE CTRL-ROUTINES
            PHA
            LDA     SUBTBL-7,Y  ;; Look up the control key handler table
            PHA                 ;; Sets up to jump to the control key handler
VIDRTS      RTS
;
;; Stores a printable ASCII character to the screen at the cursor position.
;
STORAD      LDY     CHORZ       ; DISPLAY CHARACTER
            JSR     CHRDIS
            JSR     VIDWAI      ; SEE IF CTRL-S PRESSED
ADVANC      INC     CHORZ       ; AND ADVANCE CURSOR
            LDA     CHORZ
            CMP     WNDWTH      ; CURSOR EXCEEDS SCREEN?
            BGE     CRLF        ; IF YES, CRLF
            RTS
;
;; Ouput a carriage return character.
;
CR          LDA     #0          ; CARRIAGE RETURN ONLY
            STA     CHORZ
            RTS
;
;; Sound the terminal bell.
;
BELL        LDA     #$C0        ; BELL THE SPEAKER AT 1KHZ FOR
            STA     SBAS2L      ; 0.1 SECOND
            SEC
BELL1       LDA     #0          ; 8 * 64 = 1024 / 2
BELL2       BIT     HORZSC      ; HORIZONTAL SYNC PERIOD = 64US
            BMI     *-3
            BIT     HORZSC
            BPL     *-3
            SBC     #1
            BNE     BELL2
            LDA     SPEAKR      ; TOGGLE THE SPEAKER
            DEC     SBAS2L      ; 12 * 16 / 2 = 96
            BNE     BELL1
            RTS
;
;; CTRL-^ is followed by X and Y positions, each encoded as N+$20.
;
GOTOXY      LDA     #$02        ;; Set a flag in POWER that indicates
            ORA     POWER       ;; that the next byte is the X position.
            STA     POWER
            RTS
;
;; Backspace / move cursor left.
;
BS          DEC     CHORZ
            BPL     VIDRTS      ; SHOULD NOT EXCEED THE LEFT EDGE
            LDA     WNDWTH      ; IF PASS, GO UP ONE LINE
            STA     CHORZ
            DEC     CHORZ
;
;; Move cursor up on the screen.
;
UP          LDA     CVERT
            CMP     WNDTOP      ; CURSOR SHOULD NOT GO OVER THE
            BLT     VIDRTS      ; TOP OF THE SCREEN WINDOW
            BEQ     VIDRTS
            DEC     CVERT       ; IF NOT, WE CAN GO UP
            JMP     VTAB        ; ONE LINE
;
;; Move the cursor to the top-left of the screen.
;
HOME        LDA     WNDTOP      ; TO POSITION 'HOME'
            STA     CVERT
            LDA     #0
            STA     CHORZ
            JMP     VTAB
;
;; Clear the screen.
;
CLSCRN      JSR     HOME        ; CLEAR THE WHOLE SCREEN
            LDA     WNDTOP
            LDY     #0
            BEQ     CLEOP1      ; ALWAYS
;
;; Clear to end of screen.
;
CLREOP      LDY     CHORZ       ; CLEAR TO END OF PAGE
            LDA     CVERT
CLEOP1      PHA                 ; CLSCRN ENTER HERE
            JSR     ADRCAL      ; CLEAR LINE BY LINE
            JSR     CLEOLZ
            LDY     #0          ; STARTING FROM THE SECOND LINE
            PLA                 ; CLEAR FROM THE LEFT EDGE
            CLC
            ADC     #1          ; NEXT LINE
            CMP     WNDBTM      ; DOWN TO THE BOTTOM LINE?
            BLT     CLEOP1
            JMP     VTAB
;
;; Clear to the end of the current line.
;
CLREOL      LDY     CHORZ       ; CLEAR TO END OF LINE
;
CLEOLZ      LDA     #$A0        ; CLEAR = FILL WITH SPACE
CLEOL2      JSR     CHRDIS      ; DISPLAY THE CHARACTER
            INY
            CPY     WNDWTH      ; REACH tHE END OF A LINE?
            BLT     CLEOL2      ; IF NOT, CONTINUE
            RTS
;
;; Carriage return and line feed.
;
CRLF        JSR     CR          ; CARRIAGE RETURN + LINE FEED
LF          INC     CVERT
            LDA     CVERT       ; CURSOR SHOULD NOT GO BEYOND
            CMP     WNDBTM      ; THE BOTTOM OF THE SCREEN
            BGE     *+5         ; IF EXCEED, PERFORM SCROLLING
            JMP     ADRCAL      ; IF NOT, GOOD!
            DEC     CVERT
;
;; Scroll the screen up one line.
;
SCROLL      LDA     WNDWTH      ; PREPARE FOR SCROLLING
            PHA                 ; SAVE IT FIRST
            CLC
            ADC     WNDLFT
            TAY
            DEY                 ; NATURAL V.S. INTEGER
            STY     WNDWTH      ; CREATE "NEW" WINDOW WIDTH
            JSR     RAM0IN      ; GET THE DISPLAY BANK IN
;
SCROL0      LDA     WNDTOP      ; SCROLL THE TEXT SCREEN
            PHA
            JSR     ADRCAL      ; CALCULATE A BASE ADDRESS
            JSR     COMPAT
SCROL1      LDA     SBASL
            STA     SBAS2L
            LDA     SBASH
            STA     SBAS2H
            PLA                 ; GET THE LINE COUNT BACK
            CLC
            ADC     #$01
            CMP     WNDBTM      ; REACH THE LAST LINE?
            BGE     SCROL6
            PHA                 ; SAVE IT FOR THE NEXT CYCLE
            JSR     ADRCAL      ; CALCULATE THE NEXT BASE ADDRESS
            JSR     COMPAT
            LDY     WNDWTH
            CPY     #40         ; 40 OR 80 COLUMN MODE?
            BGE     SCROL3
SCROL2      LDA     (SBASL),Y   ; MOVE UP ONE LINE
            STA     (SBAS2L),Y
            DEY
            CPY     WNDLFT      ; ONE LINE FINISHED?
            BPL     SCROL2      ; IF NO, CONTINUE
            BMI     SCROL1      ; IF YES, GO FOR THE NEXT LINE
;
SCROL3      LDA     SBASH       ; DO SOME TRANSFORMATION
            ORA     #$04        ; FOR 80 COLUMN TEXT MODE
            STA     SBASH
            LDA     SBAS2H
            ORA     #$04
            STA     SBAS2H
            LDA     WNDLFT
            SEC
            SBC     #40
            STA     WNDLFT
            TYA
            SEC
            SBC     #40
            TAY
;
SCROL4      LDA     (SBASL),Y   ; MOVE UP THE RIGHT
            STA     (SBAS2L),Y  ; HALF PAGE
            DEY
            CPY     WNDLFT      ; ONE LINE FINISHED?
            BMI     SCROL5      ; IF YES, SKIP
            TYA
            BPL     SCROL4      ; AN EXACT HALF LINE GONE?
;
SCROL5      LDA     SBASH       ; INVERSE TRANSFORM OF SCROL3 ABOVE
            EOR     #$04
            STA     SBASH
            LDA     SBAS2H
            EOR     #$04
            STA     SBAS2H
            LDY     #39
            LDA     WNDLFT
            CLC
            ADC     #40
            STA     WNDLFT
            CMP     #40
            BGE     SCROL1      ; IF LEFT EDGE >= 40, WE HAVE FINISHED
            BLT     SCROL2      ; IF LEFT EDGE < 40
;
SCROL6      JSR     COMPAT
            JSR     RAM0OU      ; TICK DISPLAY BANK OUT
            PLA
            STA     WNDWTH      ; RECOVER WINDOW WIDTH
            LDY     #0
            JSR     CLEOLZ      ; CLEAR THE BOTTOM LINE
;
;; Vertical TAB
;
VTAB        LDA     CVERT       ; PREPARE SCREEN BASE ADDRESS
;
; ROUTINE 'ADRCAL' CALCULATES THE TEXT SCREEN BASE ADDRESS
; INPUT: A = LINE NUMBER
; OUTPUT: SBASL, SBASH = SCREEN BASE ADDRESS FOR THIS LINE
;
ADRCAL      STY     SBASL       ; SAVE Y
            TAY                 ; SAVE A
            LSR     A
            AND     #$03
            ORA     TXTMOD
            STA     SBASH
            LDA     ADRESL, Y
            LDY     SBASL       ; RECOVER Y
            STA     SBASL
            RTS
;
;; Display a printable character on the screen.
;;
;; SBASL, SBASH is assumed to contain the address of the current line.
;; A is assumed to contain the character to print.
;; Y is assumed to contain the offset on the line to draw to.
;
CHRDIS      JSR     TST40C      ; REQUIRE ADDRESS MODIFICATION? ;; Saves Y
            BGE     CHRDS1
            JSR     RAM0IN      ; NO, THEN SIMPLE
            JSR     COMPAT
            STA     (SBASL),Y
            JSR     COMPAT
            LDY     TEMPY       ; GET BACK ORIGINAL Y
            JMP     RAM0OU      ; FINISHED
;
CHRDS1      JSR     SUBY40      ; MODIFY BASE ADDRESS
            JSR     RAM0IN
            JSR     COMPAT
            STA     (SBASL),Y
            JSR     COMPAT
            JSR     RAM0OU
            LDY     TEMPY       ; GET BACK ORIGINAL Y
            JMP     ADDY40      ; CURE THE MODIFICATION
;
;; Test if the column number in Y is in the right half of the 80-column screen.
;
TST40C      PHA                 ; SAVE A
            STY     TEMPY       ; SAVE Y
            TYA
            CLC                 ; Y = Y + WINDOW LEFT
            ADC     WNDLFT
            TAY
            CMP     #40         ; SET CARRY FLAG
            PLA                 ; RECOVER A
            RTS
;
SUBY40      PHA                 ; SAVE CHARACTER FIRST
            TYA                 ; Y = Y - 40
            SEC
            SBC     #40
            TAY
            JMP     TOGGSH      ; MODIFY BASE ADDRESS
;
ADDY40      PHA                 ; SAVE CHARACTER
;
TOGGSH      LDA     SBASH
            EOR     #$04
            STA     SBASH
            PLA                 ; RETAIN CHARACTER
            RTS
;
;; Enable cursor
;
ENCUR       PHA                 ; SAVE CHARACTER FIRST
            LDY     CHORZ
            JSR     TST40C      ; MODIFYING ADDRESS REQUIRED?
            BGE     ENCUR1
            JSR     RAM0IN      ; NO, THEN SIMPLE
            JSR     ENCUR3
            PLA                 ; GET BACK THE CHARACTER
            JMP     RAM0OU      ; FINISHED
;
ENCUR1      JSR     SUBY40      ; MODIFY BASE ADDRESS
            JSR     RAM0IN
            JSR     ENCUR3
            JSR     RAM0OU
            PLA
            JMP     ADDY40      ; FINISHED
;
ENCUR3      JSR     COMPAT
            LDA     (SBASL),Y
            STA     TEMPA       ; SAVE FOR DECUR
            BIT     TWOMHZ      ; TWO KINDS OF CURSOR
            BMI     *+8
            AND     #$3F        ; FOR 40 COLUMN TEXT
            ORA     #$40
            BNE     *+4         ; ALWAYS
            AND     #$7F        ; FOR 80 COLUMN TEXT
            STA     (SBASL),Y
            LDY     TEMPY       ; GET ORIGINAL Y
            JMP     COMPAT
;
;; Disable cursor
;
DECUR       PHP                 ; TURN OFF THE CURSOR
            PHA                 ; SAVE THINGS FOR SAFETY
            LDY     CHORZ
            LDA     TEMPA       ;; Get the character that was saved by ENCUR.
            JSR     CHRDIS      ;; Display it in the current position.
            PLA
            PLP
            RTS                 ; DONE
;
;; Handle escape sequences
;
ESCX2       TAY                 ; USE Y AS A POINTER
            LDA     ESCTB1-$C9,Y ; TRANSFORM X
            JSR     ESCX1       ; THEN PROCESS IT
            JSR     MRDKEY
;
ESCX        CMP     #$CE        ; >= 'N'?
            BGE     ESCXRT
            CMP     #$C9        ; < 'I'?
            BGE     ESCX2       ; IF FALSE, THEN MUST BE ESC I, J, K, L, or M
ESCX1       AND     #$3F        ; SKIP OFF HIGH ORDER BITS
            CMP     #$08        ; >= 'H'?
            BGE     ESCXRT      ; IF YES, DO NOTHING
            TAY                 ; USE Y AS A POINTER
            LDA     #>BELL
            PHA
            LDA     ESCTBL,Y
            PHA
ESCXRT      RTS
;
; RAM0IN AND RAM0OU ARE TWO VERY, VERY IMPORTANT ROUTINES
; THEY ARE CALLED BY THE KERNEL (BOTH C8 AND F8) AND THE BASIC
;
;; RAM0IN assigns memory from the virtual bank $00000 to physical address $4000.
;; RAM0OU restores the original memory bank configuration.
;;
;; PBANK2 contains the memory bank number that is normally at $4000.
;
RAM0IN      PHP                 ; SAFETY IS THE MOST IMPORTANT
            PHA
            LDA     #$00
            STA     SBANK2      ; BRING RAM 0 IN
            PLA
            PLP
            RTS
;
RAM0OU      PHP
            PHA
            LDA     POWER       ; UNDER CP/M OR PASCAL?
            AND     #$FC
            CMP     #$90
            BEQ     MUSTR1      ; IF YES, MOVE RAM 1 IN
            LDA     PBANK2      ; MOVE WHICH BLOCK IN?
            CMP     #$10        ; A REASONABLE NUMBER?
            BLT     RAM0O1
MUSTR1      LDA     #$01        ; IF NOT, ASSUME RAM 1
RAM0O1      STA     SBANK2      ; STORE IT INTO BLOCK 1
            PLA
            PLP
            RTS
;
;; Perform character I/O for BASIC.
;
IO          JSR     TUGGLE      ; PERFORM INTERCHANGE
            JSR     DECUR       ; DO THIS BEFORE EVERYTHING
            BCS     BASINP      ; INPUT OR OUTPUT?
;
BASOUT      LDA     CVWHO
            CMP     CVERT
            BEQ     CVOK
            STA     CVERT
            JSR     VTAB
CVOK        LDA     CHWHO
            CMP     CHORZ
            BLT     CHOK
            STA     CHORZ
CHOK        PLA                 ; GET BACK CHARACTER
            CMP     #$A0        ; CONTROL CHARACTER?
            BLT     BASOU1
            AND     INVFLG      ; NO, DISPLAYABLE
            JSR     STORAD
            JMP     BASOU2      ; GATHER
;
BASOU1      AND     #$7F        ; FOR CONTROL CHARACTER
            CMP     #$0D        ; CARRIAGE RETURN?
            BNE     BASOU3
            JSR     VIDOU1      ; YES
            LDA     #$0A        ; ADD A LINE-FEED
BASOU3      JSR     VIDOU1
;
BASOU2      LDA     CHORZ       ; CHARACTER HAS BEEN SENT
            BEQ     CURECH
            SBC     #$47
            BCC     DONE
            ADC     #$1F
CURECH      STA     CHWHO
;
DONE        LDA     CVERT       ; ALL FINISHED, GO BACK!
            STA     CVWHO
            JSR     ENCUR       ; ENABLE CURSOR BEFORE EXIT
            JSR     TUGGLE      ; ALSO DO THIS
            PLA
            TAY
            PLA
            TAX
            PLA                 ; RECOVER CHARACTER
DONRTS      RTS
;
;; Handle escape sequences on input for BASIC.
;
NEWESC      TAY
            LDA     ESCTB1-$C9,Y
            JSR     ESCX1
;
ESCWHO      JSR     RDKWHO      ; ESC WHAT?
            CMP     #$CE        ; >= 'N'?
            BGE     DONRTS
            CMP     #$C9        ; < 'I'?
            BGE     NEWESC
            JSR     ESCX1       ; YES
;
;; Input a character from the keyboard for BASIC.
;;
;; If the user presses CR, then the rest of the line will be cleared.
;; If the user presses the right array key ($95), then the character
;; on the screen under the cursor is returned as the key input.
;
BASINP      JSR     RDKWHO      ; READ KEY
            CMP     #$9B
            BEQ     ESCWHO      ; ESC?
            CMP     #$8D
            BNE     NOTCRW      ; CARRIAGE RETURN?
            PHA                 ; YES
            JSR     CLREOL      ; CLEAR TO END OF LINE
            PLA
NOTCRW      CMP     #$95        ; RIGHT ARROW?
            BNE     NOPICK
            LDA     TEMPA       ; YES, PICK UP CHARACTER UNDER CURSOR
            ORA     #$80        ; MSB MUST = 1
NOPICK      TSX                 ; REPLACE CHARACTER ON STACK
            STA     STACK+4,X
            LDA     #0
            STA     CHWHO
            PLA                 ; REPLACE THE DUMMY CHARACTER
            JMP     DONE        ; FINISHED
;
RDKWHO      JSR     ENCUR       ; TURN CURSOR ON
            JSR     KEYIN       ; WHILE WAITING FOR KEY INPUT
            JMP     DECUR       ; KEY GOT, TURN OFF CURSOR
;
; ROUTINE 'TUGGLE' IS USED TO INTERCHANGE A SET
; OF ZERO PAGE LOCATIONS WITH A SET OF SLOT 3 LOCATIONS
; THIS ALLOWS OUR READ-KEY AND CHARACTER-DISPLAY
; ROUTINES TO BE SHARED BY DIFFERENT OPERATING SYSTEMS
;
TUGGLE      PHP                 ; SAFETY
            PHA
;
            LDA     CHORZ       ;; Swap CHORZ and CHWHO
            PHA
            LDA     CHWHO
            STA     CHORZ
            PLA
            STA     CHWHO
;
            LDA     CVERT       ;; Swap CVERT and CVWHO
            PHA
            LDA     CVWHO
            STA     CVERT
            PLA
            STA     CVWHO
;
            LDA     WNDWTH      ;; Swap WNDWTH and SAVE1
            PHA
            LDA     SAVE1
            STA     WNDWTH
            PLA
            STA     SAVE1
;
            PLA
            PLP
            RTS

;;***********************************************************************
;;
;; End of the 80 column display firmware.
;;
;;***********************************************************************

;;***********************************************************************
;;
;; Reset handler and system initialization.
;;
;;***********************************************************************

            ORIGIN      $D571
;
; THIS IS THE RESET HANDLER
;
RESET0      CLD
            LDX     #$0F        ;; Check if PBANK4 is set to F.
            CPX     PBANK4      ;; It will not be for a cold start.
            BEQ     RESET1      ; IF NOT POWER UP, SKIP
;
DELAY       LDY     #$A0        ; WAIT TILL SYSTEM SETTLES
DELAY1      ADC     #$01
            BCC     DELAY1
            DEY
            BNE     DELAY1
;
;; At this point the A and Y registers are both zero.
;
ASSIGN      STX     SBANK4      ; ASSIGN MEMORY CONFIGURATION
            STA     SYSTEM      ; AS : 0, 1, 3, F
            STY     SBANK1      ; Bank 1 = 0
            STY     PBANK1
            STX     PBANK4      ; Bank 4 = F
            INY
            STY     SBANK2      ; Bank 2 = 1
            STY     PBANK2
            INY
            INY
            STY     SBANK3      ; Bank 3 = 3
            STY     PBANK3
;
            LDY     #$10
            STY     TXTABH
            STA     TXTABL      ; REMEMBER (A)=$00?
            STA     STATUS      ; INIT STATUS
            TAY
CLEAR       LDA     #$A0        ; CLEAR SCREEN
            STA     (TXTABL),Y
            INY
            BNE     CLEAR
            INC     TXTABH
            LDA     TXTABH
            CMP     #$18
            BNE     CLEAR
;
;; Choose the boot configuration based on the key that is pressed at startup:
;;
;;      None    BASIC starts at $1800
;;      A       BASIC starts at $0800
;;      ESC     Select 80 column text mode from startup
;
CHOICE      LDX     KEYBRD      ; BASIC STARTS AT $1800?
            CPX     #$C1
            BNE     USUAL
            LDA     #$08        ; OR AT $800?
USUAL       STA     TXTABH
            BIT     KEYSTR      ; CLEAR KEYBOARD
            CPX     #$9B        ; HAS ESC BEEN PRESSED?
            BNE     SETT40
            JSR     TEXT80      ; CAN BE 80 COLUMN TEXT
            JMP     RESET1      ; TO BE CONTINUE
SETT40      JSR     TEXT40      ; DEFAULT 40 COLUMN TEXT
;
RESET1      JSR     HRSEXT      ; FORCE MEMORY ASSIGNMENTS
            JSR     FRAM0O      ; RIGHT
            JSR     NORMAL      ; SET NORMAL DISPLAY
            LDA     TEXTCR      ; WHITE TEXT, BLACK BACKGROUND, BLACK BORDER
            LDA     BKGRND
            LDA     BKDROP
            JSR     SONINT      ; TURN OFF SOUND GEN.
            JSR     VZINIT      ; INIT TEXT DISPLAY
            JSR     SCREEN      ; INIT INPUT/OUTPUT
            JSR     KBDBRD
            JSR     MBELL       ; INFORM THE USER WITH A BEEP
            LDA     RESTVR+2    ; CHECK RESET VECTOR
            EOR     #$A5
            CMP     RESTVR+1
            BNE     FSTIME      ; FIRST TIME POWER UP?
            JMP     DEBUG1      ; NO
FSTIME      JSR     TITLE       ; SHOW OUR LOGO
            JSR     INFKEY      ; CLEAR THE FUNCTION KEYS
            JSR     PRESP3      ; PRESET PAGE 3 VECTORS
            JSR     CHKDIS      ; CHECK DRIVE CONTROLLER
NODRIV      LDA     #<BASICW    ; SET UP RESET VECTOR
            STA     RESTVR
            JSR     SRESTV
            JMP     BASICC      ;; Jump to the BASIC ROM's at $E000 (cold start)

;;***********************************************************************
;;
;; Start of the BASIC ROM's at $E000.
;;
;; If we don't have BASIC, then we jump into the kernel monitor instead
;; and replace some of the BASIC routines the kernel uses with stubs.
;;
;;***********************************************************************

    ifdef NOBASIC
            ORIGIN  BASICC
BASIC       JMP     MON1        ;; Cold start entry point for BASIC
            JMP     MON1        ;; Warm start entry point for BASIC

;
;; HRSEXT restores the correct mapping for memory bank 3.
;
            ORIGIN  HRSEXT
            PHP
            PHA
            LDA     PBANK3
            CMP     #$10
            BLT     SETBANK3
            LDA     #$03
SETBANK3    STA     SBANK3
            PLA
            PLP
            RTS
;
;; Not sure what this does - renews the function key buffer?
;
            ORIGIN  RENEW
            RTS
;
;; NORMAL sets the screen text to normal (not inverse or flashing).
;
            ORIGIN  NORMAL
            LDA     #$FF
            LDX     #$00
            STA     INVFLG
            STX     $F3
            RTS

    endif   ; NOBASIC

;;***********************************************************************
;;
;; Kernel monitor ROM at $F800.
;;
;; The original code from the Technical Reference Manual pre-filled
;; $F800 to $FFFF with $60 bytes and then overwrote the code.
;; This effectively fills all unused space with RTS instructions.
;; The "vasm" assembler doesn't allow us overlap sections like that,
;; so we instead use "DS n, $60" for padding below.
;;
;;***********************************************************************

            ORIGIN  $F800
;
;; Jump table of useful kernel routines.
;
JRAM0I      JMP     FRAM0I      ;; $F800: Bring RAM0 into BANK2 for text access
JRAM0O      JMP     FRAM0O      ;; $F803: Restore previous BANK2 configuration
JTEXT40     JMP     TEXT40      ;; $F806: Switch to 40-column text mode
JTEXT80     JMP     TEXT80      ;; $F809: Switch to 80-column text mode
JAUDOUT     JMP     AUDOUT      ;; $F80C: Send data to the 76489 sound generator
JMOUTS1     JMP     MOUTS1      ;; $F80F: Switch to the printer driver
;
;; Set the screen width to 40 or 80 columns ($F812)
;
SETWTH      LDA     TXTMOD      ; 40 OR 80 COLUMN MODE?
            CMP     #$10
            BNE     SETW40
            LDA     #80         ; 80 COLUMN TEXT MODE
            STA     VZTX80
SETW48      STA     WNDWTH
            RTS
SETW40      LDA     #40
            STA     VZTX40
            BNE     SETW48      ; ALWAYS
;
;; Copy the second kernel address into the first for "FFFF.SSSS" dot commands.
;
DOT         LDA     REG2L
            STA     REG1L
            LDA     REG2H
            STA     REG1H
            RTS
;
;
DATA07      DB      $07         ;; Bitmask used in the TAB subroutine below
            RTS                 ;; Padding
;
;; Return key pressed at the end of a kernel command.
;
RETURN      LDA     SAVEX       ; RETURN ONLY?
            BEQ     XMEM8
            JSR     SPACE       ; IF NOT, DO A SPACE FUNCTION
            JSR     DOT         ; REGISTER 1 = 2
RETRTS      PLA                 ; POP RETURN ADDRESS
            PLA
            LDA     #$00        ; CLEAR STORE MODE
            STA     STOFLG
            JMP     MON1        ; END OF KERNEL COMMAND INTERPRETATION
;
;; Display bytes from memory.
;
XMEM8       LDA     TXTMOD      ; 40 OR 80 COLUMN MODE?
            CMP     #$10
            BNE     *+5
            LDA     #$0F        ; 80 COLUMN MODE
            DB      $2C         ; $2C = "BIT" ;; skips the next instruction
            LDA     #$07        ; 40 COLUMN MODE
            STA     CHKSUM      ; USE CHKSUM AS A GENERAL REGISTER
;
            JSR     CROUT       ; CARRIAGE RETURN
            JSR     INCRE2      ; INCREMENT REGISTER 1
            LDA     REG1H       ; PRINT ADDRESS
            JSR     PRBYTE
            LDA     REG1L
            JSR     PRBYTE
            LDA     #$BD        ; FOLLOWED BY '='
            JSR     MCOUT
;
            LDY     #0          ; CLEAR OFFSET
XMEM81      LDA     #$A0        ; ADD A SPACE CHARACTER
            JSR     MCOUT
            LDA     (REG1L),Y   ; THEN THE MEMORY CONTENTS
            JSR     PRBYTE
            LDA     REG1L
            AND     CHKSUM      ; EITHER MOD 8 OR MOD 16
            CMP     CHKSUM
            BEQ     RETRTS      ; FINISHED?
            JSR     INCRE2      ; INCREMENT REGISTER 1
            JMP     XMEM81      ; CONTINUE
;
;; Message "ERROR " with the high bit set in each of the ASCII bytes.
;
ERRORM      DB      $C5, $D2, $D2, $CF, $D2, $A0
;
OPERR       LDA     #0          ; FOR INVALID OPCODES
            STA     OPCODL      ; SET LENGTH = 0
            RTS
;
LENGTH      LSR                 ; START CHECKING OPCODE
            BCS     ODD         ; IF ODD, DO MORE
ODDEVN      LSR                 ; SELECT NIBBLE
            TAY                 ; USE Y AS POINTER
            LDA     TABLE1,Y    ; GET LENGTH
            BCC     LOWNIB      ; WHICH NIBBLE?
            LSR                 ; HIGH NIBBLE
            LSR
            LSR
            LSR
LOWNIB      AND     #$0F        ; TICK OUT HIGH BITS
            CMP     #6          ; INVALID OPCODE?
            BEQ     OPERR
            STA     OPCODL      ; SAVE THE LENGTH
            RTS                 ; FINISHED
;
ODD         ROR
            BCS     OPERR       ; NO XXXXXX11 OPCODES
            EOR     #$FF
            CMP     #$5D
            BEQ     OPERR       ; NO STA #---
            EOR     #$FF
            AND     #$87        ; MASK BITS
            JMP     ODDEVN
;
;; Saving to cassette tape.
;
MTSAVE      LDA     #64
            JSR     LEADER
            BIT     TWOMHZ
            BPL     *+5
            LDY     #84         ; FIRST BYTE
            DB      $2C         ; $2C = "BIT" ;; skips the next instruction
            LDY     #37
TSAVE1      LDX     #0
            EOR     (REG1L,X)
            STA     CHKSUM
            LDA     (REG1L,X)
            JSR     WRBYTE
            JSR     INCRE2
            BIT     TWOMHZ
            BPL     *+5
            LDY     #62         ; REST BYTES
            DB      $2C         ; $2C = "BIT" ;; skips the next instruction
            LDY     #27
            LDA     CHKSUM
            BLT     TSAVE1
            BIT     TWOMHZ
            BPL     *+5
            LDY     #68         ; THE LAST: CHECK-SUM
            DB      $2C         ; $2C = "BIT" ;; skips the next instruction
            LDY     #32
            JSR     WRBYTE
            JMP     MBELL
;
;
LEADER      BIT     TWOMHZ      ; ONE OR TWO MHZ?
            BPL     *+5         ; NORMALLY IT IS 1MHZ
            LDY     #155        ; BUT CAN BE 2MHZ
            DB      $2C         ; $2C = "BIT" ;; skips the next instruction
            LDY     #73         ; GOOD, 1MHZ
            JSR     ZDELAY
            BNE     LEADER
            ADC     #$FE
            BCS     LEADER
            BIT     TWOMHZ
            BPL     *+5
            LDY     #68
            DB      $2C         ; $2C = "BIT" ;; skips the next instruction
            LDY     #31
WRTBIT      JSR     ZDELAY
            INY
            INY
ZDELAY      DEY
            BNE     ZDELAY
            BCC     WTAPE       ; ZERO IS SHORTER THAN ONE
            BIT     TWOMHZ
            BPL     *+5
            LDY     #101
            DB      $2C         ; $2C = "BIT" ;; skips the next instruction
            LDY     #47
ODELAY      DEY                 ; EXTRA DELAY FOR ONE
            BNE     ODELAY
            JMP     WTAPE       ; TIME COMPENSATION
WTAPE       LDY     TAPEOU      ; TOGGLE TAPE OUTPUT
            BIT     TWOMHZ
            BPL     *+5
            LDY     #90
            DB      $2C         ; $2C = "BIT" ;; skips the next instruction
            LDY     #42
            DEX
            RTS
;
            DS      10,$60      ;; Padding
;
;; Print the byte value in Y and then the value in X.
;
PRNYX       TYA                 ; PRINT Y
;
;; Print the byte value in A and then the value in X.
;
PRNAX       JSR     PRBYTE      ; PRINT A
            TXA
            JMP     PRBYTE
;
;; Print three spaces.
;
PRNSPC      LDA     #$03
            STA     RNDNOL
            LDA     #$A0
SPCLP       JSR     MCOUT
            DEC     RNDNOL
            BNE     SPCLP
            RTS
;
;; Read 8 bits from the cassette tape.
;
RT8BIT      LDX     #$09
            DEX
LP8BIT      PHA
            JSR     READPS
            PLA
            ROL     A
            LDY     #$39
            DEX
            BNE     LP8BIT
            RTS
;
READPS      JSR     RT1BIT
RT1BIT      DEY
            DEY
            BIT     TWOMHZ
            BPL     READPS3
            INC     RNDNOL
            DEC     RNDNOL
            INC     RNDNOL
            DEC     RNDNOL
            NOP
            NOP
READPS3     LDA     TAPEIN
            EOR     LASTBI
            BPL     READPS4
            EOR     LASTBI
            STA     LASTBI
            CPY     #$80
            RTS
READPS4     JMP     RT1BIT
;
;; Verify memory contents by comparing two regions.
;
VERIFY      LDY     #$00
            LDA     (REG1L),Y
            CMP     (REG4L),Y
            BNE     DIFFER
VERCOM      JSR     INCRE1
            BCC     VERIFY
            RTS
DIFFER      JSR     CROUT
            LDA     REG1H
            JSR     PRBYTE
            LDA     REG1L
            JSR     PRBYTE
            LDA     #$BD        ; PRINT CONTENT AFTER '='
            JSR     MCOUT
            LDY     #0
            LDA     (REG1L),Y
            JSR     PRBYTE
            LDA     #$A0        ; THEN SPACE
            JSR     MCOUT
            LDA     #$A8        ; THEN THE UNMATCHED VALUE AFTER '('
            JSR     MCOUT
            LDY     #0
            LDA     (REG4L),Y
            JSR     PRBYTE
            LDA     #$A9        ; ')'
            JSR     MCOUT
            JMP     VERCOM      ; NEXT
;
;; Handle a TAB character on input.
;
TAB         CPX     #248        ; NEAR END OF INPUT LINE?
            BGE     TABJMP      ; IF YES, DO NOTHING
            LDA     CHORZ       ; TRY TO DO TAB
            CLC
            ADC     #8          ; TAB = ADVANCE 8 POS,
            CMP     WNDWTH      ; EXCEED THE RIGHT END?
            BGE     TABJMP      ; IF YES, CANCEL
;
            JSR     C800IN      ; FOR DECUR AND ENCUR
TAB1        LDA     TEMPA       ; NOW, DO TAB
            STA     KEYBUF,X    ; COPY THINGS ON SCREEN
            INX
            INC     CHORZ
            LDA     CHORZ
            BIT     DATA07      ; TAB POS. ARE QUANTIZED
            BEQ     TABJMP      ; FINISHED?
            JSR     ENCUR       ; IF NOT, CONTINUE
            JSR     DECUR       ; COPYING CHARACTERS
            JMP     TAB1
;
TABJMP      JMP     GETLN1      ; GO BACK
;
; TABLE1 CONTAINS:
; 1. 128 4-BIT LENGTHS FOR XXXXXXX0 TYPE OF OPCODES
; 2. 8 4-BIT LENGTHS FOR XXXXXX01 TYPE OF OPCODES
;    I.E. ORA,ANDmEOR,ADC,STA,LDA,CMP,SBC
;
TABLE1      DB      $60, $16, $00, $26, $61, $16, $60, $26
            DB      $62, $11, $00, $22, $61, $16, $60, $26
            DB      $60, $16, $00, $22, $61, $16, $60, $26
            DB      $60, $16, $00, $22, $61, $16, $60, $26
            DB      $66, $11, $00, $22, $61, $16, $60, $26
            DB      $11, $11, $00, $22, $61, $11, $00, $22
            DB      $61, $11, $00, $22, $61, $16, $60, $26
            DB      $61, $11, $00, $22, $61, $16, $60, $26
            DB      $11, $21, $11, $22
;
            DS      6, $60      ;; Padding
;
;; IRQ or BRK handler
;;
;; Note: The user-supplied IRQ handler pointed to by "IRQVER" must restore
;; A from the "ACC" variable at address $45 the zero page before returning.
;; If not, the foreground code that was interrupted will act very strangely.
;;
;; Similarly, the BREAK handler pointed to by "BRKVER" must restore all
;; registers from addresses $45 to $49 in the zero page before returning.
;
            ORIGIN  $FA40
;
IRQBRK      STA     ACC         ; SAVE A
            PLA                 ; GET STATUS REGISTER
            PHA
            BIT     DATA10      ; INTERRUPT OR BREAK?
            BNE     BREAK
            JMP     (IRQVER)    ;; Jump to user-supplied IRQ handler.
BREAK       PLA                 ; GET BACK STATUS REGISTER
            STA     STATUS      ; SAVE IT
            PLA                 ; SAVE RETURN ADDRESS
            STA     PCL
            PLA
            STA     PCH
            STX     REGX        ; SAVE REGISTERS
            STY     REGY        ; SAVE REGISTERS
            TSX
            STX     STACKP
            JMP     (BRKVER)    ;; Jump to user-supplied BREAK handler.
;
            JMP     MON         ; DUMMY
;
;; RESET handler
;
RESET       JMP     RESET0
;
;; Default BREAK handler
;
BREAK1      JSR     CROUT       ; CARRIAGE RETURN FIRST
            LDX     #$00        ; INIT POINTER & COUNTER
BREAK2      LDA     BRKMES,X    ; PRINT BREAK MESSAGE
            JSR     MCOUT
            INX                 ; FINISHED?
            CPX     #11
            BNE     BREAK2
            LDA     PCL         ; PRINT ADDRESS
            SBC     #2
            PHA
            LDA     PCH
            SBC     #0
            JSR     PRBYTE
            PLA
            JSR     PRBYTE
            JMP     MON         ; THEN GOTO KERNEL
;
;; Table of kernel monitor command characters.
;
COMTBL      DB      $83         ; CTRL-C
            DB      $82         ; CTRL-B
            DB      $99         ; CTRL-Y
            DB      $8B         ; CTRL-K
            DB      $90         ; CTRL-P
            DB      $CE         ; N
            DB      $C9         ; I
            DB      $AE         ; .
            DB      $B3         ; :
            DB      $B5         ; (
            DB      $C7         ; G
            DB      $D2         ; R
            DB      $D7         ; W
            DB      $CD         ; M
            DB      $D6         ; V
            DB      $8D         ; RETURN
            DB      $A0         ; SPACE
;
;; Table of kernel monitor command handlers.
;
ADRTBL      DW      BASICW-1
            DW      BASICC-1
            DW      USRADR-1
            DW      SETIN-1
            DW      SETOU-1
            DW      SETNOR-1
            DW      SETINV-1
            DW      DOT-1
            DW      COLON-1
            DW      MODE3-1
            DW      GO-1
            DW      TLOAD-1
            DW      MTSAVE-1
            DW      MOVE-1
            DW      VERIFY-1
            DW      RETURN-1
            DW      SPACE-1
;
;; Startup banner and logo.  Encoded with the MSB set in the ASCII characters.
;;
;; "MICROSOFT BASIC V.T. VERSION 2.2<CR><CR>"
;; "(C) COPYRIGHT V.T. 1984<CR><CR><NUL>"
;
LOGO        DB      $CD, $C9, $C3, $D2, $CF, $D3
            DB      $CF, $C6, $D4, $A0, $C2, $C1
            DB      $D3, $C9, $C3, $A0, $D6, $AE
            DB      $D4, $AE, $A0, $D6, $C5, $D2
            DB      $D3, $C9, $CF, $CE, $A0, $B2
            DB      $AE, $B2, $8D, $8D, $A8, $C3
            DB      $A9, $A0, $C3, $CF, $D0, $D9
            DB      $D2, $C9, $C7, $C8, $D4, $A0
            DB      $D6, $AE, $D4, $AE, $A0, $B1
            DB      $B9, $B8, $B4, $8D, $8D, $00
;
            DS      11, $60     ;; Padding
;
;; Read paddle inputs at 1MHz
;
            ORIGIN  $FB02
PREAD1      LDA     PADDL0,X    ; 3 CYCLES
            BPL     PDLRTS      ; 2 CYCLES
            INY                 ; 2 CYCLES
            BNE     PREAD1      ; 3 CYCLES
            DEY
PDLRTS      RTS
;
;; Read paddle inputs at 2MHz
;
PREAD2      LDA     PADDL0,X    ; 3 CYCLES
            LDA     PADDL0,X    ; 3 CYCLES
            BPL     PDLRTS      ; 2 CYCLES
            BPL     PDLRTS      ; 2 CYCLES
            INY                 ; 2 CYCLES
            NOP                 ; 2 CYCLES
            STA     SBAS2L      ; 3 CYCLES
            BNE     PREAD2      ; 3 CYCLES
            DEY
            RTS
;
;; Read paddle inputs.
;
MPREAD      LDY     #$00
            BIT     TWOMHZ      ; 1 OR 2 MHZ?
            STA     PDLRES      ; RESET TIMER
            BPL     PREAD1      ; FOR 1MHZ
            BMI     PREAD2      ; FOR 2MHZ
;
            DS      5,$60       ;; Padding
;
;; Initialize the text display at system startup.
;
VZINIT      NOP                 ; SPACE FILLER
            NOP
            NOP
            NOP
            LDA     VZSELF      ;; Turn off emulation
            LDA     VZPAG1      ;; Display primary graphics display
SETTXT      LDA     VZTEXT      ;; Set text mode
            LDA     #$00
            BEQ     MSETWN      ;; Always
;
;; Copy kernel second address into fourth address.
;
MODE3       LDA     REG2L
            STA     REG4L
            LDA     REG2H
            STA     REG4H
            RTS
;
;
DATA10      DB      $10         ;; Constant for the IRQBRK subroutine.
SIGNAT      DB      $00         ; SIGNATURE BYTE
;
;; Set initial window size for the text display.
;
MSETWN      STA     WNDTOP      ; SET FULL SCREEN SIZE
            LDA     #0          ; 24*40 OR 24*80
            STA     WNDLFT
            LDA     #24
            STA     WNDBTM
            NOP
            JSR     SETWTH      ; 40 OR 80?
            LDA     #23         ; PLACE THE CURSOR AT THE BOTTOM LINE
MTABV       STA     CVERT
            JSR     MVTAB
            RTS
;
;; Initialize BRKVER and RESTVR in the zero page with
;; pointers to the default BREAK and RESET handlers.
;;
;; RESTVR+2 is set to (RESTVR+1) ^ $A5 which allows the
;; system to detect if the next reset is a warm start or not.
;
PRESP3      LDY     #4
LOOP1       LDA     P3VECT-1,Y
            STA     BRKVER-1,Y
            DEY
            BNE     LOOP1
            JMP     SRESTV
;
;; Set reset vector check byte at RESTVR+2.
;
SRESTV      LDA     RESTVR+1
            EOR     #$A5
            STA     RESTVR+2
            RTS
;
;; Set 40-column text mode.
;
TEXT40      LDA     #$04        ; ENABLE 40 COLUMN TEXT
            JSR     BEAUTI
            BIT     VZTX40
            RTS
;
;; Set 80-column text mode.
;
TEXT80      LDA     #$10        ; ENABLE 80 COLUMN TEXT
            JSR     BEAUTI
            BIT     VZTX80
            RTS
;
BEAUTI      STA     TXTMOD
            BIT     VERTSC      ; CHANGE DURING VERTICAL
            BMI     *-3         ; RETRACE PERIOD
            BIT     VZSELF      ;; Turn off emulation
            BIT     VZTEXT      ;; Set text mode
            RTS
;
;; Display welcome message at startup.
;
TITLE       JSR     F8HOME
            LDX     #0          ; USE X AS COUNTER AND POINTER
TITLE1      LDA     LOGO,X
            BEQ     TITRTS      ; END?
            JSR     MCOUT       ; DISPLAY OUR LOGO
            INX
            BNE     TITLE1      ; ALWAYS
TITRTS      RTS
;
;; Initialize the function key buffer.
;
INFKEY      JSR     FRAM0I      ; GET FUNCTION KEY BUFFER
            LDX     #24
            LDA     #$A0        ; FILL WITH SPACES
INFKE1      STA     KEYFLG,X    ; REMEMBER X=24?
            DEX
            BPL     INFKE1      ; ALSO DEACTIVATE FUNCTION KEY
            JMP     FRAM0O      ; O.K., FINISHED!
;
            DS      7, $60      ;; Padding
;
;; Routines for brining the $C800 80-column display firmware
;; into the memory map so that those functions can called from
;; the main monitor code.
;
            ORIGIN  $FBC1
FADRCAL     JSR     C800IN
            JMP     ADRCAL
;
; FRAM0I AND FRAM0U SHOULD BE CALLED WHEN YOU ARE OUTSIDE C8
; WHEN IN C8, YOU CAN SIMPLY CALL RAM0IN AND RAM0OU.
;
FRAM0I      JSR     C800IN
            JMP     RAM0IN
;
;
FRAM0O      JSR     C800IN
            JMP     RAM0OU
;
;; Default interrupt vector handlers for BREAK and RESET.
;; These are copied to BRKVER and RESTVR in the zero page at startup.
;
P3VECT      DW      BREAK1
            DW      BASICC
;
            DS      2,$60       ;; Padding
;
;
FBELL       CMP     #$87        ; CTRL-G
            BNE     FRAM0O
            NOP
            NOP
            NOP
            NOP
            NOP
            NOP                 ; FILL SPACE
            NOP
            JSR     C800IN
            JMP     BELL
;
;
ENTRY1      JSR     C800IN
            JMP     STORAD
;
FENTRY1     JSR     ENTRY1
            RTS
;
;
FADVANC     JSR     C800IN
            JMP     ADVANC
;
;; Intialize the 76489 sound generator chip.
;
SONINT      LDY     #3          ; TURN SOUND GEN. OFF
SOUND1      LDA     DEAF,Y
            JSR     AUDOUT
            DEY
            BPL     SOUND1
            RTS
;
;; Handler for the kernel monitor's ":" command.
;
COLON       LDA     #$99
            STA     STOFLG
            JMP     DOT         ; REGISTER 1=2
;
            DS      3, $60      ;; Padding
;
;
FBS         JSR     C800IN
            JMP     BS
;
; DATA USED TO TURN THE SOUND GENERATOR OFF
;
DEAF        DB      $9F, $BF, $DF, $FF
;
;
FUP         JSR     C800IN
            JMP     UP
;
            DS      2, $60      ;; Padding
;
;
MVTAB       LDA     CVERT
            JSR     C800IN
            JMP     ADRCAL
;
;; Send data to the 76489 sound generator chip.
;
AUDOUT      STA     SONGEN      ; SEND DATA TO SOUND GEN.
            BIT     HORZSC      ; WAIT FOR 1 HORIZONTAL
            BMI     *-3         ; SYNC PERIOD
            BIT     HORZSC
            BPL     *-3
            RTS
;
;; Find the starting bit on the cassette tape.
;
FNDSTB      LDY     #36         ; READ THE SYNC PERIOD
            JSR     RT1BIT
            BCS     FNDSTB
            RTS
;
            DS      2, $60      ;; Padding
;
;
FCLREOP     JSR     C800IN
            JMP     CLREOP
;
;
ENTRY2      JSR     C800IN
            JMP     CRLF
;
;; Send output to the printer driver.
;
MOUTS1      JSR     MCOUT1      ; FOR PRINTER DRIVER
            STA     ROMCLR
            STA     $C100       ; ENABLE PRINTER DRIVER
            RTS
;
;
F8HOME      JSR     C800IN      ; HOME OF BASIC
            JMP     CLSCRN      ; = CLEAR SCREEN OF PASCAL
;
            DS      4, $60      ; FILL SPACE
;
;
FCRLF       JSR     ENTRY2
            RTS
;
;
FLF         JSR     C800IN
            JMP     LF
;
;
MWAIT1      PHA                 ; SAVE MAJOR TIMER
MWAIT2      ADC     #1          ; MINOR TIMER
            BNE     MWAIT2      ; CARRY=0 FOR NON-EQUAL
            PLA                 ; GET BACK MAJOR TIMER
            ADC     #0          ; N.B. CARRY=1 FOR NOW
            BNE     MWAIT1      ; CARRY=0 FOR NON-EQUAL
            RTS                 ; ALL FINISHED!
MWAIT       EOR     #$FF        ; FORM 2's COMPLEMENT
            CLC
            ADC     #1
            JMP     MWAIT1
;
;; Increment kernel monitor addresses.
;
INCRE1      INC     REG4L       ; INCREMENT REG4L,$43
            BNE     *+4
            INC     REG4H
INCRE2      LDA     REG1H       ; COMPARE REG1L,$3D WITH
            CMP     REG2H       ; REG2H,$3F
            BLT     INCRE3
            BNE     INCRE3
            LDA     REG1L
            CMP     REG2L
INCRE3      INC     REG1L       ; CARRY HAS MEANING NOW
            BNE     *+4         ; INCREMENT REG1L,$3D
            INC     REG1H
            RTS
;
            DS      4, $60      ;; Padding
;
FCLREOL     LDY     CHORZ
            JSR     C800IN
            JMP     CLEOLZ
;
            DS      4, $60      ;; Padding
;
;
FMWAIT      JMP     MWAIT
;
            DS      9, $60      ;; Padding
;
;
INCREG4     INC     REG4L
            BNE     *+4
            INC     REG4H
            JMP     INCRE2
;
;; Message to display when BREAK occurs.
;;
;; "BREAK AT $" with the MSB set in the ASCII characters.
;
BRKMES      DB      $A1, $C2, $D2, $C5, $C1, $CB, $A0, $C1, $D4, $A0, $A4
;
            RTS                 ;; Padding
;
;
HDELAY      SEC                 ; BYPASS SOME OF THE HEADER
            LDA     #180        ; ABOUT 3 SECONDS
HDELA1      BIT     VERTSC      ; REFERENCE CLOCK
            BMI     *-3
            BIT     VERTSC
            BPL     *-3
            SBC     #1
            BNE     HDELA1
            LDA     #$FF        ; PREPARE CHECK-SUM
            STA     CHKSUM
            RTS
;
;; Kernel monitor space command.
;
SPACE       LDA     STOFLG      ; STORE OR EXAMINE?
            CMP     #$99
            BNE     EXAMIN
            LDY     #0          ; STORE
            LDA     REG2L
            STA     (REG1L),Y
            JMP     INCRE2      ; UPDATE POINTER
EXAMIN      JMP     MEMXM
;
;; Check RESTVR for a warm reset to see if we should jump
;; somewhere other than BASIC.
;
DEBUG1      LDA     RESTVR+1    ;; Is RESTVR equal to $E000?
            CMP     #$E0
            BNE     NONRST
            LDA     RESTVR
            BNE     NONRST
            JMP     NODRIV      ;; Yes, so continue with normal BASIC startup.
NONRST      JMP     (RESTVR)    ;; Jump to the user-supplied reset handler.
;
            DS      9, $60      ;; Padding
;
;; Read a key from the current input device.
;
            ORIGIN  $FD0C
MRDKEY      JSR     C800IN
            JSR     ENCUR
            LDA     TEMPA
            JMP     (INSWL)
;
            DS      3, $60      ;; Padding
;
;; Read a key from the actual keyboard.
;
MINKEY      JSR     C800IN
            STY     SAVEY       ; SAVE REGISTER Y
            JSR     KEYIN       ; USE PASCAL READ KEY ROUTINE
            JSR     DECUR       ; ON EXIT DO THIS
            LDY     SAVEY       ; RECOVER Y
            RTS
;
            DS      3, $60      ; FILL SPACE
;
;; Handle escape sequences from the current input device.
;
MESC        JSR     MRDKEY      ; ESC WHAT?
            JSR     C800IN      ; FOR NON-KEYBOARD INPUT CASE
            JSR     ESCX
;
;; Read a character from the current input device.
;
MRDCHR      JSR     MRDKEY
            CMP     #$9B        ; ESC?
            BEQ     MESC
            CMP     #$FF        ; BREAK?
            BNE     *+4
            LDA     #$83        ; YES, REPLACE WITH CTRL-C
            RTS
;
;; Check for the presence of a disk controller at either $C600 or $C500.
;
CHKDIS      LDA     $C607       ; CHECK DISK CONTROLLER
            CMP     #$3C
            BNE     CHKDI1      ; IF NO, RETURN
            LDA     $C603
            BNE     CHKDI1
            PLA                 ; IF THERE IS, BOOT DISK
            PLA
            JMP     $C600
CHKDI1      LDA     $C507       ;; Check for a disk controller at $C500 instead.
            CMP     #$3C
            BNE     CHKDRT
            LDA     $C503
            BNE     CHKDRT
            PLA
            PLA
            JMP     $C500
CHKDRT      RTS
;
            RTS                 ;; Padding
;
;; Get a line of input text, terminated by CR.
;
MGETLZ      JSR     CROUT
MGETLN      LDA     PROMPT      ; DISPLAY PROMPT SIGN
            JSR     MCOUT
            LDX     #0          ; SET UP CHARACTER COUNTER
GETLN1      JSR     MRDCHR      ; READ A CHARACTER
            CMP     #$98        ; CTRL-X?
            BEQ     CANCEL      ; IF YES, CANCEL THE LINE
            CMP     #$89        ; TAB?
            BNE     *+5
            JMP     TAB         ; YES
            CMP     #$95        ; RIGHT ARROW?
            BNE     NRIGHT
            LDA     TEMPA       ; IF YES, PICK UP THE CHARACTER UNDER CURSOR
            ORA     #$80        ; ENSURE MSB=1
NRIGHT      STA     KEYBUF,X
;
            JMP     *+6         ;; Skip the next instruction (padding?)
            JMP     CROUT
;
            CMP     #$88        ; LEFT ARROW?
            BNE     NOLEFT
            DEX                 ; YES, BACK SPACE
            DEX
            CPX     #$FE        ; BACK TOO MUCH?
            BEQ     MGETLZ
NOLEFT      CMP     #$8D        ; CARRIAGE RETURN
            BNE     NOTCR
            JSR     C800IN
            PHA                 ; IF YES, CLEAR TO END OF LINE
            JSR     CLREOL
            PLA
            JMP     MCOUT       ; END OF GET-LINE!
NOTCR       JSR     MCOUT       ; PRINT CHARCTER ON SCREEN
            INX                 ; NEXT CHARACTER
            CPX     #249        ; EAT TOO MUCH?
            BLT     GETLN1
            JSR     MBELL       ; TAKE CARE OF HEALTH
            CPX     #255
            BNE     GETLN1
CANCEL      LDA     #$AF        ; DANGER, PRINT '/' AND
            JSR     MCOUT       ; STOP IMMEDIATELY
            JMP     MGETLZ
;
;; Print a hexadecimal byte from the kernel monitor.
;
PRBYTE      STA     RNDNOL      ; SAVE A FIRST
            LSR
            LSR
            LSR
            LSR
            JSR     PRNHEX      ; PRINT HIGH NIBBLE
            LDA     RNDNOL      ; RESUME A
            AND     #$0F
            JMP     PRNHEX      ; PRINT LOW NIBBLE
;
            DS      9, $60      ;; Padding
;
            ORIGIN  $FDDA
MPRBYTE     JMP     PRBYTE
;
            DS      6, $60      ;; Padding
;
MPRNHEX     JMP     PRNHEX
;
;; C800IN assigns the 80 column display firmware to address $C800.
;
; ROUTINE 'C800IN' MST BE CALLED FIRST BEFORE ANY
; ROUTINE IN C8 IS CALLED
;
C800IN      STA     ROMCLR      ; WE WANT "SLOT 3"'s C8
            STA     $C300
            RTS
;
;; Output a character to the current output device.
;
MCOUT       JMP     (OUTSWL)
;
;; Output a character to the screen.
;
MCOUT1      JSR     C800IN      ; EVERYTHING IS IN C8
            PHA                 ; SAVE CHARACTER FIRST
            STY     SAVEY       ; SAVE Y
            AND     #$FF        ; GET N FLAG
            BPL     MCOUT5      ; FOR CHARACTERS WITH MSB=0
            CMP     #$A0        ; CONTROL CHARACTER?
            BLT     MCOUT2
            AND     INVFLG      ;; Apply normal, inverse, or blinking mod.
MCOUT5      JSR     STORAD      ;; Display character and advance the cursor
            JMP     MCOUT3
;
MCOUT2      AND     #$7F        ; DO THIS FOR CONTROL CHAR.
            CMP     #$0D        ; CARRIAGE RETURN?
            BNE     MCOUT4
            JSR     VIDOU1
            LDA     #$0A        ; YES, ADD A LINE-FEED
MCOUT4      JSR     VIDOU1
MCOUT3      PLA                 ; NOW, RESUME CHARACTER
            LDY     SAVEY
            RTS
;
;; Write a byte to the cassette tape.
;
WRBYTE      LDX     #16         ; 2 * 8 = 16
WBYTE1      ASL
            JSR     WRTBIT
            BNE     WBYTE1
            RTS
;
            DS      11, $60     ;; Padding
;
;; Move memory command in the kernel monitor.
;
; BEFORE ENTERING, PLEASE SET Y=0
;
MOVE        LDA     (REG1L),Y
            STA     (REG4L),Y
            JSR     INCRE1
            BLT     MOVE        ; FINISHED YET?
            RTS
;
            JMP     VERIFY
;
;; Set the character output routine to use the screen.
;
SCREEN      LDA     #>MCOUT1
            LDY     #<MCOUT1
            STA     OUTSWH
            STY     OUTSWL
            RTS
;
;; Set the character input routine to use the keyboard.
;
KBDBRD      LDA     #>MINKEY
            LDY     #<MINKEY
            STA     INSWH
            STY     INSWL
KBDRTS      RTS
;
;; Examine memory command in the kernel monitor.
;
; PRINT THE ADDRESS AND ITS CONTENTS
;
MEMXM       LDX     SAVEX       ; CHECK LAST KEY
            BEQ     KBDRTS      ; DO NOTHING IF THE FIRST KEY IS A SPACE
            DEX
            LDA     KEYBUF, X
            EOR     #$B0        ; A HEXADECIMAL DIGIT?
            CMP     #$0A
            BLT     MEMXM1      ; IF YES, EXAMINE MEMORY CONTENTS
            ADC     #$88
            CMP     #$FA
            BLT     KBDRTS      ; IF NO, EXIT
MEMXM1      LDA     REG2H       ;; Print the address we are examining
            JSR     PRBYTE
            LDA     REG2L
            JSR     PRBYTE
            LDA     #$BD        ;; Print "="
            JSR     MCOUT
            LDA     #$A0        ;; Print " "
            JSR     MCOUT
            LDY     #0
            LDA     (REG2L),Y   ;; Print the byte at the memory address
            JSR     PRBYTE
            JMP     CROUT
;
            DS      3, $60      ;; Padding
;
;; Set inverse text mode.
;
SETINV      LDA     #$3F        ; TURN ON INVERSE MODE
            NOP                 ; FILL SPACE
            DB      $2C         ; $2C = "BIT" ;; skips the next instruction
SETNOR      LDA     #$FF        ; NORMAL VIDEO MODE
            STA     INVFLG
            RTS
;
;; Set the input device in the kernel monitor.
;;
;; If the value in REG2L is zero, then redirect input to the keyboard.
;; Otherwise redirect the input handler to $CN00 where N is 1-7.
;
SETCIN      LDA     #$00
INPOT       STA     REG2L
SETIN       JMP     INPUT
            RTS
            RTS                 ;; Padding
            RTS                 ;; Padding
;
;; Set the output device in the kernel monitor.
;;
;; If the value in REG2L is zero, then redirect output to the screen.
;; Otherwise redirect the output handler to $CN00 where N is 1-7.
;
SETCOU      LDA     #$00
OUTPOT      STA     REG2L
SETOU       LDA     REG2L
            BEQ     SCREEN
            AND     #$07
            ORA     #$C0
            STA     OUTSWH
            LDY     #$00
            STY     OUTSWL
            RTS
;
;
INPUT       LDA     REG2L
            BEQ     KBDBRD
            AND     #$07
            ORA     #$C0
            STA     INSWH
            LDY     #$00
            STY     INSWL
            RTS
            RTS                 ;; Padding
;
;
            JMP     GO
;
;; Prints the hexadecimal digit in A.
;
PRNHEX      CMP     #10
            BLT     PRNHE1      ; 0 TO 9?
            CLC
            ADC     #7          ; FOR A TO F
PRNHE1      ADC     #$B0        ; FROM NO. TO CHAR.
            JMP     MCOUT       ; PRINT IT!
;
;; Print a carriage return.
;
CROUT       LDA     #$8D
            JMP     MCOUT
;
            DS      3, $60      ;; Padding
;
            JMP     MTSAVE
;
;; "GO" command in the kernel monitor.
;
GO          JSR     GETBRG      ; RESUME REGISTER CONTENTS
            LDA     REG2L       ; DESTINATION
            STA     PCL
            LDA     REG2H
            STA     PCH
            JMP     (PCL)       ; FLY!
;
;; Print the "ERROR" message for the kernel monitor.
;
ERROR       TXA                 ; SAVE X
            PHA
            LDX     #0          ; THEN USE X AS COUNTER
ERROR1      LDA     ERRORM,X    ; PRINT 'ERROR '
            JSR     MCOUT
            INX
            CPX     #6
            BNE     ERROR1
            PLA
            TAX
            JMP     MBELL       ; FOLLOWS WITH A BEEP
;
            DS      11, $60     ;; Padding
;
;; Load from cassette tape.
;
            ORIGIN  $FEFD
TLOAD       JSR     READPS      ; FIND LEADING SIGNAL
            JSR     HDELAY      ; BY PASS THE HEADER
            JSR     READPS      ; FIND SIGNAL AGAIN
            JSR     FNDSTB      ; FIND STARTING BIT
            JSR     RT1BIT
            LDY     #57         ; READ FIRST BYTE IN
TLOAD1      JSR     RT8BIT
            STA     (REG1L,X)
            EOR     CHKSUM      ; UPDATE CHECK-SUM
            STA     CHKSUM
            JSR     INCRE2      ; END OF TAPE READ?
            LDY     #51         ; FOR THE REST BYTES
            BLT     TLOAD1      ; NO, CONTINUE
            JSR     RT8BIT      ; READ THE LAST BYTE IN
            CMP     CHKSUM      ; THIS SHOULD BE THE CHECK-SUM
            BEQ     MBELL       ; YES, CONGRATULATION!
            BNE     ERROR
;
            DS      6, $60      ;; Padding
;
            JMP     ERROR
;
            DS      10, $60     ;; Padding
;
;; Ring the terminal bell.
;
MBELL       LDA     #$87        ; CTRL-G
            JMP     MCOUT
;
;; Restore register contents ready to jump into code from the kernel monitor.
;
GETBRG      LDX     REGX
            LDY     REGY
            LDA     STATUS
            PHA
            LDA     ACC
            PLP
            RTS
;
;; Save register contents prior to entering the kernel monitor.
;
SAVE        STX     REGX        ; SAVE ALL REGISTERS
            STY     REGY
            STA     ACC
            PHP
            PLA
            STA     STATUS
            TSX
            STX     STACKP
            CLD
            RTS
;
;; Entry point for the kernel monitor.
;
MONENT      JMP     MON
            DS      9, $60      ; FILL SPACE
;
MON         JSR     MBELL       ; BEEP!
            NOP
MON1        LDA     #$AA        ; KERNEL PROMPT SIGN IS '*'
            STA     PROMPT
            JSR     MGETLZ      ; GET A LINE
            LDX     #0          ; CLEAR A REGISTER FIRST
            DEX
MON2        JSR     GETNUM      ; GET A NO. INTO REG2
            JSR     SEARCH      ; GET A NON-NUMBER; IS IT A COMMAND?
            BCC     MON         ; NO, INFORM THE USER
            STX     SAVEX       ; STORE X FIRST
            LDX     #$00        ; SUBROUTINES LIKE THIS
            CPY     #16         ; SPACE OR RETURN?
            BGE     READY       ; IF YES, SKIP
            LDA     #$00        ; FOR OTHERS, CLEAR FLAG
            STA     STOFLG
READY       JSR     GOSUB       ; GOTO THE ROUTINE
            LDX     SAVEX       ; RESUME X
            JMP     MON2
;
;; Search for a kernel monitor command in COMTBL.
;
SEARCH      LDY     #ADRTBL-COMTBL ; SET UP POINTER
SEARC1      CMP     COMTBL-1,Y
            BNE     SEARC2
            RTS
SEARC2      DEY                 ; UPDATE POINTER
            BNE     SEARC1      ; END OF TABLE?
            CLC                 ; SET UP CARRY FLAG
            RTS
;
            DS      11, $60     ;; Padding
;
;; Get a hexadecimal number from the kernel monitor's input line.
;
            ORIGIN  $FFA7
GETNUM      LDA     #$00
            STA     REG2L
            STA     REG2H
GETNU1      INX                 ; UPDATE POINTER
            LDA     KEYBUF,X    ; GET CHARACTER
            CMP     #$B0        ; IS IT A HEX NO.?
            BLT     NONNUM
            CMP     #$C7
            BGE     NONNUM
            CMP     #$BA
            BLT     HEXNUM
            SBC     #7          ; A SHOULD FOLLOW 9
            CMP     #$BA
            BLT     NONNUM      ; BE CAREFUL! ':' NOW BECOMES 3
HEXNUM      LDY     #4          ; SET UP COUNTER
            EOR     #$B0        ; TICK OUT THE HIGH BITS
            ASL                 ; SHIFT THIS NUMBER INTO REGISTER 2
            ASL                 ;; Move the nibble up the high bits
            ASL
            ASL
NUMSHF      ASL                 ;; Rotate the bits of the nibble into REG2
            ROL     REG2L
            ROL     REG2H
            DEY                 ; SHIFT FINISHED?
            BNE     NUMSHF      ; NO, CONTINUE
            BEQ     GETNU1      ; YES, GO FOR THE NEXT
NONNUM      RTS
;
;; Jump to a specific kernel monitor command handler.
;
GOSUB       DEY                 ; MODIFY POINTER
            TYA
            ASL
            TAY
            LDA     ADRTBL+1,Y  ; GET ROUTINE ADDRESS
            PHA
            LDA     ADRTBL,Y
            PHA
            LDY     #0
            RTS                 ; GOTO THE ROUTINE
;
            DS      21, $60     ;; Padding
;
; INTERRUPT VECTORS
;
            ORIGIN  $FFFA
            DW      NMIADR
            DW      RESET
            DW      IRQBRK

            END
