
VASM = vasm6502_oldstyle
VASM_OPTS = -quiet -dotdir -Fbin
PYTHON = python3

all: loader.bin autoboot.bin hello.bin hello2.bin basload.bin moire.bin

loader.bin: loader.s
	$(VASM) $(VASM_OPTS) -L loader.lst -o loader.bin loader.s

autoboot.bin: loader.s
	$(VASM) $(VASM_OPTS) -DAUTOBOOT -L autoboot.lst -o autoboot.bin loader.s

hello.bin: hello.s
	$(VASM) $(VASM_OPTS) -o hello.bin hello.s

hello2.bin: hello2.s loader.bin
	$(VASM) $(VASM_OPTS) -o hello2.tmp hello2.s
	$(PYTHON) build-rom.py hello2.bin 0300 hello2.tmp loader.bin

basload.bin: basload.s
	$(VASM) $(VASM_OPTS) -L basload.lst -o basload.bin basload.s

moire.bin: moire.bas basload.bin
	$(PYTHON) build-basic-rom.py moire.bin moire.bas basload.bin

clean:
	rm -f loader.bin loader.lst
	rm -f autoboot.bin autoboot.lst
	rm -f basload.bin basload.lst
	rm -f hello.bin hello2.bin hello2.tmp
