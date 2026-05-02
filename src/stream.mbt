///|
/// Callback wrapper used by stream-style APIs.
///
/// The wrapped function receives `(data, is_final)`. `data` is the produced
/// output chunk and `is_final` is `true` for the final callback of a stream.
pub(all) struct FlateStreamHandler((FixedArray[Byte], Bool) -> Unit)

///|
fn call_handler(
  h : FlateStreamHandler,
  data : FixedArray[Byte],
  final_ : Bool,
) -> Unit {
  (h.0)(data, final_)
}

///|
/// Chunk-oriented raw DEFLATE compressor.
///
/// Set `ondata` before calling `push`. Input chunks are buffered until a call
/// with `final_=true`, then compressed with `deflate_sync` and emitted through
/// `ondata`.
pub(all) struct DeflateStream {
  /// Called with compressed data when a final chunk is pushed.
  mut ondata : FlateStreamHandler?
  priv o : DeflateOptions
  priv mut chunks : Array[FixedArray[Byte]]
}

///|
/// Create a raw DEFLATE compression stream.
pub fn DeflateStream::new(
  opts? : DeflateOptions = DeflateOptions::default(),
) -> DeflateStream {
  { ondata: None, o: opts, chunks: [] }
}

///|
/// Push one input chunk into the raw DEFLATE compression stream.
///
/// Chunks are buffered until `final_` is `true`. On the final push, compressed
/// output is sent to `ondata` if a handler is installed.
pub fn DeflateStream::push(
  self : DeflateStream,
  chunk : FixedArray[Byte],
  final_? : Bool = false,
) -> Unit {
  self.chunks.push(chunk)
  if final_ {
    let data = concat_chunks(self.chunks)
    let result = deflate_sync(data, opts=self.o)
    match self.ondata {
      Some(h) => call_handler(h, result, true)
      None => ()
    }
    self.chunks = []
  }
}

///|
fn concat_chunks(chunks : Array[FixedArray[Byte]]) -> FixedArray[Byte] {
  let mut total = 0
  for i in 0..<chunks.length() {
    total += chunks[i].length()
  }
  let data = FixedArray::make(total, b'\x00')
  let mut offset = 0
  for i in 0..<chunks.length() {
    let c = chunks[i]
    c.blit_to(data, len=c.length(), src_offset=0, dst_offset=offset)
    offset += c.length()
  }
  data
}

///|
/// Chunk-oriented raw DEFLATE decompressor.
///
/// Set `ondata` before calling `push`. Input chunks are buffered until a call
/// with `final_=true`, then decompressed with `inflate_sync` and emitted through
/// `ondata`.
pub(all) struct InflateStream {
  /// Called with decompressed data when a final chunk is pushed.
  mut ondata : FlateStreamHandler?
  priv mut chunks : Array[FixedArray[Byte]]
  priv opts : InflateOptions
}

///|
/// Create a raw DEFLATE decompression stream.
pub fn InflateStream::new(
  opts? : InflateOptions = InflateOptions::default(),
) -> InflateStream {
  { ondata: None, chunks: [], opts }
}

///|
/// Push one input chunk into the raw DEFLATE decompression stream.
///
/// Chunks are buffered until `final_` is `true`. On the final push, decompressed
/// output is sent to `ondata` if a handler is installed.
pub fn InflateStream::push(
  self : InflateStream,
  chunk : FixedArray[Byte],
  final_? : Bool = false,
) -> Unit raise FzipError {
  self.chunks.push(chunk)
  if final_ {
    let data = concat_chunks(self.chunks)
    let result = inflate_sync(data, opts=self.opts)
    match self.ondata {
      Some(h) => call_handler(h, result, true)
      None => ()
    }
    self.chunks = []
  }
}

///|
/// Chunk-oriented GZIP compressor.
///
/// Input chunks are buffered until the final push, then encoded with
/// `gzip_sync` and emitted through `ondata`.
pub(all) struct GzipStream {
  /// Called with compressed GZIP data when a final chunk is pushed.
  mut ondata : FlateStreamHandler?
  priv opts : GzipOptions
  priv mut chunks : Array[FixedArray[Byte]]
}

///|
/// Create a GZIP compression stream.
pub fn GzipStream::new(
  opts? : GzipOptions = GzipOptions::default(),
) -> GzipStream {
  { ondata: None, opts, chunks: [] }
}

///|
/// Push one input chunk into the GZIP compression stream.
pub fn GzipStream::push(
  self : GzipStream,
  chunk : FixedArray[Byte],
  final_? : Bool = false,
) -> Unit {
  self.chunks.push(chunk)
  if final_ {
    let data = concat_chunks(self.chunks)
    let result = gzip_sync(data, opts=self.opts)
    match self.ondata {
      Some(h) => call_handler(h, result, true)
      None => ()
    }
    self.chunks = []
  }
}

