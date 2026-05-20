# fzip – High-performance compression library for MoonBit

`fzip` (short for _fast zip_) is a high-performance, in-memory compression library for MoonBit, ported from the [fflate](https://github.com/101arrowz/fflate) JavaScript library.

This library provides:

- **Deflate, GZIP, Zlib, and ZIP** compression and decompression
- **Synchronous and streaming APIs**
- **ZIP64 metadata support** for ZIP archives that still fit the sync API memory limits
- **Validation and size limits** for malformed input, zip bombs, path traversal, and corrupted data

## Benchmark

Platform: macOS (Apple Silicon), MoonBit wasm-gc target. Full results in [bench.md](https://github.com/hustcer/fzip/blob/feature/bench/src/benchmarks/bench.md).

## Features

- Pure MoonBit implementation with no external dependencies (compiled to Wasm-GC)
- Support for DEFLATE, GZIP, Zlib, and ZIP formats
- Automatic format detection for decompression
- Streaming APIs for chunk-based compression and decompression
- ZIP read/write support, including ZIP64 metadata, data descriptors, listing, and CRC-32 validation
- Configurable input and output limits
- Tests covering format behavior, edge cases, and malformed input

## Installation

```bash
moon add hustcer/fzip
```

Or add this to your `moon.mod.json`:

```json
{
  "deps": {
    "hustcer/fzip": "0.8.0"
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

Detailed API documentation can be explored via `moon ide doc` or in the codebase.

### Working Features

- **DEFLATE compression/decompression** - Full deflate algorithm implementation
- **GZIP format support** - Deflate with GZIP headers, timestamps, metadata, and CRC-32 checksums
- **Zlib format support** - Deflate with Zlib headers and Adler-32 checksums
- **ZIP archive support** - Write, list, and extract ZIP archives
- **ZIP64 metadata support** - Read and write ZIP64 metadata for archives that fit the current sync API limits
- **ZIP data descriptors** - Read entries that use central-directory sizes and CRC-32
- **Streaming compression** - Stream-based handlers for chunk-based data processing
- **Input validation** - Size limits, path traversal detection, checksum validation, and malformed metadata rejection
- **Auto-detection** - Decompression that recognizes GZIP, Zlib, or raw DEFLATE
- **Test coverage** - Tests for encoding, decoding, edge cases, and security-related regressions

### API Compatibility

The API is inspired by the original `fflate` library structure and adapted for MoonBit:

- Type-safe synchronous and stream-based representations (`ondata` callbacks).
- Error propagation through MoonBit's `raise Error` mechanisms.
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

`zip_sync`, `unzip_sync`, and `unzip_list` understand ZIP64 metadata for archives and entries that still fit inside the sync API's `Int`/`FixedArray` limits. This is ZIP64 metadata compatibility, not large-file streaming.

The writer emits ZIP64 metadata when a classic ZIP field needs a sentinel value:

- entry compressed or uncompressed size reaches `0xFFFFFFFF`
- entry local-header offset reaches `0xFFFFFFFF`
- entry count reaches `0xFFFF`
- central directory size or offset reaches `0xFFFFFFFF`

ZIP64 archives include the ZIP64 EOCD record, ZIP64 EOCD locator, and per-entry ZIP64 extra fields required by the format. The classic EOCD is still written last.

The reader validates ZIP64 metadata before extraction. Metadata that is structurally valid but too large for the current sync API raises `FzipErrorCode::Zip64ValueTooLarge`. Malformed ZIP64 metadata, encryption, multi-disk archives, and missing required ZIP64 extras raise `InvalidZipData`.

For recoverable writer failures, use `zip_sync_checked`:

```moonbit
let archive = @fzip.zip_sync_checked(files) catch {
  FzipError(code~, message~) => {
    // Handle Zip64ValueTooLarge, ExtraFieldTooLong,
    // FilenameTooLong, InvalidZipData, or another writer error.
    return
  }
}
```

`zip_sync` uses the same builder and aborts if the builder reports a recoverable error. It does not return a partial archive.

True large-file streaming is not implemented yet. See [`docs/zip64.md`](docs/zip64.md) for the ZIP64 plan.

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

`fzip` includes checks for common compression and archive issues:

- **Size limits**: Configurable max output (default 100MB) and input (default 1GB) sizes; ZIP extraction also caps total sync output and entry fan-out
- **Checksum verification**: CRC-32 (GZIP and ZIP entries) and Adler-32 (Zlib) checksums are verified by default to detect corrupted data
  - Can be disabled via `verify_checksum: false` for better performance when data integrity is guaranteed
  - Default is `true` (security-first approach)
- **Compression ratio check**: ZIP files with compression ratios > 1000:1 are rejected
- **Path traversal protection**: ZIP entries with unsafe paths (`../`, absolute paths) are rejected
- **ZIP metadata validation**: ZIP filenames and extra fields are length-limited; encrypted and multi-disk ZIP archives are rejected
- **Data descriptor support**: ZIP entries with general-purpose bit 3 are bounded by central-directory sizes and verified with CRC-32
- **Strict UTF-8 decoding**: malformed UTF-8 is rejected unless Latin-1 decoding is explicitly requested

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

// Skip checksum verification when integrity is checked elsewhere
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
