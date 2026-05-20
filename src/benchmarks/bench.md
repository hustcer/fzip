# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260512 (81d40e3 2026-05-12)
- Target: wasm-gc
- Date: 2026-05-20

> **Note**:
>
> - `Max-Min Ratio` is calculated as the slowest mean time divided by the fastest mean time within the same row. `1.0x` means a tie; larger values mean a wider performance spread.
> - `Compression Ratio` is calculated as compressed size divided by original size. Smaller is better.

## DEFLATE Compress

| Pattern | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| zeros   | 1K   | 1.02 µs  | 89.89 µs  | 43.23 µs                                   | 55.41 µs                                         | fzip   | 88.1x         | 1.0%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 66.24 µs | 423.87 µs | 712.71 µs                                  | 113.11 µs                                        | fzip   | 10.8x         | 0.1%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 4.47 µs  | 97.56 µs  | 245.77 µs                                  | 50.11 µs                                         | fzip   | 55.0x         | 27.2%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 89.54 µs | 425.71 µs | 940.98 µs                                  | 260.56 µs                                        | fzip   | 10.5x         | 1.2%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.77 µs  | 173.7 µs  | 275.14 µs                                  | 86.74 µs                                         | fzip   | 99.3x         | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 11.73 µs | 42070 µs  | 8610 µs                                    | 3550 µs                                          | fzip   | 3586.5x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.48 µs  | 4.39 µs   | 27.72 µs                                   | 4.31 µs                                          | fzip   | 18.7x         |
| 100K | 17.02 µs | 309.03 µs | 944.17 µs                                  | 43.83 µs                                         | fzip   | 55.5x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 5.19 µs   | 104.81 µs | 5.91 µs                                    | 52.94 µs                                         | fzip   | 20.2x         | 29.0%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 160.22 µs | 803.87 µs | 588.93 µs                                  | 340.97 µs                                        | fzip   | 5.0x          | 1.3%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 1.95 µs   | 8.18 µs   | 9.95 µs                                    | 3.44 µs                                          | fzip   | 5.1x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 84.98 µs  | 660.63 µs | 992.8 µs                                   | 120.49 µs                                        | fzip   | 11.7x         | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 4.89 µs   | 111.28 µs | 260.28 µs                                  | 52.92 µs                                         | fzip   | 53.2x         | 27.8%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 130.62 µs | 499.44 µs | 1010 µs                                    | 322.1 µs                                         | fzip   | 7.7x          | 1.2%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.92 µs   | 5.25 µs   | 27.31 µs                                   | 3.24 µs                                          | fzip   | 14.2x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 54.68 µs  | 365.81 µs | 722.59 µs                                  | 96.61 µs                                         | fzip   | 13.2x         | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 15.07 µs | 543.32 µs | fzip   | 36.1x         | 73.7%      | 74.8%         |
| decompress | 1.89 µs  | 38.38 µs  | fzip   | 20.3x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| CRC32     | 1K   | 0.74 µs  | 3.5 µs    | 3.49 µs                                    | 0.77 µs                                          | fzip   | 4.7x          |
| CRC32     | 100K | 71.72 µs | 352.94 µs | 352.75 µs                                  | 75.65 µs                                         | fzip   | 4.9x          |
| ADLER32   | 1K   | 0.39 µs  | 0.63 µs   | 0.69 µs                                    | 0.53 µs                                          | fzip   | 1.8x          |
| ADLER32   | 100K | 38.44 µs | 60.87 µs  | 67.4 µs                                    | 51.89 µs                                         | fzip   | 1.8x          |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 1.94 µs  | 8.25 µs   | fzip   | 4.3x          |
| 100K | 83.96 µs | 659.03 µs | fzip   | 7.8x          |
