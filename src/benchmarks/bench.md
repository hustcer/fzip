# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260309 (f21b520 2026-03-09)
- Target: wasm-gc
- Date: 2026-03-17

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| zeros   | 1K   | 5.62 µs   | 109.32 µs | 11.04 µs | fzip   | 19.5x         | 1.2%       | 1.0%          | 100.5% ⚠️  |
| zeros   | 100K | 118.68 µs | 457.89 µs | 1070 µs  | fzip   | 9.0x          | 0.5%       | 0.1%          | 100.0% ⚠️  |
| seq     | 1K   | 15.72 µs  | 136.9 µs  | 11.1 µs  | zipc   | 12.3x         | 27.3%      | 27.2%         | 100.5% ⚠️  |
| seq     | 100K | 140.34 µs | 498.22 µs | 1210 µs  | fzip   | 8.6x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| random  | 1K   | 4.66 µs   | 234.25 µs | 11.02 µs | fzip   | 50.3x         | 100.5% ⚠️  | 105.2% ⚠️     | 100.5% ⚠️  |
| random  | 100K | 108.23 µs | 45110 µs  | 1100 µs  | fzip   | 416.8x        | 100.0% ⚠️  | 100.1% ⚠️     | 100.0% ⚠️  |

> **⚠️ Note**:
>
> - `zipc` **does not perform real compression** (just stores) for data ≥1000 bytes, so its 100K speed metrics are not comparable. Ratio ≈100%.
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.
> - Compression Ratio = Compressed Size / Original Size, smaller is better.

## DEFLATE Decompress

| Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | --------- | --------- | --------- | ------ | ------------- |
| 1K   | 3.17 µs   | 4.72 µs   | 0.79 µs   | zipc   | 6.0x          |
| 100K | 106.64 µs | 320.82 µs | 136.62 µs | fzip   | 3.0x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 17.39 µs  | 171.5 µs  | 16.72 µs  | zipc   | 10.3x         | 29.1%      | 29.0%         | 102.2% ⚠️  |
| compress   | 100K | 261.33 µs | 859.3 µs  | 1660 µs   | fzip   | 6.4x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 4.51 µs   | 8.92 µs   | 4.99 µs   | fzip   | 2.0x          | -          | -             | -          |
| decompress | 100K | 249.45 µs | 679.66 µs | 497.75 µs | fzip   | 2.7x          | -          | -             | -          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 15.85 µs  | 129.93 µs | 21.22 µs | fzip   | 8.2x          | 27.9%      | 27.8%         | 101.1% ⚠️  |
| compress   | 100K | 191.5 µs  | 565.44 µs | 2160 µs  | fzip   | 11.3x         | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 3.66 µs   | 6.99 µs   | 11.11 µs | fzip   | 3.0x          | -          | -             | -          |
| decompress | 100K | 151.67 µs | 400.25 µs | 1950 µs  | fzip   | 12.9x         | -          | -             | -          |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 32.03 µs | 666.49 µs | fzip   | 20.8x         | 73.7%      | 74.8%         |
| decompress | 4.25 µs  | 39.95 µs  | fzip   | 9.4x          | -          | -             |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------ | ------------- |
| CRC32     | 1K   | 1.34 µs   | 4.15 µs   | 3.83 µs   | fzip   | 3.1x          |
| CRC32     | 100K | 118.21 µs | 374.72 µs | 434.64 µs | fzip   | 3.7x          |
| ADLER32   | 1K   | 0.44 µs   | 0.67 µs   | 9.2 µs    | fzip   | 20.9x         |
| ADLER32   | 100K | 40.06 µs  | 64.74 µs  | 898.65 µs | fzip   | 22.4x         |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 4.14 µs   | 8.59 µs   | fzip   | 2.1x          |
| 100K | 216.97 µs | 703.14 µs | fzip   | 3.2x          |
