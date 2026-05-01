# Starts from official AFL++ Docker image as base
FROM aflplusplus/aflplusplus:latest

# System deps for building libpng
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        build-essential \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

# Download libpng 1.4.19
RUN wget -q https://download.sourceforge.net/libpng/libpng-1.4.19.tar.gz \
&& tar xf libpng-1.4.19.tar.gz \
&& cp -r libpng-1.4.19 libpng-1.4.19-vanilla \
&& rm libpng-1.4.19.tar.gz

COPY patches /work/patches

# Compile libraries
WORKDIR /work/libpng-1.4.19
RUN patch -p0 < /work/patches/libpng-nocrc.patch
RUN CC=afl-clang-fast \
CXX=afl-clang-fast++ \
CFLAGS="-fsanitize=address -g -O1  -DPNG_iTXt_SUPPORTED" \
LDFLAGS="-fsanitize=address" \
./configure --disable-shared --prefix=$(pwd)/install && make -j$(nproc) && make install

WORKDIR /work/libpng-1.4.19-vanilla
RUN patch -p0 < /work/patches/libpng-nocrc.patch
RUN CC=gcc CFLAGS="-g -O1 -DPNG_iTXt_SUPPORTED" \
./configure --disable-shared --prefix=$(pwd)/install_vanilla && make -j$(nproc) && make install

# After libpng build steps so source changes don't invalidate the libpng cache
COPY src /work/src

# Compile harnesses
RUN mkdir /work/bin && afl-clang-fast /work/src/harness.c \
-I/work/libpng-1.4.19/install/include \
-L/work/libpng-1.4.19/install/lib \
-lpng14 -lz -lm \
-fsanitize=address -g -O1 \
-DPNG_iTXt_SUPPORTED \
-o /work/bin/png_fuzz

RUN gcc /work/src/harness.c \
-I/work/libpng-1.4.19-vanilla/install_vanilla/include \
-L/work/libpng-1.4.19-vanilla/install_vanilla/lib \
-lpng14 -lz -lm \
-g -O1 \
-DPNG_iTXt_SUPPORTED \
-o /work/bin/png_fuzz_qemu

RUN afl-clang-fast /work/src/harness_persistent.c \
-I/work/libpng-1.4.19/install/include \
-L/work/libpng-1.4.19/install/lib \
-lpng14 -lz -lm \
-fsanitize=address -g -O1 \
-DPNG_iTXt_SUPPORTED \
-o /work/bin/png_fuzz_persistent

COPY seeds /work/seeds
COPY dictionaries /work/dictionaries

WORKDIR /work

CMD ["/bin/bash"]
