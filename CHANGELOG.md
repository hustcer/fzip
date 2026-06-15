# CHANGELOG

All notable changes to this project will be documented in this file.

## v0.8.2 - 2026-06-15

- Reduce output size for large periodic DEFLATE inputs by splitting the seed and bulk encoding blocks, cutting 100K sequential raw DEFLATE, GZIP, and Zlib output by about 42% with no public API change.

## v0.8.1 - 2026-06-12

- Replace deprecated MoonBit try? usage for moonc v0.10.0

## v0.8.0 - 2026-05-20

### Added

- ZIP64 metadata support for `zip_sync`, `unzip_sync`, and `unzip_list` when archives and entries still fit the current in-memory sync API limits.
- ZIP writer emission of ZIP64 extra fields, ZIP64 EOCD records, and ZIP64 EOCD locators when classic ZIP fields need sentinel values.
- `zip_sync_checked(files, opts?)`, a raising variant of `zip_sync` for recoverable ZIP writer validation errors.
- `UnzipOptions` with `verify_checksum` for callers that want ZIP entry CRC-32 validation during extraction.
- `FzipErrorCode::Zip64ValueTooLarge` for ZIP64 values that are valid metadata but cannot be represented safely by the current `Int`/`FixedArray` sync APIs.
- `zip64_eocd_signature` and `zip64_locator_signature`; the old `zip64_eocd_locator_signature` name remains as a deprecated alias.
- ZIP data-descriptor entry support for the sync reader, using central-directory sizes and CRC-32.

### Changed

- ZIP reading now validates central-directory and local-header bounds before extraction, including EOCD comment length, ZIP64/classic EOCD consistency, extra-field length, local-header signature, and entry data range.
- ZIP extraction can verify each stored or deflated entry against the central-directory CRC-32 when `verify_checksum` is enabled, and now caps total sync output and entry fan-out.
- `str_from_u8` now rejects malformed UTF-8 according to RFC 3629 instead of accepting continuation-byte starts, bad continuation bytes, overlong encodings, surrogates, and out-of-range code points.
- `gunzip_sync` now validates reserved GZIP flags, FEXTRA bounds, ISIZE range, ISIZE versus `max_output_size`, and final output length.
- `zip_sync` now writes ZIP metadata with fixed-width little-endian helpers and removes user-provided extra fields with header id `0x0001` before emitting its own ZIP64 extra field.

### Fixed

- Fixed ZIP reader integer-overflow risks in central-directory, local-header, compression-ratio, and ZIP32 field handling.
- Fixed ZIP64 EOCD locator detection and conditional ZIP64 extended-information extra-field parsing.
- Fixed DEFLATE inflate handling for dictionary-backed LZ77 back-references that were fully satisfied by the dictionary.
- Fixed malformed dynamic-Huffman handling by rejecting `HLIT > 286`, `HDIST > 30`, invalid repeat-16 placement, and code-length repeat overflows.
- Fixed fixed-output-buffer inflate paths so undersized caller buffers return `FzipError` instead of writing past capacity.

### Tests and docs

- Added ZIP64 design documentation in `docs/zip64.md`.
- Added embedded ZIP64 fixtures produced by Python `zipfile` and Info-ZIP, with generator scripts under `tools/zip64-fixtures/`.
- Added regression tests for ZIP64 parsing/writing, ZIP bounds checks, GZIP header/ISIZE validation, DEFLATE malformed input handling, and strict UTF-8 decoding.

## v0.7.0 - 2026-05-16

### Performance

- **Periodic DEFLATE fast path**: Detect periodic inputs and emit specialized LZ77 streams. In the `feature/bench` v0.7.0 benchmark diff, sequential fzip compression improves across raw DEFLATE **7.89 µs -> 4.59 µs (41.83% faster)** for 1K and **138.26 µs -> 84.96 µs (38.55% faster)** for 100K; GZIP **8.71 µs -> 5.28 µs (39.38% faster)** for 1K and **211.66 µs -> 156.19 µs (26.21% faster)** for 100K; Zlib **8.36 µs -> 4.95 µs (40.79% faster)** for 1K and **177.20 µs -> 124.35 µs (29.83% faster)** for 100K.
- **Inflate-friendly large periodic output**: Large periodic streams now use fixed-Huffman, non-overlapping matches to avoid the decompression regression from the initial fast path. The same benchmark diff shows 100K fzip decompression improvements for raw DEFLATE **20.70 µs -> 16.22 µs (21.64% faster)**, GZIP **90.55 µs -> 84.13 µs (7.09% faster)**, Zlib **59.50 µs -> 55.36 µs (6.96% faster)**, and auto-detect **88.36 µs -> 83.16 µs (5.89% faster)**.
- **Compression-size tradeoff**: The fixed-Huffman large-periodic path improves runtime while increasing 100K sequential output size from **1127 -> 1263 bytes** for raw DEFLATE, **1145 -> 1281 bytes** for GZIP, and **1133 -> 1269 bytes** for Zlib.

## v0.6.3 - 2026-05-13

### Performance

- **RLE fast path for single-byte runs**: Detect all-same-byte inputs before LZ77 hashing and emit a dedicated RLE block (`dflt_rle_block`) that encodes the run as one literal plus repeated length/distance symbols, skipping the full hash-chain scan entirely. Yields a **74.1% compression speedup** for single-byte run inputs.

### Chores

