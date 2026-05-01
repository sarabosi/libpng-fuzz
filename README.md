# libpng Fuzzing Lab

Coverage-guided fuzzing of libpng 1.4.19 using AFL++.

## Structure

- `src/` - fuzzing harness source (`harness.c`, `harness_persistent.c`)
- `patches/` - patches applied to libpng (CRC removal)
- `seeds/` - seed corpus
- `Dockerfile` - reproducible fuzzing environment
- `Makefile` - `build`, `fuzz`, `fuzz-qemu`, `fuzz-persistent`, `clean` targets

## Usage

- `make build` — build the Docker image
- `make fuzz` — run the instrumented AFL++ campaign
- `make fuzz-qemu` — run the QEMU-mode AFL++ campaign
- `make fuzz-persistent` — run the persistent-mode AFL++ campaign
- `make clean` — remove build artifacts

## Target

This project fuzzes libpng 1.4.19, which is still vulnerable to CVE-2016-10087 (a NULL-pointer dereference in `png_set_text_2`, fixed in 1.4.20). The harness targets the text chunk write path via `png_set_text`.

A patch is applied to disable CRC-32 checksum validation so the fuzzer can reach chunk parsing code without every mutation being rejected at the checksum check. The patch is in `patches/`.

## TODO

- run `make fuzz` for at least 30 min
- run `make fuzz-qemu` for at least 30 min
- run `make fuzz-persistent` for the Q8 performance comparison
- after each campaign run `afl-plot findings/default/ plot_output/` (same for qemu and persistent) to generate the graphs
- if there are crashes in `findings/default/crashes/`: minimize one with `afl-tmin` (AFL++ crash minimizer), run it with ASan to get the stack trace
- if no crashes: inject a synthetic bug, show AFL++ finds it
