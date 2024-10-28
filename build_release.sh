#!/bin/bash

mkdir -p ./target/release

odin build pbt -out:./target/release/pbt_release.bin -strict-style -no-bounds-check -o:speed
