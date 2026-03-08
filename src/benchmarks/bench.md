# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260209 (b129ae2 2026-02-09)
- Target: wasm-gc
- Date: 2026-03-08

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| zeros   | 1K   | 6.86 µs   | 115.52 µs | 10.74 µs | fzip    | 16.8x         |
| zeros   | 100K | 451.2 µs  | 443.38 µs | 1070 µs  | moonzip | 2.4x          |
| seq     | 1K   | 14.44 µs  | 123.08 µs | 10.68 µs | zipc    | 11.5x         |
| seq     | 100K | 463.34 µs | 465.51 µs | 1080 µs  | fzip    | 2.3x          |
| random  | 1K   | 34.05 µs  | 191.71 µs | 10.9 µs  | zipc    | 17.6x         |
| random  | 100K | 98.75 µs  | 43270 µs  | 1070 µs  | fzip    | 438.2x        |

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | --------- | --------- | --------- | ------ | ------------- |
| 1K   | 3.13 µs   | 4.51 µs   | 0.77 µs   | zipc   | 5.9x          |
| 100K | 117.33 µs | 319.73 µs | 117.42 µs | fzip   | 2.7x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| compress   | 1K   | 17.94 µs  | 114.92 µs | 15.99 µs  | zipc    | 7.2x          |
| compress   | 100K | 824.18 µs | 816.69 µs | 1570 µs   | moonzip | 1.9x          |
| decompress | 1K   | 6.48 µs   | 8.38 µs   | 5.36 µs   | zipc    | 1.6x          |
| decompress | 100K | 454.53 µs | 674.51 µs | 492.69 µs | fzip    | 1.5x          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| compress   | 1K   | 14.91 µs  | 115.13 µs | 20.95 µs | fzip    | 7.7x          |
| compress   | 100K | 524.17 µs | 514.33 µs | 2090 µs  | moonzip | 4.1x          |
| decompress | 1K   | 3.8 µs    | 5.38 µs   | 10.1 µs  | fzip    | 2.7x          |
| decompress | 100K | 179.19 µs | 371.97 µs | 1890 µs  | fzip    | 10.5x         |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---------- | -------- | --------- | ------ | ------------- |
| compress   | 81.23 µs | 609.16 µs | fzip   | 7.5x          |
| decompress | 4.61 µs  | 39.48 µs  | fzip   | 8.6x          |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| CRC32     | 1K   | 3.66 µs   | 3.61 µs   | 3.62 µs   | moonzip | 1.0x          |
| CRC32     | 100K | 360.53 µs | 359.61 µs | 366.45 µs | moonzip | 1.0x          |
| ADLER32   | 1K   | 0.63 µs   | 0.64 µs   | 8.75 µs   | fzip    | 13.9x         |
| ADLER32   | 100K | 61.68 µs  | 61.56 µs  | 884.54 µs | moonzip | 14.4x         |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 6.48 µs   | 8.62 µs   | fzip   | 1.3x          |
| 100K | 458.31 µs | 691.06 µs | fzip   | 1.5x          |
