FROM aflplusplus/aflplusplus:latest

# ----------------- libpng 1.4.8 -----------------
RUN apt-get update && apt-get install -y \
    wget \
    zlib1g-dev \
    patch \
    && rm -rf /var/lib/apt/lists/*

# Copy patches into the image
COPY patches/ /tmp/patches/

RUN wget https://download.sourceforge.net/libpng/libpng-1.4.8.tar.gz \
    && tar -xf libpng-1.4.8.tar.gz \
    && cd libpng-1.4.8 \
    && patch -p0 < /tmp/patches/libpng-nocrc.patch

#Vanilla (uninstrumented) libpng for QEMU mode
RUN cp -r libpng-1.4.8 libpng-1.4.8-vanilla \
    && cd libpng-1.4.8-vanilla \
    && ./configure --prefix=/usr/local/vanilla --disable-shared --build=aarch64-unknown-linux-gnu \
    && make -j$(nproc) && make install && ldconfig \
    && cd / && rm -rf libpng-1.4.8-vanilla

# Instrumented libpng with ASan
# Use export so autoconf cannot ignore the compiler setting
RUN cd libpng-1.4.8 \
    && export CC=afl-clang-fast \
    && export AFL_LLVM_LAF_ALL=1 \
    && export CFLAGS="-fsanitize=address -g" \
    && export LDFLAGS="-fsanitize=address" \
    && ./configure --prefix=/usr/local/asan --disable-shared --build=aarch64-unknown-linux-gnu \
    && make -j$(nproc) && make install \
    && strings /usr/local/asan/lib/libpng14.a | grep -q __afl_area_ptr \
    && echo "[+] libpng instrumented with AFL++ OK" \
    && strings /usr/local/asan/lib/libpng14.a | grep -q __asan_report \
    && echo "[+] libpng instrumented with ASAN OK" \
    && cd / && rm -rf libpng-1.4.8 libpng-1.4.8.tar.gz

WORKDIR /work

CMD ["/bin/bash"]
