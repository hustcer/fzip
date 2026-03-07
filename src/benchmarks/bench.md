# fzip vs moonzip Benchmark

- Platform: macOS (Darwin 25.3.0, Apple Silicon)
- MoonBit: moon 0.1.20260209
- fzip: 0.1.0, moonzip: 0.2.4
- Target: wasm-gc (default)
- Date: 2026-03-07

Run: `moon bench -p benchmarks`

## DEFLATE Compress (level 6)

| Data Pattern | Size  | fzip    | moonzip  | Winner      | Speedup   |
| ------------ | ----- | ------- | -------- | ----------- | --------- |
| zeros        | 1KB   | 39 µs   | 111 µs   | **fzip**    | 2.8x      |
| zeros        | 100KB | 783 µs  | 440 µs   | **moonzip** | 1.8x      |
| sequential   | 1KB   | 51 µs   | 119 µs   | **fzip**    | 2.4x      |
| sequential   | 100KB | 778 µs  | 450 µs   | **moonzip** | 1.7x      |
| random       | 1KB   | 71 µs   | 198 µs   | **fzip**    | 2.8x      |
| random       | 100KB | 2.75 ms | 42.65 ms | **fzip**    | **15.5x** |

## DEFLATE Decompress

| Size  | fzip   | moonzip | Winner      | Speedup |
| ----- | ------ | ------- | ----------- | ------- |
| 1KB   | 93 µs  | 4.4 µs  | **moonzip** | 21x     |
| 100KB | 187 µs | 304 µs  | **fzip**    | 1.6x    |

## GZIP Compress / Decompress

| Op         | Size  | fzip    | moonzip | Winner      | Speedup  |
| ---------- | ----- | ------- | ------- | ----------- | -------- |
| compress   | 1KB   | 55 µs   | 124 µs  | **fzip**    | 2.3x     |
| compress   | 100KB | 1.16 ms | 814 µs  | **moonzip** | 1.4x     |
| decompress | 1KB   | 2.8 µs  | 8.3 µs  | **fzip**    | 2.9x     |
| decompress | 100KB | 91 µs   | 661 µs  | **fzip**    | **7.3x** |

## Zlib Compress / Decompress

| Op         | Size  | fzip   | moonzip | Winner      | Speedup |
| ---------- | ----- | ------ | ------- | ----------- | ------- |
| compress   | 1KB   | 52 µs  | 126 µs  | **fzip**    | 2.4x    |
| compress   | 100KB | 853 µs | 518 µs  | **moonzip** | 1.6x    |
| decompress | 1KB   | 95 µs  | 5.3 µs  | **moonzip** | 18x     |
| decompress | 100KB | 183 µs | 367 µs  | **fzip**    | 2.0x    |

## ZIP Compress / Decompress

| Op                   | fzip   | moonzip | Winner   | Speedup  |
| -------------------- | ------ | ------- | -------- | -------- |
| compress (3 files)   | 221 µs | 625 µs  | **fzip** | 2.8x     |
| decompress (3 files) | 4.6 µs | 40 µs   | **fzip** | **8.7x** |

## Checksum

| Algorithm | Size  | fzip    | moonzip | Result |
| --------- | ----- | ------- | ------- | ------ |
| CRC-32    | 1KB   | 3.7 µs  | 3.5 µs  | tie    |
| CRC-32    | 100KB | 391 µs  | 369 µs  | tie    |
| Adler-32  | 1KB   | 0.63 µs | 0.63 µs | tie    |
| Adler-32  | 100KB | 62 µs   | 62 µs   | tie    |

## Auto-detect Decompress (decompress_sync)

| Size  | fzip   | moonzip | Winner   | Speedup  |
| ----- | ------ | ------- | -------- | -------- |
| 1KB   | 2.9 µs | 8.7 µs  | **fzip** | 3.1x     |
| 100KB | 91 µs  | 666 µs  | **fzip** | **7.3x** |

## Key Findings

1. **fzip decompression wins big** — GZIP/ZIP/auto-detect decompress is **3~9x** faster because `gunzip_sync` pre-allocates output buffer from GZIP footer size.
2. **fzip small-data compression wins** — 1KB compression is consistently **2~3x** faster.
3. **moonzip large-data regular compression wins** — 100KB zeros/sequential compression is **1.4~1.8x** faster.
4. **fzip dominates random data** — random 100KB is **15.5x** faster (moonzip 42ms vs fzip 2.75ms).
5. **Checksums identical** — CRC-32/Adler-32 performance is the same (same algorithm).
6. **fzip raw inflate small-data bottleneck** — 1KB `inflate_sync`/`unzlib_sync` is 18~21x slower than moonzip, likely due to buffer allocation strategy (`gunzip_sync` avoids this by pre-knowing output size).
