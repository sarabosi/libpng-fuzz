/* Persistent-mode harness for libpng using 
 * __AFL_FUZZ_INIT() / __AFL_INIT() / __AFL_LOOP(10000) / __AFL_FUZZ_TESTCASE_BUF.
 *
 * The input parsing and libpng call are identical to harness.c 
 * but runs in-process via __AFL_LOOP to avoid fork overhead,
 * continue replaces return 0 so each loop iteration moves on without forking.
 */

#include <png.h>
#include <setjmp.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

__AFL_FUZZ_INIT();

static void sink(png_structp p, png_bytep d, png_size_t n) { (void)p; (void)d; (void)n; }
static void flush(png_structp p) { (void)p; }

int main(void) {
    __AFL_INIT();

    uint8_t *buf = __AFL_FUZZ_TESTCASE_BUF;

    while (__AFL_LOOP(10000)) {
        size_t n = (size_t)__AFL_FUZZ_TESTCASE_LEN;

        if (n < 8) continue;

        /* Layout: byte0 = compression, byte1 = key_len (0..79),
            rest split into key + text per key_len. */
        int    compression = (int8_t)buf[0];
        size_t key_len     = buf[1] % 80;
        if (key_len + 2 > n) key_len = n - 2;

        char key[80] = {0};
        memcpy(key, buf + 2, key_len);
        key[key_len] = '\0';

        png_text txt;
        memset(&txt, 0, sizeof(txt));
        txt.compression = compression;
        txt.key         = key;
        txt.text        = (char *)(buf + 2 + key_len);
        txt.text_length = n - 2 - key_len;

        png_structp png  = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
        if (!png) continue;
        png_infop   info = png_create_info_struct(png);
        if (!info) { png_destroy_write_struct(&png, NULL); continue; }

        if (setjmp(png_jmpbuf(png))) {
            png_destroy_write_struct(&png, &info);
            continue;
        }

        png_set_write_fn(png, NULL, sink, flush);
        png_set_IHDR(png, info, 1, 1, 8, PNG_COLOR_TYPE_GRAY,
                     PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT,
                     PNG_FILTER_TYPE_DEFAULT);
        png_set_text(png, info, &txt, 1);
        png_write_info(png, info);

        png_destroy_write_struct(&png, &info);
    }

    return 0;
}


// afl-fuzz -i seeds -o findings-persistent -x dictionaries/text_input.dict -- ./bin/png_fuzz_persistent
// ./bin/png_fuzz_persistent < seeds/text_none.bin