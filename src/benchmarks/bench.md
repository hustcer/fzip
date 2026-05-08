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

| Pattern | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio |
| ------- | ---- | --------- | --------- | ------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ |
| zeros   | 1K   | 5.44 µs   | 104.64 µs | 43.17 µs                                   | fzip   | 19.2x         | 1.2%       | 1.0%          | 1.2%                                             |
| zeros   | 100K | 121.8 µs  | 430.81 µs | 741.75 µs                                  | fzip   | 6.1x          | 0.5%       | 0.1%          | 0.4%                                             |
| seq     | 1K   | 14.7 µs   | 112.59 µs | 245.72 µs                                  | fzip   | 16.7x         | 27.3%      | 27.2%         | 27.4%                                            |
| seq     | 100K | 134.03 µs | 429.63 µs | 929.12 µs                                  | fzip   | 6.9x          | 1.1%       | 0.7%          | 0.9%                                             |
| random  | 1K   | 2.76 µs   | 184.86 µs | 273.19 µs                                  | fzip   | 99.0x         | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        |
| random  | 100K | 12.05 µs  | 42070 µs  | 8580 µs                                    | fzip   | 3491.3x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------ | ------------- |
| 1K   | 1.48 µs  | 4.3 µs    | 28.55 µs                                   | fzip   | 19.3x         |
| 100K | 25.41 µs | 295.67 µs | 878.98 µs                                  | fzip   | 34.6x         |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | Winner      | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ----------- | ------------- | ---------- | ------------- | ------------------------------------------------ |
| compress   | 1K   | 15.85 µs  | 117.73 µs | 5.89 µs                                    | mizchi/zlib | 20.0x         | 29.1%      | 29.0%         | 102.2% ⚠️                                        |
| compress   | 100K | 248.52 µs | 798.61 µs | 589.12 µs                                  | fzip        | 3.2x          | 1.1%       | 0.7%          | 100.0% ⚠️                                        |
| decompress | 1K   | 2.34 µs   | 8.33 µs   | 10.01 µs                                   | fzip        | 4.3x          | -          | -             | -                                                |
| decompress | 100K | 128.05 µs | 652.73 µs | 993.55 µs                                  | fzip        | 7.8x          | -          | -             | -                                                |

> **Note**:
>
> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.
> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ |
| compress   | 1K   | 15.49 µs  | 117.87 µs | 246.71 µs                                  | fzip   | 15.9x         | 27.9%      | 27.8%         | 28.0%                                            |
| compress   | 100K | 173.53 µs | 496.42 µs | 1020 µs                                    | fzip   | 5.9x          | 1.1%       | 0.7%          | 0.9%                                             |
| decompress | 1K   | 1.91 µs   | 5.12 µs   | 26.83 µs                                   | fzip   | 14.0x         | -          | -             | -                                                |
| decompress | 100K | 64.01 µs  | 353.56 µs | 719.56 µs                                  | fzip   | 11.2x         | -          | -             | -                                                |

> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.

## ZIP

| Operation  | fzip    | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | ------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 27.8 µs | 575.25 µs | fzip   | 20.7x         | 73.7%      | 74.8%         |
| decompress | 1.84 µs | 38.38 µs  | fzip   | 20.9x         | -          | -             |

> **Note**: `mizchi/zlib` does not provide a ZIP API, so it is omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------ | ------------- |
| CRC32     | 1K   | 1.13 µs  | 3.49 µs   | 3.49 µs                                    | fzip   | 3.1x          |
| CRC32     | 100K | 111.5 µs | 352.52 µs | 354.53 µs                                  | fzip   | 3.2x          |
| ADLER32   | 1K   | 0.39 µs  | 0.61 µs   | 0.69 µs                                    | fzip   | 1.8x          |
| ADLER32   | 100K | 38.54 µs | 59.96 µs  | 66.94 µs                                   | fzip   | 1.7x          |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 2.34 µs   | 8.22 µs   | fzip   | 3.5x          |
| 100K | 127.71 µs | 653.33 µs | fzip   | 5.1x          |
