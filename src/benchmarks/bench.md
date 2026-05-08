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
| zeros   | 1K   | 5.39 µs   | 105.1 µs  | 44.6 µs                                    | 55.58 µs                                         | fzip     | 19.5x         | 1.2%       | 1.0%          | 1.2%                                             | 1.4%                                                   |
| zeros   | 100K | 117.45 µs | 430.49 µs | 710 µs                                     | 112.06 µs                                        | compress | 6.3x          | 0.5%       | 0.1%          | 0.4%                                             | 0.1%                                                   |
| seq     | 1K   | 14.72 µs  | 112.68 µs | 245.26 µs                                  | 50.59 µs                                         | fzip     | 16.7x         | 27.3%      | 27.2%         | 27.4%                                            | 27.7%                                                  |
| seq     | 100K | 134.19 µs | 431.25 µs | 932.41 µs                                  | 259.57 µs                                        | fzip     | 6.9x          | 1.1%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| random  | 1K   | 2.78 µs   | 184.62 µs | 273.86 µs                                  | 85.71 µs                                         | fzip     | 98.5x         | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        | 105.5% ⚠️                                              |
| random  | 100K | 11.91 µs  | 42140 µs  | 8570 µs                                    | 3520 µs                                          | fzip     | 3538.2x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        | 100.2% ⚠️                                              |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- |
| 1K   | 1.48 µs  | 4.3 µs    | 28.1 µs                                    | 4.06 µs                                          | fzip   | 19.0x         |
| 100K | 25.02 µs | 300.89 µs | 882.26 µs                                  | 43.09 µs                                         | fzip   | 35.3x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner      | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ----------- | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 15.89 µs  | 112.72 µs | 5.91 µs                                    | 52.35 µs                                         | mizchi/zlib | 19.1x         | 29.1%      | 29.0%         | 102.2% ⚠️                                        | 29.5%                                                  |
| compress   | 100K | 244.45 µs | 797.44 µs | 590.25 µs                                  | 337.38 µs                                        | fzip        | 3.3x          | 1.1%       | 0.7%          | 100.0% ⚠️                                        | 0.7%                                                   |
| decompress | 1K   | 2.33 µs   | 8.4 µs    | 9.96 µs                                    | 4.08 µs                                          | fzip        | 4.3x          | -          | -             | -                                                | -                                                      |
| decompress | 100K | 127.56 µs | 656.6 µs  | 985.27 µs                                  | 120.71 µs                                        | compress    | 8.2x          | -          | -             | -                                                | -                                                      |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio | [compress](https://github.com/bikallem/compress) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ | ------------------------------------------------------ |
| compress   | 1K   | 15.42 µs  | 109.84 µs | 247.41 µs                                  | 51.88 µs                                         | fzip   | 16.0x         | 27.9%      | 27.8%         | 28.0%                                            | 28.3%                                                  |
| compress   | 100K | 173.93 µs | 492.94 µs | 1000 µs                                    | 319.43 µs                                        | fzip   | 5.7x          | 1.1%       | 0.7%          | 0.9%                                             | 0.7%                                                   |
| decompress | 1K   | 1.88 µs   | 5.09 µs   | 27.31 µs                                   | 3.78 µs                                          | fzip   | 14.5x         | -          | -             | -                                                | -                                                      |
| decompress | 100K | 63.24 µs  | 359.85 µs | 722.26 µs                                  | 99.49 µs                                         | fzip   | 11.4x         | -          | -             | -                                                | -                                                      |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 27.42 µs | 572.45 µs | fzip   | 20.9x         | 73.7%      | 74.8%         |
| decompress | 1.77 µs  | 38.38 µs  | fzip   | 21.7x         | -          | -             |

> **Note**: `mizchi/zlib` and `bikallem/compress` do not provide ZIP APIs, so they are omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | [compress](https://github.com/bikallem/compress) | Winner   | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------------------------------------------------ | -------- | ------------- |
| CRC32     | 1K   | 1.13 µs  | 3.5 µs    | 3.49 µs                                    | 0.77 µs                                          | compress | 4.5x          |
| CRC32     | 100K | 111.7 µs | 352.22 µs | 352.3 µs                                   | 75.55 µs                                         | compress | 4.7x          |
| ADLER32   | 1K   | 0.4 µs   | 0.61 µs   | 0.69 µs                                    | 0.53 µs                                          | fzip     | 1.7x          |
| ADLER32   | 100K | 38.03 µs | 59.77 µs  | 66.63 µs                                   | 51.4 µs                                          | fzip     | 1.8x          |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 2.33 µs   | 8.3 µs    | fzip   | 3.6x          |
| 100K | 127.36 µs | 655.21 µs | fzip   | 5.1x          |
