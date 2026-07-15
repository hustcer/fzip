# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260713 (75c7e1f 2026-07-13)
- Target: wasm-gc
- Date: 2026-07-15

> **Note**:
>
> - `Max-Min Ratio` is calculated as the slowest mean time divided by the fastest mean time within the same row. `1.0x` means a tie; larger values mean a wider performance spread.
> - `Compression Ratio` is calculated as compressed size divided by original size. Smaller is better.

## DEFLATE Compress

| Pattern | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| zeros   | 1K   | 1.1 µs   | 102.93 µs | 25.78 µs                                   | 62.9 µs                                          | fzip   | 93.6x         | 1.0%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 69.57 µs | 457.13 µs | 407.99 µs                                  | 121.89 µs                                        | fzip   | 6.6x          | 0.1%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 4.87 µs  | 116.22 µs | 333.51 µs                                  | 55.32 µs                                         | fzip   | 68.5x         | 27.2%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 93.21 µs | 466.79 µs | 739.59 µs                                  | 281.55 µs                                        | fzip   | 7.9x          | 0.7%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.98 µs  | 198.01 µs | 306.88 µs                                  | 93.15 µs                                         | fzip   | 103.0x        | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 13.37 µs | 45520 µs  | 4100 µs                                    | 3810 µs                                          | fzip   | 3404.6x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.56 µs  | 4.65 µs   | 22.4 µs                                    | 8.47 µs                                          | fzip   | 14.4x         |
| 100K | 18.18 µs | 327.35 µs | 212.94 µs                                  | 48 µs                                            | fzip   | 18.0x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner      | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ----------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 5.89 µs   | 123.53 µs | 1.81 µs                                    | 58.2 µs                                          | mizchi/zlib | 68.2x         | 29.0%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 166.06 µs | 865.54 µs | 174.64 µs                                  | 365.58 µs                                        | fzip        | 5.2x          | 0.7%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 2.14 µs   | 8.68 µs   | 3.64 µs                                    | 3.63 µs                                          | fzip        | 4.1x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 84.58 µs  | 706.86 µs | 359.81 µs                                  | 128.23 µs                                        | fzip        | 8.4x          | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 5.29 µs   | 118.84 µs | 335.47 µs                                  | 74.3 µs                                          | fzip   | 63.4x         | 27.8%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 135.47 µs | 538.76 µs | 892.94 µs                                  | 348.75 µs                                        | fzip   | 6.6x          | 0.7%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.97 µs   | 5.5 µs    | 23.05 µs                                   | 3.22 µs                                          | fzip   | 11.7x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 59.58 µs  | 396.69 µs | 283.03 µs                                  | 104.69 µs                                        | fzip   | 6.7x          | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 15.96 µs | 622.34 µs | fzip   | 39.0x         | 73.7%      | 74.8%         |
| decompress | 2.17 µs  | 41.31 µs  | fzip   | 19.0x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| CRC32     | 1K   | 0.72 µs  | 3.76 µs   | 0.82 µs                                    | 0.87 µs                                          | fzip   | 5.2x          |
| CRC32     | 100K | 70.52 µs | 380.83 µs | 79.77 µs                                   | 80.77 µs                                         | fzip   | 5.4x          |
| ADLER32   | 1K   | 0.42 µs  | 0.66 µs   | 0.73 µs                                    | 0.57 µs                                          | fzip   | 1.7x          |
| ADLER32   | 100K | 41.06 µs | 64.79 µs  | 73.16 µs                                   | 56.39 µs                                         | fzip   | 1.8x          |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 2.21 µs  | 9.51 µs   | fzip   | 4.3x          |
| 100K | 87.43 µs | 716.53 µs | fzip   | 8.2x          |
