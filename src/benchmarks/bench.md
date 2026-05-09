# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260427 (48d7def 2026-04-27)
- Target: wasm-gc
- Date: 2026-05-09

> **Note**:
>
> - `Max-Min Ratio` is calculated as the slowest mean time divided by the fastest mean time within the same row. `1.0x` means a tie; larger values mean a wider performance spread.
> - `Compression Ratio` is calculated as compressed size divided by original size. Smaller is better.

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner   | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | -------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| zeros   | 1K   | 5.39 µs   | 104.5 µs  | 45.12 µs                                   | 56.07 µs                                         | fzip     | 19.4x         | 1.2%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 119.68 µs | 422.34 µs | 714.29 µs                                  | 113.87 µs                                        | compress | 6.3x          | 0.5%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 15.16 µs  | 114.56 µs | 259.89 µs                                  | 52.28 µs                                         | fzip     | 17.1x         | 27.3%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 136.31 µs | 469.81 µs | 1080 µs                                    | 276.96 µs                                        | fzip     | 7.9x          | 1.1%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.79 µs   | 184.39 µs | 291.23 µs                                  | 86.28 µs                                         | fzip     | 104.4x        | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 12.84 µs  | 42120 µs  | 8630 µs                                    | 3530 µs                                          | fzip     | 3280.4x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.56 µs  | 4.42 µs   | 28.47 µs                                   | 4.41 µs                                          | fzip   | 18.3x         |
| 100K | 20.16 µs | 302.86 µs | 885.26 µs                                  | 45.93 µs                                         | fzip   | 43.9x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner      | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ----------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 16.52 µs  | 117.61 µs | 5.91 µs                                    | 58.68 µs                                         | mizchi/zlib | 19.9x         | 29.1%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 213.51 µs | 801.28 µs | 627.53 µs                                  | 345.23 µs                                        | fzip        | 3.8x          | 1.1%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 1.95 µs   | 8.29 µs   | 10.18 µs                                   | 5.12 µs                                          | fzip        | 5.2x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 90.4 µs   | 682.66 µs | 987.62 µs                                  | 123.58 µs                                        | fzip        | 10.9x         | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 15.43 µs  | 109.88 µs | 253.53 µs                                  | 54.74 µs                                         | fzip   | 16.4x         | 27.9%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 176.31 µs | 508.75 µs | 1020 µs                                    | 323.02 µs                                        | fzip   | 5.8x          | 1.1%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.94 µs   | 5.31 µs   | 27.5 µs                                    | 3.98 µs                                          | fzip   | 14.2x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 59.46 µs  | 373.71 µs | 787.92 µs                                  | 101.02 µs                                        | fzip   | 13.3x         | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip    | moonzip  | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | ------- | -------- | ------ | ------------- | ---------- | ------------- |
| compress   | 27.1 µs | 568.6 µs | fzip   | 21.0x         | 73.7%      | 74.8%         |
| decompress | 1.81 µs | 39.08 µs | fzip   | 21.6x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| CRC32     | 1K   | 0.75 µs  | 3.66 µs   | 3.68 µs                                    | 0.77 µs                                          | fzip   | 4.9x          |
| CRC32     | 100K | 72.17 µs | 354.88 µs | 363.49 µs                                  | 76.2 µs                                          | fzip   | 5.0x          |
| ADLER32   | 1K   | 0.39 µs  | 0.66 µs   | 0.7 µs                                     | 0.54 µs                                          | fzip   | 1.8x          |
| ADLER32   | 100K | 38.78 µs | 60.54 µs  | 67.6 µs                                    | 50.99 µs                                         | fzip   | 1.7x          |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 1.94 µs  | 8.38 µs   | fzip   | 4.3x          |
| 100K | 88.61 µs | 663.09 µs | fzip   | 7.5x          |
