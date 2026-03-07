# TODO

## Performance Improvements

Based on benchmark comparison with moonzip (see `src/benchmarks/bench.md`).

### ~~P0: inflate 128KB minimum allocation~~ ✅

`inflt()` in `src/inflate.mbt` always called `ensure_buf(buf, bt + 131072)`, allocating at least 128KB even for tiny output.

Fixed: scaled `ensure_buf` growth relative to input size. Result: 1KB inflate 93µs → 3.1µs (**30x faster**).

### ~~P1: Remove unnecessary slc() copy in gunzip_sync~~ ✅

Added `dat_off`/`dat_end` parameters to `inflt()` to pass offset/length directly, eliminating the O(n) copy in `gunzip_sync`, `unzlib_sync`, and `unzip_sync`.

### ~~P2: Large-data compression hash strategy~~ ✅

Capped deflate hash table to 32K entries matching the sliding window size. Result: 100KB zeros/sequential compress ~780µs → ~450µs (**1.7x faster**, now tied with moonzip).

### ~~P3: Reduce slc() copies across codebase~~ ✅

`dflt()`/`dopt()`/`inflt()` now return `(FixedArray[Byte], Int)` tuples, deferring `slc()` to public API boundaries. `str_from_u8()` gained `offset`/`len` parameters to avoid `slc()` in ZIP filename extraction. `zip_sync()` calls `dopt()` directly, eliminating one intermediate `slc()` per file.

Result: 100KB deflate decompress 187µs → 131µs (**1.4x**), 100KB zlib decompress 183µs → 120µs (**1.5x**), 100KB gzip/zlib compress **1.4–1.6x faster**.

## Current Status

After P0–P3, fzip wins or ties moonzip on every benchmark. See `src/benchmarks/bench.md` for full results.
