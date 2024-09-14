#!/usr/bin/python
#
# Usage: build-rom.py output.bin ???? program.bin loader.bin
#
#   output.bin  Output binary file to generate
#   ????        Hexadecimal address to load the program to.
#   program.bin Binary file for the program to load.
#   loader.bin  Binary file for the loader stub.
#

import sys
import struct

if len(sys.argv) < 5:
    print("Usage: build-rom.py output.bin ???? program.bin loader.bin")
    sys.exit(1)

output_file = sys.argv[1]
address = int(sys.argv[2], 16)
program_file = sys.argv[3]
loader_file = sys.argv[4]

# Load the binaries.
with open(program_file, 'rb') as file:
    program = file.read()
with open(loader_file, 'rb') as file:
    loader = file.read()

# Check the size of the binaries.
max_size = 32768 - 128
if len(loader) != 124:
    print("Incorrect size for %s, should be 124" % loader_file)
    sys.exit(1)
if len(program) > max_size:
    print("Program file %s is too large" % program_file)
    sys.exit(1)

# Determine the size of the program which should be a multiple of 128 minus 1.
# Round up the size if necessary.
size = len(program)
pad = size
if (size % 128) != 0:
    size += 128 - (size % 128)
size -= 1

# Write the output file.
with open(output_file, 'wb') as file:
    file.write(program)
    while pad < max_size:
        file.write(struct.pack('B', 0xFF))
        pad += 1
    file.write(loader)
    file.write(struct.pack('<HH', address, size))
