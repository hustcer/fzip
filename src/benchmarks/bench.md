# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260309 (f21b520 2026-03-09)
- Target: wasm-gc
- Date: 2026-03-13

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| zeros   | 1K   | 4.15 µs   | 106.6 µs  | 10.59 µs | fzip   | 25.7x         | 1.2%       | 1.0%          | 100.5% ⚠️  |
| zeros   | 100K | 100.69 µs | 442.87 µs | 1160 µs  | fzip   | 11.5x         | 0.5%       | 0.1%          | 100.0% ⚠️  |
| seq     | 1K   | 12.7 µs   | 115.97 µs | 10.57 µs | zipc   | 11.0x         | 27.3%      | 27.2%         | 100.5% ⚠️  |
| seq     | 100K | 120.19 µs | 448.18 µs | 1060 µs  | fzip   | 8.8x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| random  | 1K   | 82.9 µs   | 198.84 µs | 10.57 µs | zipc   | 18.8x         | 100.5% ⚠️  | 105.2% ⚠️     | 100.5% ⚠️  |
| random  | 100K | 98.42 µs  | 44480 µs  | 1080 µs  | fzip   | 451.9x        | 100.0% ⚠️  | 100.1% ⚠️     | 100.0% ⚠️  |

> **⚠️ Note**:
>
> - `zipc` **does not perform real compression** (just stores) for data ≥1000 bytes, so its 100K speed metrics are not comparable. Ratio ≈100%.
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.
> - Compression Ratio = Compressed Size / Original Size, smaller is better.

## DEFLATE Decompress

| Size | fzip     | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | -------- | --------- | --------- | ------ | ------------- |
| 1K   | 3.08 µs  | 4.47 µs   | 0.77 µs   | zipc   | 5.8x          |
| 100K | 102.4 µs | 309.47 µs | 116.96 µs | fzip   | 3.0x          |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 15.8 µs   | 122.68 µs | 15.68 µs  | zipc   | 7.8x          | 29.1%      | 29.0%         | 102.2% ⚠️  |
| compress   | 100K | 476.21 µs | 809.61 µs | 1580 µs   | fzip   | 3.3x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 6.4 µs    | 8.33 µs   | 4.86 µs   | zipc   | 1.7x          | -          | -             | -          |
| decompress | 100K | 454.87 µs | 669.36 µs | 485.39 µs | fzip   | 1.5x          | -          | -             | -          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 12.86 µs  | 133.26 µs | 20.73 µs | fzip   | 10.4x         | 27.9%      | 27.8%         | 101.1% ⚠️  |
| compress   | 100K | 159.09 µs | 509.52 µs | 2090 µs  | fzip   | 13.1x         | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 3.49 µs   | 5.34 µs   | 10.09 µs | fzip   | 2.9x          | -          | -             | -          |
| decompress | 100K | 140.16 µs | 386.48 µs | 1900 µs  | fzip   | 13.6x         | -          | -             | -          |

## ZIP

| Operation  | fzip      | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | --------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 131.74 µs | 600.67 µs | fzip   | 4.6x          | 73.7%      | 74.8%         |
| decompress | 4.07 µs   | 38.8 µs   | fzip   | 9.5x          | -          | -             |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner  | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------- | ------------- |
| CRC32     | 1K   | 3.6 µs    | 3.53 µs   | 3.59 µs   | moonzip | 1.0x          |
| CRC32     | 100K | 355.85 µs | 357.07 µs | 360.69 µs | fzip    | 1.0x          |
| ADLER32   | 1K   | 0.39 µs   | 0.62 µs   | 8.8 µs    | fzip    | 22.6x         |
| ADLER32   | 100K | 38.98 µs  | 60.57 µs  | 873.45 µs | fzip    | 22.4x         |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 6.4 µs    | 8.35 µs   | fzip   | 1.3x          |
| 100K | 450.18 µs | 671.32 µs | fzip   | 1.5x          |
