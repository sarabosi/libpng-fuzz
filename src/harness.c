#include <png.h>
#include <setjmp.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    const uint8_t *data;
    size_t size;
    size_t offset;
} buf_state_t;

static void buf_read(png_structp png, png_bytep out, png_size_t want) {
    buf_state_t *s = (buf_state_t *)png_get_io_ptr(png);
    if (s->offset + want > s->size) {
        png_error(png, "short read");
        return;
    }
    memcpy(out, s->data + s->offset, want);
    s->offset += want;
}


static void prog_info_cb(png_structp png, png_infop info) {
    (void)png; (void)info;
}

static void prog_row_cb(png_structp png, png_bytep row, png_uint_32 row_num, int pass) {
    (void)png; (void)row; (void)row_num; (void)pass;
}

static void prog_end_cb(png_structp png, png_infop info) {
    (void)png; (void)info;
}

static void run_progressive_read(const uint8_t *data, size_t len) {
    png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!png) return;
    png_infop info = png_create_info_struct(png);
    if (!info) { png_destroy_read_struct(&png, NULL, NULL); return; }

    if (setjmp(png_jmpbuf(png))) {
        png_destroy_read_struct(&png, &info, NULL);
        return;
    }

    // png_set_user_limits(png, 4096, 4096);
    // png_set_chunk_malloc_max(png, 8 << 20);
    png_set_keep_unknown_chunks(png, PNG_HANDLE_CHUNK_ALWAYS, NULL, 0);
    png_set_progressive_read_fn(png, NULL, prog_info_cb, prog_row_cb, prog_end_cb);

    size_t chunk = (len > 0) ? ((data[0] & 0x3F) + 1) : 64;
    size_t pos = 0;
    while (pos < len) {
        size_t n = (len - pos < chunk) ? (len - pos) : chunk;
        png_process_data(png, info, (png_bytep)(data + pos), n);
        pos += n;
    }

    png_destroy_read_struct(&png, &info, NULL);
}

