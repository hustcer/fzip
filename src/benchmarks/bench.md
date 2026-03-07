# fzip vs moonzip Benchmark

- Platform: macOS (Darwin 25.3.0, Apple Silicon)
- MoonBit: moon 0.1.20260209
- fzip: 0.1.0, moonzip: 0.2.4
- Target: wasm-gc (default)
- Date: 2026-03-07 (after P0–P3 optimizations)

Run: `moon bench -p benchmarks`

## DEFLATE Compress (level 6)

| Data Pattern | Size  | fzip    | moonzip  | Winner   | Speedup  |
| ------------ | ----- | ------- | -------- | -------- | -------- |
| zeros        | 1KB   | 38 µs   | 112 µs   | **fzip** | 2.9x     |
| zeros        | 100KB | 447 µs  | 456 µs   | tie      | —        |
| sequential   | 1KB   | 52 µs   | 119 µs   | **fzip** | 2.3x     |
| sequential   | 100KB | 460 µs  | 452 µs   | tie      | —        |
| random       | 1KB   | 80 µs   | 210 µs   | **fzip** | 2.6x     |
| random       | 100KB | 6.45 ms | 43.88 ms | **fzip** | **6.8x** |

## DEFLATE Decompress

| Size  | fzip   | moonzip | Winner   | Speedup |
| ----- | ------ | ------- | -------- | ------- |
| 1KB   | 3.1 µs | 4.4 µs  | **fzip** | 1.4x    |
| 100KB | 131 µs | 329 µs  | **fzip** | 2.5x    |

## GZIP Compress / Decompress

| Op         | Size  | fzip   | moonzip | Winner   | Speedup  |
| ---------- | ----- | ------ | ------- | -------- | -------- |
| compress   | 1KB   | 53 µs  | 129 µs  | **fzip** | 2.4x     |
| compress   | 100KB | 844 µs | 910 µs  | **fzip** | 1.1x     |
| decompress | 1KB   | 2.9 µs | 8.2 µs  | **fzip** | 2.8x     |
| decompress | 100KB | 89 µs  | 658 µs  | **fzip** | **7.4x** |

## Zlib Compress / Decompress

| Op         | Size  | fzip   | moonzip | Winner   | Speedup |
| ---------- | ----- | ------ | ------- | -------- | ------- |
| compress   | 1KB   | 53 µs  | 123 µs  | **fzip** | 2.3x    |
| compress   | 100KB | 534 µs | 512 µs  | tie      | —       |
| decompress | 1KB   | 3.2 µs | 5.9 µs  | **fzip** | 1.8x    |
| decompress | 100KB | 120 µs | 369 µs  | **fzip** | 3.1x    |

## ZIP Compress / Decompress

| Op                   | fzip   | moonzip | Winner   | Speedup  |
| -------------------- | ------ | ------- | -------- | -------- |
| compress (3 files)   | 212 µs | 636 µs  | **fzip** | 3.0x     |
| decompress (3 files) | 4.8 µs | 39 µs   | **fzip** | **8.2x** |

## Checksum

| Algorithm | Size  | fzip    | moonzip | Result |
| --------- | ----- | ------- | ------- | ------ |
| CRC-32    | 1KB   | 3.6 µs  | 3.8 µs  | tie    |
| CRC-32    | 100KB | 359 µs  | 370 µs  | tie    |
| Adler-32  | 1KB   | 0.61 µs | 0.63 µs | tie    |
| Adler-32  | 100KB | 61 µs   | 61 µs   | tie    |

## Auto-detect Decompress (decompress_sync)

| Size  | fzip   | moonzip | Winner   | Speedup  |
| ----- | ------ | ------- | -------- | -------- |
| 1KB   | 2.8 µs | 8.4 µs  | **fzip** | 3.0x     |
| 100KB | 89 µs  | 656 µs  | **fzip** | **7.4x** |

## Key Findings

1. **fzip wins across the board** — After P0–P3 optimizations, fzip is faster or tied in every benchmark category.
2. **Small-data decompression fixed** — 1KB `inflate_sync` went from 93µs → 3.1µs (30x improvement, P0 buffer fix). 1KB `unzlib_sync` went from 95µs → 3.2µs.
3. **Large-data compression now tied** — 100KB zeros/sequential compression went from 1.4–1.8x slower than moonzip to essentially tied (~450µs both).
4. **fzip decompression dominates** — GZIP/ZIP/auto-detect decompress is **3–8x** faster.
5. **fzip small-data compression wins** — 1KB compression is consistently **2–3x** faster.
6. **fzip dominates random data** — random 100KB is **6.8x** faster (moonzip 44ms vs fzip 6.5ms).
7. **Checksums identical** — CRC-32/Adler-32 performance is the same (same algorithm).

## Improvement Summary (P0–P3)

| Metric                   | Before  | After  | Improvement      |
| ------------------------ | ------- | ------ | ---------------- |
| 1KB inflate_sync         | 93 µs   | 3.1 µs | **30x** (P0)     |
| 1KB unzlib decompress    | 95 µs   | 3.2 µs | **30x** (P0)     |
| 100KB zeros compress     | 783 µs  | 447 µs | **1.8x** (P2)    |
| 100KB seq compress       | 778 µs  | 460 µs | **1.7x** (P2)    |
| 100KB gzip compress      | 1.16 ms | 844 µs | **1.4x** (P2+P3) |
| 100KB zlib compress      | 853 µs  | 534 µs | **1.6x** (P2+P3) |
| 100KB deflate decompress | 187 µs  | 131 µs | **1.4x** (P3)    |
| 100KB zlib decompress    | 183 µs  | 120 µs | **1.5x** (P3)    |
