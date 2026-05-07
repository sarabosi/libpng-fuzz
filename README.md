# libpng Fuzzing Lab

Coverage-guided fuzzing of libpng 1.2.56 using AFL++.

## Structure

- `src/` - fuzzing harness source (`harness.c`, `harness_persistent.c`)
- `patches/` - patches applied to libpng (CRC removal)
- `seeds/` - seed corpus of small valid PNGs
- `Dockerfile` - reproducible fuzzing environment
- `Makefile` - `build`, `fuzz`, `fuzz-qemu`, `clean` targets

## Usage

The Makefile exposes the following targets:

- `make build` — build the Docker image
- `make fuzz` — run the instrumented AFL++ campaign
- `make fuzz-qemu` — run the QEMU-mode AFL++ campaign
- `make clean` — remove build artifacts

See Makefile.

## Target

This project fuzzes libpng version 1.2.56, which contains known pre-fix vulnerabilities including CVE-2016-10087 (a NULL-pointer dereference in the `png_set_text_2` function). Using an older version with documented bugs lets us verify the fuzzing setup by rediscovering real historical issues.

A patch is applied to libpng to disable CRC-32 checksum validation. Without this, every fuzzer-mutated PNG chunk would fail the checksum check and be rejected before reaching the parsing code we actually want to test. The patch is sourced from the AFL++ project at `utils/libpng_no_checksum/`.
