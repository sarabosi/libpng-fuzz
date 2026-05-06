FROM aflplusplus/aflplusplus:latest

# ----------------- libpng 1.2.56 -----------------
RUN apt-get update && apt-get install -y \
    wget \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# ----------------- libpng (forQEMU) -----------------
RUN wget https://download.sourceforge.net/libpng/libpng-1.2.56.tar.gz \
    && tar -xf libpng-1.2.56.tar.gz \
    && cd libpng-1.2.56 \
    && ./configure --prefix=/usr/local \
    && make -j$(nproc) && make install && ldconfig \
    && cd / && rm -rf libpng-1.2.56

# ----------------- Sanitized libpng -----------------
RUN tar -xf libpng-1.2.56.tar.gz \
    && cd libpng-1.2.56 \
    && ./configure --prefix=/usr/local/asan \
       CC=afl-clang-fast \
       CFLAGS="-fsanitize=address,undefined -g" \
       LDFLAGS="-fsanitize=address,undefined" \
    && make -j$(nproc) && make install \
    && cd / && rm -rf libpng-1.2.56 libpng-1.2.56.tar.gz

WORKDIR /work

CMD ["/bin/bash"]

