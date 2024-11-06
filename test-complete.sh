#!/bin/bash

mkdir -p ./target/tests

odin test tests -out:./target/tests/pbt_tests.bin -strict-style -vet -all-packages # -debug
