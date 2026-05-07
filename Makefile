# ── Configuration ────────────────────────────────────────────────────────────
IMAGE       := libpng-fuzz
CORPUS_DIR  := seeds
DICT        := dictionaries/png.dict
AFL_FLAGS   := -i $(CORPUS_DIR) -x $(DICT)

# ── Build targets ─────────────────────────────────────────────────────────────
.PHONY: all build fuzz fuzz-qemu fuzz-persistent fuzz-persistent-noasan clean help

all: build

build:
	docker build -t $(IMAGE) .

# ── Fuzzing targets ───────────────────────────────────────────────────────────

fuzz: build
	@mkdir -p findings
	docker run --rm -it \
		-e AFL_AUTORESUME=1 \
		-e AFL_SKIP_CPUFREQ=1 \
		-v "$(CURDIR)/seeds:/work/seeds" \
		-v "$(CURDIR)/dictionaries:/work/dictionaries" \
		-v "$(CURDIR)/findings:/work/findings" \
		$(IMAGE) \
		afl-fuzz $(AFL_FLAGS) -o findings -- ./harness-white @@

fuzz-qemu: build
	@mkdir -p findings-qemu
	docker run --rm -it \
		-e AFL_AUTORESUME=1 \
		-e AFL_SKIP_CPUFREQ=1 \
		-v "$(CURDIR)/seeds:/work/seeds" \
		-v "$(CURDIR)/dictionaries:/work/dictionaries" \
		-v "$(CURDIR)/findings-qemu:/work/findings-qemu" \
		$(IMAGE) \
		afl-fuzz -Q $(AFL_FLAGS) -o findings-qemu -- ./harness-black @@

fuzz-persistent: build
	@mkdir -p findings-persistent
	docker run --rm -it \
		-e AFL_AUTORESUME=1 \
		-e AFL_SKIP_CPUFREQ=1 \
		-v "$(CURDIR)/seeds:/work/seeds" \
		-v "$(CURDIR)/dictionaries:/work/dictionaries" \
		-v "$(CURDIR)/findings-persistent:/work/findings-persistent" \
		$(IMAGE) \
		afl-fuzz $(AFL_FLAGS) -o findings-persistent -- ./harness-persistent

fuzz-persistent-noasan: build
	@mkdir -p findings-persistent-noasan
	docker run --rm -it \
		-e AFL_AUTORESUME=1 \
		-e AFL_SKIP_CPUFREQ=1 \
		-v "$(CURDIR)/seeds:/work/seeds" \
		-v "$(CURDIR)/dictionaries:/work/dictionaries" \
		-v "$(CURDIR)/findings-persistent-noasan:/work/findings-persistent-noasan" \
		$(IMAGE) \
		afl-fuzz $(AFL_FLAGS) -o findings-persistent-noasan -- ./harness-persistent-noasan

# ── Housekeeping ──────────────────────────────────────────────────────────────

clean:
	rm -rf findings findings-qemu findings-persistent findings-persistent-noasan
	rm -rf plot_output plot_output_qemu plot_output_persistent

help:
	@echo ""
	@echo "  make build              build the Docker image"
	@echo "  make fuzz               run the instrumented AFL++ campaign"
	@echo "  make fuzz-qemu          run the QEMU-mode campaign"
	@echo "  make fuzz-persistent          run the persistent-mode campaign (ASan)"
	@echo "  make fuzz-persistent-noasan  run the persistent-mode campaign (no ASan, Q8)"
	@echo "  make clean                   remove campaign findings"
	@echo ""