static void run_standard(const uint8_t *data, size_t len) {
    buf_state_t state = { data, len, 0 };

    png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!png) return;
    png_infop info = png_create_info_struct(png);
    if (!info) {
        png_destroy_read_struct(&png, NULL, NULL);
        return;
    }

    png_bytep * volatile rows = NULL;
    volatile png_uint_32 height = 0;

    if (setjmp(png_jmpbuf(png))) {
        if (rows) {
            for (png_uint_32 i = 0; i < height; i++) free(rows[i]);
            free(rows);
        }
        png_destroy_read_struct(&png, &info, NULL);
        return;
    }

    png_set_read_fn(png, &state, buf_read);
    png_set_user_limits(png, 4096, 4096);
    /* Keep all unknown chunks so pngrutil.c unknown-chunk path is exercised */
    png_set_keep_unknown_chunks(png, PNG_HANDLE_CHUNK_ALWAYS, NULL, 0);
    // png_set_chunk_malloc_max(png, 8 << 20);

    png_read_info(png, info);

    png_uint_32 width;
    int bit_depth, color_type;
    png_get_IHDR(png, info, &width, &height, &bit_depth, &color_type,
                 NULL, NULL, NULL);

    png_set_expand_gray_1_2_4_to_8(png);
    png_set_palette_to_rgb(png);
    png_set_strip_16(png);
    png_set_strip_alpha(png);
    png_set_packswap(png);
    png_set_swap_alpha(png);

    png_set_bgr(png);
    png_set_invert_mono(png);
    png_set_invert_alpha(png);

    // png_set_packing(png);
    png_set_filler(png, 0xFF, PNG_FILLER_BEFORE);
    png_set_add_alpha(png, 0x80 , PNG_FILLER_AFTER);

    png_set_swap(png);
    png_set_gamma(png, 0.45455, 1.0);
    // png_set_rgb_to_gray(png, 1, -1.0, -1.0);
    // png_set_gray_to_rgb(png);
    png_set_interlace_handling(png);

    png_read_update_info(png, info);

    size_t rowbytes = png_get_rowbytes(png, info);
    rows = (png_bytep *)calloc(height, sizeof(png_bytep));
    if (!rows) png_error(png, "row array alloc");
    for (png_uint_32 i = 0; i < height; i++) {
        rows[i] = (png_bytep)malloc(rowbytes);
        if (!rows[i]) png_error(png, "row alloc");
    }

    png_read_image(png, rows);
    png_read_end(png, info);

    (void)png_get_image_width(png, info);
    (void)png_get_image_height(png, info);
    (void)png_get_bit_depth(png, info);
    (void)png_get_color_type(png, info);
    (void)png_get_filter_type(png, info);
    (void)png_get_interlace_type(png, info);
    (void)png_get_compression_type(png, info);
    (void)png_get_channels(png, info);

    png_textp text_ptr = NULL;
    int num_text = 0;
    (void)png_get_text(png, info, &text_ptr, &num_text);

    png_charp icc_name = NULL;
    int icc_compression = 0;
    png_charp icc_profile = NULL;
    png_uint_32 icc_proflen = 0;
    (void)png_get_iCCP(png, info, &icc_name, &icc_compression,
                        &icc_profile, &icc_proflen);

    int srgb_intent = 0;
    (void)png_get_sRGB(png, info, &srgb_intent);

    double gamma = 0;
    (void)png_get_gAMA(png, info, &gamma);

    double wx = 0, wy = 0, rx = 0, ry = 0, gx = 0, gy = 0, bx = 0, by = 0;
    (void)png_get_cHRM(png, info, &wx, &wy, &rx, &ry, &gx, &gy, &bx, &by);

    png_color_16p bkgd = NULL;
    (void)png_get_bKGD(png, info, &bkgd);

    png_bytep trans_alpha = NULL;
    int num_trans = 0;
    png_color_16p trans_color = NULL;
    (void)png_get_tRNS(png, info, &trans_alpha, &num_trans, &trans_color);

    png_colorp palette = NULL;
    int num_palette = 0;
    (void)png_get_PLTE(png, info, &palette, &num_palette);

    png_uint_16p hist = NULL;
    (void)png_get_hIST(png, info, &hist);

    png_uint_32 res_x = 0, res_y = 0;
    int phys_unit = 0;
    (void)png_get_pHYs(png, info, &res_x, &res_y, &phys_unit);

    png_int_32 off_x = 0, off_y = 0;
    int off_unit = 0;
    (void)png_get_oFFs(png, info, &off_x, &off_y, &off_unit);

    int scal_unit = 0;
    double scal_w = 0, scal_h = 0;
    (void)png_get_sCAL(png, info, &scal_unit, &scal_w, &scal_h);

    png_timep mod_time = NULL;
    (void)png_get_tIME(png, info, &mod_time);

    png_color_8p sig_bit = NULL;
    (void)png_get_sBIT(png, info, &sig_bit);

    png_sPLT_tp splt_entries = NULL;
    (void)png_get_sPLT(png, info, &splt_entries);

    png_charp pcal_purpose = NULL;
    png_int_32 pcal_X0 = 0, pcal_X1 = 0;
    int pcal_type = 0, pcal_nparams = 0;
    png_charp pcal_units = NULL;
    png_charpp pcal_params = NULL;
    (void)png_get_pCAL(png, info, &pcal_purpose, &pcal_X0, &pcal_X1,
                        &pcal_type, &pcal_nparams, &pcal_units, &pcal_params);

    png_unknown_chunkp unknowns = NULL;
    (void)png_get_unknown_chunks(png, info, &unknowns);

    const png_uint_32 chunk_flags[] = {
        PNG_INFO_gAMA, PNG_INFO_sBIT, PNG_INFO_cHRM, PNG_INFO_PLTE,
        PNG_INFO_tRNS, PNG_INFO_bKGD, PNG_INFO_hIST, PNG_INFO_pHYs,
        PNG_INFO_oFFs, PNG_INFO_tIME, PNG_INFO_pCAL, PNG_INFO_sRGB,
        PNG_INFO_iCCP, PNG_INFO_sPLT, PNG_INFO_sCAL, PNG_INFO_IDAT
    };
    for (size_t i = 0; i < sizeof(chunk_flags)/sizeof(*chunk_flags); i++) {
        (void)png_get_valid(png, info, chunk_flags[i]);
    }

    (void)png_get_x_pixels_per_meter(png, info);
    (void)png_get_y_pixels_per_meter(png, info);
    (void)png_get_pixel_aspect_ratio(png, info);

    for (png_uint_32 i = 0; i < height; i++) free(rows[i]);
    free(rows);
    png_destroy_read_struct(&png, &info, NULL);
}

int main(int argc, char **argv) {
    if (argc < 2) return 1;

    FILE *f = fopen(argv[1], "rb");
    if (!f) return 1;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return 1; }
    long len = ftell(f);
    if (len < 0) { fclose(f); return 1; }
    rewind(f);

    uint8_t *data = (uint8_t *)malloc((size_t)len);
    if (!data) { fclose(f); return 1; }
    if (fread(data, 1, (size_t)len, f) != (size_t)len) {
        free(data); fclose(f); return 1;
    }
    fclose(f);

    run_standard(data, (size_t)len);
    run_progressive_read(data, (size_t)len);

    free(data);
    return 0;
}
