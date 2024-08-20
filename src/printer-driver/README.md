
This directory contains a dump of the printer device ROM's in the Cat
which are located at $C100 and $C800 in memory.  The code at $C800
must be bank-switched in at runtime using the following sequence:

    STA $CFFF
    STA $C100

* `C100.hex` - Hexadecimal dump of the $C100 ROM contents.
* `C100.bin` - Binary dump of the $C100 ROM contents.
* `C100.s` - Annotated assembly code for the $C100 ROM.
* `C100.lst` - Assembly listing for the $C100 ROM, generated from `C100.s`.
* `C800.hex` - Hexadecimal dump of the $C800 ROM contents.
* `C800.bin` - Binary dump of the $C800 ROM contents.
* `C800.s` - Annotated assembly code for the $C800 ROM.
* `C800.lst` - Assembly listing for the $C800 ROM, generated from `C800.s`.

The `*.s` files are designed to be assembled using
[vasm](http://sun.hasenbraten.de/vasm/).
