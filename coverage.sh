#!/bin/bash

mkdir -p ./target/coverage

# Build examples with debug symbols and as an object file
odin build ./examples/basics/ -out:./target/coverage/basic.bin -debug
odin build ./examples/basics/ -out:./target/coverage/basic.o -build-mode:obj -debug

odin build ./examples/collections/ -out:./target/coverage/collections.bin -debug
odin build ./examples/collections/ -out:./target/coverage/collections.o -build-mode:obj -debug

# Clean old coverage report
rm -rf ./coverage

# Check coverage only on pbt package
kcov --include-path=./pbt/ ./coverage ./target/coverage/basic.bin
kcov --include-path=./pbt/ ./coverage ./target/coverage/collections.bin
