///|
/// Options for raw DEFLATE compression.
///
/// `level` follows the usual 0-9 compression scale: `0` stores data without
/// compression and higher values spend more CPU to improve compression ratio.
/// `mem` controls the internal hash table size; leave it as `0` to let fzip
/// choose a size from the input length. `dictionary` can be used when both the
/// compressor and decompressor share the same preset dictionary.
pub(all) struct DeflateOptions {
  /// Compression level, from 0 (store) to 9 (maximum compression).
  level : Int
  /// Memory level hint, expected to be 0-12. Use 0 to let fzip choose automatically.
  mem : Int
  /// Optional preset dictionary for repeated or domain-specific data.
  dictionary : FixedArray[Byte]?
} derive(Debug)

///|
/// Return the default raw DEFLATE compression options.
pub fn DeflateOptions::default() -> DeflateOptions {
  { level: 6, mem: 0, dictionary: None }
}

///|
/// Options for raw DEFLATE decompression.
///
/// `out` lets callers provide a reusable output buffer. The buffer must be large
/// enough for the full uncompressed payload when it is supplied. The size limits
/// are enforced before or during decompression to protect callers from malformed
/// streams and zip-bomb style inputs.
pub(all) struct InflateOptions {
  /// Optional pre-allocated output buffer; when supplied, it must fit the full output.
  out : FixedArray[Byte]?
  /// Optional preset dictionary used by the compressed stream.
  dictionary : FixedArray[Byte]?
  /// Maximum allowed uncompressed output size.
  max_output_size : Int
  /// Maximum allowed compressed input size.
  max_input_size : Int
} derive(Debug)

///|
/// Return the default raw DEFLATE decompression options.
pub fn InflateOptions::default() -> InflateOptions {
  {
    out: None,
    dictionary: None,
    max_output_size: default_max_output_size,
    max_input_size: default_max_input_size,
  }
}

///|
/// Options for GZIP compression.
///
/// These options control the inner DEFLATE stream plus GZIP metadata. `mtime`
/// is a Unix timestamp in seconds; use `0` to leave the timestamp unset.
/// `filename` is written into the optional GZIP original-name field as
/// single-byte header data when it is non-empty. GZIP does not record a
/// dictionary identifier, so decompression must be given the same dictionary
/// out of band when one is used.
pub(all) struct GzipOptions {
  /// Compression level, from 0 (store) to 9 (maximum compression).
  level : Int
  /// Memory level hint, expected to be 0-12. Use 0 to let fzip choose automatically.
  mem : Int
  /// Optional preset dictionary for the inner DEFLATE stream.
  dictionary : FixedArray[Byte]?
  /// Unix timestamp in seconds, or 0 to omit it from the header.
  mtime : Int
  /// Optional original filename to store in the GZIP header as single-byte data.
  filename : String
} derive(Debug)

///|
/// Return the default GZIP compression options.
pub fn GzipOptions::default() -> GzipOptions {
  { level: 6, mem: 0, dictionary: None, mtime: 0, filename: "" }
}

///|
/// Options for GZIP decompression.
///
/// By default fzip verifies the CRC-32 footer to detect corrupted data. Disable
/// `verify_checksum` only when data integrity is already guaranteed elsewhere
/// and decompression speed is more important. When `out` is not supplied,
/// `gunzip_sync` allocates its output from the GZIP ISIZE footer after checking
/// it against `max_output_size`.
pub(all) struct GunzipOptions {
  /// Optional pre-allocated output buffer; when supplied, it must fit the full output.
  out : FixedArray[Byte]?
  /// Optional preset dictionary used by the inner DEFLATE stream.
  dictionary : FixedArray[Byte]?
  /// Maximum allowed uncompressed output size.
  max_output_size : Int
  /// Maximum allowed compressed input size.
  max_input_size : Int
  /// Whether to verify the GZIP CRC-32 checksum.
  verify_checksum : Bool
} derive(Debug)

///|
/// Return the default GZIP decompression options.
pub fn GunzipOptions::default() -> GunzipOptions {
  {
    out: None,
    dictionary: None,
    max_output_size: default_max_output_size,
    max_input_size: default_max_input_size,
    verify_checksum: true,
  }
}

///|
/// Options for Zlib compression.
///
/// Zlib wraps a raw DEFLATE stream with a header and Adler-32 checksum. When a
/// dictionary is supplied, its Adler-32 value is written to the Zlib header and
/// decompression must use the same dictionary.
pub(all) struct ZlibOptions {
  /// Compression level, from 0 (store) to 9 (maximum compression).
  level : Int
  /// Memory level hint, expected to be 0-12. Use 0 to let fzip choose automatically.
  mem : Int
  /// Optional preset dictionary for the inner DEFLATE stream.
  dictionary : FixedArray[Byte]?
} derive(Debug)

///|
/// Return the default Zlib compression options.
pub fn ZlibOptions::default() -> ZlibOptions {
  { level: 6, mem: 0, dictionary: None }
}

///|
/// Options for Zlib decompression.
///
/// By default fzip verifies the Adler-32 footer to detect corrupted data. If a
/// dictionary is required, the stream must advertise that requirement and the
/// caller must provide the matching dictionary; the dictionary checksum in the
/// header is skipped rather than compared.
pub(all) struct UnzlibOptions {
  /// Optional pre-allocated output buffer; when supplied, it must fit the full output.
  out : FixedArray[Byte]?
  /// Optional preset dictionary required by the Zlib stream.
  dictionary : FixedArray[Byte]?
  /// Maximum allowed uncompressed output size.
  max_output_size : Int
  /// Maximum allowed compressed input size.
  max_input_size : Int
  /// Whether to verify the Zlib Adler-32 checksum.
  verify_checksum : Bool
} derive(Debug)

///|
/// Return the default Zlib decompression options.
pub fn UnzlibOptions::default() -> UnzlibOptions {
  {
    out: None,
    dictionary: None,
    max_output_size: default_max_output_size,
    max_input_size: default_max_input_size,
    verify_checksum: true,
  }
}

///|
/// Options applied to entries written by `zip_sync`.
///
/// The current API applies one set of options to every entry in the archive.
/// `level = 0` stores entries without compression; other levels use DEFLATE.
/// Extra fields are written as `(header_id, data)` pairs.
pub(all) struct ZipEntryOptions {
  /// Compression level, expected to be 0-9; 0 stores entries and non-zero values deflate them.
  level : Int
  /// Memory level hint for entry compression, expected to be 0-12.
  mem : Int
  /// ZIP "version made by" operating system code, such as 0 for MS-DOS or 3 for Unix.
  os : Int
  /// External file attributes written into central directory entries.
  attrs : Int
  /// Extra fields written to local and central directory headers.
  extra : Array[(Int, FixedArray[Byte])]
  /// Central directory file comment.
  comment : String
  /// Modification time value written into ZIP headers.
  mtime : Int
} derive(Debug)

///|
/// Return the default ZIP entry options.
pub fn ZipEntryOptions::default() -> ZipEntryOptions {
  { level: 6, mem: 0, os: 0, attrs: 0, extra: [], comment: "", mtime: 0 }
}

///|
/// Metadata for an entry returned by `unzip_list`.
pub(all) struct UnzipFileInfo {
  /// Entry path stored in the archive.
  name : String
  /// Compressed size in bytes.
  size : Int
  /// Uncompressed size in bytes.
  original_size : Int
  /// ZIP compression method, usually 0 for stored or 8 for deflated.
  compression : Int
} derive(Debug)
