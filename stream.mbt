///|
/// Stream handler type - callback (data, is_final)
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
/// Streaming DEFLATE compression
pub(all) struct DeflateStream {
  mut ondata : FlateStreamHandler?
  priv o : DeflateOptions
  priv mut chunks : Array[FixedArray[Byte]]
}

///|
pub fn DeflateStream::new(
  opts? : DeflateOptions = DeflateOptions::default(),
) -> DeflateStream {
  { ondata: None, o: opts, chunks: [] }
}

///|
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
/// Streaming DEFLATE decompression
pub(all) struct InflateStream {
  mut ondata : FlateStreamHandler?
  priv mut chunks : Array[FixedArray[Byte]]
  priv opts : InflateOptions
}

///|
pub fn InflateStream::new(
  opts? : InflateOptions = InflateOptions::default(),
) -> InflateStream {
  { ondata: None, chunks: [], opts }
}

///|
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
/// Streaming GZIP compression
pub(all) struct GzipStream {
  mut ondata : FlateStreamHandler?
  priv opts : GzipOptions
  priv mut chunks : Array[FixedArray[Byte]]
}

///|
pub fn GzipStream::new(
  opts? : GzipOptions = GzipOptions::default(),
) -> GzipStream {
  { ondata: None, opts, chunks: [] }
}

///|
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
/// Streaming GZIP decompression
pub(all) struct GunzipStream {
  mut ondata : FlateStreamHandler?
  priv opts : GunzipOptions
  priv mut chunks : Array[FixedArray[Byte]]
}

///|
pub fn GunzipStream::new(
  opts? : GunzipOptions = GunzipOptions::default(),
) -> GunzipStream {
  { ondata: None, opts, chunks: [] }
}

///|
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
/// Streaming Zlib compression
pub(all) struct ZlibStream {
  mut ondata : FlateStreamHandler?
  priv opts : ZlibOptions
  priv mut chunks : Array[FixedArray[Byte]]
}

///|
pub fn ZlibStream::new(
  opts? : ZlibOptions = ZlibOptions::default(),
) -> ZlibStream {
  { ondata: None, opts, chunks: [] }
}

///|
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
/// Streaming Zlib decompression
pub(all) struct UnzlibStream {
  mut ondata : FlateStreamHandler?
  priv opts : UnzlibOptions
  priv mut chunks : Array[FixedArray[Byte]]
}

///|
pub fn UnzlibStream::new(
  opts? : UnzlibOptions = UnzlibOptions::default(),
) -> UnzlibStream {
  { ondata: None, opts, chunks: [] }
}

///|
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
/// Auto-detecting decompression stream
pub(all) struct DecompressStream {
  mut ondata : FlateStreamHandler?
  priv opts : InflateOptions
  priv mut chunks : Array[FixedArray[Byte]]
}

///|
pub fn DecompressStream::new(
  opts? : InflateOptions = InflateOptions::default(),
) -> DecompressStream {
  { ondata: None, opts, chunks: [] }
}

///|
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
