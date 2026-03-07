# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260209 (b129ae2 2026-02-09)
- Target: wasm-gc
- Date: 2026-03-07

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| zeros   | 1K   | 36.93 µs  | 108.22 µs | 10.51 µs | zipc    | 10.3x         |
| zeros   | 100K | 447.83 µs | 438.81 µs | 1070 µs  | moonzip | 2.4x          |
| seq     | 1K   | 49.24 µs  | 110.81 µs | 10.49 µs | zipc    | 10.6x         |
| seq     | 100K | 459.3 µs  | 445.76 µs | 1050 µs  | moonzip | 2.4x          |
| random  | 1K   | 69.66 µs  | 205.75 µs | 10.5 µs  | zipc    | 19.6x         |
| random  | 100K | 6560 µs   | 42650 µs  | 1050 µs  | zipc    | 40.6x         |

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | --------- | --------- | --------- | ------ | ------------- |
| 1K   | 3.07 µs   | 4.45 µs   | 0.77 µs   | zipc   | 5.8x          |
| 100K | 119.27 µs | 304.15 µs | 117.38 µs | zipc   | 2.6x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| compress   | 1K   | 54.36 µs  | 120.13 µs | 15.6 µs  | zipc    | 7.7x          |
| compress   | 100K | 826.17 µs | 812.54 µs | 1570 µs  | moonzip | 1.9x          |
| decompress | 1K   | 2.94 µs   | 8.52 µs   | 4.89 µs  | fzip    | 2.9x          |
| decompress | 100K | 89.37 µs  | 667.03 µs | 491.8 µs | fzip    | 7.5x          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| compress   | 1K   | 54.35 µs  | 118.4 µs  | 20.61 µs | zipc    | 5.7x          |
| compress   | 100K | 526.79 µs | 513.91 µs | 2070 µs  | moonzip | 4.0x          |
| decompress | 1K   | 3.11 µs   | 5.32 µs   | 9.91 µs  | fzip    | 3.2x          |
| decompress | 100K | 118.3 µs  | 366.08 µs | 1910 µs  | fzip    | 16.1x         |

## ZIP

| Operation  | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---------- | --------- | --------- | ------ | ------------- |
| compress   | 183.51 µs | 618.26 µs | fzip   | 3.4x          |
| decompress | 4.45 µs   | 38.88 µs  | fzip   | 8.7x          |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| CRC32     | 1K   | 3.59 µs   | 3.52 µs   | 3.56 µs   | moonzip | 1.0x          |
| CRC32     | 100K | 358.56 µs | 364.74 µs | 359.19 µs | fzip    | 1.0x          |
| ADLER32   | 1K   | 0.63 µs   | 0.63 µs   | 8.71 µs   | fzip    | 13.8x         |
| ADLER32   | 100K | 61.77 µs  | 61.92 µs  | 876.25 µs | fzip    | 14.2x         |

## Auto-detect Decompress

| Size | fzip     | moonzip  | Winner | Max-Min Ratio |
| ---- | -------- | -------- | ------ | ------------- |
| 1K   | 2.9 µs   | 8.3 µs   | fzip   | 2.9x          |
| 100K | 90.35 µs | 679.6 µs | fzip   | 7.5x          |
