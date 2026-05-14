.PHONY: all build fuzz fuzz-nosan fuzz-qemu fuzz-persistent clean help

ASAN_PATH = /usr/local/asan
VANILLA_PATH = /usr/local/vanilla
NOSAN_PATH = /usr/local/nosan

# Flags common to both harnesses
COMMON_FLAGS = -DPNG_iTXt_SUPPORTED -g -O2

# Default target
all: help

help:
	@echo "libpng fuzzing lab — available targets:"
	@echo "  build            Build all three binaries for AFL++ campaign"
	@echo "  build-nosan      Build AFL++ instrumented binary without ASan for Q8"
	@echo "  fuzz             Run AFL++ with non-persistent harness (file argument mode)"
	@echo "  fuzz-nosan       Run AFL++ no-sanitizer fork-mode campaign for Q8"
	@echo "  fuzz-qemu        Run AFL++ in QEMU black-box mode"
	@echo "  fuzz-persistent  Run AFL++ with persistent-mode harness (fastest)"
	@echo "  clean            Remove build and findings"

build:
	mkdir -p bin

	# Non-persistent harness (using ASan instrumented lib)
	afl-clang-fast src/harness.c \
		-I$(ASAN_PATH)/include \
		$(ASAN_PATH)/lib/libpng14.a -lz -lm \
		-fsanitize=address $(COMMON_FLAGS) \
		-o bin/png_fuzz

	# Persistent harness (using ASan instrumented lib)
	afl-clang-fast src/harness_persistent.c \
		-I$(ASAN_PATH)/include \
		$(ASAN_PATH)/lib/libpng14.a -lz -lm \
		-fsanitize=address $(COMMON_FLAGS) \
		-o bin/png_fuzz_persistent

	# QEMU harness (using Vanilla/Uninstrumented lib)
	gcc src/harness.c \
		-I$(VANILLA_PATH)/include \
		$(VANILLA_PATH)/lib/libpng14.a -lz -lm \
		$(COMMON_FLAGS) \
		-o bin/png_fuzz_qemu

build-nosan:
	mkdir -p bin

	# Non-persistent harness without ASan, but still AFL++ instrumented
	afl-clang-fast src/harness.c \
		-I$(NOSAN_PATH)/include \
		$(NOSAN_PATH)/lib/libpng14.a -lz -lm \
		$(COMMON_FLAGS) \
		-o bin/png_fuzz_nosan

fuzz: build
	afl-fuzz -i seeds -o findings \
		-x dictionaries/png.dict \
		-- bin/png_fuzz @@

fuzz-qemu: build
	# Note: -Q is for QEMU mode
	afl-fuzz -Q -i seeds -o findings-qemu \
		-x dictionaries/png.dict \
		-- bin/png_fuzz_qemu @@

fuzz-persistent: build
	afl-fuzz -i seeds -o findings-persistent \
		-x dictionaries/png.dict \
		-- bin/png_fuzz_persistent

fuzz-nosan: build-nosan
	afl-fuzz -i seeds -o findings-nosan \
		-x dictionaries/png.dict \
		-- bin/png_fuzz_nosan @@

clean:
	rm -rf bin findings findings-qemu findings-persistent findings-nosan