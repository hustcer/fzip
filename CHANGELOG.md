# CHANGELOG

All notable changes to this project will be documented in this file.

## v0.5.0 - 2026-03-14

### Performance

- **Slice-by-4 CRC-32 Algorithm**: Replaced the serial byte-at-a-time CRC-32 checksum calculation with a high-bandwidth Slice-by-4 implementation. By utilizing 4 pre-computed lookup tables (`crct`, `crct1`, `crct2`, `crct3`), the mathematical pipeline now independently processes 4 bytes per loop iteration, inherently breaking the previous CPU serial dependency chain. This architectural shift yielded a staggering ~3.2x throughput acceleration on CRC-32 operations (e.g., CRC-32 100K: `371µs` → `117.8µs`).

### Testing & Chores

- **Slice-by-4 Validations**: Engineered comprehensive test blocks tracking non-zero slice boundaries, chunk alignments, and sequential data cross-verifications to assert the mathematical correctness of the new CRC pipelines.

## v0.3.1 - 2026-03-13

### Bug Fixes

- **DEFLATE Level Scaling Resolution**: Fixed a core algorithmic flaw in `dflt()` where the adaptive hash chain search depth dynamically hardcoded limits down to ranges of 4–16, effectively bottlenecking compression ratios and making higher `level: 6-9` runs behave identically to `level: 1-2`. The algorithm now correctly incorporates the configuration's proper baseline depth (`c`), using `c / 4` and `c / 2` reductions dynamically, ensuring superior compression ratios on higher config levels. Added comparative level ratio testing validations.

### Documentation & Chores

- **README Cleanups**: Synced the visible license links pointing out to Apache-2.0.

## v0.3.0 - 2026-03-13

### Performance

- **DEFLATE Lazy Hash Skip**: Engineered a dramatic performance leap (e.g., up to `~76%` faster on highly sequential/zeroed 100K datasets) by identifying redundant hash table insertions. When `dflt()` encounters matches exceeding 16 bytes with ample remaining payload (over 500 bytes), intermediate pointer indices are advanced automatically (skipping `O(match_len)` useless hash insertions).

### Bug Fixes

- **Huffman Tree Out-Of-Bounds Check**: Fixed a latent boundary oversight occurring inside `wblk()`. The `h_tree(lcfreq, 7)` utility can technically yield arrays shorter than 19 elements if length codes carry zero frequencies. `lct[clim[i]]` lookups now safely map out-of-range lengths effectively as zero-length codes rather than triggering potential panics.

## v0.2.5 - 2026-03-13

### Performance

- **Loop Unrolling Architectures**: Delivered aggressive, byte-level loop unrolling across three core computational bottlenecks to minimize CPU branch predictability overhead and maximize throughput:
  - **DEFLATE Match Length**: Unrolled the inner `dflt()` match-length finder loop by 4 bytes, restoring `~15%` performance gains on highly repetitve/sequential data payloads (e.g., `seq_1k: 17.62µs → 14.95µs`).
  - **Adler-32 Validation**: Unrolled the inner checksum accumulation loop by 8 bytes instead of byte-by-byte iteration, radically dropping loop condition evaluations per data chunk.
  - **CRC-32 Validation**: Unrolled the inner checksum bitwise matching loop by 4 bytes.

## v0.2.3 - 2026-03-12

### Performance

- **DEFLATE Hot Path Optimization**: Eliminated expensive integer division operations during adaptive hash chain depth calculations within `dflt()`. By algebraically transforming the division validation (`matches * 100 / searches < threshold`) into a multiplication-based equivalent (`matches * 100 < searches * threshold`), the pipeline bypasses CPU division latency penalties on every hash chain lookup. Added extensive test coverage for all permutation branches.

### Chores & Licensing

- Migrated the open-source license assignment from `MIT` to `Apache-2.0`.

## v0.2.2 - 2026-03-08

### Refactoring

- **ZIP Constants Extraction**: Consolidated ZIP format architecture magic numbers by extracting local header signatures, central directory signatures (`zip_cd_signature`, `zip_eocd_signature`), and `max_filename_length` limits into the shared `constants.mbt` file.

### Documentation & Chores

- **Security Guide**: Introduced a comprehensive `Security Features` section to the `README.md`, thoroughly documenting the recently added Zip bomb size limits, checksum toggles, and path traversal protections.
- **Tooling**: Minor development workflow updates to `Justfile` and `CLAUDE.md`.

## v0.2.1 - 2026-03-08

### Performance

- **Zero-Copy Checksum Verifications**: Eliminated expensive full-array memory copying during `gzip` and `zlib` checksum validations. By introducing the `push_range` method to both the `CRC32State` and `AdlerState` calculators, the library now safely calculates trailer checksums directly off the target buffer regions. This restored decompression speeds by over 400% for 100K payloads (e.g., GZIP decompress 100K: `462.92µs` → `89.51µs`).

### Features

- **Optional Checksum Toggles**: Added a new `verify_checksum` configuration flag (defaulting to `true`) within `GunzipOptions` and `UnzlibOptions`. This gives developers the authority to completely bypass checksum math on fully trusted payloads for absolute maximum decompression speeds.

### Documentation

- Updated `README.md` to comprehensively highlight the newly introduced security safeguards (Zip bomb prevention, ZipSlip protections, etc.) and testing coverage analysis reports.

## v0.2.0 - 2026-03-08

