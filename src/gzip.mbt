///|
/// Write GZIP header
fn gzh(c : FixedArray[Byte], o : GzipOptions) -> Unit {
  c[0] = b'\x1F' // magic 1
  c[1] = b'\x8B' // magic 2
  c[2] = b'\x08' // CM = deflate
  let xfl : Byte = if o.level < 2 {
    b'\x04'
  } else if o.level == 9 {
    b'\x02'
  } else {
    b'\x00'
  }
  c[8] = xfl
  c[9] = b'\x03' // OS = Unix
  if o.mtime != 0 {
    wbytes(c, 4, o.mtime)
  }
  if o.filename.length() > 0 {
    c[3] = b'\x08' // FNAME flag
    let fn_bytes = o.filename
    for i in 0..<fn_bytes.length() {
      c[i + 10] = fn_bytes[i].to_int().to_byte()
    }
    c[fn_bytes.length() + 10] = b'\x00' // null terminator
  }
}

///|
/// Parse GZIP header and return data start offset
fn gzs(d : FixedArray[Byte]) -> Int raise FzipError {
  if d[0] != b'\x1F' || d[1] != b'\x8B' || d[2] != b'\x08' {
    raise fzip_err(InvalidHeader, msg="invalid gzip data")
  }
  let flg = d[3].to_int()
  let mut st = 10
  if (flg & 4) != 0 {
    st += (d[10].to_int() | (d[11].to_int() << 8)) + 2
  }
  // skip FNAME and FCOMMENT
  let mut zs = ((flg >> 3) & 1) + ((flg >> 4) & 1)
  while zs > 0 {
    if d[st] == b'\x00' {
      zs -= 1
    }
    st += 1
  }
  // skip FHCRC
  st + (flg & 2)
}

///|
/// Read GZIP original (uncompressed) size from footer
fn gzl(d : FixedArray[Byte]) -> Int {
  let l = d.length()
  (d[l - 4].to_int() |
  (d[l - 3].to_int() << 8) |
  (d[l - 2].to_int() << 16) |
  (d[l - 1].to_int() << 24))
  .reinterpret_as_uint()
  .reinterpret_as_int()
}

///|
/// Calculate GZIP header length
fn gzhl(o : GzipOptions) -> Int {
  10 + (if o.filename.length() > 0 { o.filename.length() + 1 } else { 0 })
}

///|
/// Compress data with GZIP
pub fn gzip_sync(
  data : FixedArray[Byte],
  opts? : GzipOptions = GzipOptions::default(),
) -> FixedArray[Byte] {
  let c = CRC32State::new()
  let l = data.length()
  c.push(data)
  let d = dopt(
    data,
    { level: opts.level, mem: opts.mem, dictionary: opts.dictionary },
    gzhl(opts),
    8,
    None,
  )
  let s = d.length()
  gzh(d, opts)
  wbytes(d, s - 8, c.digest().reinterpret_as_int())
  wbytes(d, s - 4, l)
  d
}

///|
/// Decompress GZIP data
pub fn gunzip_sync(
  data : FixedArray[Byte],
  opts? : GunzipOptions = GunzipOptions::default(),
) -> FixedArray[Byte] raise FzipError {
  let st = gzs(data)
  if st + 8 > data.length() {
    raise fzip_err(InvalidHeader, msg="invalid gzip data")
  }
  let compressed = slc(data, st, e=data.length() - 8)
  let out = match opts.out {
    Some(o) => o
    None => FixedArray::make(gzl(data), b'\x00')
  }
  inflt(compressed, InflateState::new(2), Some(out), opts.dictionary)
}
