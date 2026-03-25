# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260309 (f21b520 2026-03-09)
- Target: wasm-gc
- Date: 2026-03-25

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | bkl       | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio | bkl Ratio |
| ------- | ---- | --------- | --------- | -------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- | --------- |
| zeros   | 1K   | 5.44 µs   | 118 µs    | 10.68 µs | 69.7 µs   | fzip   | 21.7x         | 1.2%       | 1.0%          | 100.5% ⚠️  | 1.4%      |
| zeros   | 100K | 118.44 µs | 441.74 µs | 1060 µs  | 120.83 µs | fzip   | 8.9x          | 0.5%       | 0.1%          | 100.0% ⚠️  | 0.1%      |
| seq     | 1K   | 15.37 µs  | 132.49 µs | 10.86 µs | 61.38 µs  | zipc   | 12.2x         | 27.3%      | 27.2%         | 100.5% ⚠️  | 27.7%     |
| seq     | 100K | 140.07 µs | 468.88 µs | 1070 µs  | 272.66 µs | fzip   | 7.6x          | 1.1%       | 0.7%          | 100.0% ⚠️  | 0.7%      |
| random  | 1K   | 3.76 µs   | 214.2 µs  | 10.69 µs | 99.8 µs   | fzip   | 57.0x         | 100.5% ⚠️  | 105.2% ⚠️     | 100.5% ⚠️  | 105.5% ⚠️ |
| random  | 100K | 102.47 µs | 43280 µs  | 1090 µs  | 3730 µs   | fzip   | 422.4x        | 100.0% ⚠️  | 100.1% ⚠️     | 100.0% ⚠️  | 100.2% ⚠️ |

> **⚠️ Note**:
>
> - `zipc` **does not perform real compression** (just stores) for data ≥1000 bytes, so its 100K speed metrics are not comparable. Ratio ≈100%.
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.
> - Compression Ratio = Compressed Size / Original Size, smaller is better.

## DEFLATE Decompress

| Size | fzip     | moonzip   | zipc      | bkl      | Winner | Max-Min Ratio |
| ---- | -------- | --------- | --------- | -------- | ------ | ------------- |
| 1K   | 1.59 µs  | 4.69 µs   | 0.8 µs    | 9.37 µs  | zipc   | 11.7x         |
| 100K | 29.25 µs | 356.45 µs | 129.62 µs | 52.44 µs | fzip   | 12.2x         |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | bkl       | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio | bkl Ratio |
| ---------- | ---- | --------- | --------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- | --------- |
| compress   | 1K   | 36.77 µs  | 176.07 µs | 16.52 µs  | 65.31 µs  | zipc   | 10.7x         | 29.1%      | 29.0%         | 102.2% ⚠️  | 29.5%     |
| compress   | 100K | 255.22 µs | 846.21 µs | 1600 µs   | 359.82 µs | fzip   | 6.3x          | 1.1%       | 0.7%          | 100.0% ⚠️  | 0.7%      |
| decompress | 1K   | 2.54 µs   | 8.95 µs   | 5.5 µs    | 5.49 µs   | fzip   | 3.5x          | -          | -             | -          | -         |
| decompress | 100K | 132.15 µs | 686.63 µs | 497.01 µs | 128.22 µs | bkl    | 5.4x          | -          | -             | -          | -         |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | bkl       | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio | bkl Ratio |
| ---------- | ---- | --------- | --------- | -------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- | --------- |
| compress   | 1K   | 15.93 µs  | 128.88 µs | 21.63 µs | 63.68 µs  | fzip   | 8.1x          | 27.9%      | 27.8%         | 101.1% ⚠️  | 28.3%     |
| compress   | 100K | 188.75 µs | 544.29 µs | 2120 µs  | 349.93 µs | fzip   | 11.2x         | 1.1%       | 0.7%          | 100.0% ⚠️  | 0.7%      |
| decompress | 1K   | 1.99 µs   | 5.63 µs   | 10.27 µs | 4.58 µs   | fzip   | 5.2x          | -          | -             | -          | -         |
| decompress | 100K | 68.04 µs  | 378.84 µs | 1910 µs  | 108.96 µs | fzip   | 28.1x         | -          | -             | -          | -         |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 30.21 µs | 677.19 µs | fzip   | 22.4x         | 73.7%      | 74.8%         |
| decompress | 1.9 µs   | 39.56 µs  | fzip   | 20.8x         | -          | -             |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | bkl      | Winner | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | -------- | ------ | ------------- |
| CRC32     | 1K   | 1.16 µs   | 3.6 µs    | 3.64 µs   | 0.81 µs  | bkl    | 4.5x          |
| CRC32     | 100K | 120.24 µs | 428.81 µs | 399.15 µs | 80.04 µs | bkl    | 5.4x          |
| ADLER32   | 1K   | 0.42 µs   | 0.7 µs    | 9.36 µs   | 0.61 µs  | fzip   | 22.3x         |
| ADLER32   | 100K | 40.46 µs  | 64.62 µs  | 910.34 µs | 61.02 µs | fzip   | 22.5x         |

## Auto-detect Decompress

| Size | fzip      | moonzip  | Winner | Max-Min Ratio |
| ---- | --------- | -------- | ------ | ------------- |
| 1K   | 2.48 µs   | 8.9 µs   | fzip   | 3.6x          |
| 100K | 142.42 µs | 774.5 µs | fzip   | 5.4x          |
