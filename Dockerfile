# Starts from official AFL++ Docker image as base
FROM aflplusplus/aflplusplus:latest

# System deps for building libpng
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        build-essential \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

# Download libpng 1.2.56
RUN wget -q https://download.sourceforge.net/libpng/libpng-1.2.56.tar.gz \
    && tar xf libpng-1.2.56.tar.gz \
    && rm libpng-1.2.56.tar.gz

# Last so source changes don't invalidate the libpng cache
COPY . /work

# TODO:
#  - apply CRC patch to the libpng source before compiling 
#  - compile libpng with instrumentation (afl-clang-fast + ASan)
#  - compile a second copy of libpng without instrumentation (for QEMU mode)
#  - compile harness variants (regular, persistent, QEMU)
#  - set default CMD to an interactive shell
