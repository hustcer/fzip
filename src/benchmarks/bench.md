# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260608 (60bc8c3 2026-06-08)
- Target: wasm-gc
- Date: 2026-06-15

> **Note**:
>
> - `Max-Min Ratio` is calculated as the slowest mean time divided by the fastest mean time within the same row. `1.0x` means a tie; larger values mean a wider performance spread.
> - `Compression Ratio` is calculated as compressed size divided by original size. Smaller is better.

## DEFLATE Compress

| Pattern | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| zeros   | 1K   | 1.02 µs  | 105.98 µs | 44.79 µs                                   | 56.47 µs                                         | fzip   | 103.9x        | 1.0%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 68.73 µs | 434.58 µs | 718.81 µs                                  | 113.07 µs                                        | fzip   | 10.5x         | 0.1%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 4.47 µs  | 116.36 µs | 249.5 µs                                   | 51.68 µs                                         | fzip   | 55.8x         | 27.2%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 90.1 µs  | 438.22 µs | 940.39 µs                                  | 263.7 µs                                         | fzip   | 10.4x         | 0.7%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.74 µs  | 189.83 µs | 276.23 µs                                  | 97.39 µs                                         | fzip   | 100.8x        | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 12.95 µs | 43350 µs  | 8690 µs                                    | 3570 µs                                          | fzip   | 3347.5x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.52 µs  | 4.27 µs   | 27.98 µs                                   | 3.73 µs                                          | fzip   | 18.4x         |
| 100K | 35.78 µs | 305.82 µs | 890.79 µs                                  | 44.09 µs                                         | fzip   | 24.9x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner      | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ----------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 5.27 µs   | 113.55 µs | 4.56 µs                                    | 53.81 µs                                         | mizchi/zlib | 24.9x         | 29.0%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 160.72 µs | 795.99 µs | 446.99 µs                                  | 344.85 µs                                        | fzip        | 5.0x          | 0.7%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 1.98 µs   | 8.08 µs   | 7.96 µs                                    | 3.83 µs                                          | fzip        | 4.1x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 85.42 µs  | 660.34 µs | 795.33 µs                                  | 121.18 µs                                        | fzip        | 9.3x          | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 4.96 µs   | 117.12 µs | 253.7 µs                                   | 53.09 µs                                         | fzip   | 51.1x         | 27.8%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 124.87 µs | 504.54 µs | 1140 µs                                    | 352.39 µs                                        | fzip   | 9.1x          | 0.7%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.93 µs   | 5.21 µs   | 26.93 µs                                   | 3.01 µs                                          | fzip   | 14.0x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 74.09 µs  | 372.09 µs | 736.42 µs                                  | 99.11 µs                                         | fzip   | 9.9x          | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip     | moonzip  | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | -------- | ------ | ------------- | ---------- | ------------- |
| compress   | 15.22 µs | 581.7 µs | fzip   | 38.2x         | 73.7%      | 74.8%         |
| decompress | 1.93 µs  | 38.65 µs | fzip   | 20.0x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner      | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ----------- | ------------- |
| CRC32     | 1K   | 0.74 µs  | 3.51 µs   | 0.77 µs                                    | 0.77 µs                                          | fzip        | 4.7x          |
| CRC32     | 100K | 75.05 µs | 355.45 µs | 74.91 µs                                   | 75.49 µs                                         | mizchi/zlib | 4.7x          |
| ADLER32   | 1K   | 0.39 µs  | 0.63 µs   | 0.69 µs                                    | 0.53 µs                                          | fzip        | 1.8x          |
| ADLER32   | 100K | 38.49 µs | 60.81 µs  | 67.7 µs                                    | 52.07 µs                                         | fzip        | 1.8x          |

## Auto-detect Decompress

| Size | fzip     | moonzip   | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------ | ------------- |
| 1K   | 1.97 µs  | 8.33 µs   | fzip   | 4.2x          |
| 100K | 86.04 µs | 663.83 µs | fzip   | 7.7x          |
