
;; Useful definitions for I/O.

;***********************************************************************
;
;       SYSTEM KERNEL
;
;       (C) COPYRIGHT
;       1984 :
;       V.T.L.
;
;***********************************************************************
;
; I/O EQUATES
;
;; See Chapter 2 of the "CAT Technical Reference Manual", for a description
;; of the I/O map.  In particular, "Software Switches" and "Internal I/O".
;;
;; Software switches are activated by writing any value to the address.
;; Not all of these are used by the kernel code.  Provided for documentation
;; purposes to help understand how the switches actually work.
;
KEYBRD      EQU     $C000   ;; Read keyboard data
KEYSTR      EQU     $C010   ;; Clear keyboard strobe
BKDROP      EQU     $C008   ;; Set border colour to black
BKDROP1     EQU     $C009   ;; Set border colour to red
BKDROP2     EQU     $C00A   ;; Set border colour to green
BKDROP3     EQU     $C00B   ;; Set border colour to yellow
BKDROP4     EQU     $C00C   ;; Set border colour to blue
BKDROP5     EQU     $C00D   ;; Set border colour to magenta
BKDROP6     EQU     $C00E   ;; Set border colour to cyan
BKDROP7     EQU     $C00F   ;; Set border colour to white
BKGRND      EQU     $C018   ;; Set background colour to black
BKGRND1     EQU     $C019   ;; Set background colour to red
BKGRND2     EQU     $C01A   ;; Set background colour to green
BKGRND3     EQU     $C01B   ;; Set background colour to yellow
BKGRND4     EQU     $C01C   ;; Set background colour to blue
BKGRND5     EQU     $C01D   ;; Set background colour to magenta
BKGRND6     EQU     $C01E   ;; Set background colour to cyan
BKGRND7     EQU     $C01F   ;; Set background colour to white
TAPEOU      EQU     $C020   ;; Cassette output
TEXTCR      EQU     $C028   ;; Enable multi colour mode
TEXTCR1     EQU     $C029   ;; Set to single colour mode with red pixels
TEXTCR2     EQU     $C02A   ;; Set to single colour mode with green pixels
TEXTCR3     EQU     $C02B   ;; Set to single colour mode with yellow pixels
TEXTCR4     EQU     $C02C   ;; Set to single colour mode with blue pixels
TEXTCR5     EQU     $C02D   ;; Set to single colour mode with magenta pixels
TEXTCR6     EQU     $C02E   ;; Set to single colour mode with cyan pixels
TEXTCR7     EQU     $C02F   ;; Set to single colour mode with white pixels
SPEAKR      EQU     $C030   ;; Toggle speaker
VZTX40      EQU     $C04C   ;; Set to low resolution mode
VZGRGB      EQU     $C04D   ;; Set to RGB mode
VZGHGH      EQU     $C04E   ;; Set to high resolution mode
VZTX80      EQU     $C04F   ;; Set to 80-column mode
VZGRPH      EQU     $C050   ;; Set to graphics mode
VZTEXT      EQU     $C051   ;; Set to text mode
VZTEXT1     EQU     $C052   ;; Set to pure text or graphics mode
VZTEXT2     EQU     $C053   ;; Set to mixed text or graphics mode
VZPAG1      EQU     $C054   ;; Display primary graphics page
VZPAG2      EQU     $C055   ;; Display secondary graphics page
VZSELF      EQU     $C056   ;; Turn off emulation
VZEMUL      EQU     $C057   ;; Set emulation only
TAPEIN      EQU     $C060   ;; Cassette input
BINFLG0     EQU     $C061   ;; Binary flag 1 input
BINFLG1     EQU     $C062   ;; Binary flag 2 input
BINFLG2     EQU     $C063   ;; Binary flag 3 input
PADDL0      EQU     $C064   ;; Game paddle 1 input
PADDL1      EQU     $C065   ;; Game paddle 2 input
PADDL2      EQU     $C066   ;; Game paddle 3 input
PADDL3      EQU     $C067   ;; Game paddle 4 input
SONGEN      EQU     $C068   ;; Write data to 76489 sound generator
PDLRES      EQU     $C070   ;; Analog clear
SYSTEM      EQU     $C078
SBANK1      EQU     $C07C   ;; Select memory bank for memory window 0 (0-15)
SBANK2      EQU     $C07D   ;; Select memory bank for memory window 1 (0-15)
SBANK3      EQU     $C07E   ;; Select memory bank for memory window 2 (0-15)
SBANK4      EQU     $C07F   ;; Select memory bank for memory window 3 (0-15)
PRINTR      EQU     $C090   ;; Write data to printer
PRTACK      EQU     $C1C0   ;; Read printer acknowledge
PRTBSY      EQU     $C1C1   ;; Read printer busy
HORZSC      EQU     $C1C2   ;; Read horizontal blanking
VERTSC      EQU     $C1C3   ;; Read vertical blanking
LINFRQ      EQU     $C1C4   ;; Read 50/60Hz status
TWOMHZ      EQU     $C1C5   ;; Read high resolution switch (SWR1) status
ROMCLR      EQU     $CFFF   ;; Clear ROM bank switching
