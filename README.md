# CS-412 Group 10 libpng Fuzzing Lab

Coverage-guided fuzzing of libpng 1.4.8 using AFL++.

## Structure

- `Dockerfile` - environment with AFL++, clang, gcc and gdb
- `src/harness.c` - AFL++ style harness - reads pngs input and calls the libpng library
- `src/harness_persistent.c` - AFL++ style harness - in persistend mode
- `patches/` - AFL++ libpng CRC patch: AFLplusplus/utils/libpng_no_checksum/
- `seeds/` - minimized (afl-cmin) seed corpus copied from pngSuite : Copyright (c) Willem van Schaik willem@schaik.com Calgary, April 2011)
- `dictionaries/png.dict` - AFL++ PNG dictionary: AFLplusplus/dictionaries/png.dict
- `Makefile` - `build`, `fuzz`, `fuzz-qemu`, `fuzz-persistent`, `clean` targets

## Setup: Build Stuff inside Docker

**For macOS/Linux:**
```bash
docker build -t afl-libpng-g10 .
docker run --rm -it -v "$PWD":/work afl-libpng-g10
cd /work
make build
```

**For Windows (Git Bash):**
```bash
docker build -t afl-libpng-g10 .
docker run --rm -it -v "$(pwd -W)":/work afl-libpng-g10
cd /work
make build
```

## Usage

- `make build` — build all three binary for AFL++ campaign 
- `make fuzz` — run the instrumented AFL++ campaign
- `make fuzz-qemu` — run the QEMU-mode AFL++ campaign
- `make fuzz-persistent` — run the persistent-mode AFL++ campaign
- `make clean` — remove build and findings

## Target

This project fuzzes libpng 1.4.8 

A patch is applied to disable CRC-32 checksum validation so the fuzzer can reach chunk parsing code without every mutation being rejected at the checksum check. The patch is in `patches/`.

## What has been done for the campaign

- run `make fuzz` for at least 30 min
- run `make fuzz-qemu` for at least 30 min
- run `make fuzz-persistent` for the Q8 performance comparison
- after each campaign run `afl-plot findings/default/ plot_output/` (same for qemu and persistent) to generate the graphs
- if there are crashes in `findings/default/crashes/`: minimize one with `afl-tmin` (AFL++ crash minimizer), run it with ASan to get the stack trace 




