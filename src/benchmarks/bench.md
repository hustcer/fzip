# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260209 (b129ae2 2026-02-09)
- Target: wasm-gc
- Date: 2026-03-07

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| zeros   | 1K   | 6.58 µs   | 105.62 µs | 11.06 µs | fzip    | 16.1x         |
| zeros   | 100K | 462.56 µs | 441.03 µs | 1070 µs  | moonzip | 2.4x          |
| seq     | 1K   | 15.41 µs  | 116.55 µs | 10.68 µs | zipc    | 10.9x         |
| seq     | 100K | 476.38 µs | 447.06 µs | 1080 µs  | moonzip | 2.4x          |
| random  | 1K   | 34.15 µs  | 190.05 µs | 10.69 µs | zipc    | 17.8x         |
| random  | 100K | 98.36 µs  | 43000 µs  | 1070 µs  | fzip    | 437.2x        |

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio |
| ---- | --------- | --------- | -------- | ------ | ------------- |
| 1K   | 3.14 µs   | 4.41 µs   | 0.77 µs  | zipc   | 5.7x          |
| 100K | 117.25 µs | 302.96 µs | 117.3 µs | fzip   | 2.6x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| compress   | 1K   | 18.97 µs  | 120.92 µs | 15.96 µs  | zipc    | 7.6x          |
| compress   | 100K | 828.35 µs | 814.32 µs | 1570 µs   | moonzip | 1.9x          |
| decompress | 1K   | 2.86 µs   | 8.29 µs   | 4.88 µs   | fzip    | 2.9x          |
| decompress | 100K | 89.49 µs  | 678.67 µs | 488.67 µs | fzip    | 7.6x          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| compress   | 1K   | 16.04 µs  | 118.21 µs | 20.96 µs | fzip    | 7.4x          |
| compress   | 100K | 528.83 µs | 508.92 µs | 2090 µs  | moonzip | 4.1x          |
| decompress | 1K   | 3.15 µs   | 5.3 µs    | 10.23 µs | fzip    | 3.2x          |
| decompress | 100K | 117.42 µs | 365.29 µs | 1900 µs  | fzip    | 16.2x         |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---------- | -------- | --------- | ------ | ------------- |
| compress   | 82.66 µs | 598.06 µs | fzip   | 7.2x          |
| decompress | 4.44 µs  | 39.16 µs  | fzip   | 8.8x          |

## Checksum

| Algorithm | Size | fzip      | moonzip  | zipc      | Winner  | Max-Min Ratio |
| --------- | ---- | --------- | -------- | --------- | ------- | ------------- |
| CRC32     | 1K   | 3.58 µs   | 3.57 µs  | 3.63 µs   | moonzip | 1.0x          |
| CRC32     | 100K | 360.77 µs | 361.8 µs | 377.23 µs | fzip    | 1.0x          |
| ADLER32   | 1K   | 0.64 µs   | 0.63 µs  | 8.8 µs    | moonzip | 14.0x         |
| ADLER32   | 100K | 61.38 µs  | 61.15 µs | 885.42 µs | moonzip | 14.5x         |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 2.86 µs  | 8.35 µs   | fzip   | 2.9x          |
| 100K | 89.72 µs | 666.65 µs | fzip   | 7.4x          |
