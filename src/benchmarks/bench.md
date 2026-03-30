# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260309 (f21b520 2026-03-09)
- Target: wasm-gc
- Date: 2026-03-30

## DEFLATE Compress

| Pattern | Size | fzip     | moonzip   | zipc      | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ------- | ---- | -------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- |
| zeros   | 1K   | 3.83 µs  | 71.7 µs   | 6.84 µs   | fzip   | 18.7x         | 1.2%       | 1.0%          | 100.5% ⚠️  |
| zeros   | 100K | 78.83 µs | 260.47 µs | 685.68 µs | fzip   | 8.7x          | 0.5%       | 0.1%          | 100.0% ⚠️  |
| seq     | 1K   | 10.03 µs | 77.03 µs  | 6.83 µs   | zipc   | 11.3x         | 27.3%      | 27.2%         | 100.5% ⚠️  |
| seq     | 100K | 91.93 µs | 270.07 µs | 685.64 µs | fzip   | 7.5x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| random  | 1K   | 2.41 µs  | 121.76 µs | 6.83 µs   | fzip   | 50.5x         | 100.5% ⚠️  | 105.2% ⚠️     | 100.5% ⚠️  |
| random  | 100K | 52.13 µs | 24410 µs  | 685.19 µs | fzip   | 468.3x        | 100.0% ⚠️  | 100.1% ⚠️     | 100.0% ⚠️  |

> **⚠️ Note**:
>
> - `zipc` **does not perform real compression** (just stores) for data ≥1000 bytes, so its 100K speed metrics are not comparable. Ratio ≈100%.
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.
> - Compression Ratio = Compressed Size / Original Size, smaller is better.

## DEFLATE Decompress

| Size | fzip    | moonzip   | zipc     | Winner | Max-Min Ratio |
| ---- | ------- | --------- | -------- | ------ | ------------- |
| 1K   | 1.02 µs | 2.74 µs   | 0.49 µs  | zipc   | 5.6x          |
| 100K | 15.7 µs | 201.95 µs | 74.56 µs | fzip   | 12.9x         |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 11.02 µs  | 80.31 µs  | 10.15 µs  | zipc   | 7.9x          | 29.1%      | 29.0%         | 102.2% ⚠️  |
| compress   | 100K | 173.94 µs | 505.01 µs | 1000 µs   | fzip   | 5.7x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 1.67 µs   | 5.3 µs    | 3.04 µs   | fzip   | 3.2x          | -          | -             | -          |
| decompress | 100K | 92.21 µs  | 436.55 µs | 310.13 µs | fzip   | 4.7x          | -          | -             | -          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 10.49 µs  | 78.71 µs  | 13.47 µs | fzip   | 7.5x          | 27.9%      | 27.8%         | 101.1% ⚠️  |
| compress   | 100K | 119.95 µs | 309.87 µs | 1350 µs  | fzip   | 11.3x         | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 1.28 µs   | 3.28 µs   | 6.55 µs  | fzip   | 5.1x          | -          | -             | -          |
| decompress | 100K | 42.45 µs  | 235.57 µs | 1240 µs  | fzip   | 29.2x         | -          | -             | -          |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 20.62 µs | 370.46 µs | fzip   | 18.0x         | 73.7%      | 74.8%         |
| decompress | 1.3 µs   | 26 µs     | fzip   | 20.0x         | -          | -             |

## Checksum

| Algorithm | Size | fzip     | moonzip  | zipc      | Winner | Max-Min Ratio |
| --------- | ---- | -------- | -------- | --------- | ------ | ------------- |
| CRC32     | 1K   | 0.8 µs   | 2.38 µs  | 2.31 µs   | fzip   | 3.0x          |
| CRC32     | 100K | 80.13 µs | 241.3 µs | 232.65 µs | fzip   | 3.0x          |
| ADLER32   | 1K   | 0.26 µs  | 0.33 µs  | 5.78 µs   | fzip   | 22.2x         |
| ADLER32   | 100K | 25.9 µs  | 31.44 µs | 581.61 µs | fzip   | 22.5x         |

## Auto-detect Decompress

| Size | fzip     | moonzip | Winner | Max-Min Ratio |
| ---- | -------- | ------- | ------ | ------------- |
| 1K   | 1.7 µs   | 5.31 µs | fzip   | 3.1x          |
| 100K | 92.98 µs | 441 µs  | fzip   | 4.7x          |
