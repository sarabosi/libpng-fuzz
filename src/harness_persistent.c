#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include <png.h>

/* ================================================================== */

typedef struct {
    const uint8_t *data;
    size_t         size;
    size_t         pos;
} mem_source_t;

static void mem_read_fn(png_structp png_ptr, png_bytep buf, png_size_t count)
{
    mem_source_t *src = (mem_source_t *)png_get_io_ptr(png_ptr);

    if (src->pos + count > src->size) {
        png_error(png_ptr, "not enough data");
    }
    memcpy(buf, src->data + src->pos, count);
    src->pos += count;
}

/* ================================================================== */

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

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    /* Minimum PNG: signature (8 bytes) + IHDR chunk (25 bytes) = 33 bytes */
    if (size < 33)
        return 0;

    png_structp png_ptr              = NULL;
    png_infop   info_ptr             = NULL;
    png_bytep * volatile row_pointers = NULL;  /* volatile: safe across longjmp */

    png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, error_fn, warning_fn);
    if (!png_ptr) return 0;

    info_ptr = png_create_info_struct(png_ptr);
    if (!info_ptr) {
        png_destroy_read_struct(&png_ptr, NULL, NULL);
        return 0;
    }

    if (setjmp(png_jmpbuf(png_ptr))) {
        /* Error path — free however many rows were actually allocated */
        if (row_pointers) {
            png_uint_32 h = png_get_image_height(png_ptr, info_ptr);
            for (png_uint_32 i = 0; i < h; i++)
                free(row_pointers[i]);
            free(row_pointers);
        }
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }

    mem_source_t src = { data, size, 0 };
    png_set_read_fn(png_ptr, &src, mem_read_fn);

    /* ------ Read PNG header / metadata -------------------------------- */
    png_read_info(png_ptr, info_ptr);

    png_uint_32 width      = png_get_image_width(png_ptr, info_ptr);
    png_uint_32 height     = png_get_image_height(png_ptr, info_ptr);
    int         bit_depth  = png_get_bit_depth(png_ptr, info_ptr);
    int         color_type = png_get_color_type(png_ptr, info_ptr);

    /* Cap image size to keep fuzzer throughput high */
    if (width == 0 || height == 0 || width > 4096 || height > 4096) {
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        return 0;
    }

    /* --- Expand + normalise transforms (increase code paths) ---------- */
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

    /* --- Allocate row buffers ----------------------------------------- */
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

    /* --- Read image data ---------------------------------------------- */
    png_read_image(png_ptr, row_pointers);

    /* --- Read trailing chunks (tEXt, zTXt, eXIf, …) ------------------- */
    png_read_end(png_ptr, info_ptr);

    /* --- Cleanup -------------------------------------------------------- */
    for (png_uint_32 i = 0; i < height; i++)
        free(row_pointers[i]);
    free(row_pointers);
    row_pointers = NULL;

    png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
    return 0;
}

/* ================================================================== */
/* AFL++ persistent mode entry point                                   */
/* ================================================================== */

__AFL_FUZZ_INIT();  /* ← declare the shared memory buffer */

int main(void)
{
    __AFL_INIT();   /* ← connect to AFL++ shared memory */

    uint8_t *buf = __AFL_FUZZ_TESTCASE_BUF;  /* pointer to mutated input */

    while (__AFL_LOOP(10000)) {
        size_t len = __AFL_FUZZ_TESTCASE_LEN; /* length of current input */

        LLVMFuzzerTestOneInput(buf, len);      /* no malloc, no fopen, no fread */
    }

    return 0;
}
