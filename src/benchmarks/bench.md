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
| zeros   | 1K   | 5.39 µs   | 94 µs     | 42.96 µs                                   | 54.2 µs                                          | fzip     | 17.4x         | 1.2%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 116.41 µs | 419.37 µs | 716.23 µs                                  | 113.09 µs                                        | compress | 6.3x          | 0.5%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 14.74 µs  | 103.13 µs | 246.38 µs                                  | 50.7 µs                                          | fzip     | 16.7x         | 27.3%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 134.62 µs | 432.06 µs | 935.5 µs                                   | 260.81 µs                                        | fzip     | 6.9x          | 1.1%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.79 µs   | 180.18 µs | 273.3 µs                                   | 85.95 µs                                         | fzip     | 98.0x         | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 11.92 µs  | 42150 µs  | 8670 µs                                    | 3540 µs                                          | fzip     | 3536.1x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.48 µs  | 4.31 µs   | 27.71 µs                                   | 4.05 µs                                          | fzip   | 18.7x         |
| 100K | 25.28 µs | 300.75 µs | 881.38 µs                                  | 43.55 µs                                         | fzip   | 34.9x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner      | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ----------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 15.93 µs  | 112.42 µs | 5.89 µs                                    | 52.83 µs                                         | mizchi/zlib | 19.1x         | 29.1%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 245.61 µs | 788.68 µs | 588.43 µs                                  | 342.23 µs                                        | fzip        | 3.2x          | 1.1%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 2.35 µs   | 8.14 µs   | 9.97 µs                                    | 3.94 µs                                          | fzip        | 4.2x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 128.24 µs | 655.46 µs | 987.34 µs                                  | 122 µs                                           | compress    | 8.1x          | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 15.2 µs  | 102.99 µs | 248.61 µs                                  | 51.8 µs                                          | fzip   | 16.4x         | 27.9%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 175.7 µs | 496.06 µs | 1010 µs                                    | 318.2 µs                                         | fzip   | 5.7x          | 1.1%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.88 µs  | 5.12 µs   | 26.33 µs                                   | 3.69 µs                                          | fzip   | 14.0x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 63.4 µs  | 360.44 µs | 733.49 µs                                  | 104.87 µs                                        | fzip   | 11.6x         | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 27.77 µs | 553.91 µs | fzip   | 19.9x         | 73.7%      | 74.8%         |
| decompress | 1.78 µs  | 38.34 µs  | fzip   | 21.5x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner   | Max-Min Ratio |
| --------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | -------- | ------------- |
| CRC32     | 1K   | 1.12 µs   | 3.5 µs    | 3.5 µs                                     | 0.76 µs                                          | compress | 4.6x          |
| CRC32     | 100K | 112.29 µs | 353.64 µs | 353.47 µs                                  | 75.11 µs                                         | compress | 4.7x          |
| ADLER32   | 1K   | 0.39 µs   | 0.62 µs   | 0.68 µs                                    | 0.53 µs                                          | fzip     | 1.7x          |
| ADLER32   | 100K | 38.35 µs  | 60.4 µs   | 66.9 µs                                    | 51.43 µs                                         | fzip     | 1.7x          |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 2.4 µs    | 8.17 µs   | fzip   | 3.4x          |
| 100K | 128.99 µs | 654.69 µs | fzip   | 5.1x          |
