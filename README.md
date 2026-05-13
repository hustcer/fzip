# fzip – High-performance compression library for MoonBit

`fzip` (short for _fast zip_) is a high-performance, in-memory compression library for MoonBit, ported from the [fflate](https://github.com/101arrowz/fflate) JavaScript library.

This library provides:

- **Deflate, GZIP, Zlib, and ZIP** compression and decompression
- **Streaming and Synchronous APIs** for flexible data processing
- **Built-in Security** against zip bombs, path traversal, and corrupted data

## Benchmark

Platform: macOS (Apple Silicon), MoonBit wasm-gc target. Full results in [bench.md](https://github.com/hustcer/fzip/blob/feature/bench/src/benchmarks/bench.md).

## Features

- Pure MoonBit implementation with no external dependencies (compiled to Wasm-GC)
- Support for DEFLATE, GZIP, Zlib, and ZIP formats
- Automatic format detection for decompression
- High-performance, memory-efficient streaming APIs
- Robust security limits configurable per operation
- Comprehensive test coverage (220+ tests)

## Installation

```bash
moon add hustcer/fzip
```

Or add this to your `moon.mod.json`:

```json
{
  "deps": {
    "hustcer/fzip": "0.7.0"
  }
}
```

## Quick Start

```moonbit
// Compress (GZIP)
let data = @fzip.str_to_u8("Hello, MoonBit!")
let compressed = @fzip.gzip_sync(data)

// Decompress (auto-detect format)
let original = @fzip.decompress_sync(compressed)
let text = @fzip.str_from_u8(original)

println(text) // "Hello, MoonBit!"
```

## Current Status

This library is fully functional and actively maintained. Detailed documentation for APIs can be explored via `moon ide doc` or in the codebase.

### Working Features

- **DEFLATE compression/decompression** - Full deflate algorithm implementation
- **GZIP format support** - Deflate with GZIP headers, timestamps, metadata, and CRC-32 checksums
- **Zlib format support** - Deflate with Zlib headers and Adler-32 checksums
- **ZIP archive structure** - Types and basic operations for parsing and encoding
- **ZIP encoding** - Write complete ZIP archives with proper headers
- **ZIP parsing** - Extract existing ZIP files with format support
- **Streaming compression** - Stream-based handlers for chunk-based data processing
- **In-built protections** - Size limits, path traversal detection, and zip bomb mitigation
- **Auto-detection** - Smart decompression that automatically recognizes formats
- **Comprehensive tests** - 220+ passing tests spanning basic encoding, edge cases, and security

### API Compatibility

The API is directly inspired by the original `fflate` library structure but adapted for robust MoonBit semantics:

- Type-safe synchronous and stream-based representations (`ondata` callbacks).
- Clean error propagation utilizing MoonBit's `raise Error` mechanisms rather than unchecked exceptions.
- Zero-dependency string encoding/decoding implementations built-in.

## Detailed API

### ZIP

```moonbit
// Create ZIP archive
let files : Array[(String, FixedArray[Byte])] = [
  ("hello.txt", @fzip.str_to_u8("Hello!")),
  ("binary.dat", my_bytes),
]
let archive = @fzip.zip_sync(files)

// Extract ZIP archive
let extracted = @fzip.unzip_sync(archive)
for entry in extracted {
  let (filename, content) = entry
  println("\{filename}: \{content.length()} bytes")
}

// List files without extracting
let infos = @fzip.unzip_list(archive)
for info in infos {
  println("\{info.name}: original size \{info.original_size} (compressed: \{info.size})")
}
```

#### ZIP64 metadata support

`zip_sync`, `unzip_sync`, and `unzip_list` understand ZIP64 metadata for
archives and entries that fit inside the sync API's `Int`/`FixedArray`
budget. The writer automatically promotes an archive to ZIP64 when any of
the classic 4 GiB / 64 K limits is reached:

- entry compressed or uncompressed size ≥ `0xFFFFFFFF`
- entry local-header offset ≥ `0xFFFFFFFF`
- entry count ≥ `0xFFFF`
- central directory size or offset ≥ `0xFFFFFFFF`

When promoted the archive carries the spec-mandated ZIP64 EOCD record,
ZIP64 EOCD locator, and per-entry ZIP64 extra fields; the existing
classic EOCD continues to be written last so classic-only readers can
still locate the central directory.

The reader path validates ZIP64 metadata up front: structurally valid
ZIP64 archives whose count, size, offset, or layout exceeds what the
current sync API can safely index raise the new
`FzipErrorCode::Zip64ValueTooLarge`. Data-descriptor entries
(general-purpose bit 3) are accepted using the central directory's
authoritative sizes and CRC. Malformed archives, encryption, multi-disk
archives, and missing required ZIP64 extras continue to raise
`InvalidZipData`.

For recoverable writer failures (ZIP64 layout overflow, oversized extras,
filenames/comments that do not fit ZIP fields, or invalid extra-field ids)
use the new `zip_sync_checked` API:

```moonbit
let archive = @fzip.zip_sync_checked(files) catch {
  FzipError(code~, message~) => {
    // handle Zip64ValueTooLarge, ExtraFieldTooLong, FilenameTooLong,
    // InvalidZipData, or other writer validation errors here
    return
  }
}
```

`zip_sync` itself shares the same builder and traps deterministically
with a stable abort message when the builder reports a recoverable
error — it never returns a partial or corrupt archive.

True large-file streaming (entries or archives larger than ~2 GiB) is
not yet supported; that work is tracked under Phase 2 and depends on a
streaming DEFLATE engine. See [`docs/zip64.md`](docs/zip64.md) for the
full plan.

### Automatic Decompression

```moonbit
// compress_sync defaults to gzip_sync
let compressed = @fzip.compress_sync(data)

// decompress_sync automatically detects GZIP, Zlib, or DEFLATE
let original = @fzip.decompress_sync(compressed)
```

### Streaming

```moonbit
let stream = @fzip.DeflateStream::new()
stream.ondata = Some(FlateStreamHandler(fn(data, is_final) {
  // handle output chunk
}))
stream.push(chunk1)
stream.push(chunk2, final_=true)
```

Available streams: `DeflateStream`, `InflateStream`, `GzipStream`, `GunzipStream`, `ZlibStream`, `UnzlibStream`, `DecompressStream`.

### Security Features

`fzip` includes built-in protections against common compression attacks:

- **Size limits**: Configurable max output (default 100MB) and input (default 1GB) sizes prevent zip bombs; ZIP extraction also caps total sync output and entry fan-out
- **Checksum verification**: CRC-32 (GZIP and ZIP entries) and Adler-32 (Zlib) checksums are verified by default to detect corrupted data
  - Can be disabled via `verify_checksum: false` for better performance when data integrity is guaranteed
  - Default is `true` (security-first approach)
- **Compression ratio check**: ZIP files with compression ratios > 1000:1 are rejected
- **Path traversal protection**: ZIP entries with unsafe paths (`../`, absolute paths) are rejected
- **Filename length validation**: ZIP filenames are limited to 4096 bytes
- **Data descriptor support**: ZIP entries with general-purpose bit 3 are bounded by central-directory sizes and verified with CRC-32

Configure security options per operation:

```moonbit
// With all security features (default)
let original = @fzip.gunzip_sync(compressed, opts={
  out: None,
  dictionary: None,
  max_output_size: 10485760,   // 10MB limit
  max_input_size: 104857600,   // 100MB limit
  verify_checksum: true,        // Verify CRC-32 (default)
})

// Performance-optimized (skip checksum verification)
let original = @fzip.gunzip_sync(compressed, opts={
  verify_checksum: false,       // Skip CRC-32 for ~4x faster decompression
  ..
})
```

## Development

```bash
moon check              # Type check
moon build              # Full build
moon test               # Run tests
moon test -v            # Verbose output
moon fmt                # Format code
moon bench              # Run benchmarks
```

## License

[Apache-2.0](LICENSE)
