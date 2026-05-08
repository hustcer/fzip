# fzip Benchmark Report

- Platform: Darwin arm64
- MoonBit: moon 0.1.20260427 (48d7def 2026-04-27)
- Target: wasm-gc
- Date: 2026-05-08

## DEFLATE Compress

| Pattern | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio |
| ------- | ---- | --------- | --------- | ------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ |
| zeros   | 1K   | 5.4 µs    | 105.38 µs | 44.03 µs                                   | fzip   | 19.5x         | 1.2%       | 1.0%          | 1.2%                                             |
| zeros   | 100K | 118.14 µs | 432.37 µs | 720.34 µs                                  | fzip   | 6.1x          | 0.5%       | 0.1%          | 0.4%                                             |
| seq     | 1K   | 14.83 µs  | 108.06 µs | 245.05 µs                                  | fzip   | 16.5x         | 27.3%      | 27.2%         | 27.4%                                            |
| seq     | 100K | 134.6 µs  | 430.63 µs | 933.72 µs                                  | fzip   | 6.9x          | 1.1%       | 0.7%          | 0.9%                                             |
| random  | 1K   | 2.76 µs   | 181.08 µs | 273.02 µs                                  | fzip   | 98.9x         | 100.5% ⚠️  | 105.2% ⚠️     | 105.1% ⚠️                                        |
| random  | 100K | 12.03 µs  | 42060 µs  | 8580 µs                                    | fzip   | 3496.3x       | 100.0% ⚠️  | 100.1% ⚠️     | 100.1% ⚠️                                        |

> **⚠️ Note**:
>
> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.
> - Compression Ratio = Compressed Size / Original Size, smaller is better.

## DEFLATE Decompress

| Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | Winner | Max-Min Ratio |
| ---- | -------- | --------- | ------------------------------------------ | ------ | ------------- |
| 1K   | 1.48 µs  | 4.37 µs   | 27.95 µs                                   | fzip   | 18.9x         |
| 100K | 34.24 µs | 292.87 µs | 874.46 µs                                  | fzip   | 25.5x         |

## GZIP

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ |
| compress   | 1K   | 16.05 µs  | 105.61 µs | 5.88 µs                                    | zlib   | 18.0x         | 29.1%      | 29.0%         | 102.2% ⚠️                                        |
| compress   | 100K | 246.94 µs | 791.67 µs | 586.46 µs                                  | fzip   | 3.2x          | 1.1%       | 0.7%          | 100.0% ⚠️                                        |
| decompress | 1K   | 2.33 µs   | 8.23 µs   | 9.88 µs                                    | fzip   | 4.2x          | -          | -             | -                                                |
| decompress | 100K | 128.61 µs | 654.33 µs | 984.93 µs                                  | fzip   | 7.7x          | -          | -             | -                                                |

> **Note**: `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.

## Zlib

| Operation  | Size | fzip      | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio | [zlib](https://github.com/mizchi/zlib.mbt) Ratio |
| ---------- | ---- | --------- | --------- | ------------------------------------------ | ------ | ------------- | ---------- | ------------- | ------------------------------------------------ |
| compress   | 1K   | 15.25 µs  | 106.55 µs | 249.12 µs                                  | fzip   | 16.3x         | 27.9%      | 27.8%         | 28.0%                                            |
| compress   | 100K | 173.56 µs | 490 µs    | 1000 µs                                    | fzip   | 5.8x          | 1.1%       | 0.7%          | 0.9%                                             |
| decompress | 1K   | 1.88 µs   | 5.2 µs    | 26.84 µs                                   | fzip   | 14.3x         | -          | -             | -                                                |
| decompress | 100K | 64.34 µs  | 357.77 µs | 732.54 µs                                  | fzip   | 11.4x         | -          | -             | -                                                |

## ZIP

| Operation  | fzip     | moonzip   | Winner | Max-Min Ratio | fzip Ratio | moonzip Ratio |
| ---------- | -------- | --------- | ------ | ------------- | ---------- | ------------- |
| compress   | 27.77 µs | 583.31 µs | fzip   | 21.0x         | 73.7%      | 74.8%         |
| decompress | 1.81 µs  | 38.65 µs  | fzip   | 21.4x         | -          | -             |

> **Note**: `mizchi/zlib` does not provide a ZIP API, so it is omitted from this table.

## Checksum

| Algorithm | Size | fzip     | moonzip   | [zlib](https://github.com/mizchi/zlib.mbt) | Winner | Max-Min Ratio |
| --------- | ---- | -------- | --------- | ------------------------------------------ | ------ | ------------- |
| CRC32     | 1K   | 1.14 µs  | 3.52 µs   | 3.53 µs                                    | fzip   | 3.1x          |
| CRC32     | 100K | 112.6 µs | 357.21 µs | 355.14 µs                                  | fzip   | 3.2x          |
| ADLER32   | 1K   | 0.39 µs  | 0.62 µs   | 0.68 µs                                    | fzip   | 1.7x          |
| ADLER32   | 100K | 38.33 µs | 60.08 µs  | 66.82 µs                                   | fzip   | 1.7x          |

## Auto-detect Decompress

| Size | fzip      | moonzip   | Winner | Max-Min Ratio |
| ---- | --------- | --------- | ------ | ------------- |
| 1K   | 2.35 µs   | 8.14 µs   | fzip   | 3.5x          |
| 100K | 127.78 µs | 653.59 µs | fzip   | 5.1x          |
