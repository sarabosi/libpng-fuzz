.PHONY: all build fuzz fuzz-qemu fuzz-persistent clean help

# Default target
all: help

help:
	@echo "libpng fuzzing lab — available targets:"
	@echo "  build            Build the Docker image"
	@echo "  fuzz             Run the instrumented AFL++ campaign"
	@echo "  fuzz-qemu        Run the QEMU-mode AFL++ campaign"
	@echo "  fuzz-persistent  Run the persistent-mode AFL++ campaign"
	@echo "  clean            Remove build artifacts"

build:
	docker build -t libpng-fuzz .

IMAGE ?= libpng-fuzz

fuzz: build
	@mkdir -p findings
	docker run --rm -it \
		-v "$(CURDIR)/seeds:/work/seeds" \
		-v "$(CURDIR)/dictionaries:/work/dictionaries" \
		-v "$(CURDIR)/findings:/work/findings" \
		$(IMAGE) \
		afl-fuzz -i seeds -o findings -x dictionaries/text_input.dict -- ./bin/png_fuzz @@

fuzz-qemu: build
	@mkdir -p findings-qemu
	docker run --rm -it \
		-v "$(CURDIR)/seeds:/work/seeds" \
		-v "$(CURDIR)/dictionaries:/work/dictionaries" \
		-v "$(CURDIR)/findings-qemu:/work/findings-qemu" \
		$(IMAGE) \
		afl-fuzz -Q -i seeds -o findings-qemu -x dictionaries/text_input.dict -- ./bin/png_fuzz_qemu @@

fuzz-persistent: build
	@mkdir -p findings-persistent
	docker run --rm -it \
		-v "$(CURDIR)/seeds:/work/seeds" \
		-v "$(CURDIR)/dictionaries:/work/dictionaries" \
		-v "$(CURDIR)/findings-persistent:/work/findings-persistent" \
		$(IMAGE) \
		afl-fuzz -i seeds -o findings-persistent -x dictionaries/text_input.dict -- ./bin/png_fuzz_persistent @@

clean:
	rm -rf findings findings-qemu findings-persistent plot_output plot_output_qemu plot_output_persistent
	rm -f png_fuzz png_fuzz_qemu png_fuzz_persistent
