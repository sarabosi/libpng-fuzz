# ── Configuration ────────────────────────────────────────────────────────────
TARGET      := harness
SRC         := src/harness.c
SRC_PERSIST := src/harness_persistent.c
LIBPNG_INC  := /usr/local/include
LIBPNG_LIB  := /usr/local/lib
LIBS        := -lpng12 -lz -lm

LIBPNG_INC_ASAN := /usr/local/asan/include
LIBPNG_LIB_ASAN := /usr/local/asan/lib
        

CORPUS_DIR  := seeds
OUTPUT_DIR  := findings
DICT        := dictionaries/png.dict

AFL_FUZZ    := afl-fuzz
# Note: -o is intentionally omitted here; each fuzz target supplies its own
# output directory to avoid the "multiple -o options" error.
AFL_FLAGS   := -i $(CORPUS_DIR) -x $(DICT)

# ── Compilers ─────────────────────────────────────────────────────────────────
CC_WHITE    := afl-clang-fast		# instrumented — white box
CC_BLACK    := clang -DFUZZING_AFL	# plain binary — black box (QEMU mode)

CFLAGS      := -I$(LIBPNG_INC) -fsanitize=address,undefined -g
LDFLAGS     := -L$(LIBPNG_LIB) $(LIBS)

# ── Build targets ─────────────────────────────────────────────────────────────
.PHONY: all white-box black-box persistent fuzz fuzz-qemu fuzz-persistent clean help

all: white-box black-box persistent

white-box: $(SRC)
	AFL_LLVM_LAF_ALL=1 $(CC_WHITE) -fsanitize=fuzzer \
		-I$(LIBPNG_INC_ASAN) -fsanitize=address,undefined -g \
		-o $(TARGET)-white $< \
		-L$(LIBPNG_LIB_ASAN) $(LIBS) -Wl,-rpath,$(LIBPNG_LIB_ASAN)
	@echo "[+] White-box binary ready: $(TARGET)-white"

black-box: $(SRC)
	$(CC_BLACK) \
		-I$(LIBPNG_INC) -fsanitize=address,undefined -g \
		-o $(TARGET)-black $< \
		-L$(LIBPNG_LIB) $(LIBS)
	@echo "[+] Black-box binary ready: $(TARGET)-black"

## persistent — compile the persistent-mode binary (AFL++ stdin loop)
persistent: $(SRC_PERSIST)
	AFL_LLVM_LAF_ALL=1 $(CC_WHITE) \
		-I$(LIBPNG_INC_ASAN) -fsanitize=address,undefined -g \
		-o $(TARGET)-persistent $< \
		-L$(LIBPNG_LIB_ASAN) $(LIBS) -Wl,-rpath,$(LIBPNG_LIB_ASAN)
	@echo "[+] Persistent-mode binary ready: $(TARGET)-persistent"

# ── Fuzzing targets ───────────────────────────────────────────────────────────

## fuzz             — run AFL++ on the instrumented binary (white box)
fuzz: white-box
	@mkdir -p $(CORPUS_DIR) $(OUTPUT_DIR)
	$(AFL_FUZZ) $(AFL_FLAGS) -o $(OUTPUT_DIR) -- ./$(TARGET)-white @@

## fuzz-qemu        — run AFL++ in QEMU mode on the plain binary (black box)
fuzz-qemu: black-box
	@mkdir -p $(CORPUS_DIR) $(OUTPUT_DIR)-qemu
	$(AFL_FUZZ) -Q $(AFL_FLAGS) -o $(OUTPUT_DIR)-qemu -- ./$(TARGET)-black @@

## fuzz-persistent  — run AFL++ with persistent mode (stdin, no @@ needed)
fuzz-persistent: persistent
	@mkdir -p $(CORPUS_DIR) $(OUTPUT_DIR)-persistent
	$(AFL_FUZZ) $(AFL_FLAGS) -o $(OUTPUT_DIR)-persistent -- ./$(TARGET)-persistent

# ── Housekeeping ──────────────────────────────────────────────────────────────

## clean  — remove compiled binaries and fuzzer output
clean:
	rm -f $(TARGET)-white $(TARGET)-black $(TARGET)-persistent
	rm -rf $(OUTPUT_DIR)
	rm -rf $(OUTPUT_DIR)-qemu
	rm -rf $(OUTPUT_DIR)-persistent
	@echo "[+] Cleaned"

## help   — show available targets
help:
	@echo ""
	@echo "  make white-box          compile with AFL++ instrumentation"
	@echo "  make black-box          compile as plain binary (QEMU mode)"
	@echo "  make persistent         compile persistent-mode binary"
	@echo "  make all                build all three (default)"
	@echo "  make fuzz               fuzz the white-box binary"
	@echo "  make fuzz-qemu          fuzz the black-box binary via QEMU"
	@echo "  make fuzz-persistent    fuzz with persistent mode (fastest)"
	@echo "  make clean              remove binaries and fuzzer output"
	@echo ""
