FROM aflplusplus/aflplusplus:latest

# ----------------- system deps -----------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    zlib1g-dev \
    patch \
    && rm -rf /var/lib/apt/lists/*

COPY patches/ /tmp/patches/

# ----------------- libpng 1.2.56 -----------------
RUN wget -q https://download.sourceforge.net/libpng/libpng-1.2.56.tar.gz \
    && tar -xf libpng-1.2.56.tar.gz \
    && cd libpng-1.2.56 \
    && patch -p0 < /tmp/patches/libpng-nocrc.patch  # line 210 in 1.2.56 pngrutil.c — update if switching to a different libpng version

# plain build for QEMU mode (no instrumentation, no sanitizers)
RUN cp -r libpng-1.2.56 libpng-1.2.56-plain \
    && cd libpng-1.2.56-plain \
    && ./configure --prefix=/usr/local --disable-shared CC=gcc \
    && make -j$(nproc) && make install && ldconfig \
    && cd / && rm -rf libpng-1.2.56-plain

# instrumented build with ASan for white-box fuzzing
RUN cp -r libpng-1.2.56 libpng-1.2.56-asan \
    && cd libpng-1.2.56-asan \
    && ./configure --prefix=/usr/local/asan --disable-shared \
       CC=afl-clang-fast \
       CFLAGS="-fsanitize=address,undefined -g" \
       LDFLAGS="-fsanitize=address,undefined" \
    && make -j$(nproc) && make install \
    && cd / && rm -rf libpng-1.2.56-asan libpng-1.2.56 libpng-1.2.56.tar.gz

WORKDIR /work

# last so source changes don't invalidate the libpng cache
COPY src /work/src

# white-box: instrumented + ASan
RUN AFL_LLVM_LAF_ALL=1 afl-clang-fast -DFUZZING_AFL \
    -I/usr/local/asan/include -fsanitize=address,undefined -g \
    -o /work/harness-white /work/src/harness.c \
    -L/usr/local/asan/lib -lpng12 -lz -lm \
    -Wl,-rpath,/usr/local/asan/lib

# black-box: no instrumentation, no sanitizers (QEMU mode)
RUN clang -DFUZZING_AFL \
    -I/usr/local/include -g \
    -o /work/harness-black /work/src/harness.c \
    -L/usr/local/lib -lpng12 -lz -lm

# persistent: instrumented + ASan + AFL++ persistent mode
RUN AFL_LLVM_LAF_ALL=1 afl-clang-fast \
    -I/usr/local/asan/include -fsanitize=address,undefined -g \
    -o /work/harness-persistent /work/src/harness_persistent.c \
    -L/usr/local/asan/lib -lpng12 -lz -lm \
    -Wl,-rpath,/usr/local/asan/lib

# no-sanitizer persistent: instrumented only, no ASan (for Q8 speed comparison)
RUN AFL_LLVM_LAF_ALL=1 afl-clang-fast \
    -I/usr/local/include -g \
    -o /work/harness-persistent-noasan /work/src/harness_persistent.c \
    -L/usr/local/lib -lpng12 -lz -lm \
    -Wl,-rpath,/usr/local/lib

COPY seeds /work/seeds
COPY dictionaries /work/dictionaries

CMD ["/bin/bash"]
