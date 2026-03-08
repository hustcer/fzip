# fzip

High-performance compression library for [MoonBit](https://www.moonbitlang.com/), ported from [fflate](https://github.com/101arrowz/fflate). Supports DEFLATE, GZIP, Zlib, and ZIP formats.

## Installation

```bash
moon add hustcer/fzip
```

## Benchmark

Platform: macOS (Apple Silicon), MoonBit wasm-gc target. Full results in [bench.md](https://github.com/hustcer/fzip/blob/feature/bench/src/benchmarks/bench.md).

## Quick Start

```moonbit
// Compress (GZIP)
let data = @fzip.str_to_u8("Hello, World!")
let compressed = @fzip.gzip_sync(data)

// Decompress (auto-detect format)
let original = @fzip.decompress_sync(compressed)
let text = @fzip.str_from_u8(original)
```

## API

### DEFLATE

```moonbit
// Compress
let compressed = @fzip.deflate_sync(data)
// With options (level 0-9, default 6)
let compressed = @fzip.deflate_sync(data, opts={ level: 9, mem: 0, dictionary: None })

// Decompress
let original = @fzip.inflate_sync(compressed)
```

### GZIP

```moonbit
// Compress
let compressed = @fzip.gzip_sync(data)
// With metadata
let compressed = @fzip.gzip_sync(data, opts={
  level: 6, mem: 0, dictionary: None,
  mtime: 1709827200,  // Unix timestamp
  filename: "data.bin",
})

// Decompress
let original = @fzip.gunzip_sync(compressed)
// With size limits (default: 100MB output, 1GB input)
let original = @fzip.gunzip_sync(compressed, opts={
  out: None,
  dictionary: None,
  max_output_size: 104857600,  // 100MB
  max_input_size: 1073741824,  // 1GB
})
```

### Zlib

```moonbit
// Compress
let compressed = @fzip.zlib_sync(data)

// Decompress
let original = @fzip.unzlib_sync(compressed)
```

### ZIP

```moonbit
// Create ZIP archive
let files : Array[(String, FixedArray[Byte])] = [
  ("hello.txt", @fzip.str_to_u8("Hello!")),
  ("data.bin", some_binary_data),
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
  println("\{info.name}: \{info.original_size} bytes (compressed: \{info.size})")
}
```

### Auto-detect Decompression

```moonbit
// Automatically detects GZIP, Zlib, or raw DEFLATE
let original = @fzip.decompress_sync(compressed_data)
```

### Convenience

```moonbit
// compress_sync = gzip_sync
let compressed = @fzip.compress_sync(data)

// decompress_sync auto-detects format
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

### Checksums

```moonbit
let checksum = @fzip.crc32(data)    // CRC-32
let checksum = @fzip.adler32(data)  // Adler-32
```

### String Utilities

```moonbit
// String → bytes (UTF-8)
let bytes = @fzip.str_to_u8("Hello")

// bytes → String (UTF-8)
let text = @fzip.str_from_u8(bytes)

// Latin-1 mode
let bytes = @fzip.str_to_u8("Hello", latin1=true)
let text = @fzip.str_from_u8(bytes, latin1=true)
```

## Security Features

fzip includes built-in protections against common compression attacks:

- **Size limits**: Configurable max output (default 100MB) and input (default 1GB) sizes prevent zip bombs
- **Checksum verification**: CRC-32 (GZIP) and Adler-32 (Zlib) checksums are verified to detect corrupted data
- **Compression ratio check**: ZIP files with compression ratios > 1000:1 are rejected
- **Path traversal protection**: ZIP entries with unsafe paths (../, absolute paths) are rejected
- **Filename length validation**: ZIP filenames are limited to 4096 bytes

Configure size limits per operation:

```moonbit
let original = @fzip.inflate_sync(compressed, opts={
  out: None,
  dictionary: None,
  max_output_size: 10485760,   // 10MB
  max_input_size: 104857600,   // 100MB
})
```

## Development

```bash
moon check              # Type check
moon build              # Full build
moon test               # Run tests (128 tests)
moon test -v            # Verbose output
moon fmt                # Format code
moon bench              # Run benchmarks
```

## License

[MIT](LICENSE)
