# libpng Fuzzing Lab

Coverage-guided fuzzing of libpng 1.2.56 using AFL++.

## Structure

- `src/` - fuzzing harness source (`harness.c`, `harness_persistent.c`)
- `patches/` - patches applied to libpng (CRC removal)
- `seeds/` - seed corpus of real PNG files covering different color types and bit depths
- `dictionaries/` - AFL++ dictionary with PNG chunk tokens
- `Dockerfile` - reproducible fuzzing environment
- `Makefile` - `build`, `fuzz`, `fuzz-qemu`, `fuzz-persistent`, `clean` targets

## Usage

- `make build` — build the Docker image (compiles all three harnesses inside)
- `make fuzz` — run the instrumented AFL++ campaign
- `make fuzz-qemu` — run the QEMU-mode AFL++ campaign
- `make fuzz-persistent` — run the persistent-mode AFL++ campaign (fastest, for Q8)
- `make clean` — remove campaign findings and plot output

Findings in `findings/`, `findings-qemu/`, `findings-persistent/` on local machine. Campaigns can be stopped and resumed safely as `AFL_AUTORESUME=1` is set automatically.

After a campaign, generate plots with:
```
afl-plot findings/default/ plot_output/
afl-plot findings-qemu/default/ plot_output_qemu/
afl-plot findings-persistent/default/ plot_output_persistent/
```

## Harness

`harness.c` targets the PNG decode path: it feeds the fuzzer input directly into libpng's read pipeline (`png_read_info`, `png_read_image`, `png_read_end`) using an in-memory source instead of a file. Several transforms are enabled to push AFL++ into more decoder code paths (palette expansion, alpha, 16-to-8-bit stripping). Text and ancillary chunks are explicitly queried after decoding to exercise the tEXt/zTXt/iTXt parsers.

`harness_persistent.c` runs the same decode pipeline in AFL++ persistent mode, looping 10000 times per process instead of forking on every input.

## Target

This project fuzzes libpng 1.2.56, which is vulnerable to CVE-2016-10087 (a NULL-pointer dereference in `png_set_text_2`, fixed in 1.2.57). 

A CRC patch is applied to libpng before building so the fuzzer can mutate chunk data without every input being rejected at the checksum check. The patch is in `patches/`.

## TODO

- run `make fuzz` for at least 30 min
- run `make fuzz-qemu` for at least 30 min
- run `make fuzz-persistent` for the Q8 performance comparison
- run `afl-plot` on each findings directory to generate the graphs
- if there are crashes in `findings/default/crashes/`: pick one, minimize it with `afl-tmin` (AFL++ crash minimizer), run it to get the stack trace
- if no crashes: inject a synthetic bug, show AFL++ finds it
- write the report (Q1–Q8)
