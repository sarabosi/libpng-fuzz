Patches applied to libpng before building.

The CRC patch disables CRC-32 validation so the fuzzer can reach chunk parsing
code without every mutation being rejected at the checksum check.

Sourced from `AFLplusplus/utils/libpng_no_checksum/`.
