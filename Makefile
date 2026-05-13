.PHONY: all build fuzz fuzz-qemu fuzz-persistent clean help

# Default target
all: help

help:
	@echo "libpng fuzzing lab — available targets:"
	@echo "  build            Build the Docker image"
	@echo "  fuzz             Run AFL++ with non-persistent harness (file argument mode)"
	@echo "  fuzz-qemu        Run AFL++ in QEMU black-box mode"
	@echo "  fuzz-persistent  Run AFL++ with persistent-mode harness (fastest)"
	@echo "  clean            Remove findings directories"

build:
	docker build -t libpng-fuzz .

IMAGE ?= libpng-fuzz

fuzz: build
	docker run --rm -it \
		-v "$(CURDIR)/findings:/work/findings" \
		$(IMAGE) \
		afl-fuzz -i /work/pngsuite-full -o /work/findings \
		-x /AFLplusplus/dictionaries/png.dict \
		-- /work/bin/png_fuzz @@

fuzz-qemu: build
	docker run --rm -it \
		-v "$(CURDIR)/findings-qemu:/work/findings-qemu" \
		$(IMAGE) \
		afl-fuzz -Q -i /work/pngsuite-full -o /work/findings-qemu \
		-x /AFLplusplus/dictionaries/png.dict \
		-- /work/bin/png_fuzz_qemu @@

fuzz-persistent: build
	docker run --rm -it \
		-v "$(CURDIR)/findings-persistent:/work/findings-persistent" \
		$(IMAGE) \
		afl-fuzz -i /work/pngsuite-full -o /work/findings-persistent \
		-x /AFLplusplus/dictionaries/png.dict \
		-- /work/bin/png_fuzz_persistent @@

clean:
	rm -rf findings findings-qemu findings-persistent
