#!/usr/bin/python
#
# Usage: build-basic-rom.py output.bin program.bas basload.bin
#
#   output.bin  Output binary file to generate
#   program.bas BASIC source text to load.
#   basload.bin Binary file for the BASIC loader stub.
#

import sys
import struct

if len(sys.argv) < 4:
    print("Usage: build-basic-rom.py output.bin program.bas basload.bin")
    sys.exit(1)

output_file = sys.argv[1]
program_file = sys.argv[2]
loader_file = sys.argv[3]

# Load the binaries.
with open(program_file, 'rb') as file:
    program = file.read()
with open(loader_file, 'rb') as file:
    loader = file.read()

# Check the size of the binaries.
max_size = 32768 - 128
if len(loader) != 128:
    print("Incorrect size for %s, should be 128" % loader_file)
    sys.exit(1)
if len(program) > (max_size - 16):
    print("BASIC program file %s is too large" % program_file)
    sys.exit(1)

# Write the output file.
with open(output_file, 'wb') as file:
    file.write(struct.pack('B', 0x4E))  # N
    file.write(struct.pack('B', 0x45))  # E
    file.write(struct.pack('B', 0x57))  # W
    file.write(struct.pack('B', 0x0D))  # CR
    size = 4
    for b in program:
        if b == 10:
            # Convert LF into CR.
            b = 13
        file.write(struct.pack('B', b))
        size += 1
    file.write(struct.pack('B', 0x52))  # R
    file.write(struct.pack('B', 0x55))  # U
    file.write(struct.pack('B', 0x4E))  # N
    file.write(struct.pack('B', 0x0D))  # CR
    size += 4
    while size < max_size:
        file.write(struct.pack('B', 0))
        size += 1
    file.write(loader)
