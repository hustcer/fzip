# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260309 (f21b520 2026-03-09)
- Target: wasm-gc
- Date: 2026-03-19

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| zeros   | 1K   | 5.46 µs   | 104.79 µs | 10.54 µs | fzip   | 19.2x         | 1.2%       | 1.0%          | 100.5% ⚠️  |
| zeros   | 100K | 118.77 µs | 436.87 µs | 1050 µs  | fzip   | 8.8x          | 0.5%       | 0.1%          | 100.0% ⚠️  |
| seq     | 1K   | 14.94 µs  | 114.37 µs | 10.65 µs | zipc   | 10.7x         | 27.3%      | 27.2%         | 100.5% ⚠️  |
| seq     | 100K | 133.7 µs  | 440.51 µs | 1050 µs  | fzip   | 7.9x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| random  | 1K   | 3.7 µs    | 192.17 µs | 10.56 µs | fzip   | 51.9x         | 100.5% ⚠️  | 105.2% ⚠️     | 100.5% ⚠️  |
| random  | 100K | 97.13 µs  | 42820 µs  | 1050 µs  | fzip   | 440.9x        | 100.0% ⚠️  | 100.1% ⚠️     | 100.0% ⚠️  |

> **⚠️ Note**:
>
> - `zipc` **does not perform real compression** (just stores) for data ≥1000 bytes, so its 100K speed metrics are not comparable. Ratio ≈100%.
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.
> - Compression Ratio = Compressed Size / Original Size, smaller is better.

## DEFLATE Decompress

| Size | fzip     | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | -------- | --------- | --------- | ------ | ------------- |
| 1K   | 1.98 µs  | 4.52 µs   | 0.77 µs   | zipc   | 5.9x          |
| 100K | 92.99 µs | 309.12 µs | 117.37 µs | fzip   | 3.3x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 16.34 µs  | 115.36 µs | 15.73 µs  | zipc   | 7.3x          | 29.1%      | 29.0%         | 102.2% ⚠️  |
| compress   | 100K | 250.92 µs | 806.96 µs | 1540 µs   | fzip   | 6.1x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 2.83 µs   | 8.36 µs   | 4.78 µs   | fzip   | 3.0x          | -          | -             | -          |
| decompress | 100K | 198.95 µs | 661.45 µs | 484.79 µs | fzip   | 3.3x          | -          | -             | -          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 15.52 µs  | 112.3 µs  | 21.06 µs | fzip   | 7.2x          | 27.9%      | 27.8%         | 101.1% ⚠️  |
| compress   | 100K | 177.16 µs | 502.68 µs | 2050 µs  | fzip   | 11.6x         | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 2.39 µs   | 5.3 µs    | 9.94 µs  | fzip   | 4.2x          | -          | -             | -          |
| decompress | 100K | 135.85 µs | 372.27 µs | 1910 µs  | fzip   | 14.1x         | -          | -             | -          |

## ZIP

| Operation  | fzip     | moonzip  | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | -------- | ------ | ------------- | ---------- | ------------- |
| compress   | 29.66 µs | 582 µs   | fzip   | 19.6x         | 73.7%      | 74.8%         |
| decompress | 2.93 µs  | 38.67 µs | fzip   | 13.2x         | -          | -             |

## Checksum

| Algorithm | Size | fzip     | moonzip   | zipc      | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | --------- | ------ | ------------- |
| CRC32     | 1K   | 1.13 µs  | 3.53 µs   | 3.58 µs   | fzip   | 3.2x          |
| CRC32     | 100K | 116.1 µs | 355.44 µs | 359.64 µs | fzip   | 3.1x          |
| ADLER32   | 1K   | 0.39 µs  | 0.63 µs   | 8.62 µs   | fzip   | 22.1x         |
| ADLER32   | 100K | 38.84 µs | 60.22 µs  | 881.86 µs | fzip   | 22.7x         |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 2.85 µs  | 8.32 µs   | fzip   | 2.9x          |
| 100K | 196.4 µs | 665.25 µs | fzip   | 3.4x          |