///|
/// Chunk-oriented GZIP decompressor.
///
/// Input chunks are buffered until the final push, then decoded with
/// `gunzip_sync` and emitted through `ondata`.
pub(all) struct GunzipStream {
  /// Called with decompressed data when a final chunk is pushed.
  mut ondata : FlateStreamHandler?
  priv opts : GunzipOptions
  priv mut chunks : Array[FixedArray[Byte]]
}

///|
/// Create a GZIP decompression stream.
pub fn GunzipStream::new(
  opts? : GunzipOptions = GunzipOptions::default(),
) -> GunzipStream {
  { ondata: None, opts, chunks: [] }
}

///|
/// Push one input chunk into the GZIP decompression stream.
pub fn GunzipStream::push(
  self : GunzipStream,
  chunk : FixedArray[Byte],
  final_? : Bool = false,
) -> Unit raise FzipError {
  self.chunks.push(chunk)
  if final_ {
    let data = concat_chunks(self.chunks)
    let result = gunzip_sync(data, opts=self.opts)
    match self.ondata {
      Some(h) => call_handler(h, result, true)
      None => ()
    }
    self.chunks = []
  }
}

///|
/// Chunk-oriented Zlib compressor.
///
/// Input chunks are buffered until the final push, then encoded with
/// `zlib_sync` and emitted through `ondata`.
pub(all) struct ZlibStream {
  /// Called with compressed Zlib data when a final chunk is pushed.
  mut ondata : FlateStreamHandler?
  priv opts : ZlibOptions
  priv mut chunks : Array[FixedArray[Byte]]
}

///|
/// Create a Zlib compression stream.
pub fn ZlibStream::new(
  opts? : ZlibOptions = ZlibOptions::default(),
) -> ZlibStream {
  { ondata: None, opts, chunks: [] }
}

///|
/// Push one input chunk into the Zlib compression stream.
pub fn ZlibStream::push(
  self : ZlibStream,
  chunk : FixedArray[Byte],
  final_? : Bool = false,
) -> Unit {
  self.chunks.push(chunk)
  if final_ {
    let data = concat_chunks(self.chunks)
    let result = zlib_sync(data, opts=self.opts)
    match self.ondata {
      Some(h) => call_handler(h, result, true)
      None => ()
    }
    self.chunks = []
  }
}

///|
/// Chunk-oriented Zlib decompressor.
///
/// Input chunks are buffered until the final push, then decoded with
/// `unzlib_sync` and emitted through `ondata`.
pub(all) struct UnzlibStream {
  /// Called with decompressed data when a final chunk is pushed.
  mut ondata : FlateStreamHandler?
  priv opts : UnzlibOptions
  priv mut chunks : Array[FixedArray[Byte]]
}

///|
/// Create a Zlib decompression stream.
pub fn UnzlibStream::new(
  opts? : UnzlibOptions = UnzlibOptions::default(),
) -> UnzlibStream {
  { ondata: None, opts, chunks: [] }
}

///|
/// Push one input chunk into the Zlib decompression stream.
pub fn UnzlibStream::push(
  self : UnzlibStream,
  chunk : FixedArray[Byte],
  final_? : Bool = false,
) -> Unit raise FzipError {
  self.chunks.push(chunk)
  if final_ {
    let data = concat_chunks(self.chunks)
    let result = unzlib_sync(data, opts=self.opts)
    match self.ondata {
      Some(h) => call_handler(h, result, true)
      None => ()
    }
    self.chunks = []
  }
}

///|
/// Chunk-oriented decompressor with automatic format detection.
///
/// Input chunks are buffered until the final push, then decoded with
/// `decompress_sync`. GZIP, Zlib, and raw DEFLATE inputs are supported.
pub(all) struct DecompressStream {
  /// Called with decompressed data when a final chunk is pushed.
  mut ondata : FlateStreamHandler?
  priv opts : InflateOptions
  priv mut chunks : Array[FixedArray[Byte]]
}

///|
/// Create an auto-detecting decompression stream.
pub fn DecompressStream::new(
  opts? : InflateOptions = InflateOptions::default(),
) -> DecompressStream {
  { ondata: None, opts, chunks: [] }
}

///|
/// Push one input chunk into the auto-detecting decompression stream.
pub fn DecompressStream::push(
  self : DecompressStream,
  chunk : FixedArray[Byte],
  final_? : Bool = false,
) -> Unit raise FzipError {
  self.chunks.push(chunk)
  if final_ {
    let data = concat_chunks(self.chunks)
    let result = decompress_sync(data, opts=self.opts)
    match self.ondata {
      Some(h) => call_handler(h, result, true)
      None => ()
    }
    self.chunks = []
  }
}
