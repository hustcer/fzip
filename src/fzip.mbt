///|
/// Compress data using the library default container format.
///
/// This is a convenience wrapper around `gzip_sync`, so the returned bytes are a
/// complete GZIP stream with a GZIP header and CRC-32 footer. Use
/// `deflate_sync` or `zlib_sync` when you need those formats explicitly.
pub fn compress_sync(
  data : FixedArray[Byte],
  opts? : GzipOptions = GzipOptions::default(),
) -> FixedArray[Byte] {
  gzip_sync(data, opts~)
}

///|
/// Decompress GZIP, Zlib, or raw DEFLATE data.
///
/// The input format is detected from the leading bytes. GZIP and Zlib streams
/// are decoded with checksum verification enabled and no option to disable it
/// through this convenience API; otherwise the input is treated as a raw DEFLATE
/// stream. The supplied `InflateOptions` control the output buffer, optional
/// dictionary, and inflater size limits. For GZIP input without `out`, the
/// output allocation follows the GZIP ISIZE footer.
pub fn decompress_sync(
  data : FixedArray[Byte],
  opts? : InflateOptions = InflateOptions::default(),
) -> FixedArray[Byte] raise FzipError {
  if data.length() < 3 {
    return inflate_sync(data, opts~)
  }
  // Check for GZIP magic
  if data[0] == b'\x1F' && data[1] == b'\x8B' && data[2] == b'\x08' {
    return gunzip_sync(data, opts={
      out: opts.out,
      dictionary: opts.dictionary,
      max_output_size: opts.max_output_size,
      max_input_size: opts.max_input_size,
      verify_checksum: true,
    })
  }
  // Check for Zlib header
  if (data[0].to_int() & 15) == 8 &&
    data[0].to_int() >> 4 <= 7 &&
    ((data[0].to_int() << 8) | data[1].to_int()) % 31 == 0 {
    return unzlib_sync(data, opts={
      out: opts.out,
      dictionary: opts.dictionary,
      max_output_size: opts.max_output_size,
      max_input_size: opts.max_input_size,
      verify_checksum: true,
    })
  }
  // Fall back to raw DEFLATE
  inflate_sync(data, opts~)
}
