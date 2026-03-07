# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260209 (b129ae2 2026-02-09)
- Target: wasm-gc
- Date: 2026-03-07

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| zeros   | 1K   | 37.03 µs  | 104.96 µs | 10.53 µs | zipc    | 10.0x         |
| zeros   | 100K | 447.01 µs | 431.52 µs | 1060 ms  | moonzip | 2456.4x       |
| seq     | 1K   | 49.2 µs   | 122.05 µs | 10.5 µs  | zipc    | 11.6x         |
| seq     | 100K | 457.6 µs  | 443.09 µs | 1050 ms  | moonzip | 2369.7x       |
| random  | 1K   | 68.48 µs  | 188.36 µs | 10.58 µs | zipc    | 17.8x         |
| random  | 100K | 6460 ms   | 42220 ms  | 1050 ms  | zipc    | 40.2x         |

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | --------- | --------- | --------- | ------ | ------------- |
| 1K   | 3.06 µs   | 4.4 µs    | 0.76 µs   | zipc   | 5.8x          |
| 100K | 115.22 µs | 303.74 µs | 116.37 µs | fzip   | 2.6x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| compress   | 1K   | 53.15 µs  | 112.45 µs | 15.69 µs  | zipc    | 7.2x          |
| compress   | 100K | 809.04 µs | 803.18 µs | 1550 ms   | moonzip | 1929.8x       |
| decompress | 1K   | 2.85 µs   | 8.23 µs   | 4.79 µs   | fzip    | 2.9x          |
| decompress | 100K | 89.47 µs  | 657.03 µs | 485.31 µs | fzip    | 7.3x          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner  | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------- | ------------- |
| compress   | 1K   | 50.59 µs  | 113.14 µs | 20.68 µs | zipc    | 5.5x          |
| compress   | 100K | 520.55 µs | 503.61 µs | 2050 ms  | moonzip | 4070.6x       |
| decompress | 1K   | 3.05 µs   | 5.24 µs   | 9.94 µs  | fzip    | 3.3x          |
| decompress | 100K | 115.81 µs | 363.99 µs | 1870 ms  | fzip    | 16147.1x      |

## ZIP

| Operation  | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---------- | --------- | --------- | ------ | ------------- |
| compress   | 179.82 µs | 584.78 µs | fzip   | 3.3x          |
| decompress | 4.37 µs   | 38.52 µs  | fzip   | 8.8x          |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| CRC32     | 1K   | 3.52 µs   | 3.56 µs   | 3.56 µs   | fzip    | 1.0x          |
| CRC32     | 100K | 354.51 µs | 354.44 µs | 359.38 µs | moonzip | 1.0x          |
| ADLER32   | 1K   | 0.61 µs   | 0.62 µs   | 8.68 µs   | fzip    | 14.2x         |
| ADLER32   | 100K | 60.85 µs  | 60.33 µs  | 869.6 µs  | moonzip | 14.4x         |

## Auto-detect Decompress

| Size | fzip     | moonzip  | Winner | Max-Min Ratio |
| ---- | -------- | -------- | ------ | ------------- |
| 1K   | 2.81 µs  | 8.25 µs  | fzip   | 2.9x          |
| 100K | 88.24 µs | 657.2 µs | fzip   | 7.4x          |
