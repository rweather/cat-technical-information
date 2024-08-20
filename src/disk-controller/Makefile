
VASM = vasm6502_oldstyle

all: boot0.bin

boot0.bin: C600.s
	$(VASM) -quiet -dotdir -Fbin -L C600.lst -o boot0.bin C600.s

clean:
	rm -f boot0.bin C600.lst

dump:	boot0.bin
	hexdump -C boot0.bin
