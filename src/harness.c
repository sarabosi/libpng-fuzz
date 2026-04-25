/* Fuzzing harness for libpng. 
 * 
 * AFL++ will pass each test input as a file path on the command line.
 * The program opens the file and feed it to libpng. Returns 0 if libpng doesn't crash.
 * To be filled in after the Dockerfile and build steps work.
 */

#include <png.h>
#include <setjmp.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
static void sink(png_structp p, png_bytep d, png_size_t n) { (void)p; (void)d; (void)n; }
static void flush(png_structp p) { (void)p; }

int main(int argc, char **argv) {
    if (argc < 2) return 1;
    FILE *f = fopen(argv[1], "rb");
    if (!f) return 1;

    uint8_t buf[4096];
    size_t n = fread(buf, 1, sizeof(buf), f);
    fclose(f);
    if (n < 8) return 0;                     // need a few bytes to map fields

    /* Layout: byte0 = compression, byte1 = key_len (0..79),
        rest split into key + text per key_len. */
    int     compression = (int8_t)buf[0];    // includes negative / out-of-range values
    size_t  key_len     = buf[1] % 80;
    if (key_len + 2 > n) key_len = n - 2;

    char key[80] = {0};
    memcpy(key, buf + 2, key_len);
    key[key_len] = '\0';                     // png_text.key must be NUL-terminated

    png_text txt;
    memset(&txt, 0, sizeof(txt));
    txt.compression = compression;
    txt.key         = key;
    txt.text        = (char *)(buf + 2 + key_len);
    txt.text_length = n - 2 - key_len;

    png_structp png  = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!png) return 0;
    png_infop   info = png_create_info_struct(png);
    if (!info) { png_destroy_write_struct(&png, NULL); return 0; }

    if (setjmp(png_jmpbuf(png))) {
        png_destroy_write_struct(&png, &info);
        return 0;
    }
    png_set_text(png, info, &txt, 1); 

    
    png_set_write_fn(png, NULL, sink, flush);
    png_set_IHDR(png, info, 1, 1, 8, PNG_COLOR_TYPE_GRAY,
                PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT,
                PNG_FILTER_TYPE_DEFAULT);
    png_set_text(png, info, &txt, 1);
    png_write_info(png, info);

    png_destroy_write_struct(&png, &info);
    return 0;
}

// afl-fuzz -i /AFLplusplus/testcases/images/png/ -o findings -x /AFLplusplus/dictionaries/png.dict -- ./bin/png_fuzz @@
// afl-fuzz -i seeds -o findings -x dictionaries/text_input.dict -- ./bin/png_fuzz @@
// ./bin/png_fuzz /AFLplusplus/testcases/images/png/not_kitty.png