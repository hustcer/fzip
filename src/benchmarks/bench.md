# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260309 (f21b520 2026-03-09)
- Target: wasm-gc
- Date: 2026-03-15

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| zeros   | 1K   | 5.29 µs   | 98.91 µs  | 10.57 µs | fzip   | 18.7x         | 1.2%       | 1.0%          | 100.5% ⚠️  |
| zeros   | 100K | 116.64 µs | 439.17 µs | 1100 µs  | fzip   | 9.4x          | 0.5%       | 0.1%          | 100.0% ⚠️  |
| seq     | 1K   | 14.28 µs  | 111.25 µs | 10.62 µs | zipc   | 10.5x         | 27.3%      | 27.2%         | 100.5% ⚠️  |
| seq     | 100K | 135.85 µs | 442.15 µs | 1050 µs  | fzip   | 7.7x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| random  | 1K   | 2.45 µs   | 187.97 µs | 10.62 µs | fzip   | 76.7x         | 100.5% ⚠️  | 105.2% ⚠️     | 100.5% ⚠️  |
| random  | 100K | 98.56 µs  | 42450 µs  | 1050 µs  | fzip   | 430.7x        | 100.0% ⚠️  | 100.1% ⚠️     | 100.0% ⚠️  |

> **⚠️ Note**:
>
> - `zipc` **does not perform real compression** (just stores) for data ≥1000 bytes, so its 100K speed metrics are not comparable. Ratio ≈100%.
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.
> - Compression Ratio = Compressed Size / Original Size, smaller is better.

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio |
| ---- | --------- | --------- | -------- | ------ | ------------- |
| 1K   | 3.07 µs   | 4.41 µs   | 0.77 µs  | zipc   | 5.7x          |
| 100K | 101.73 µs | 304.97 µs | 117.8 µs | fzip   | 3.0x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 15.25 µs  | 115.8 µs  | 15.59 µs  | fzip   | 7.6x          | 29.1%      | 29.0%         | 102.2% ⚠️  |
| compress   | 100K | 262.13 µs | 807.82 µs | 1580 µs   | fzip   | 6.0x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 3.96 µs   | 8.22 µs   | 4.85 µs   | fzip   | 2.1x          | -          | -             | -          |
| decompress | 100K | 207.55 µs | 669.58 µs | 484.43 µs | fzip   | 3.2x          | -          | -             | -          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc    | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | ------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 14.57 µs  | 121.72 µs | 20.6 µs | fzip   | 8.4x          | 27.9%      | 27.8%         | 101.1% ⚠️  |
| compress   | 100K | 174.45 µs | 509.44 µs | 2060 µs | fzip   | 11.8x         | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 3.46 µs   | 5.26 µs   | 9.96 µs | fzip   | 2.9x          | -          | -             | -          |
| decompress | 100K | 139.83 µs | 367.01 µs | 1870 µs | fzip   | 13.4x         | -          | -             | -          |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 27.03 µs | 572.13 µs | fzip   | 21.2x         | 73.7%      | 74.8%         |
| decompress | 4.06 µs  | 38.62 µs  | fzip   | 9.5x          | -          | -             |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------ | ------------- |
| CRC32     | 1K   | 1.15 µs   | 3.52 µs   | 3.58 µs   | fzip   | 3.1x          |
| CRC32     | 100K | 114.42 µs | 361.68 µs | 360.45 µs | fzip   | 3.2x          |
| ADLER32   | 1K   | 0.4 µs    | 0.63 µs   | 8.72 µs   | fzip   | 21.8x         |
| ADLER32   | 100K | 39.15 µs  | 61.2 µs   | 875.15 µs | fzip   | 22.4x         |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 4.01 µs  | 8.26 µs   | fzip   | 2.1x          |
| 100K | 206.2 µs | 664.21 µs | fzip   | 3.2x          |
