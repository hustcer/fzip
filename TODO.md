# TODO

## Performance Improvements

Based on benchmark comparison with moonzip (see `src/benchmarks/bench.md`).

### P0: inflate 128KB minimum allocation

`inflt()` in `src/inflate.mbt` always calls `ensure_buf(buf, bt + 131072)`, allocating at least 128KB even for tiny output. Then `slc()` copies again to right-size. This causes `inflate_sync`/`unzlib_sync` to be **18~21x slower** than moonzip for 1KB data (93µs vs 4.4µs), while `gunzip_sync` (which pre-allocates exact size from GZIP footer) only takes 2.8µs.

Fix: scale `ensure_buf` growth relative to input size instead of hardcoding 131072.

### P1: Remove unnecessary slc() copy in gunzip_sync

`gunzip_sync` (`src/gzip.mbt:103`) copies compressed data with `slc(data, st, e=data.length()-8)` before decompressing. This O(n) copy can be avoided by passing offset/length to `inflt()` directly.

Expected: ~10-20% improvement on GZIP decompression.

### P2: Large-data compression hash strategy

100KB compression of regular patterns (zeros/sequential) is **1.4~1.8x slower** than moonzip. `compute_mem_level` in `src/deflate.mbt` may produce suboptimal hash table sizes, and hash chain traversal efficiency may have room for improvement.

### P3: Reduce slc() copies across codebase

`slc()` always allocates + copies. Key sites:

- `dflt()` L356: truncates output buffer after compression
- `inflt()` L271-274: truncates output after decompression
- Various format wrappers

Consider length-tracking or buffer views to avoid O(n) copies.
