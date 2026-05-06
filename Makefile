# ── Configuration ────────────────────────────────────────────────────────────
TARGET      := harness
SRC         := src/harness.c
LIBPNG_INC  := /usr/local/include
LIBPNG_LIB  := /usr/local/lib
LIBS        := -lpng12 -lz -lm

LIBPNG_INC_ASAN := /usr/local/asan/include
LIBPNG_LIB_ASAN := /usr/local/asan/lib
        

CORPUS_DIR  := seeds
OUTPUT_DIR  := findings
DICT        := dictionaries/png.dict

AFL_FUZZ    := afl-fuzz
AFL_FLAGS   := -i $(CORPUS_DIR) -o $(OUTPUT_DIR) -x $(DICT)

# ── Compilers ─────────────────────────────────────────────────────────────────
CC_WHITE    := afl-clang-fast		# instrumented — white box
CC_BLACK    := clang -DFUZZING_AFL	# plain binary — black box (QEMU mode)

CFLAGS      := -I$(LIBPNG_INC) -fsanitize=address,undefined -g
LDFLAGS     := -L$(LIBPNG_LIB) $(LIBS)

# ── Build targets ─────────────────────────────────────────────────────────────
.PHONY: all white-box black-box fuzz fuzz-qemu clean help

all: white-box black-box
	
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

# ── Fuzzing targets ───────────────────────────────────────────────────────────

## fuzz       — run AFL++ on the instrumented binary (white box)
fuzz: white-box
	@mkdir -p $(CORPUS_DIR) $(OUTPUT_DIR)
	$(AFL_FUZZ) $(AFL_FLAGS) -- ./$(TARGET)-white @@

## fuzz-qemu  — run AFL++ in QEMU mode on the plain binary (black box)
fuzz-qemu: black-box
	@mkdir -p $(CORPUS_DIR) $(OUTPUT_DIR)-qemu
	$(AFL_FUZZ) -Q $(AFL_FLAGS) -- ./$(TARGET)-black @@

# ── Housekeeping ──────────────────────────────────────────────────────────────

## clean  — remove compiled binaries and fuzzer output
clean:
	rm -f $(TARGET)-white $(TARGET)-black
	rm -rf $(OUTPUT_DIR)
	rm -rf $(OUTPUT_DIR)-qemu
	@echo "[+] Cleaned"

## help   — show available targets
help:
	@echo ""
	@echo "  make white-box        compile with AFL++ instrumentation"
	@echo "  make black-box        compile as plain binary (QEMU mode)"
	@echo "  make all              build both (default)"
	@echo "  make fuzz             fuzz the white-box binary"
	@echo "  make fuzz-qemu        fuzz the black-box binary via QEMU"
	@echo "  make clean            remove binaries and fuzzer output"
	@echo ""
