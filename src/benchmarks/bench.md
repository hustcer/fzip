# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260512 (81d40e3 2026-05-12)
- Target: wasm-gc
- Date: 2026-05-16

> **Note**:
>
> - `Max-Min Ratio` is calculated as the slowest mean time divided by the fastest mean time within the same row. `1.0x` means a tie; larger values mean a wider performance spread.
> - `Compression Ratio` is calculated as compressed size divided by original size. Smaller is better.

## DEFLATE Compress

| Pattern | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| zeros   | 1K   | 1.02 µs  | 100.65 µs | 45.84 µs                                   | 58.82 µs                                         | fzip   | 98.7x         | 1.0%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 65.3 µs  | 434.63 µs | 725.78 µs                                  | 116.73 µs                                        | fzip   | 11.1x         | 0.1%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 4.59 µs  | 113.17 µs | 252.73 µs                                  | 53.99 µs                                         | fzip   | 55.1x         | 27.2%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 84.96 µs | 443.63 µs | 957.74 µs                                  | 268.62 µs                                        | fzip   | 11.3x         | 1.2%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.81 µs  | 183.6 µs  | 279.56 µs                                  | 88.25 µs                                         | fzip   | 99.5x         | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 12.15 µs | 42540 µs  | 8640 µs                                    | 3550 µs                                          | fzip   | 3501.2x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.51 µs  | 4.32 µs   | 28.62 µs                                   | 4.06 µs                                          | fzip   | 19.0x         |
| 100K | 16.22 µs | 311.34 µs | 896.89 µs                                  | 45.23 µs                                         | fzip   | 55.3x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 5.28 µs   | 110.98 µs | 5.89 µs                                    | 53.35 µs                                         | fzip   | 21.0x         | 29.0%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 156.19 µs | 790.57 µs | 589.3 µs                                   | 343.41 µs                                        | fzip   | 5.1x          | 1.3%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 1.95 µs   | 8.14 µs   | 10.03 µs                                   | 3.28 µs                                          | fzip   | 5.1x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 84.13 µs  | 664.57 µs | 987.11 µs                                  | 119.68 µs                                        | fzip   | 11.7x         | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 4.95 µs   | 116.35 µs | 250.02 µs                                  | 53.39 µs                                         | fzip   | 50.5x         | 27.8%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 124.35 µs | 496.6 µs  | 1010 µs                                    | 320.7 µs                                         | fzip   | 8.1x          | 1.2%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.91 µs   | 5.17 µs   | 27.64 µs                                   | 3.02 µs                                          | fzip   | 14.5x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 55.36 µs  | 365.23 µs | 738.95 µs                                  | 97.23 µs                                         | fzip   | 13.3x         | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 15.03 µs | 585.25 µs | fzip   | 38.9x         | 73.7%      | 74.8%         |
| decompress | 1.79 µs  | 38.44 µs  | fzip   | 21.5x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| CRC32     | 1K   | 0.73 µs  | 3.5 µs    | 3.5 µs                                     | 0.77 µs                                          | fzip   | 4.8x          |
| CRC32     | 100K | 71.55 µs | 353.27 µs | 353.25 µs                                  | 74.88 µs                                         | fzip   | 4.9x          |
| ADLER32   | 1K   | 0.39 µs  | 0.62 µs   | 0.68 µs                                    | 0.53 µs                                          | fzip   | 1.7x          |
| ADLER32   | 100K | 38.55 µs | 60.4 µs   | 67.02 µs                                   | 51.68 µs                                         | fzip   | 1.7x          |

## Auto-detect Decompress

| Size | fzip     | moonzip  | Winner | Max-Min Ratio |
| ---- | -------- | -------- | ------ | ------------- |
| 1K   | 1.95 µs  | 8.17 µs  | fzip   | 4.2x          |
| 100K | 83.16 µs | 660.4 µs | fzip   | 7.9x          |
