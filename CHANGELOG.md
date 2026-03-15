# CHANGELOG

All notable changes to this project will be documented in this file.

## v0.5.1 - 2026-03-15

### Performance

- **Small Data Compressibility Detection**: Improved `is_compressible()` for data under 4096 bytes. Instead of sparse sampling, performs a full byte scan to count unique byte values. Data with >240 unique bytes undergoes an additional periodicity check at 10 candidate distances to avoid false positives on patterned data (e.g., sequential bytes cycling through all 256 values). On random 1K data, this skips the LZ77 search entirely and falls back to stored blocks (82 µs → 2.5 µs).
- **Scaled `prev` Array**: The hash chain `prev` array in `dflt()` is now sized to `min(data_size, 32768)` instead of a fixed 32768 entries, reducing memory allocation for small inputs.

### Testing

- Added 4 white-box tests for `is_compressible()` covering random data, sequential patterns, all-zeros, and small data below the detection threshold.

## v0.5.0 - 2026-03-14

### Performance

- **Slice-by-4 CRC-32 Algorithm**: Replaced the byte-at-a-time CRC-32 checksum calculation with a Slice-by-4 implementation. By utilizing 4 pre-computed lookup tables (`crct`, `crct1`, `crct2`, `crct3`), the algorithm processes 4 bytes per loop iteration with independent table lookups, breaking the serial dependency chain of the previous unrolled approach. This yields ~3.1x throughput improvement on CRC-32 operations.

### Testing & Chores

- **Slice-by-4 Validations**: Added test cases covering various alignment boundaries (1, 3, 5, 16 bytes), chunk-based incremental consistency, and sequential data cross-verifications to validate the correctness of the new CRC pipelines.

## v0.3.1 - 2026-03-13

### Bug Fixes

- **DEFLATE Level Scaling Resolution**: Fixed a bug in `dflt()` where the adaptive hash chain search depth used hardcoded limits (ranges of 4–16), effectively bottlenecking compression ratios and making higher `level: 6-9` runs behave similarly to lower levels. The algorithm now correctly incorporates the configuration's baseline depth (`c`), using `c / 4` and `c / 2` reductions dynamically, ensuring higher compression levels produce better ratios. Added comparative level ratio testing validations.

### Documentation & Chores

- **README Cleanups**: Synced the visible license links pointing out to Apache-2.0.

## v0.3.0 - 2026-03-13

### Performance

- **DEFLATE Lazy Hash Skip**: Improved performance on highly sequential/zeroed 100K datasets (~76% faster) by skipping redundant hash table insertions. When `dflt()` encounters matches exceeding 16 bytes with ample remaining payload (over 500 bytes), intermediate pointer indices are advanced automatically, skipping unnecessary hash insertions for the matched range.

### Bug Fixes

- **Huffman Tree Out-Of-Bounds Check**: Fixed boundary issues inside `wblk()`. The `h_tree(lcfreq, 7)` utility can yield arrays shorter than 19 elements if length codes carry zero frequencies. Added bounds checks for `lct[clim[i]]`, `llm[len]`, and `lct[len]` lookups to safely treat out-of-range indices as zero-length codes rather than triggering potential panics.

## v0.2.5 - 2026-03-13

### Performance

- **Loop Unrolling**: Applied byte-level loop unrolling across three core computational bottlenecks to reduce loop control overhead and improve throughput:
  - **DEFLATE Match Length**: Unrolled the inner `dflt()` match-length finder loop by 4 bytes.
  - **Adler-32 Checksum**: Unrolled the inner checksum accumulation loop by 8 bytes instead of byte-by-byte iteration, reducing loop condition evaluations per data chunk.
  - **CRC-32 Checksum**: Unrolled the inner checksum loop by 4 bytes.

## v0.2.3 - 2026-03-12

### Performance

- **DEFLATE Adaptive Chain Depth Optimization**: Eliminated integer division operations during adaptive hash chain depth calculations within `dflt()`. By algebraically transforming the division validation (`matches * 100 / searches < threshold`) into a multiplication-based equivalent (`matches * 100 < searches * threshold`), the pipeline avoids division overhead when the adaptive depth check triggers (after every 100 searches). Added test coverage for the three depth branches.

### Chores & Licensing

- Migrated the open-source license assignment from `MIT` to `Apache-2.0`.

## v0.2.2 - 2026-03-08

### Refactoring

- **ZIP Constants Extraction**: Consolidated ZIP format magic numbers by extracting local header signature (`zip_local_signature`), central directory signature (`zip_cd_signature`), EOCD signature (`zip_eocd_signature`), ZIP64 EOCD locator signature (`zip64_eocd_locator_signature`), and `max_filename_length` limit into the shared `constants.mbt` file.

### Documentation & Chores

- **Security Guide**: Updated and expanded the `Security Features` section in `README.md`, adding documentation for checksum toggles (`verify_checksum`) and updated code examples.
- **Tooling**: Minor development workflow updates to `Justfile` and `CLAUDE.md`.

## v0.2.1 - 2026-03-08

### Performance

- **Range-Based Checksum Calculation**: Eliminated intermediate array allocation during `gzip` and `zlib` checksum validations. By introducing the `push_range` method to both the `CRC32State` and `AdlerState` calculators, the library now calculates trailer checksums directly on the target buffer regions without creating a copy via `slc()`.

### Features

- **Optional Checksum Toggles**: Added a new `verify_checksum` configuration flag (defaulting to `true`) within `GunzipOptions` and `UnzlibOptions`. This allows developers to bypass checksum calculation on trusted payloads for faster decompression.

## v0.2.0 - 2026-03-08

### Security & Robustness

