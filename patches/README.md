Patches applied to libpng before building.

Currently uses the AFL++ CRC-removal patch from `AFLplusplus/utils/libpng_no_checksum/libpng-nocrc.patch`, which is applied inside the Docker container during the build.

TODO before final submission: copy the patch file into this directory so the build is fully reproducible from this repo alone (not dependent on the AFL++ base image).
