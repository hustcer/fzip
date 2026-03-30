# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260309 (f21b520 2026-03-09)
- Target: wasm-gc
- Date: 2026-03-30

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | zipc     | bkl       | mizchi    | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio | bkl Ratio | mizchi Ratio |
| ------- | ---- | --------- | --------- | -------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- | --------- | ------------ |
| zeros   | 1K   | 5.39 µs   | 100.26 µs | 10.54 µs | 56.66 µs  | 42.49 µs  | fzip   | 18.6x         | 1.2%       | 1.0%          | 100.5% ⚠️  | 1.4%      | 1.2%         |
| zeros   | 100K | 118.68 µs | 435.6 µs  | 1050 µs  | 114.41 µs | 778.62 µs | bkl    | 9.2x          | 0.5%       | 0.1%          | 100.0% ⚠️  | 0.1%      | 0.4%         |
| seq     | 1K   | 15.33 µs  | 112.73 µs | 10.53 µs | 51.9 µs   | 253.25 µs | zipc   | 24.1x         | 27.3%      | 27.2%         | 100.5% ⚠️  | 27.7%     | 27.4%        |
| seq     | 100K | 138.37 µs | 455.27 µs | 1060 µs  | 274.05 µs | 976.46 µs | fzip   | 7.7x          | 1.1%       | 0.7%          | 100.0% ⚠️  | 0.7%      | 0.9%         |
| random  | 1K   | 3.87 µs   | 188.32 µs | 10.52 µs | 89.83 µs  | 280.83 µs | fzip   | 72.6x         | 100.5% ⚠️  | 105.2% ⚠️     | 100.5% ⚠️  | 105.5% ⚠️ | 105.1% ⚠️    |
| random  | 100K | 97.84 µs  | 42660 µs  | 1050 µs  | 3600 µs   | 8860 µs   | fzip   | 436.0x        | 100.0% ⚠️  | 100.1% ⚠️     | 100.0% ⚠️  | 100.2% ⚠️ | 100.1% ⚠️    |

> **⚠️ Note**:
>
> - `zipc` **does not perform real compression** (just stores) for data ≥1000 bytes, so its 100K speed metrics are not comparable. Ratio ≈100%.
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.
> - Compression Ratio = Compressed Size / Original Size, smaller is better.

## DEFLATE Decompress

| Size | fzip     | moonzip   | zipc     | bkl      | mizchi   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | -------- | -------- | -------- | ------ | ------------- |
| 1K   | 1.5 µs   | 4.31 µs   | 0.76 µs  | 4.16 µs  | 29.19 µs | zipc   | 38.4x         |
| 100K | 27.21 µs | 309.04 µs | 115.3 µs | 46.35 µs | 1080 µs  | fzip   | 39.7x         |

## GZIP

| Operation  | Size | fzip      | moonzip   | zipc      | bkl       | mizchi    | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio | bkl Ratio | mizchi Ratio |
| ---------- | ---- | --------- | --------- | --------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- | --------- | ------------ |
| compress   | 1K   | 16.36 µs  | 128.76 µs | 15.66 µs  | 53.99 µs  | 6.13 µs   | mizchi | 21.0x         | 29.1%      | 29.0%         | 102.2% ⚠️  | 29.5%     | 102.2% ⚠️    |
| compress   | 100K | 251.5 µs  | 807.2 µs  | 1540 µs   | 346.94 µs | 598.21 µs | fzip   | 6.1x          | 1.1%       | 0.7%          | 100.0% ⚠️  | 0.7%      | 100.0% ⚠️    |
| decompress | 1K   | 2.36 µs   | 8.17 µs   | 4.81 µs   | 4.36 µs   | 10.28 µs  | fzip   | 4.4x          | -          | -             | -          | -         | -            |
| decompress | 100K | 133.45 µs | 665.18 µs | 487.38 µs | 125.74 µs | 1020 µs   | bkl    | 8.1x          | -          | -             | -          | -         | -            |

> **Note**: `mizchi/zlib` currently benchmarks `gzip_compress_stored`, so its GZIP compression rows reflect store-mode throughput rather than real DEFLATE compression.

## Zlib

| Operation  | Size | fzip      | moonzip   | zipc     | bkl       | mizchi    | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | zipc Ratio | bkl Ratio | mizchi Ratio |
| ---------- | ---- | --------- | --------- | -------- | --------- | --------- | ------ | ------------- | ---------- | ------------- | ---------- | --------- | ------------ |
| compress   | 1K   | 16.62 µs  | 116.01 µs | 20.62 µs | 57.85 µs  | 254.89 µs | fzip   | 15.3x         | 27.9%      | 27.8%         | 101.1% ⚠️  | 28.3%     | 28.0%        |
| compress   | 100K | 176.31 µs | 506.24 µs | 2070 µs  | 325.98 µs | 1060 µs   | fzip   | 11.7x         | 1.1%       | 0.7%          | 100.0% ⚠️  | 0.7%      | 0.9%         |
| decompress | 1K   | 1.92 µs   | 5.19 µs   | 9.94 µs  | 4.07 µs   | 26.74 µs  | fzip   | 13.9x         | -          | -             | -          | -         | -            |
| decompress | 100K | 65.68 µs  | 367.91 µs | 1870 µs  | 100.88 µs | 745.09 µs | fzip   | 28.5x         | -          | -             | -          | -         | -            |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 29.75 µs | 599.43 µs | fzip   | 20.1x         | 73.7%      | 74.8%         |
| decompress | 1.87 µs  | 39.21 µs  | fzip   | 21.0x         | -          | -             |

> **Note**: `zipc`, `bkl`, and `mizchi/zlib` are omitted here because the current benchmark matrix does not expose compatible ZIP APIs.

## Checksum

| Algorithm | Size | fzip     | moonzip   | zipc      | bkl      | mizchi    | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | --------- | -------- | --------- | ------ | ------------- |
| CRC32     | 1K   | 1.14 µs  | 3.52 µs   | 3.58 µs   | 0.77 µs  | 3.52 µs   | bkl    | 4.6x          |
| CRC32     | 100K | 113.4 µs | 355.85 µs | 372.37 µs | 78.09 µs | 358.35 µs | bkl    | 4.8x          |
| ADLER32   | 1K   | 0.4 µs   | 0.64 µs   | 8.84 µs   | 0.55 µs  | 0.69 µs   | fzip   | 22.1x         |
| ADLER32   | 100K | 38.96 µs | 61.83 µs  | 877.5 µs  | 52.57 µs | 68.01 µs  | fzip   | 22.5x         |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 2.43 µs   | 8.3 µs    | fzip   | 3.4x          |
| 100K | 130.73 µs | 675.03 µs | fzip   | 5.2x          |

> **Note**: Only `fzip` and `moonzip` expose a comparable auto-detect decompress API in this benchmark matrix.
