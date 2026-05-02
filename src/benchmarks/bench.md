# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260427 (48d7def 2026-04-27)
- Target: wasm-gc
- Date: 2026-05-02

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| zeros   | 1K   | 5.68 µs   | 107.91 µs | 11.8 µs  | fzip   | 19.0x         | 1.2%       | 1.0%          | 100.5% ⚠️  |
| zeros   | 100K | 124.87 µs | 430.95 µs | 1070 µs  | fzip   | 8.6x          | 0.5%       | 0.1%          | 100.0% ⚠️  |
| seq     | 1K   | 15.22 µs  | 116.64 µs | 10.75 µs | zipc   | 10.9x         | 27.3%      | 27.2%         | 100.5% ⚠️  |
| seq     | 100K | 144.05 µs | 442.89 µs | 1070 µs  | fzip   | 7.4x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| random  | 1K   | 3.65 µs   | 192.36 µs | 10.74 µs | fzip   | 52.7x         | 100.5% ⚠️  | 105.2% ⚠️     | 100.5% ⚠️  |
| random  | 100K | 96.88 µs  | 42960 µs  | 1080 µs  | fzip   | 443.4x        | 100.0% ⚠️  | 100.1% ⚠️     | 100.0% ⚠️  |

> **⚠️ Note**:
>
> - `zipc` **does not perform real compression** (just stores) for data ≥1000 bytes, so its 100K speed metrics are not comparable. Ratio ≈100%.
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.
> - Compression Ratio = Compressed Size / Original Size, smaller is better.

## DEFLATE Decompress

| Size | fzip     | moonzip   | zipc      | Winner | Max-Min Ratio |
| ---- | -------- | --------- | --------- | ------ | ------------- |
| 1K   | 1.51 µs  | 4.32 µs   | 0.77 µs   | zipc   | 5.6x          |
| 100K | 25.77 µs | 308.32 µs | 116.67 µs | fzip   | 12.0x         |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 16.38 µs  | 120.59 µs | 15.94 µs  | zipc   | 7.6x          | 29.1%      | 29.0%         | 102.2% ⚠️  |
| compress   | 100K | 258.38 µs | 806.03 µs | 1580 µs   | fzip   | 6.1x          | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 2.39 µs   | 8.15 µs   | 4.56 µs   | fzip   | 3.4x          | -          | -             | -          |
| decompress | 100K | 129.6 µs  | 671.13 µs | 487.91 µs | fzip   | 5.2x          | -          | -             | -          |

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio |
| ---------- | ---- | --------- | --------- | -------- | ------ | ------------- | ---------- | ------------- | ---------- |
| compress   | 1K   | 15.61 µs  | 116.65 µs | 20.97 µs | fzip   | 7.5x          | 27.9%      | 27.8%         | 101.1% ⚠️  |
| compress   | 100K | 183.09 µs | 504.91 µs | 2090 µs  | fzip   | 11.4x         | 1.1%       | 0.7%          | 100.0% ⚠️  |
| decompress | 1K   | 1.92 µs   | 5.21 µs   | 9.69 µs  | fzip   | 5.0x          | -          | -             | -          |
| decompress | 100K | 64.67 µs  | 368.84 µs | 1890 µs  | fzip   | 29.2x         | -          | -             | -          |

## ZIP

| Operation  | fzip     | moonzip  | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | -------- | ------ | ------------- | ---------- | ------------- |
| compress   | 30.02 µs | 585.1 µs | fzip   | 19.5x         | 73.7%      | 74.8%         |
| decompress | 1.82 µs  | 38.96 µs | fzip   | 21.4x         | -          | -             |

## Checksum

| Algorithm | Size | fzip      | moonzip   | zipc      | Winner | Max-Min Ratio |
| --------- | ---- | --------- | --------- | --------- | ------ | ------------- |
| CRC32     | 1K   | 1.15 µs   | 3.57 µs   | 3.64 µs   | fzip   | 3.2x          |
| CRC32     | 100K | 114.61 µs | 360.65 µs | 365.56 µs | fzip   | 3.2x          |
| ADLER32   | 1K   | 0.4 µs    | 0.63 µs   | 8.82 µs   | fzip   | 22.1x         |
| ADLER32   | 100K | 39.1 µs   | 61.35 µs  | 881.92 µs | fzip   | 22.6x         |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 2.39 µs   | 8.22 µs   | fzip   | 3.4x          |
| 100K | 129.02 µs | 667.65 µs | fzip   | 5.2x          |
