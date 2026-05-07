# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260427 (48d7def 2026-04-27)
- Target: wasm-gc
- Date: 2026-05-07

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| zeros   | 1K   | 5.45 µs   | 88.48 µs  | 11.63 µs | fzip   | 16.2x         | 1.2%       | 1.0%          | 100.5% ⚠️  |
| zeros   | 100K | 120.01 µs | 426.51 µs | 1050 µs  | fzip   | 8.7x          | 0.5%       | 0.1%          | 100.0% ⚠️  |
| seq     | 1K   | 14.8 µs   | 98.68 µs  | 10.58 µs | zipc   | 9.3x          | 27.3%      | 27.2%         | 100.5% ⚠️  |
| seq     | 100K | 134.34 µs | 427.07 µs | 1050 µs  | fzip   | 7.8x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| random  | 1K   | 2.79 µs   | 181.84 µs | 10.59 µs | fzip   | 65.2x         | 100.5% ⚠️  | 105.2% ⚠️     | 100.5% ⚠️  |
| random  | 100K | 11.79 µs  | 42170 µs  | 1050 µs  | fzip   | 3576.8x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.0% ⚠️  |

> **⚠️ Note**:
>
> - `zipc` **does not perform real compression** (just stores) for data ≥1000 bytes, so its 100K speed metrics are not comparable. Ratio ≈100%.
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.
> - Compression Ratio = Compressed Size / Original Size, smaller is better.

## DEFLATE Decompress

| Size | fzip     | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | -------- | --------- | --------- | ------ | ------------- |
| 1K   | 1.48 µs  | 4.38 µs   | 0.75 µs   | zipc   | 5.8x          |
| 100K | 25.04 µs | 306.22 µs | 115.03 µs | fzip   | 12.2x         |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 16.17 µs  | 113.86 µs | 15.67 µs  | zipc   | 7.3x          | 29.1%      | 29.0%         | 102.2% ⚠️  |
| compress   | 100K | 245.5 µs  | 793.07 µs | 1540 µs   | fzip   | 6.3x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 2.35 µs   | 8.47 µs   | 4.44 µs   | fzip   | 3.6x          | -          | -             | -          |
| decompress | 100K | 128.72 µs | 655.81 µs | 483.51 µs | fzip   | 5.1x          | -          | -             | -          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 15.19 µs  | 110.36 µs | 20.57 µs | fzip   | 7.3x          | 27.9%      | 27.8%         | 101.1% ⚠️  |
| compress   | 100K | 172.88 µs | 488.54 µs | 2050 µs  | fzip   | 11.9x         | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 1.92 µs   | 5.22 µs   | 9.55 µs  | fzip   | 5.0x          | -          | -             | -          |
| decompress | 100K | 63.16 µs  | 361.52 µs | 1860 µs  | fzip   | 29.4x         | -          | -             | -          |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 28.06 µs | 559.99 µs | fzip   | 20.0x         | 73.7%      | 74.8%         |
| decompress | 1.77 µs  | 38.52 µs  | fzip   | 21.8x         | -          | -             |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------ | ------------- |
| CRC32     | 1K   | 1.13 µs   | 3.5 µs    | 3.56 µs   | fzip   | 3.2x          |
| CRC32     | 100K | 111.75 µs | 352.06 µs | 356.52 µs | fzip   | 3.2x          |
| ADLER32   | 1K   | 0.39 µs   | 0.62 µs   | 8.62 µs   | fzip   | 22.1x         |
| ADLER32   | 100K | 38.62 µs  | 59.85 µs  | 864.65 µs | fzip   | 22.4x         |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 2.39 µs  | 8.48 µs   | fzip   | 3.5x          |
| 100K | 128.6 µs | 656.55 µs | fzip   | 5.1x          |
