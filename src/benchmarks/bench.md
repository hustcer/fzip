# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260309 (f21b520 2026-03-09)
- Target: wasm-gc
- Date: 2026-03-14

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| zeros   | 1K   | 4.13 µs   | 101.91 µs | 10.64 µs | fzip   | 24.7x         | 1.2%       | 1.0%          | 100.5% ⚠️  |
| zeros   | 100K | 102.37 µs | 427.29 µs | 1040 µs  | fzip   | 10.2x         | 0.5%       | 0.1%          | 100.0% ⚠️  |
| seq     | 1K   | 12.26 µs  | 110.6 µs  | 10.51 µs | zipc   | 10.5x         | 27.3%      | 27.2%         | 100.5% ⚠️  |
| seq     | 100K | 121.02 µs | 460.31 µs | 1060 µs  | fzip   | 8.8x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| random  | 1K   | 82.23 µs  | 190.24 µs | 10.54 µs | zipc   | 18.0x         | 100.5% ⚠️  | 105.2% ⚠️     | 100.5% ⚠️  |
| random  | 100K | 98.46 µs  | 42340 µs  | 1110 µs  | fzip   | 430.0x        | 100.0% ⚠️  | 100.1% ⚠️     | 100.0% ⚠️  |

> **⚠️ Note**:
>
> - `zipc` **does not perform real compression** (just stores) for data ≥1000 bytes, so its 100K speed metrics are not comparable. Ratio ≈100%.
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.
> - Compression Ratio = Compressed Size / Original Size, smaller is better.

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | --------- | --------- | --------- | ------ | ------------- |
| 1K   | 3.08 µs   | 4.42 µs   | 0.77 µs   | zipc   | 5.7x          |
| 100K | 100.03 µs | 308.15 µs | 117.57 µs | fzip   | 3.1x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 13.47 µs  | 121.85 µs | 15.6 µs   | fzip   | 9.0x          | 29.1%      | 29.0%         | 102.2% ⚠️  |
| compress   | 100K | 236.3 µs  | 805.1 µs  | 1550 µs   | fzip   | 6.6x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 3.98 µs   | 8.28 µs   | 4.81 µs   | fzip   | 2.1x          | -          | -             | -          |
| decompress | 100K | 209.48 µs | 662.18 µs | 488.76 µs | fzip   | 3.2x          | -          | -             | -          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 12.63 µs  | 115.52 µs | 20.57 µs | fzip   | 9.1x          | 27.9%      | 27.8%         | 101.1% ⚠️  |
| compress   | 100K | 157.49 µs | 505.82 µs | 2100 µs  | fzip   | 13.3x         | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 3.51 µs   | 5.33 µs   | 9.92 µs  | fzip   | 2.8x          | -          | -             | -          |
| decompress | 100K | 140.35 µs | 370.12 µs | 1880 µs  | fzip   | 13.4x         | -          | -             | -          |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 119.9 µs | 587.62 µs | fzip   | 4.9x          | 73.7%      | 74.8%         |
| decompress | 4.12 µs  | 38.64 µs  | fzip   | 9.4x          | -          | -             |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------ | ------------- |
| CRC32     | 1K   | 1.15 µs   | 3.52 µs   | 3.65 µs   | fzip   | 3.2x          |
| CRC32     | 100K | 113.01 µs | 356.86 µs | 358.16 µs | fzip   | 3.2x          |
| ADLER32   | 1K   | 0.39 µs   | 0.63 µs   | 8.67 µs   | fzip   | 22.2x         |
| ADLER32   | 100K | 38.59 µs  | 61.14 µs  | 871.54 µs | fzip   | 22.6x         |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 3.98 µs   | 8.44 µs   | fzip   | 2.1x          |
| 100K | 207.89 µs | 672.98 µs | fzip   | 3.2x          |
