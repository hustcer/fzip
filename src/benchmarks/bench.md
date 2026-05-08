# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260427 (48d7def 2026-04-27)
- Target: wasm-gc
- Date: 2026-05-08

> **Note**:
>
> - `Max-Min Ratio` is calculated as the slowest mean time divided by the fastest mean time within the same row. `1.0x` means a tie; larger values mean a wider performance spread.
> - `Compression Ratio` is calculated as compressed size divided by original size. Smaller is better.

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner   | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | -------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| zeros   | 1K   | 5.39 µs   | 105.22 µs | 46.49 µs                                   | 57.22 µs                                         | fzip     | 19.5x         | 1.2%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 117.35 µs | 421.39 µs | 711.82 µs                                  | 114.31 µs                                        | compress | 6.2x          | 0.5%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 14.92 µs  | 113.7 µs  | 249.07 µs                                  | 52.54 µs                                         | fzip     | 16.7x         | 27.3%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 137.38 µs | 433.17 µs | 947.26 µs                                  | 262.39 µs                                        | fzip     | 6.9x          | 1.1%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.78 µs   | 185.99 µs | 277.94 µs                                  | 86.82 µs                                         | fzip     | 100.0x        | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 12.24 µs  | 42050 µs  | 8760 µs                                    | 3610 µs                                          | fzip     | 3435.5x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.53 µs  | 4.31 µs   | 28.12 µs                                   | 4.1 µs                                           | fzip   | 18.4x         |
| 100K | 25.35 µs | 301.69 µs | 902.73 µs                                  | 43.9 µs                                          | fzip   | 35.6x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner      | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ----------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 15.72 µs  | 117.66 µs | 5.9 µs                                     | 53.23 µs                                         | mizchi/zlib | 19.9x         | 29.1%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 206.11 µs | 798.03 µs | 590.04 µs                                  | 337.65 µs                                        | fzip        | 3.9x          | 1.1%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 1.92 µs   | 8.16 µs   | 9.86 µs                                    | 4.1 µs                                           | fzip        | 5.1x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 87.89 µs  | 668.9 µs  | 994.93 µs                                  | 123.19 µs                                        | fzip        | 11.3x         | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 15.3 µs   | 121.45 µs | 249.29 µs                                  | 55.32 µs                                         | fzip   | 16.3x         | 27.9%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 177.57 µs | 509.46 µs | 1060 µs                                    | 321.59 µs                                        | fzip   | 6.0x          | 1.1%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.91 µs   | 5.23 µs   | 27.51 µs                                   | 3.86 µs                                          | fzip   | 14.4x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 65.49 µs  | 364.91 µs | 732.51 µs                                  | 97.9 µs                                          | fzip   | 11.2x         | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip     | moonzip  | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | -------- | ------ | ------------- | ---------- | ------------- |
| compress   | 26.02 µs | 566.6 µs | fzip   | 21.8x         | 73.7%      | 74.8%         |
| decompress | 1.81 µs  | 39.44 µs | fzip   | 21.8x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| CRC32     | 1K   | 0.72 µs  | 3.49 µs   | 3.49 µs                                    | 0.77 µs                                          | fzip   | 4.8x          |
| CRC32     | 100K | 70.73 µs | 352.11 µs | 352.29 µs                                  | 75.37 µs                                         | fzip   | 5.0x          |
| ADLER32   | 1K   | 0.39 µs  | 0.62 µs   | 0.69 µs                                    | 0.52 µs                                          | fzip   | 1.8x          |
| ADLER32   | 100K | 38.03 µs | 59.81 µs  | 66.57 µs                                   | 50.66 µs                                         | fzip   | 1.8x          |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 1.95 µs  | 8.42 µs   | fzip   | 4.3x          |
| 100K | 88.37 µs | 659.31 µs | fzip   | 7.5x          |
