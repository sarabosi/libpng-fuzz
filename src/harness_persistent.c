#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <png.h>

// in-memory read source: libpng reads from a buffer instead of a file

typedef struct {
    const uint8_t *data;
    size_t         size;
    size_t         pos;
} mem_source_t;

static void mem_read_fn(png_structp png_ptr, png_bytep buf, png_size_t count)
{
    mem_source_t *src = (mem_source_t *)png_get_io_ptr(png_ptr);

    if (src->pos + count > src->size)
        png_error(png_ptr, "not enough data"); // triggers longjmp in error_fn

    memcpy(buf, src->data + src->pos, count);
    src->pos += count;
}

// error/warning callbacks: silence output and recover via longjmp 

static void error_fn(png_structp png_ptr, png_const_charp msg)
{
    (void)msg;
    longjmp(png_jmpbuf(png_ptr), 1);
}

static void warning_fn(png_structp png_ptr, png_const_charp msg)
{
    (void)png_ptr;
    (void)msg;
}

/* ================================================================== */
// decode: takes one buffer, runs it through libpng

static int fuzz_one(const uint8_t *data, size_t size)
{
    // PNG signature (8) + IHDR chunk (25) = 33 bytes minimum 
    if (size < 33)
        return 0;

    // setup libpng objects
    png_structp png_ptr      = NULL;
    png_infop   info_ptr     = NULL;
    png_bytep  *row_pointers = NULL;

    png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, error_fn, warning_fn);
    if (!png_ptr) return 0;

    info_ptr = png_create_info_struct(png_ptr);
    if (!info_ptr) {
        png_destroy_read_struct(&png_ptr, NULL, NULL);
        return 0;
    }

    // setjmp recovery point
    if (setjmp(png_jmpbuf(png_ptr))) {
        if (row_pointers) {
            png_uint_32 h = png_get_image_height(png_ptr, info_ptr);
            for (png_uint_32 i = 0; i < h; i++)
                free(row_pointers[i]);
            free(row_pointers);
        }
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }

    // memory source
    mem_source_t src = { data, size, 0 };
    png_set_read_fn(png_ptr, &src, mem_read_fn);
    png_read_info(png_ptr, info_ptr);

    png_uint_32 width      = png_get_image_width(png_ptr, info_ptr);
    png_uint_32 height     = png_get_image_height(png_ptr, info_ptr);
    int         bit_depth  = png_get_bit_depth(png_ptr, info_ptr);
    int         color_type = png_get_color_type(png_ptr, info_ptr);


    if (width == 0 || height == 0 || width > 4096 || height > 4096) {
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }

    // apply transforms
    if (color_type == PNG_COLOR_TYPE_PALETTE)
        png_set_palette_to_rgb(png_ptr);
    if (color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8)
        png_set_expand_gray_1_2_4_to_8(png_ptr);
    if (png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS))
        png_set_tRNS_to_alpha(png_ptr);
    if (bit_depth == 16)
        png_set_strip_16(png_ptr);
    if (!(color_type & PNG_COLOR_MASK_ALPHA))
        png_set_filler(png_ptr, 0xFF, PNG_FILLER_AFTER);

    png_read_update_info(png_ptr, info_ptr);

    // allocate row buffers
    png_size_t rowbytes = png_get_rowbytes(png_ptr, info_ptr);

    row_pointers = (png_bytep *)malloc(height * sizeof(png_bytep));
    if (!row_pointers) {
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }

    for (png_uint_32 i = 0; i < height; i++)
        row_pointers[i] = NULL;

    for (png_uint_32 i = 0; i < height; i++) {
        row_pointers[i] = (png_bytep)malloc(rowbytes);
        if (!row_pointers[i]) {
            for (png_uint_32 j = 0; j < i; j++)
                free(row_pointers[j]);
            free(row_pointers);
            row_pointers = NULL;
            png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
            return 0;
        }
    }

    // decode image
    png_read_image(png_ptr, row_pointers);

    png_read_end(png_ptr, info_ptr);

    // query text/ancillary chunks
    png_textp text_ptr; int num_text = 0;
    png_get_text(png_ptr, info_ptr, &text_ptr, &num_text);

    double gamma;           png_get_gAMA(png_ptr, info_ptr, &gamma);
    png_color_16p bg;       png_get_bKGD(png_ptr, info_ptr, &bg);
    png_uint_32 rx, ry, u;  png_get_pHYs(png_ptr, info_ptr, &rx, &ry, &u);

    // cleanup
    for (png_uint_32 i = 0; i < height; i++)
        free(row_pointers[i]);
    free(row_pointers);
    row_pointers = NULL;

    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    return 0;
}

/* ================================================================== */

// the persistent loop: AFL+ writes input in buf each iteration and we decode it in a loop
__AFL_FUZZ_INIT();

int main(void)
{
    __AFL_INIT();                           // fork server starts here
    uint8_t *buf = __AFL_FUZZ_TESTCASE_BUF; // AFL++ writes each input into buf

    while (__AFL_LOOP(10000)) {             // run 10000 times then restart
        fuzz_one(buf, __AFL_FUZZ_TESTCASE_LEN);
    }

    return 0;
}

// afl-fuzz -i seeds -o findings-persistent -x dictionaries/png.dict -- ./harness-persistent
// ./harness-persistent < seeds/not_kitty.png