- **Fix `moon check` for moon 0.9.2**: Updated `inflate_wbtest.mbt` to resolve type-check errors introduced by changes in moon 0.9.2.

## v0.6.2 - 2026-05-11

### Performance

- **Speed up small DEFLATE blocks**: For blocks up to 1024 bytes, skip dynamic Huffman tree construction and use the smaller of stored or fixed-Huffman encoding, yielding a 48.1% compression speedup for small fixed-block cases.

## v0.6.1 - 2026-05-09

### Performance

- **Tune inflate preallocation for high-ratio streams**: For compressed inputs in the 512–2047 byte range, preallocate 96× instead of 3× the input size, reducing buffer reallocations and yielding a **13.7% decompression speedup**.

## v0.6.0 - 2026-05-08

### Performance

- **Slice-by-8 CRC-32 Algorithm**: Upgraded CRC-32 from Slice-by-4 to Slice-by-8 by adding four new pre-computed lookup tables (`crct4`–`crct7`). The inner loop now processes 8 bytes per iteration instead of 4, with 8 independent table lookups per step, yielding a 36.6% throughput improvement on CRC-32 operations.

## v0.5.10 - 2026-05-07

### Performance

- **Optimize stored block copy with `blit_to`**: Replace the manual byte-by-byte loop in `wfblk()` with a single `blit_to` call, delivering up to 60%+ faster stored-block (level 0) compression.

## v0.5.9 - 2026-05-02

### Chores

- Fix warnings for moon 0.9.1
- Update docs for public API

## v0.5.8 - 2026-04-07

### Chores

- Replace deprecated Show derives for moon 0.9.0

## v0.5.7 - 2026-04-01

### Chores

- Fix all warnings for the latest moon

## v0.5.6 - 2026-03-30

### Performance

- **Fused checksum updates into existing DEFLATE passes**: `dopt()`/`dflt()` can now update `CRC32State` and `AdlerState` while compressing, and `inflt()` can update those states while producing output. `gzip_sync` and `zlib_sync` now reuse those fused updates instead of doing a separate full-buffer checksum pass after compression; `gunzip_sync` and `unzlib_sync` do the same during decompression when checksum verification is enabled. `zip_sync` reuses the fused CRC-32 path for compressed entries; stored entries are also unified to use `CRC32State` instead of a standalone `crc32()` call.
- **Smaller initial DEFLATE output allocation**: For compressed (`level > 0`) inputs larger than 512 bytes, `dflt()` now starts with a smaller output buffer and grows it on demand instead of preallocating close to the full input size.

### Robustness

- **Safer DEFLATE output capacity math**: Added saturating helpers for DEFLATE output sizing so intermediate buffer-capacity calculations do not wrap on large values. The internal sizing helpers now also guard their non-negative input invariant and fail fast if it is violated.

### Testing

- Added white-box coverage for DEFLATE output growth and capacity helpers, including multi-block growth cases and large-value saturation checks.
- Added checksum-fusion tests for DEFLATE, GZIP, and Zlib across compressed, stored-block, multi-block, incompressible, and dictionary-backed cases.
- Added ZIP tests that verify the CRC-32 written to both the local file header and the central directory header.

## v0.5.5 - 2026-03-23

### Performance

- **Specialized DEFLATE Back-Reference Copy Paths**: Reworked the back-reference copy step in `inflt()` to use three explicit paths instead of a byte-at-a-time loop: `fill()` for distance-1 runs, `blit_to()` for non-overlapping copies, and a doubling `blit_to()` strategy for overlapping matches.
- Benchmark results vs pre-optimization baseline:
  - DEFLATE decompress 100K: 102.63 µs → 29.31 µs (3.50x faster)

### Testing

- **Back-Reference Coverage**: Added 8 white-box tests for the updated inflate copy logic, covering distance-1 runs, overlapping 2/3/4-byte patterns, non-overlapping copies, mixed back-reference patterns in a single stream, and a gzip roundtrip case that exercises the same inflate paths.

## v0.5.3 - 2026-03-19

### Performance

- **32-Bit Bit Buffer for DEFLATE Decompression**: Replaced per-symbol bit-reading wrappers (`bits()` and `bits16()`) in `inflt()` with an inline 32-bit bit accumulator. By maintaining local bit states (`bbuf`, `bcnt`) and only refilling from the data buffer when necessary, byte-boundary divisions and array accesses are drastically reduced (from ~8-12 down to ~3-4 array reads per decoded symbol). This optimization yields approximately a 1.5x speedup during the decompression of 1K payloads.

### Testing & Chores

- **Bit Buffer Coverage**: Added 6 targeted test cases for the new 32-bit buffer mechanism, verifying edge cases including stored blocks alignment, fixed/dynamic Huffman trees, heavy back-references, and non-byte-aligned data bounds.

## v0.5.2 - 2026-03-17

### Performance

- **Enhanced Compressibility Detection**: Upgraded `is_compressible()` with a two-pass entropy detection mechanism for data < 8KB. By distinguishing skewed/compressible data from near-uniform random data via frequency analysis, it avoids unnecessary DEFLATE computation on incompressible inputs.

### Refactoring

- **Constants Extraction**: Extracted magic numbers and hardcoded compression thresholds (e.g., `full_scan_threshold`, `high_entropy_unique_threshold`) from `deflate.mbt` into a documented `constants.mbt` file.

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
