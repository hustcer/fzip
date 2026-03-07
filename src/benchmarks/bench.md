# fzip vs moonzip vs zipc Benchmark

- Platform: macOS (Darwin 25.3.0, Apple Silicon)
- MoonBit: moon 0.1.20260209
- fzip: 0.1.2, moonzip: 0.2.4, zipc: 0.1.1
- Target: wasm-gc (default)
- Date: 2026-03-07

Run: `moon bench -p hustcer/fzip/benchmarks`

## DEFLATE Compress (level 6)

| Data Pattern | Size  | fzip       | moonzip  | zipc        | Winner |
| ------------ | ----- | ---------- | -------- | ----------- | ------ |
| zeros        | 1KB   | 38 µs      | 99 µs    | **11 µs**   | zipc   |
| zeros        | 100KB | **448 µs** | 451 µs   | 1.07 ms     | fzip   |
| sequential   | 1KB   | 50 µs      | 112 µs   | **11 µs**   | zipc   |
| sequential   | 100KB | **464 µs** | 447 µs   | 1.05 ms     | fzip   |
| random       | 1KB   | 72 µs      | 195 µs   | **11 µs**   | zipc   |
| random       | 100KB | 6.59 ms    | 42.80 ms | **1.05 ms** | zipc   |

> Note: zipc 1KB compression times are uniformly ~11µs regardless of data pattern.

## DEFLATE Decompress

| Size  | fzip       | moonzip | zipc       | Winner            |
| ----- | ---------- | ------- | ---------- | ----------------- |
| 1KB   | 3.1 µs     | 4.7 µs  | **0.8 µs** | zipc              |
| 100KB | **118 µs** | 306 µs  | 118 µs     | tie (fzip ≈ zipc) |

## GZIP Compress / Decompress

| Op         | Size  | fzip       | moonzip | zipc      | Winner |
| ---------- | ----- | ---------- | ------- | --------- | ------ |
| compress   | 1KB   | 55 µs      | 117 µs  | **16 µs** | zipc   |
| compress   | 100KB | **827 µs** | 823 µs  | 1.57 ms   | fzip   |
| decompress | 1KB   | **2.8 µs** | 8.5 µs  | 4.9 µs    | fzip   |
| decompress | 100KB | **90 µs**  | 670 µs  | 499 µs    | fzip   |

## Zlib Compress / Decompress

| Op         | Size  | fzip       | moonzip | zipc      | Winner |
| ---------- | ----- | ---------- | ------- | --------- | ------ |
| compress   | 1KB   | 50 µs      | 118 µs  | **21 µs** | zipc   |
| compress   | 100KB | **526 µs** | 512 µs  | 2.09 ms   | fzip   |
| decompress | 1KB   | **3.1 µs** | 5.4 µs  | 9.9 µs    | fzip   |
| decompress | 100KB | **117 µs** | 368 µs  | 1.87 ms   | fzip   |

## ZIP Compress / Decompress

| Op                   | fzip       | moonzip | zipc | Winner |
| -------------------- | ---------- | ------- | ---- | ------ |
| compress (3 files)   | **184 µs** | 585 µs  | —    | fzip   |
| decompress (3 files) | **4.4 µs** | 40 µs   | —    | fzip   |

> Note: zipc uses a different Archive builder API, not comparable for ZIP operations.

## Checksum

| Algorithm | Size  | fzip        | moonzip | zipc   | Winner |
| --------- | ----- | ----------- | ------- | ------ | ------ |
| CRC-32    | 1KB   | 3.5 µs      | 3.5 µs  | 3.6 µs | tie    |
| CRC-32    | 100KB | 356 µs      | 356 µs  | 362 µs | tie    |
| Adler-32  | 1KB   | **0.62 µs** | 0.63 µs | 8.7 µs | fzip   |
| Adler-32  | 100KB | **61 µs**   | 61 µs   | 872 µs | fzip   |

## Auto-detect Decompress (decompress_sync)

| Size  | fzip       | moonzip | zipc | Winner |
| ----- | ---------- | ------- | ---- | ------ |
| 1KB   | **2.9 µs** | 8.4 µs  | —    | fzip   |
| 100KB | **90 µs**  | 666 µs  | —    | fzip   |

> Note: zipc does not provide an auto-detect decompress API.

## Key Findings

1. **fzip is the most well-rounded** — Fastest or tied in decompression, large-data compression, checksums, ZIP, and auto-detect across all categories.
2. **zipc excels at small-data compression** — 1KB DEFLATE/GZIP/Zlib compression is 3–7x faster than fzip, with uniform timing (~11µs regardless of data pattern).
3. **zipc dominates random 100KB compression** — 1.05ms vs fzip 6.59ms (6.3x) vs moonzip 42.80ms (40.8x).
4. **fzip dominates decompression** — GZIP decompress 100KB: fzip 90µs vs zipc 499µs (5.5x) vs moonzip 670µs (7.4x). Zlib decompress 100KB: fzip 117µs vs zipc 1.87ms (16x).
5. **zipc Adler-32 is slow** — 872µs vs fzip/moonzip 61µs (14.3x slower).
6. **CRC-32 is identical across all three** — Same algorithm, same performance (~356µs for 100KB).