### Security & Robustness

- **Zip Bomb Prevention**: Hardened decompression safeguards against zip bombs. Introduced a configurable `max_output_size` (defaulted to 100MB, with an absolute hard limit of 1GB) and added a dynamic compression ratio check (rejecting extraction if uncompressed is > 1000x compressed).
- **Checksum Validations**: Enforced missing integrity validation steps in `unzlib_sync` (Adler-32) and `gunzip_sync` (CRC-32), natively rejecting payloads with mismatched trailer checksums.
- **Filename Bound Checks**: Capped ZIP filename lengths at a generous but safe 4096 bytes and added bounds checking to prevent out-of-bounds panics when parsing corrupted central directory headers.

### Refactoring & Chores

- **Code Duplication Reduction**: Extracted scattered magic constants out into a standalone `constants.mbt`. Consolidated buffer trimming (`trim_buf`) and max value reduction (`max_val`) into unified helper functions.
- **Testing**: Added specific security validation tests checking coverage around the new checksum panics and zip bomb scenarios.

## v0.1.7 - 2026-03-08

### Security & Bug Fixes

- **Input Validation & Bound Checks**: Hardened input validation across the library to prevent out-of-bounds panics when processing malformed or truncated compressed data. Added strict minimum data length constraints to the Gzip header parser (`gzip_start`), Zlib header parser (`zls`), and ZIP archive footer readers.
- **ZipSlip Protection**: Explicitly secured `unzip_sync` by adding a new `is_unsafe_path` guard. The extractor will now proactively reject and raise errors for any ZIP entries attempting directory traversals (e.g., containing `../` or absolute root paths) to prevent malicious arbitrary file overwriting.

### Chores

- **Testing**: Added 8 new unit tests focusing on robust error handling for corrupted/truncated payloads, stream boundaries, and tiny data limits, pushing the overall line coverage up to 96.9%.

## v0.1.6 - 2026-03-08

### Performance

- **Huffman Tree Array Pooling**: Refactored the internal DEFLATE Huffman tree construction mechanism to use `Global Array Pools` instead of continuously instantiating new Node objects. Replaced object allocations with reusable integer arrays (like `h_tree_s_pool`, `h_tree_f_pool`), significantly lessening Garbage Collection pressure and reducing memory fragmentation.

### Documentation

- Moved the `Benchmark` section up in the `README.md` to improve visibility.

## v0.1.5 - 2026-03-08

### Performance (Advanced Optimizations)

- **Precise Memory Allocation (Solution 5)**: Further refined heavy memory allocation for small files, replacing the previous version's coarse-grained degradation strategy. Buffers `<512` bytes now strictly allocate `512` bytes, payloads `512~4K` use exact fit sizes, and payloads `4K~16K` scale linearly at a reduced `1.25x` ratio.
- **Incompressible Data Escape (Solution 1)**: Added `is_compressible` checks leveraging block "byte entropy" and match rates. When compressing data with high entropy and low compression value, the program now dynamically bypasses the heavy DEFLATE computation entirely.
- **Adaptive Hash Chaining (Solution 2)**: Introduced the `successful_matches` tracker. By dynamically monitoring hit rates during runtime (e.g., if match rate dips below 5%), the maximum chain search depth is adaptively downgraded to 4 iterations, drastically cutting down on pointless searches. 100K random data compression speeds are boosted by an additional `20.6%`.

## v0.1.3 - 2026-03-08

### Performance (Initial Optimizations)

- **Static Memory Degradation**: Initially mitigated large memory footprints for small file DEFLATE compression (e.g., reducing 1KB payload memory usage from 148KB sharply down to 24KB). Rewrote the `compute_mem_level` block to cap the initial `window_size` and `syms_size` bounds for small files.
- **Static Hash Truncation**: Applied the first LZ77 hash chain depth limit (roughly capped at 16 or 32 searches based on payload size), and introduced an early exit mechanism for fast matching strings exceeding 32 bytes. Reduced massive blocks of meaningless searches for 100K random payloads, speeding them up by `47%`.

## v0.1.2 - 2026-03-08

### Features

- **CI / Actions**: Added GitHub Actions workflow (`ci.yml`) to automatically check formatting, build, and run tests across Ubuntu, macOS, and Windows.
- **Task Runner**: Added a comprehensive `Justfile` to standardize local development workflows (e.g., formatting, building, testing, benchmarking, coverage, and releasing).

### Bug Fixes

- **String Utilities**: Fixed critical UTF-8 encoding and decoding bugs in `str_to_u8` and `str_from_u8` affecting 4-byte characters.
  - Corrected the extraction and combining logic of high and low surrogate pairs during UTF-8 encoding for 4-byte characters (e.g., emojis like 😀 and symbols like 𝄞).
  - Switched the encoding loop from `for` to `while` to properly skip the low surrogate string index.
  - Fixed bitwise operator precedence issues in the 4-byte decoding logic.
  - Added robust roundtrip unit tests for 3-byte CJK characters and 4-byte emojis to prevent regressions.

### Chores

- **Documentation**: Updated compression and decompression benchmark latency metrics in `README.md`.
- **Formatting**: Applied standard code formatting to the codebase.

## v0.1.1 - 2026-03-08

Initial commit of `fzip`. Ported from `fflate`, with DEFLATE, GZIP, Zlib, and ZIP compression and decompression, streaming and synchronous APIs supported.
