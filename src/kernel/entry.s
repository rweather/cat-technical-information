
;; Useful entry points into the kernel monitor ROM's to
;; access the kernel routines from other ROM's and user code.

KEYIN       EQU     $C84D       ;; Read from the keyboard
VIDOUT      EQU     $C9F9       ;; Output a character to the screen
ENCUR       EQU     $CBA0       ;; Enable the cursor
DECUR       EQU     $CBDF       ;; Disable the cursor
;;
TEXT40      EQU     $F806       ;; Switch to 40-column text mode
TEXT80      EQU     $F809       ;; Switch to 80-column text mode
AUDOUT      EQU     $F80C       ;; Send data to the 76489 sound generator
;;
PRNYX       EQU     $F940       ;; Print Y and X as four hexadecimal digits
PRNAX       EQU     $F941       ;; Print A and X as four hexadecimal digits
PRNX        EQU     $F944       ;; Print X as two hexadecimal digits
PRNSPC      EQU     $F948       ;; Print three spaces
;;
RESET       EQU     $FA62       ;; Default reset handler
;;
MPREAD      EQU     $FB1E       ;; Get the position of the paddle
FADRCAL     EQU     $FBC1       ;; Calculate text display base address (line=A)
FRAM0I      EQU     $FBC7       ;; Bring RAM0 into BANK2 for text buffer access
FRAM0U      EQU     $FBCD       ;; Restore previous BANK2 configuration
FBELL       EQU     $FBD9       ;; Ring the terminal bell
FSTORAD     EQU     $FBF0       ;; Store ASCII character to screen and advance
FADVANC     EQU     $FBF4       ;; Move the cursor right
;;
FBS         EQU     $FC10       ;; Move the cursor left
FUP         EQU     $FC1A       ;; Move the cursor up
MVTAB       EQU     $FC22       ;; Calculate base address for current line
FCLREOP     EQU     $FC42       ;; Clear to the end of the screen
F8HOME      EQU     $FC58       ;; Clear the screen and move cursor to top-left
FCRLF       EQU     $FC62       ;; Do a CRLF sequence
FLF         EQU     $FC66       ;; Move the cursor down
FCLREOL     EQU     $FC9C       ;; Clear to the end of the current line
MWAIT       EQU     $FCA8       ;; Wait timer
;;
MRDKEY      EQU     $FD0C       ;; Read a key from the current input device
MINKEY      EQU     $FD1B       ;; Read a key from the actual keyboard
MRDCHR      EQU     $FD35       ;; Read a character and handle escapes
MGETLZ      EQU     $FD67       ;; Print CRLF and then prompt for a line
MGETLN      EQU     $FD6A       ;; Prompt for and get a line
CROUT       EQU     $FD8E       ;; Output a carriage return to the output device
MPRBYTE     EQU     $FDDA       ;; Print a hex byte in A
MPRNHEX     EQU     $FDE3       ;; Print a hex nibble in A
C800IN      EQU     $FDE6       ;; Bring in the 80 column ROM at $C800
MCOUT       EQU     $FDED       ;; Output a char to the current output device
MCOUT1      EQU     $FDF0       ;; Output a character to the screen
;;
MOVE        EQU     $FE2C       ;; Move memory
SETINV      EQU     $FE80       ;; Set inverse text mode
SETNOR      EQU     $FE84       ;; Set normal text mode
MTSAVE      EQU     $FECD       ;; Save memory contents to cassette tape
MTLOAD      EQU     $FEFD       ;; Load memory contents from cassette tape
;;
ERROR       EQU     $FF2D       ;; Print "ERROR" to the current output device
MBELL       EQU     $FF3A       ;; Beep the terminal bell
GETBRG      EQU     $FF3F       ;; Restore the CPU registers from the zero page
SAVE        EQU     $FF4A       ;; Save the CPU registers to the zero page
MON         EQU     $FF59       ;; Beep and enter the kernel monitor
MON1        EQU     $FF69       ;; Enter the kernel monitor directly (no beep)
MBELL1      EQU     $FFD9       ;; Beep the terminal bell (alt entry point)

DSKCTL1     EQU     $C600       ;; Entry point for the first disk controller
DSKCTL2     EQU     $C500       ;; Entry point for the second disk controller
