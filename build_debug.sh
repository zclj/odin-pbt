#!/bin/bash

mkdir -p ./target/debug

odin build pbt -out:./target/debug/pbt_debug.bin -strict-style -debug
