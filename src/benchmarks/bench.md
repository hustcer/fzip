# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260512 (81d40e3 2026-05-12)
- Target: wasm-gc
- Date: 2026-05-13

> **Note**:
>
> - `Max-Min Ratio` is calculated as the slowest mean time divided by the fastest mean time within the same row. `1.0x` means a tie; larger values mean a wider performance spread.
> - `Compression Ratio` is calculated as compressed size divided by original size. Smaller is better.

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| zeros   | 1K   | 1.03 µs   | 104.18 µs | 46.41 µs                                   | 58.18 µs                                         | fzip   | 101.1x        | 1.0%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 65.36 µs  | 430.97 µs | 726.36 µs                                  | 114.59 µs                                        | fzip   | 11.1x         | 0.1%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 7.89 µs   | 107.9 µs  | 248.79 µs                                  | 52.17 µs                                         | fzip   | 31.5x         | 27.3%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 138.26 µs | 432.33 µs | 941.12 µs                                  | 262.78 µs                                        | fzip   | 6.8x          | 1.1%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.77 µs   | 181.57 µs | 278.68 µs                                  | 88.82 µs                                         | fzip   | 100.6x        | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 12.33 µs  | 42650 µs  | 8700 µs                                    | 3560 µs                                          | fzip   | 3459.0x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip    | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | ------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.52 µs | 4.31 µs   | 27.56 µs                                   | 16.25 µs                                         | fzip   | 18.1x         |
| 100K | 20.7 µs | 307.76 µs | 891.64 µs                                  | 48.12 µs                                         | fzip   | 43.1x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner      | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ----------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 8.71 µs   | 110.71 µs | 5.93 µs                                    | 53.86 µs                                         | mizchi/zlib | 18.7x         | 29.1%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 211.66 µs | 797.79 µs | 594.2 µs                                   | 343.84 µs                                        | fzip        | 3.8x          | 1.1%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 1.94 µs   | 8.08 µs   | 10.11 µs                                   | 3.62 µs                                          | fzip        | 5.2x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 90.55 µs  | 700.4 µs  | 1010 µs                                    | 120.87 µs                                        | fzip        | 11.2x         | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 8.36 µs  | 107.86 µs | 253.87 µs                                  | 52.95 µs                                         | fzip   | 30.4x         | 27.9%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 177.2 µs | 504.59 µs | 1080 µs                                    | 329.49 µs                                        | fzip   | 6.1x          | 1.1%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.92 µs  | 5.15 µs   | 27.21 µs                                   | 3.06 µs                                          | fzip   | 14.2x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 59.5 µs  | 368.76 µs | 736.21 µs                                  | 98.18 µs                                         | fzip   | 12.4x         | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 15.04 µs | 559.74 µs | fzip   | 37.2x         | 73.7%      | 74.8%         |
| decompress | 1.79 µs  | 38.32 µs  | fzip   | 21.4x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| CRC32     | 1K   | 0.74 µs  | 3.49 µs   | 3.52 µs                                    | 0.78 µs                                          | fzip   | 4.8x          |
| CRC32     | 100K | 72.08 µs | 352.69 µs | 353.57 µs                                  | 76.36 µs                                         | fzip   | 4.9x          |
| ADLER32   | 1K   | 0.4 µs   | 0.64 µs   | 0.7 µs                                     | 0.53 µs                                          | fzip   | 1.7x          |
| ADLER32   | 100K | 38.26 µs | 60.7 µs   | 66.58 µs                                   | 52.25 µs                                         | fzip   | 1.7x          |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 1.96 µs  | 8.59 µs   | fzip   | 4.4x          |
| 100K | 88.36 µs | 661.54 µs | fzip   | 7.5x          |
