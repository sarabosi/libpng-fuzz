FROM aflplusplus/aflplusplus:latest

# ----------------- libpng 1.2.56 -----------------
RUN apt-get update && apt-get install -y \
    wget \
    zlib1g-dev \
    patch \
    && rm -rf /var/lib/apt/lists/*

# Copy patches into the image
COPY patches/ /tmp/patches/

# Download and extract libpng once, then apply the CRC patch
RUN wget https://download.sourceforge.net/libpng/libpng-1.2.56.tar.gz \
    && tar -xf libpng-1.2.56.tar.gz \
    && cd libpng-1.2.56 \
    && patch -p0 < /tmp/patches/libpng-nocrc.patch

# ----------------- libpng (for QEMU) -----------------
RUN cp -r libpng-1.2.56 libpng-1.2.56-plain \
    && cd libpng-1.2.56-plain \
    && ./configure --prefix=/usr/local --disable-shared \
    && make -j$(nproc) && make install && ldconfig \
    && cd / && rm -rf libpng-1.2.56-plain

# ----------------- Sanitized libpng -----------------
# Use export so autoconf cannot ignore the compiler setting
RUN cp -r libpng-1.2.56 libpng-1.2.56-asan \
    && cd libpng-1.2.56-asan \
    && export CC=afl-clang-fast \
    && export AFL_LLVM_LAF_ALL=1 \
    && export CFLAGS="-fsanitize=address -g" \
    && export LDFLAGS="-fsanitize=address" \
    && ./configure --prefix=/usr/local/asan --disable-shared \
    && make -j$(nproc) && make install \
    && strings /usr/local/asan/lib/libpng12.a | grep -q __afl_area_ptr \
    && echo "[+] libpng instrumented with AFL++ OK" \
    && strings /usr/local/asan/lib/libpng12.a | grep -q __asan_report \
    && echo "[+] libpng instrumented with ASAN OK" \
    && cd / && rm -rf libpng-1.2.56-asan libpng-1.2.56 libpng-1.2.56.tar.gz

WORKDIR /work

CMD ["/bin/bash"]
