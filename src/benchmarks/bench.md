# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260529 (3e1c753 2026-05-29)
- Target: wasm-gc
- Date: 2026-06-08

> **Note**:
>
> - `Max-Min Ratio` is calculated as the slowest mean time divided by the fastest mean time within the same row. `1.0x` means a tie; larger values mean a wider performance spread.
> - `Compression Ratio` is calculated as compressed size divided by original size. Smaller is better.

## DEFLATE Compress

| Pattern | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| zeros   | 1K   | 1.01 µs  | 91.63 µs  | 43.46 µs                                   | 57.06 µs                                         | fzip   | 90.7x         | 1.0%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 65.17 µs | 419.2 µs  | 707.06 µs                                  | 113.55 µs                                        | fzip   | 10.8x         | 0.1%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 4.54 µs  | 118.09 µs | 263.98 µs                                  | 55.09 µs                                         | fzip   | 58.1x         | 27.2%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 84.11 µs | 432.14 µs | 932.01 µs                                  | 262.28 µs                                        | fzip   | 11.1x         | 1.2%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.82 µs  | 182.69 µs | 294.93 µs                                  | 86.12 µs                                         | fzip   | 104.6x        | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 11.79 µs | 42120 µs  | 8630 µs                                    | 3540 µs                                          | fzip   | 3572.5x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.49 µs  | 4.34 µs   | 27.21 µs                                   | 3.71 µs                                          | fzip   | 18.3x         |
| 100K | 16.22 µs | 302.99 µs | 875.45 µs                                  | 43.65 µs                                         | fzip   | 54.0x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner      | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ----------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 5.3 µs    | 108.46 µs | 3.18 µs                                    | 52.3 µs                                          | mizchi/zlib | 34.1x         | 29.0%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 156.65 µs | 788.13 µs | 310.82 µs                                  | 340.08 µs                                        | fzip        | 5.0x          | 1.3%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 1.94 µs   | 8.19 µs   | 8.07 µs                                    | 3.34 µs                                          | fzip        | 4.2x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 84.45 µs  | 659.2 µs  | 795.41 µs                                  | 119.73 µs                                        | fzip        | 9.4x          | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 4.92 µs   | 116.28 µs | 250.73 µs                                  | 52.64 µs                                         | fzip   | 51.0x         | 27.8%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 122.86 µs | 496.58 µs | 1000 µs                                    | 319.78 µs                                        | fzip   | 8.1x          | 1.2%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.89 µs   | 5.62 µs   | 27.28 µs                                   | 3.11 µs                                          | fzip   | 14.4x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 55.06 µs  | 364.9 µs  | 733.76 µs                                  | 98.91 µs                                         | fzip   | 13.3x         | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 15.16 µs | 567.34 µs | fzip   | 37.4x         | 73.7%      | 74.8%         |
| decompress | 1.9 µs   | 38.36 µs  | fzip   | 20.2x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| CRC32     | 1K   | 0.73 µs  | 3.5 µs    | 0.77 µs                                    | 0.77 µs                                          | fzip   | 4.8x          |
| CRC32     | 100K | 71.19 µs | 353.36 µs | 75.1 µs                                    | 74.85 µs                                         | fzip   | 5.0x          |
| ADLER32   | 1K   | 0.39 µs  | 0.61 µs   | 0.68 µs                                    | 0.53 µs                                          | fzip   | 1.7x          |
| ADLER32   | 100K | 38.29 µs | 60.39 µs  | 66.77 µs                                   | 51.82 µs                                         | fzip   | 1.7x          |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 1.95 µs  | 8.15 µs   | fzip   | 4.2x          |
| 100K | 84.99 µs | 660.44 µs | fzip   | 7.8x          |
