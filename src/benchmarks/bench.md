# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260209 (b129ae2 2026-02-09)
- Target: wasm-gc
- Date: 2026-03-07

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| zeros   | 1K   | 39.47 µs  | 104.32 µs | 10.55 µs | zipc    | 9.9x          |
| zeros   | 100K | 464.03 µs | 459.44 µs | 1050 µs  | moonzip | 2.3x          |
| seq     | 1K   | 49.12 µs  | 118.23 µs | 10.72 µs | zipc    | 11.0x         |
| seq     | 100K | 459.18 µs | 438.98 µs | 1050 µs  | moonzip | 2.4x          |
| random  | 1K   | 68.94 µs  | 183.93 µs | 10.94 µs | zipc    | 16.8x         |
| random  | 100K | 6500 µs   | 43190 µs  | 1050 µs  | zipc    | 41.1x         |

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | --------- | --------- | --------- | ------ | ------------- |
| 1K   | 3.04 µs   | 4.42 µs   | 0.78 µs   | zipc   | 5.7x          |
| 100K | 116.84 µs | 303.37 µs | 117.46 µs | fzip   | 2.6x          |

## GZIP

| Operation  | Size | fzip     | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---------- | ---- | -------- | --------- | --------- | ------ | ------------- |
| compress   | 1K   | 54.59 µs | 120.86 µs | 15.61 µs  | zipc   | 7.7x          |
| compress   | 100K | 824.1 µs | 883.04 µs | 1550 µs   | fzip   | 1.9x          |
| decompress | 1K   | 2.91 µs  | 8.49 µs   | 4.9 µs    | fzip   | 2.9x          |
| decompress | 100K | 89.88 µs | 737.72 µs | 504.82 µs | fzip   | 8.2x          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| compress   | 1K   | 52.83 µs  | 112.39 µs | 20.73 µs | zipc    | 5.4x          |
| compress   | 100K | 525.23 µs | 524.23 µs | 2110 µs  | moonzip | 4.0x          |
| decompress | 1K   | 3.17 µs   | 5.32 µs   | 9.97 µs  | fzip    | 3.1x          |
| decompress | 100K | 116.41 µs | 365.7 µs  | 1870 µs  | fzip    | 16.1x         |

## ZIP

| Operation  | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---------- | --------- | --------- | ------ | ------------- |
| compress   | 187.67 µs | 598.98 µs | fzip   | 3.2x          |
| decompress | 4.52 µs   | 38.97 µs  | fzip   | 8.6x          |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| CRC32     | 1K   | 3.51 µs   | 3.52 µs   | 3.58 µs   | fzip    | 1.0x          |
| CRC32     | 100K | 362.71 µs | 356.28 µs | 358.71 µs | moonzip | 1.0x          |
| ADLER32   | 1K   | 0.63 µs   | 0.63 µs   | 8.67 µs   | fzip    | 13.8x         |
| ADLER32   | 100K | 61.97 µs  | 61.26 µs  | 870.68 µs | moonzip | 14.2x         |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 2.87 µs  | 8.3 µs    | fzip   | 2.9x          |
| 100K | 89.71 µs | 668.27 µs | fzip   | 7.4x          |
