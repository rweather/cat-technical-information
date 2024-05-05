
;; Useful locations in RAM.

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
; ZERO PAGE EQUATES
;
WNDLFT      EQU     $20     ;; Left-most column of the text window (0-79)
WNDWTH      EQU     $21     ;; Width of the text window (1-80)
WNDTOP      EQU     $22     ;; Top-most line of the text window (0-22)
WNDBTM      EQU     $23     ;; Bottom-most line of the text window (1-24)
CHORZ       EQU     $24     ;; Horizontal offset of the cursor (0-WNDWTH-1)
CVERT       EQU     $25     ;; Veritical offset of the cursor (0-WNDBTM-1)
FKEYPL      EQU     $26     ;; Function key definition pointer (low)
FKEYPH      EQU     $27     ;; Function key definition pointer (high)
SBASL       EQU     $28     ;; Screen base address 1 (low)
SBASH       EQU     $29     ;; Screen base address 1 (high)
SBAS2L      EQU     $2A     ;; Screen base address 2 (low)
SBAS2H      EQU     $2B     ;; Screen base address 2 (high)
CHKSUM      EQU     $2E
OPCODL      EQU     $2F     ;; Opcode length in the kernel monitor
LASTBI      EQU     $2F
STOFLG      EQU     $31     ;; Flag for the kernel doing a store command
INVFLG      EQU     $32     ;; Normal=$FF, Inverse=$3F, Blinking=$7F
PROMPT      EQU     $33     ;; Prompt character with MSB set ($DD = ']')
SAVEX       EQU     $34
SAVEY       EQU     $35
OUTSWL      EQU     $36     ;; Address of the character output routine (low)
OUTSWH      EQU     $37     ;; Address of the character output routine (high)
INSWL       EQU     $38     ;; Address of the character input routine (low)
INSWH       EQU     $39     ;; Address of the character input routine (high)
PCL         EQU     $3A     ;; Saved PC register for BREAK (low)
PCH         EQU     $3B     ;; Saved PC register for BREAK (high)
REG1L       EQU     $3C     ;; First address for a kernel operation (low)
REG1H       EQU     $3D     ;; First address for a kernel operation (high)
REG2L       EQU     $3E     ;; Second address for a kernel operation (low)
REG2H       EQU     $3F     ;; Second address for a kernel operation (high)
REG4L       EQU     $42     ;; Fourth address for a kernel operation (low)
REG4H       EQU     $43     ;; Fourth address for a kernel operation (high)
ACC         EQU     $45     ;; Saved A register for BREAK
REGX        EQU     $46     ;; Saved X register for BREAK
REGY        EQU     $47     ;; Saved Y register for BREAK
STATUS      EQU     $48     ;; Saved P register for BREAK
STACKP      EQU     $49     ;; Saved SP register for BREAK
RNDNOL      EQU     $4E     ;; Random number seed (low)
RNDNOH      EQU     $4F     ;; Random number seed (high)
TXTABL      EQU     $67
TXTABH      EQU     $68
PBANK1      EQU     $C5     ;; Page that is selected for memory bank 1 (0-15)
PBANK2      EQU     $C6     ;; Page that is selected for memory bank 2 (0-15)
PBANK3      EQU     $C7     ;; Page that is selected for memory bank 3 (0-15)
PBANK4      EQU     $C8     ;; Page that is selected for memory bank 4 (0-15)
;
; SLOT 0 EQUATES
;
SAVE1       EQU     $778    ;; Saves window width in 'TUGGLE' subroutine
;
; SLOT 3 EQUATES
;
TEMPY       EQU     $4FB
TXTMOD      EQU     $57B    ;; $04 for 40-column text, $10 for 80-column text
TEMPX       EQU     $5FB
BYTE        EQU     $67B    ;; Byte read by KEYIN or output character
TEMPA       EQU     $6FB    ;; Character under the cursor position
POWER       EQU     $77B
CHWHO       EQU     $47B    ;; Horizontal position for output with "IO"
CVWHO       EQU     $7FB    ;; Vertical position for output with "IO"
;
; OTHER RAM LOC. EQUATES
;
STACK       EQU     $100    ;; Stack
KEYBUF      EQU     $200    ;; Keyboard buffer
BRKVER      EQU     $3F0    ;; Address of BRK handler
RESTVR      EQU     $3F2    ;; Address of the soft RESET handler
PWRIND      EQU     $3F4    ;; Power-on indicator to detect hard-vs-soft RESET
USRADR      EQU     $3F8
NMIADR      EQU     $3FB    ;; NMI interrupts jump to here
IRQVER      EQU     $3FE    ;; Address of the IRQ handler
KEYFLG      EQU     $4800
