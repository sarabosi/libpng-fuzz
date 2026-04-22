.PHONY: all build fuzz fuzz-qemu clean help

# Default target
all: help

help:
	@echo "libpng fuzzing lab — available targets:"
	@echo "  build       Build the Docker image"
	@echo "  fuzz        Run the instrumented AFL++ campaign"
	@echo "  fuzz-qemu   Run the QEMU-mode AFL++ campaign"
	@echo "  clean       Remove build artifacts"

build:
	docker build -t libpng-fuzz .

# TODO
fuzz:
	@echo "Not implemented yet"

fuzz-qemu:
	@echo "Not implemented yet"

clean:
	rm -rf findings findings-qemu plot_output plot_output_qemu
	rm -f png_fuzz png_fuzz_qemu png_fuzz_persistent
