#include <png.h>

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    return png_access_version_number() == 0;
}
