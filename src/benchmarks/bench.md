# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260309 (f21b520 2026-03-09)
- Target: wasm-gc
- Date: 2026-03-23

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| zeros   | 1K   | 5.47 µs   | 113.42 µs | 10.7 µs  | fzip   | 20.7x         | 1.2%       | 1.0%          | 100.5% ⚠️  |
| zeros   | 100K | 119.85 µs | 449.34 µs | 1070 µs  | fzip   | 8.9x          | 0.5%       | 0.1%          | 100.0% ⚠️  |
| seq     | 1K   | 15.41 µs  | 117.51 µs | 10.67 µs | zipc   | 11.0x         | 27.3%      | 27.2%         | 100.5% ⚠️  |
| seq     | 100K | 136.73 µs | 450.46 µs | 1070 µs  | fzip   | 7.8x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| random  | 1K   | 3.74 µs   | 196.95 µs | 10.77 µs | fzip   | 52.7x         | 100.5% ⚠️  | 105.2% ⚠️     | 100.5% ⚠️  |
| random  | 100K | 100.75 µs | 43500 µs  | 1070 µs  | fzip   | 431.8x        | 100.0% ⚠️  | 100.1% ⚠️     | 100.0% ⚠️  |

> **⚠️ Note**:
>
> - `zipc` **does not perform real compression** (just stores) for data ≥1000 bytes, so its 100K speed metrics are not comparable. Ratio ≈100%.
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.
> - Compression Ratio = Compressed Size / Original Size, smaller is better.

## DEFLATE Decompress

| Size | fzip     | moonzip   | zipc    | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------- | ------ | ------------- |
| 1K   | 1.55 µs  | 4.55 µs   | 0.78 µs | zipc   | 5.8x          |
| 100K | 27.19 µs | 313.67 µs | 118 µs  | fzip   | 11.5x         |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 16.44 µs  | 126.36 µs | 15.95 µs  | zipc   | 7.9x          | 29.1%      | 29.0%         | 102.2% ⚠️  |
| compress   | 100K | 252.37 µs | 824.31 µs | 1580 µs   | fzip   | 6.3x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 2.41 µs   | 8.46 µs   | 4.9 µs    | fzip   | 3.5x          | -          | -             | -          |
| decompress | 100K | 131.36 µs | 678.8 µs  | 494.54 µs | fzip   | 5.2x          | -          | -             | -          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 15.67 µs  | 119.15 µs | 21.08 µs | fzip   | 7.6x          | 27.9%      | 27.8%         | 101.1% ⚠️  |
| compress   | 100K | 176.21 µs | 515.42 µs | 2090 µs  | fzip   | 11.9x         | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 1.93 µs   | 5.4 µs    | 10.07 µs | fzip   | 5.2x          | -          | -             | -          |
| decompress | 100K | 66.19 µs  | 375.58 µs | 1890 µs  | fzip   | 28.6x         | -          | -             | -          |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 29.95 µs | 594.07 µs | fzip   | 19.8x         | 73.7%      | 74.8%         |
| decompress | 1.92 µs  | 39.47 µs  | fzip   | 20.6x         | -          | -             |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------ | ------------- |
| CRC32     | 1K   | 1.15 µs   | 3.58 µs   | 3.67 µs   | fzip   | 3.2x          |
| CRC32     | 100K | 115.14 µs | 358.28 µs | 363.11 µs | fzip   | 3.2x          |
| ADLER32   | 1K   | 0.42 µs   | 0.63 µs   | 8.7 µs    | fzip   | 20.7x         |
| ADLER32   | 100K | 39.08 µs  | 61.93 µs  | 877.39 µs | fzip   | 22.5x         |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 2.4 µs    | 8.46 µs   | fzip   | 3.5x          |
| 100K | 131.03 µs | 676.72 µs | fzip   | 5.2x          |
