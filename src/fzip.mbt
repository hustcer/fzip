///|
/// Compress data (defaults to GZIP format)
pub fn compress_sync(
  data : FixedArray[Byte],
  opts? : GzipOptions = GzipOptions::default(),
) -> FixedArray[Byte] {
  gzip_sync(data, opts~)
}

///|
/// Decompress data (auto-detect format: GZIP, Zlib, or raw DEFLATE)
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
    })
  }
  // Fall back to raw DEFLATE
  inflate_sync(data, opts~)
}