- **Zip Bomb Prevention**: Hardened decompression safeguards against zip bombs. Introduced a configurable `max_output_size` (defaulted to 100MB) and `max_input_size` in `InflateOptions`, `GunzipOptions`, and `UnzlibOptions`. Added a dynamic compression ratio check in ZIP extraction (rejecting entries if uncompressed is > 1000x compressed).
- **Checksum Validations**: Enforced missing integrity validation steps in `unzlib_sync` (Adler-32) and `gunzip_sync` (CRC-32), natively rejecting payloads with mismatched trailer checksums.
- **Filename Bound Checks**: Capped ZIP filename lengths at a generous but safe 4096 bytes and added bounds checking to prevent out-of-bounds panics when parsing corrupted central directory headers.

### Refactoring & Chores

- **Code Duplication Reduction**: Created `constants.mbt` for shared size limit constants (`default_max_output_size`, `default_max_input_size`). Extracted buffer trimming into a `trim_buf` helper function, replacing repeated `slc(buf, 0, e=len)` patterns across `deflate.mbt`, `gzip.mbt`, `inflate.mbt`, `string.mbt`, and `zlib.mbt`.
- **Testing**: Added security validation tests covering checksum verification failures and size limit enforcement.

## v0.1.7 - 2026-03-08

### Security & Bug Fixes

- **Input Validation & Bound Checks**: Hardened input validation across the library to prevent out-of-bounds panics when processing malformed or truncated compressed data. Added strict minimum data length constraints to the Gzip header parser (`gzs`), Zlib header parser (`zls`), and ZIP archive footer readers.
- **ZipSlip Protection**: Explicitly secured `unzip_sync` by adding a new `is_unsafe_path` guard. The extractor will now proactively reject and raise errors for any ZIP entries attempting directory traversals (e.g., containing `../` or absolute root paths) to prevent malicious arbitrary file overwriting.

### Chores

- **Testing**: Added 33 new unit tests focusing on error handling for corrupted/truncated payloads, streaming API basics, and tiny data limits.

## v0.1.6 - 2026-03-08

### Performance

- **Array Pooling**: Refactored internal DEFLATE and Huffman tree construction to use global array pools instead of per-call allocations. Replaced `HuffNode` object allocations with flat integer arrays (`h_tree_s_pool`, `h_tree_f_pool`, etc.) in `huffman.mbt`, and added `dflt_head_pool`, `dflt_prev_pool`, `dflt_syms_pool`, `dflt_lf_pool`, `dflt_df_pool` in `deflate.mbt` to reuse hash table and symbol buffer arrays across calls.

### Documentation

- Moved the `Benchmark` section up in the `README.md` to improve visibility.

## v0.1.5 - 2026-03-08

### Performance (Advanced Optimizations)

- **Precise Memory Allocation (Solution 5)**: Further refined heavy memory allocation for small files, replacing the previous version's coarse-grained degradation strategy. Buffers `<512` bytes now strictly allocate `512` bytes, payloads `512~4K` use exact fit sizes, and payloads `4K~16K` scale linearly at a reduced `1.25x` ratio.
- **Incompressible Data Escape (Solution 1)**: Added `is_compressible` checks leveraging block "byte entropy" and match rates. When compressing data with high entropy and low compression value, the program falls back to stored blocks (level=0) to avoid unnecessary DEFLATE computation.
- **Adaptive Hash Chaining (Solution 2)**: Introduced the `successful_matches` tracker. By dynamically monitoring hit rates during runtime (e.g., if match rate dips below 5%), the maximum chain search depth is adaptively downgraded to 4 iterations, reducing pointless searches on low-compressibility data.

## v0.1.3 - 2026-03-08

### Performance (Initial Optimizations)

- **Static Memory Degradation**: Mitigated large memory footprints for small file DEFLATE compression. Extended `compute_mem_level` with early returns for small inputs, reducing the `head` hash table from 2^15 to as low as 2^10 entries; separately capped `window_size` (the `prev` sliding window array) and `syms_size` (the LZ77 symbol buffer) inline within `dflt()` based on input size.
- **Static Hash Truncation**: Applied the first LZ77 hash chain depth limit (roughly capped at 16 or 32 searches based on remaining data size), and introduced an early exit mechanism for fast matching strings of 32 or more bytes.

## v0.1.2 - 2026-03-08

### Features

- **CI / Actions**: Added GitHub Actions workflow (`ci.yml`) to automatically type-check, build, and run tests across Ubuntu, macOS, and Windows.
- **Task Runner**: Added a comprehensive `Justfile` to standardize local development workflows (e.g., formatting, building, testing, benchmarking, coverage, and releasing).

### Bug Fixes

- **String Utilities**: Fixed critical UTF-8 encoding and decoding bugs in `str_to_u8` and `str_from_u8` affecting 4-byte characters.
  - Corrected the extraction and combining logic of high and low surrogate pairs during UTF-8 encoding for 4-byte characters (e.g., emojis like 😀 and symbols like 𝄞).
  - Switched the encoding loop from `for` to `while` to properly skip the low surrogate string index.
  - Fixed bitwise operator precedence issues in the 4-byte decoding logic.
  - Added robust roundtrip unit tests for 3-byte CJK characters and 4-byte emojis to prevent regressions.

### Chores

- **Documentation**: Updated compression and decompression benchmark latency metrics in `README.md`.
- **Formatting**: Applied code formatting to `src/string.mbt`.

## v0.1.1 - 2026-03-08

Initial commit of `fzip`. Ported from `fflate`, with DEFLATE, GZIP, Zlib, and ZIP compression and decompression, streaming and synchronous APIs supported.
