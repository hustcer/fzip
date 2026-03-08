# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260209 (b129ae2 2026-02-09)
- Target: wasm-gc
- Date: 2026-03-08

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| zeros   | 1K   | 6.83 µs   | 100.95 µs | 10.67 µs | fzip    | 14.8x         |
| zeros   | 100K | 450.57 µs | 434.26 µs | 1050 µs  | moonzip | 2.4x          |
| seq     | 1K   | 14.36 µs  | 111.91 µs | 10.53 µs | zipc    | 10.6x         |
| seq     | 100K | 460.71 µs | 454.81 µs | 1060 µs  | moonzip | 2.3x          |
| random  | 1K   | 33.84 µs  | 183.75 µs | 10.54 µs | zipc    | 17.4x         |
| random  | 100K | 97.82 µs  | 42610 µs  | 1090 µs  | fzip    | 435.6x        |

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | --------- | --------- | --------- | ------ | ------------- |
| 1K   | 3.1 µs    | 4.46 µs   | 0.77 µs   | zipc   | 5.8x          |
| 100K | 116.71 µs | 309.11 µs | 117.21 µs | fzip   | 2.6x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| compress   | 1K   | 17.93 µs  | 115.32 µs | 15.81 µs  | zipc    | 7.3x          |
| compress   | 100K | 823.92 µs | 816.43 µs | 1550 µs   | moonzip | 1.9x          |
| decompress | 1K   | 2.82 µs   | 8.22 µs   | 4.82 µs   | fzip    | 2.9x          |
| decompress | 100K | 89.51 µs  | 661.65 µs | 481.23 µs | fzip    | 7.4x          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| compress   | 1K   | 14.9 µs   | 115.27 µs | 20.56 µs | fzip    | 7.7x          |
| compress   | 100K | 524.94 µs | 509.64 µs | 2120 µs  | moonzip | 4.2x          |
| decompress | 1K   | 3.11 µs   | 5.32 µs   | 9.91 µs  | fzip    | 3.2x          |
| decompress | 100K | 117.32 µs | 369.84 µs | 1870 µs  | fzip    | 15.9x         |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---------- | -------- | --------- | ------ | ------------- |
| compress   | 81.27 µs | 612.03 µs | fzip   | 7.5x          |
| decompress | 4.44 µs  | 39.21 µs  | fzip   | 8.8x          |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| CRC32     | 1K   | 3.51 µs   | 3.52 µs   | 3.57 µs   | fzip    | 1.0x          |
| CRC32     | 100K | 363.44 µs | 355.19 µs | 360.98 µs | moonzip | 1.0x          |
| ADLER32   | 1K   | 0.63 µs   | 0.62 µs   | 8.67 µs   | moonzip | 14.0x         |
| ADLER32   | 100K | 61.18 µs  | 60.85 µs  | 872.22 µs | moonzip | 14.3x         |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 2.85 µs  | 8.55 µs   | fzip   | 3.0x          |
| 100K | 89.25 µs | 672.75 µs | fzip   | 7.5x          |
