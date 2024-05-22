#!/bin/bash

mkdir BUILD
yosys -l BUILD/yosys.log -p 'synth_ice40 -relut -top top -json BUILD/build.json' icestick.v
nextpnr-ice40 --force --hx1k --json BUILD/build.json --pcf icestick.pcf --asc BUILD/build.asc --package tq144 --freq 12
icepack BUILD/build.asc BUILD/build.bin
iceprog BUILD/build.bin
