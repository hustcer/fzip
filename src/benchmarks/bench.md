# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260427 (48d7def 2026-04-27)
- Target: wasm-gc
- Date: 2026-05-11

> **Note**:
>
> - `Max-Min Ratio` is calculated as the slowest mean time divided by the fastest mean time within the same row. `1.0x` means a tie; larger values mean a wider performance spread.
> - `Compression Ratio` is calculated as compressed size divided by original size. Smaller is better.

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner   | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | -------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| zeros   | 1K   | 3.95 µs   | 106.03 µs | 45.17 µs                                   | 61.71 µs                                         | fzip     | 26.8x         | 1.2%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 118.1 µs  | 431.72 µs | 723.64 µs                                  | 115.89 µs                                        | compress | 6.2x          | 0.5%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 7.89 µs   | 105.23 µs | 247.82 µs                                  | 51.43 µs                                         | fzip     | 31.4x         | 27.3%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 134.94 µs | 435.91 µs | 937.7 µs                                   | 261.51 µs                                        | fzip     | 6.9x          | 1.1%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.79 µs   | 183.73 µs | 281.99 µs                                  | 87.14 µs                                         | fzip     | 101.1x        | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 12.69 µs  | 44080 µs  | 8710 µs                                    | 3550 µs                                          | fzip     | 3473.6x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.5 µs   | 4.28 µs   | 27.33 µs                                   | 4.04 µs                                          | fzip   | 18.2x         |
| 100K | 20.28 µs | 304.54 µs | 882.74 µs                                  | 43.51 µs                                         | fzip   | 43.5x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner      | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ----------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 8.59 µs   | 110.3 µs  | 5.87 µs                                    | 53.37 µs                                         | mizchi/zlib | 18.8x         | 29.1%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 207.86 µs | 794.1 µs  | 587.44 µs                                  | 341.09 µs                                        | fzip        | 3.8x          | 1.1%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 1.94 µs   | 8.03 µs   | 9.92 µs                                    | 3.98 µs                                          | fzip        | 5.1x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 87.49 µs  | 656.34 µs | 992.63 µs                                  | 121.37 µs                                        | fzip        | 11.3x         | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 8.25 µs   | 108.38 µs | 262.72 µs                                  | 66.53 µs                                         | fzip   | 31.8x         | 27.9%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 176.72 µs | 523.78 µs | 1060 µs                                    | 328.04 µs                                        | fzip   | 6.0x          | 1.1%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.92 µs   | 5.09 µs   | 26.56 µs                                   | 3.75 µs                                          | fzip   | 13.8x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 58.51 µs  | 366.97 µs | 735.22 µs                                  | 98.73 µs                                         | fzip   | 12.6x         | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 17.84 µs | 582.31 µs | fzip   | 32.6x         | 73.7%      | 74.8%         |
| decompress | 1.79 µs  | 38.4 µs   | fzip   | 21.5x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| CRC32     | 1K   | 0.73 µs  | 3.5 µs    | 3.5 µs                                     | 0.76 µs                                          | fzip   | 4.8x          |
| CRC32     | 100K | 71.96 µs | 355.25 µs | 359.3 µs                                   | 75.59 µs                                         | fzip   | 5.0x          |
| ADLER32   | 1K   | 0.4 µs   | 0.62 µs   | 0.69 µs                                    | 0.54 µs                                          | fzip   | 1.7x          |
| ADLER32   | 100K | 38.51 µs | 60.23 µs  | 67.46 µs                                   | 51.98 µs                                         | fzip   | 1.8x          |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 1.94 µs  | 8.08 µs   | fzip   | 4.2x          |
| 100K | 86.94 µs | 683.62 µs | fzip   | 7.9x          |
