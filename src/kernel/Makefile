
VASM = vasm6502_oldstyle

all: kernel.hex kernel.bin

kernel.hex: kernel.s
	$(VASM) -quiet -Fihex -i32hex -L kernel.lst -c02 -o kernel.hex kernel.s

kernel.bin: kernel.s
	$(VASM) -quiet -DNOBASIC -DEPROM -Fbin -c02 -o kernel.bin kernel.s

clean:
	rm -f kernel.hex kernel.bin kernel.lst

dump:	kernel.bin
	hexdump -C kernel.bin
