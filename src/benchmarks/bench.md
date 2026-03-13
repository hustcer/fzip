# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260309 (f21b520 2026-03-09)
- Target: wasm-gc
- Date: 2026-03-13

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio |
| ------- | ---- | --------- | --------- | -------- | ------ | ------------- |
| zeros   | 1K   | 4.13 µs   | 106.55 µs | 10.64 µs | fzip   | 25.8x         |
| zeros   | 100K | 101.06 µs | 447.53 µs | 1070 µs  | fzip   | 10.6x         |
| seq     | 1K   | 12.62 µs  | 114.75 µs | 10.65 µs | zipc   | 10.8x         |
| seq     | 100K | 121.46 µs | 463.12 µs | 1090 µs  | fzip   | 9.0x          |
| random  | 1K   | 33.88 µs  | 208.77 µs | 10.63 µs | zipc   | 19.6x         |
| random  | 100K | 98.06 µs  | 42930 µs  | 1070 µs  | fzip   | 437.8x        |

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | --------- | --------- | --------- | ------ | ------------- |
| 1K   | 3.11 µs   | 4.48 µs   | 0.78 µs   | zipc   | 5.7x          |
| 100K | 105.17 µs | 308.61 µs | 117.03 µs | fzip   | 2.9x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------ | ------------- |
| compress   | 1K   | 15.78 µs  | 121.52 µs | 15.72 µs  | zipc   | 7.7x          |
| compress   | 100K | 476.21 µs | 812.55 µs | 1570 µs   | fzip   | 3.3x          |
| decompress | 1K   | 6.39 µs   | 8.28 µs   | 4.82 µs   | zipc   | 1.7x          |
| decompress | 100K | 451.31 µs | 666.98 µs | 502.89 µs | fzip   | 1.5x          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------ | ------------- |
| compress   | 1K   | 12.66 µs  | 128.04 µs | 20.75 µs | fzip   | 10.1x         |
| compress   | 100K | 161.81 µs | 696.93 µs | 2230 µs  | fzip   | 13.8x         |
| decompress | 1K   | 3.51 µs   | 5.3 µs    | 10.15 µs | fzip   | 2.9x          |
| decompress | 100K | 141.01 µs | 377.96 µs | 1900 µs  | fzip   | 13.5x         |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---------- | -------- | --------- | ------ | ------------- |
| compress   | 78.37 µs | 627.25 µs | fzip   | 8.0x          |
| decompress | 4.15 µs  | 40.42 µs  | fzip   | 9.7x          |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| CRC32     | 1K   | 3.63 µs   | 3.57 µs   | 3.68 µs   | moonzip | 1.0x          |
| CRC32     | 100K | 357.88 µs | 358.34 µs | 362.96 µs | fzip    | 1.0x          |
| ADLER32   | 1K   | 0.39 µs   | 0.62 µs   | 8.93 µs   | fzip    | 22.9x         |
| ADLER32   | 100K | 40.22 µs  | 67.33 µs  | 936.13 µs | fzip    | 23.3x         |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 6.85 µs   | 8.98 µs   | fzip   | 1.3x          |
| 100K | 470.22 µs | 672.19 µs | fzip   | 1.4x          |
