# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260608 (60bc8c3 2026-06-08)
- Target: wasm-gc
- Date: 2026-06-20

> **Note**:
>
> - `Max-Min Ratio` is calculated as the slowest mean time divided by the fastest mean time within the same row. `1.0x` means a tie; larger values mean a wider performance spread.
> - `Compression Ratio` is calculated as compressed size divided by original size. Smaller is better.

## DEFLATE Compress

| Pattern | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| zeros   | 1K   | 1.03 µs  | 94.98 µs  | 44.73 µs                                   | 55.04 µs                                         | fzip   | 92.2x         | 1.0%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 70.01 µs | 429.78 µs | 720 µs                                     | 113.17 µs                                        | fzip   | 10.3x         | 0.1%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 4.55 µs  | 105.88 µs | 249.64 µs                                  | 50.13 µs                                         | fzip   | 54.9x         | 27.2%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 92.77 µs | 436.1 µs  | 952.68 µs                                  | 260.79 µs                                        | fzip   | 10.3x         | 0.7%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.76 µs  | 173.09 µs | 275.11 µs                                  | 86.6 µs                                          | fzip   | 99.7x         | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 12.06 µs | 42760 µs  | 8560 µs                                    | 3560 µs                                          | fzip   | 3545.6x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.51 µs  | 4.41 µs   | 27.83 µs                                   | 3.93 µs                                          | fzip   | 18.4x         |
| 100K | 17.17 µs | 306.37 µs | 888.92 µs                                  | 43.32 µs                                         | fzip   | 51.8x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner      | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ----------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 5.22 µs   | 100.91 µs | 4.58 µs                                    | 52.49 µs                                         | mizchi/zlib | 22.0x         | 29.0%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 158.74 µs | 791.07 µs | 446.14 µs                                  | 343.41 µs                                        | fzip        | 5.0x          | 0.7%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 1.91 µs   | 8.48 µs   | 7.99 µs                                    | 3.44 µs                                          | fzip        | 4.4x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 80.05 µs  | 661.12 µs | 797.35 µs                                  | 119.89 µs                                        | fzip        | 10.0x         | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 4.97 µs   | 106.04 µs | 247.58 µs                                  | 51.44 µs                                         | fzip   | 49.8x         | 27.8%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 138.49 µs | 497.41 µs | 1020 µs                                    | 319.71 µs                                        | fzip   | 7.4x          | 0.7%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.92 µs   | 5.33 µs   | 27.01 µs                                   | 3.21 µs                                          | fzip   | 14.1x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 55.91 µs  | 369.18 µs | 736.91 µs                                  | 98.11 µs                                         | fzip   | 13.2x         | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 15.04 µs | 551.37 µs | fzip   | 36.7x         | 73.7%      | 74.8%         |
| decompress | 1.96 µs  | 38.92 µs  | fzip   | 19.9x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| CRC32     | 1K   | 0.68 µs  | 3.51 µs   | 0.79 µs                                    | 0.77 µs                                          | fzip   | 5.2x          |
| CRC32     | 100K | 66.25 µs | 353.34 µs | 75.06 µs                                   | 75.5 µs                                          | fzip   | 5.3x          |
| ADLER32   | 1K   | 0.39 µs  | 0.62 µs   | 0.69 µs                                    | 0.54 µs                                          | fzip   | 1.8x          |
| ADLER32   | 100K | 38.03 µs | 59.74 µs  | 67.85 µs                                   | 52.16 µs                                         | fzip   | 1.8x          |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 1.92 µs  | 8.48 µs   | fzip   | 4.4x          |
| 100K | 80.25 µs | 657.53 µs | fzip   | 8.2x          |
