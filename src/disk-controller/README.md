
This directory contains a dump of the ROM in the Cat disk controller,
which is located at $C600 in memory when the disk controller cartridge
is plugged into the Cat.

* `C600.hex` - Hexadecimal dump of the ROM contents.
* `C600.bin` - Binary dump of the ROM contents.
* `C600.s` - Annotated assembly code for the ROM.
* `C600.lst` - Assembly listing for the ROM, generated from `C600.s`.

The `C600.s` file is designed to be assembled using
[vasm](http://sun.hasenbraten.de/vasm/).

Note: This ROM image is for the earlier version of the Cat disk
controller.  VTech got in trouble with Apple's lawyers because it was
too similar to the Apple II disk controller.

A later version of the Cat disk controller used a gate array and
different software.  Information on the later version can be found
[here](https://github.com/RedskullDC/Laser_3000_DSE_Cat/tree/main/Roms/Disk_Controller).
