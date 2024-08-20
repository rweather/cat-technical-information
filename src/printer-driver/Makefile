
VASM = vasm6502_oldstyle

all: printC100.bin printC800.bin

printC100.bin: C100.s common.s
	$(VASM) -quiet -dotdir -Fbin -L C100.lst -o printC100.bin C100.s

printC800.bin: C800.s common.s
	$(VASM) -quiet -dotdir -Fbin -L C800.lst -o printC800.bin C800.s

clean:
	rm -f printC100.bin printC800.bin
