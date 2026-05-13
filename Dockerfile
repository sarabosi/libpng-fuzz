# Starts from official AFL++ Docker image as base
FROM aflplusplus/aflplusplus:latest

# System deps for building libpng
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        build-essential \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

COPY patches /work/patches

WORKDIR /work

# Download libpng 1.4.8
RUN wget -q https://download.sourceforge.net/libpng/libpng-1.4.8.tar.gz \
&& tar xf libpng-1.4.8.tar.gz \
&& cp -r libpng-1.4.8 libpng-1.4.8-vanilla \
&& rm libpng-1.4.8.tar.gz

# PngSuite corpus
COPY PngSuite-2017jul19.tgz /tmp/pngsuite.tgz
RUN mkdir -p /work/pngsuite-full \
 && tar xf /tmp/pngsuite.tgz -C /work/pngsuite-full \
 && rm /tmp/pngsuite.tgz

# Compile libraries
WORKDIR /work/libpng-1.4.8
RUN patch -p0 < /work/patches/libpng-nocrc.patch
RUN CC=afl-clang-fast \
CXX=afl-clang-fast++ \
CFLAGS="-fsanitize=address -fno-sanitize-address-use-after-scope -g -O1 -DPNG_iTXt_SUPPORTED" \
LDFLAGS="-fsanitize=address" \
./configure --disable-shared --prefix=$(pwd)/install && make -j$(nproc) && make install

WORKDIR /work/libpng-1.4.8-vanilla
RUN patch -p0 < /work/patches/libpng-nocrc.patch
RUN CC=gcc CFLAGS="-g -O1 -DPNG_iTXt_SUPPORTED" \
./configure --disable-shared --prefix=$(pwd)/install_vanilla && make -j$(nproc) && make install

COPY src /work/src

# Compile harnesses
RUN mkdir -p /work/bin

# Non-persistent harness (for make fuzz with @@ file argument)
RUN afl-clang-fast /work/src/harness.c \
-I/work/libpng-1.4.8/install/include \
-L/work/libpng-1.4.8/install/lib \
-lpng14 -lz -lm \
-fsanitize=address -g -O1 \
-DPNG_iTXt_SUPPORTED \
-o /work/bin/png_fuzz

# Persistent harness (AFL++ persistent mode, fastest)
RUN afl-clang-fast /work/src/harness_persistent.c \
-I/work/libpng-1.4.8/install/include \
-L/work/libpng-1.4.8/install/lib \
-lpng14 -lz -lm \
-fsanitize=address -g -O1 \
-DPNG_iTXt_SUPPORTED \
-o /work/bin/png_fuzz_persistent

# QEMU harness: uninstrumented gcc build for black-box mode
RUN gcc /work/src/harness_persistent.c \
-I/work/libpng-1.4.8-vanilla/install_vanilla/include \
-L/work/libpng-1.4.8-vanilla/install_vanilla/lib \
-lpng14 -lz -lm \
-g -O1 \
-DPNG_iTXt_SUPPORTED \
-o /work/bin/png_fuzz_qemu

# Last so source changes don't invalidate the libpng cache
COPY seeds /work/seeds
COPY dictionaries /work/dictionaries

WORKDIR /work

CMD ["/bin/bash"]
