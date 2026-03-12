# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260309 (f21b520 2026-03-09)
- Target: wasm-gc
- Date: 2026-03-12

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio |
| ------- | ---- | --------- | --------- | -------- | ------ | ------------- |
| zeros   | 1K   | 7.04 µs   | 114.92 µs | 11.01 µs | fzip   | 16.3x         |
| zeros   | 100K | 465.35 µs | 492.1 µs  | 1110 µs  | fzip   | 2.4x          |
| seq     | 1K   | 14.77 µs  | 136.53 µs | 11.2 µs  | zipc   | 12.2x         |
| seq     | 100K | 480.02 µs | 501.36 µs | 1110 µs  | fzip   | 2.3x          |
| random  | 1K   | 35.16 µs  | 211.54 µs | 11 µs    | zipc   | 19.2x         |
| random  | 100K | 105.39 µs | 44870 µs  | 1120 µs  | fzip   | 425.8x        |

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | --------- | --------- | --------- | ------ | ------------- |
| 1K   | 3.34 µs   | 4.81 µs   | 0.8 µs    | zipc   | 6.0x          |
| 100K | 126.06 µs | 325.62 µs | 121.12 µs | zipc   | 2.7x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------ | ------------- |
| compress   | 1K   | 18.49 µs  | 132.02 µs | 16.38 µs | zipc   | 8.1x          |
| compress   | 100K | 853.31 µs | 854.3 µs  | 1620 µs  | fzip   | 1.9x          |
| decompress | 1K   | 6.73 µs   | 8.7 µs    | 5.02 µs  | zipc   | 1.7x          |
| decompress | 100K | 472.18 µs | 705.57 µs | 511.8 µs | fzip   | 1.5x          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| compress   | 1K   | 15.66 µs  | 131.74 µs | 22.02 µs | fzip    | 8.4x          |
| compress   | 100K | 540.03 µs | 533.66 µs | 2160 µs  | moonzip | 4.0x          |
| decompress | 1K   | 4.16 µs   | 5.57 µs   | 10.4 µs  | fzip    | 2.5x          |
| decompress | 100K | 188.25 µs | 393.08 µs | 1960 µs  | fzip    | 10.4x         |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---------- | -------- | --------- | ------ | ------------- |
| compress   | 83.94 µs | 644.41 µs | fzip   | 7.7x          |
| decompress | 4.8 µs   | 40.16 µs  | fzip   | 8.4x          |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| CRC32     | 1K   | 3.65 µs   | 3.65 µs   | 3.74 µs   | fzip    | 1.0x          |
| CRC32     | 100K | 368.99 µs | 368.52 µs | 377.35 µs | moonzip | 1.0x          |
| ADLER32   | 1K   | 0.65 µs   | 0.64 µs   | 9 µs      | moonzip | 14.1x         |
| ADLER32   | 100K | 63.78 µs  | 63.2 µs   | 904.24 µs | moonzip | 14.3x         |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 6.6 µs    | 8.57 µs   | fzip   | 1.3x          |
| 100K | 467.83 µs | 686.18 µs | fzip   | 1.5x          |
