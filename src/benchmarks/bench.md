# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260309 (f21b520 2026-03-09)
- Target: wasm-gc
- Date: 2026-03-13

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio |
| ------- | ---- | --------- | --------- | -------- | ------ | ------------- |
| zeros   | 1K   | 6.49 µs   | 100.88 µs | 10.76 µs | fzip   | 15.5x         |
| zeros   | 100K | 430.2 µs  | 438.09 µs | 1070 µs  | fzip   | 2.5x          |
| seq     | 1K   | 13.89 µs  | 116.42 µs | 10.57 µs | zipc   | 11.0x         |
| seq     | 100K | 433.09 µs | 460.6 µs  | 1090 µs  | fzip   | 2.5x          |
| random  | 1K   | 33.69 µs  | 186.81 µs | 10.62 µs | zipc   | 17.6x         |
| random  | 100K | 97.7 µs   | 42610 µs  | 1060 µs  | fzip   | 436.1x        |

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | --------- | --------- | --------- | ------ | ------------- |
| 1K   | 3.11 µs   | 4.4 µs    | 0.77 µs   | zipc   | 5.7x          |
| 100K | 116.04 µs | 308.73 µs | 116.38 µs | fzip   | 2.7x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------ | ------------- |
| compress   | 1K   | 17.4 µs   | 121.47 µs | 15.86 µs  | zipc   | 7.7x          |
| compress   | 100K | 791.01 µs | 807.17 µs | 1570 µs   | fzip   | 2.0x          |
| decompress | 1K   | 6.44 µs   | 8.25 µs   | 4.81 µs   | zipc   | 1.7x          |
| decompress | 100K | 450.02 µs | 668.68 µs | 483.98 µs | fzip   | 1.5x          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------ | ------------- |
| compress   | 1K   | 14.46 µs  | 122.36 µs | 22.2 µs  | fzip   | 8.5x          |
| compress   | 100K | 492.71 µs | 506.49 µs | 2090 µs  | fzip   | 4.2x          |
| decompress | 1K   | 3.51 µs   | 5.45 µs   | 10.21 µs | fzip   | 2.9x          |
| decompress | 100K | 155.93 µs | 371.4 µs  | 1880 µs  | fzip   | 12.1x         |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---------- | -------- | --------- | ------ | ------------- |
| compress   | 79.59 µs | 621.54 µs | fzip   | 7.8x          |
| decompress | 4.56 µs  | 38.84 µs  | fzip   | 8.5x          |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| CRC32     | 1K   | 3.56 µs   | 3.55 µs   | 3.59 µs   | moonzip | 1.0x          |
| CRC32     | 100K | 356.81 µs | 356.95 µs | 365.2 µs  | fzip    | 1.0x          |
| ADLER32   | 1K   | 0.39 µs   | 0.62 µs   | 8.73 µs   | fzip    | 22.4x         |
| ADLER32   | 100K | 38.82 µs  | 61 µs     | 878.61 µs | fzip    | 22.6x         |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 6.41 µs  | 8.45 µs   | fzip   | 1.3x          |
| 100K | 452.1 µs | 665.49 µs | fzip   | 1.5x          |
