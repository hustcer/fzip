# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260209 (b129ae2 2026-02-09)
- Target: wasm-gc
- Date: 2026-03-07

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| zeros   | 1K   | 6.75 µs   | 104.06 µs | 10.61 µs | fzip    | 15.4x         |
| zeros   | 100K | 468.35 µs | 440.02 µs | 1050 µs  | moonzip | 2.4x          |
| seq     | 1K   | 15.29 µs  | 118.98 µs | 10.58 µs | zipc    | 11.2x         |
| seq     | 100K | 466.97 µs | 459.3 µs  | 1070 µs  | moonzip | 2.3x          |
| random  | 1K   | 43.34 µs  | 193.01 µs | 10.59 µs | zipc    | 18.2x         |
| random  | 100K | 3390 µs   | 42450 µs  | 1060 µs  | zipc    | 40.0x         |

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio |
| ---- | --------- | --------- | -------- | ------ | ------------- |
| 1K   | 3.08 µs   | 4.48 µs   | 0.77 µs  | zipc   | 5.8x          |
| 100K | 116.99 µs | 304.49 µs | 117.8 µs | fzip   | 2.6x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| compress   | 1K   | 19.05 µs  | 127.83 µs | 15.7 µs   | zipc    | 8.1x          |
| compress   | 100K | 839.37 µs | 812.23 µs | 1550 µs   | moonzip | 1.9x          |
| decompress | 1K   | 2.83 µs   | 8.35 µs   | 4.86 µs   | fzip    | 3.0x          |
| decompress | 100K | 90.6 µs   | 670.84 µs | 486.32 µs | fzip    | 7.4x          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| compress   | 1K   | 16.1 µs   | 123.87 µs | 20.76 µs | fzip    | 7.7x          |
| compress   | 100K | 532.42 µs | 508.66 µs | 2060 µs  | moonzip | 4.0x          |
| decompress | 1K   | 3.15 µs   | 5.38 µs   | 9.99 µs  | fzip    | 3.2x          |
| decompress | 100K | 117.48 µs | 366.9 µs  | 1870 µs  | fzip    | 15.9x         |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---------- | -------- | --------- | ------ | ------------- |
| compress   | 92.67 µs | 592.65 µs | fzip   | 6.4x          |
| decompress | 4.47 µs  | 38.86 µs  | fzip   | 8.7x          |

## Checksum

| Algorithm | Size | fzip      | moonzip  | zipc      | Winner  | Max-Min Ratio |
| --------- | ---- | --------- | -------- | --------- | ------- | ------------- |
| CRC32     | 1K   | 3.52 µs   | 3.52 µs  | 3.59 µs   | fzip    | 1.0x          |
| CRC32     | 100K | 356.31 µs | 357.5 µs | 371.89 µs | fzip    | 1.0x          |
| ADLER32   | 1K   | 0.62 µs   | 0.63 µs  | 8.71 µs   | fzip    | 14.0x         |
| ADLER32   | 100K | 61.43 µs  | 61.34 µs | 875.38 µs | moonzip | 14.3x         |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 2.85 µs  | 8.37 µs   | fzip   | 2.9x          |
| 100K | 90.12 µs | 663.28 µs | fzip   | 7.4x          |
