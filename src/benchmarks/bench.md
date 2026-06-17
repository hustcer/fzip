# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260608 (60bc8c3 2026-06-08)
- Target: wasm-gc
- Date: 2026-06-17

> **Note**:
>
> - `Max-Min Ratio` is calculated as the slowest mean time divided by the fastest mean time within the same row. `1.0x` means a tie; larger values mean a wider performance spread.
> - `Compression Ratio` is calculated as compressed size divided by original size. Smaller is better.

## DEFLATE Compress

| Pattern | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| zeros   | 1K   | 1.02 µs  | 88.44 µs  | 42.32 µs                                   | 53.78 µs                                         | fzip   | 86.7x         | 1.0%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 66.87 µs | 427.69 µs | 713.06 µs                                  | 112.8 µs                                         | fzip   | 10.7x         | 0.1%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 4.46 µs  | 98.74 µs  | 246.28 µs                                  | 50.75 µs                                         | fzip   | 55.2x         | 27.2%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 90.63 µs | 432.58 µs | 936.53 µs                                  | 262 µs                                           | fzip   | 10.3x         | 0.7%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.72 µs  | 180.41 µs | 271.97 µs                                  | 86.19 µs                                         | fzip   | 100.0x        | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 11.84 µs | 42250 µs  | 8460 µs                                    | 3520 µs                                          | fzip   | 3568.4x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.51 µs  | 4.42 µs   | 28.23 µs                                   | 3.96 µs                                          | fzip   | 18.7x         |
| 100K | 17.14 µs | 306.87 µs | 888.37 µs                                  | 43.24 µs                                         | fzip   | 51.8x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner      | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ----------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 5.18 µs   | 110.65 µs | 4.56 µs                                    | 53.06 µs                                         | mizchi/zlib | 24.3x         | 29.0%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 172.94 µs | 797.76 µs | 440.45 µs                                  | 342.59 µs                                        | fzip        | 4.6x          | 0.7%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 1.93 µs   | 8.45 µs   | 7.98 µs                                    | 3.54 µs                                          | fzip        | 4.4x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 83.78 µs  | 656.13 µs | 782.87 µs                                  | 118.48 µs                                        | fzip        | 9.3x          | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 4.91 µs   | 107.96 µs | 248.2 µs                                   | 52.34 µs                                         | fzip   | 50.5x         | 27.8%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 135.62 µs | 494.34 µs | 1000 µs                                    | 317.49 µs                                        | fzip   | 7.4x          | 0.7%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.91 µs   | 5.21 µs   | 27.16 µs                                   | 3.32 µs                                          | fzip   | 14.2x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 56.07 µs  | 367.81 µs | 737.2 µs                                   | 97.63 µs                                         | fzip   | 13.1x         | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 14.89 µs | 552.82 µs | fzip   | 37.1x         | 73.7%      | 74.8%         |
| decompress | 1.9 µs   | 38.44 µs  | fzip   | 20.2x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| CRC32     | 1K   | 0.74 µs  | 3.5 µs    | 0.76 µs                                    | 0.77 µs                                          | fzip   | 4.7x          |
| CRC32     | 100K | 72.19 µs | 352.22 µs | 75.52 µs                                   | 74.8 µs                                          | fzip   | 4.9x          |
| ADLER32   | 1K   | 0.39 µs  | 0.61 µs   | 0.7 µs                                     | 0.53 µs                                          | fzip   | 1.8x          |
| ADLER32   | 100K | 38.04 µs | 59.8 µs   | 66.58 µs                                   | 50.9 µs                                          | fzip   | 1.8x          |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 1.94 µs  | 8.3 µs    | fzip   | 4.3x          |
| 100K | 84.17 µs | 657.35 µs | fzip   | 7.8x          |
