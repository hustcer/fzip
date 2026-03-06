# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

fzip is a high-performance compression library for MoonBit, ported from the JavaScript [fflate](https://github.com/101arrowz/fflate) library. It implements DEFLATE, GZIP, Zlib, and ZIP formats in a single flat package (`hustcer/fzip`).

## Build & Test Commands

```bash
moon check              # Type check (fast, run after every edit)
moon build              # Full build
moon test               # Run all tests (44 tests)
moon test -v            # Verbose with test names
moon test deflate_wbtest.mbt --filter "deflate*"  # Run specific tests
moon fmt                # Format all code
moon info               # Regenerate pkg.generated.mbti (public API summary)
```

Validation loop: `moon check` → `moon test` → `moon fmt` → `moon info`

## Architecture

Single-package design — all `.mbt` files share the same scope. No imports needed.

### Data Flow (compression)

```
raw data → dflt() [LZ77 + Huffman] → raw DEFLATE bits
         → deflate_sync()           (DEFLATE wrapper)
         → gzip_sync()              (+ GZIP header/CRC-32 footer)
         → zlib_sync()              (+ Zlib header/Adler-32 footer)
         → zip_sync()               (+ ZIP local headers/central directory/EOCD)
```

### Data Flow (decompression)

```
compressed → inflt() [block decoder] → raw data
           → inflate_sync()           (DEFLATE wrapper)
           → gunzip_sync()            (validates GZIP header/footer)
           → unzlib_sync()            (validates Zlib header/footer)
           → unzip_sync()             (parses ZIP structure)
           → decompress_sync()        (auto-detects format: GZIP/Zlib/raw)
```

### File Responsibilities

| File | Role |
|------|------|
| `bits.mbt` | Bit-level I/O (`bits`, `bits16`, `wbits`, `wbits16`), byte readers (`b2`/`b4`/`b8`), buffer helpers (`slc`, `fa_set`) |
| `tables.mbt` | DEFLATE constant lookup tables (`fleb`, `fdeb`, `clim`, `rev`, `flt`, `fdt`, `deo`) |
| `huffman.mbt` | Huffman tree construction (`h_map`, `h_tree`, `freb`, `lc_gen`, `clen`); derived tables (`fl`, `fd`, `flm`, `fdm` and their reverse variants) |
| `deflate.mbt` | Core compressor: `dflt()` (LZ77 hash chain + Huffman), `wblk()`/`wfblk()` block writers, `dopt()`, public `deflate_sync()` |
| `inflate.mbt` | Core decompressor: `inflt()` (~280 lines, handles stored/fixed/dynamic blocks), `ensure_buf()`, public `inflate_sync()` |
| `gzip.mbt` | GZIP format: header write/parse (`gzh`/`gzs`), `gzip_sync()`, `gunzip_sync()` |
| `zlib.mbt` | Zlib format: header write/parse (`zlh`/`zls`), `zlib_sync()`, `unzlib_sync()` |
| `zip.mbt` | ZIP format: local/central headers (`wzh`/`wzf`/`zh`/`slzh`), ZIP64 (`z64e`), `zip_sync()`, `unzip_sync()`, `unzip_list()` |
| `checksum.mbt` | CRC-32 and Adler-32 (both one-shot and incremental state) |
| `string.mbt` | UTF-8 ↔ String conversion (`str_to_u8`, `str_from_u8`) with latin1 mode |
| `stream.mbt` | Streaming wrappers: `DeflateStream`, `InflateStream`, `GzipStream`, `GunzipStream`, `ZlibStream`, `UnzlibStream`, `DecompressStream` |
| `fzip.mbt` | Convenience API: `compress_sync()` (= gzip), `decompress_sync()` (auto-detect) |
| `error.mbt` | `FzipErrorCode` enum (15 codes), `FzipError` suberror, `fzip_err()` helper |
| `types.mbt` | Option structs with `::default()` methods |

### Key Internal Patterns

- **Buffer type**: `FixedArray[Byte]` everywhere (MoonBit equivalent of JS `Uint8Array`). Fixed size — use `ensure_buf()` or allocate new + `blit_to()` to grow.
- **`slc()` copies**: Unlike JS `subarray` (zero-copy view), `slc()` always allocates a new array.
- **Unsigned operations**: CRC-32/Adler-32 use `UInt` with `reinterpret_as_uint()`/`reinterpret_as_int()` for unsigned semantics.
- **Symbol encoding in `dflt()`**: Match length+distance packed as `268435456 | (revfl[l] << 18) | revfd[d]`.
- **Error pattern**: Internal code uses `raise fzip_err(ErrorCode)` to throw; decompression functions declare `raise FzipError`.

### Test Organization

- `*_wbtest.mbt` — White-box tests (can access private functions like `bits`, `inflt`, `slc`)
- `roundtrip_test.mbt` — Black-box roundtrip tests across all formats
