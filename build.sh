#!/usr/bin/sh

echo "building Elite DX:"
echo

echo "* building loader - stage 0:"
echo "- compiling 'loader_stage0.asm'..."
./bin/cc65/bin/ca65 -t c64 -g -o build/loader_stage0.o \
    src/loader_stage0.asm

echo "- linking 'firebird.prg'..."
./bin/cc65/bin/ld65 -C c64-asm.cfg \
    --start-addr \$02A7 -o bin/firebird.prg \
    build/loader_stage0.o \
    c64.lib

echo
echo "* building loader - stage 1:"
echo "- compiling 'loader_stage1.asm'..."
./bin/cc65/bin/ca65 -t c64 -g -o build/loader_stage1.o \
    src/loader_stage1.asm

echo "- linking 'gma1.prg'..."
./bin/cc65/bin/ld65 -C c64-asm.cfg \
    --start-addr \$0334 -o bin/gma1.prg \
    build/loader_stage1.o \
    c64.lib

echo
echo "complete."
exit 0