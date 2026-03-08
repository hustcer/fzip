///|
/// Check if a ZIP entry path is unsafe (path traversal or absolute path)
fn is_unsafe_path(path : String) -> Bool {
  // Reject absolute paths
  if path.length() > 0 && (path[0] == '/' || path[0] == '\\') {
    return true
  }
  // Reject Windows absolute paths like "C:\..."
  if path.length() >= 3 &&
    ((path[0] >= 'A' && path[0] <= 'Z') || (path[0] >= 'a' && path[0] <= 'z')) &&
    path[1] == ':' &&
    (path[2] == '/' || path[2] == '\\') {
    return true
  }
  // Check for path traversal components ("../", "..\")
  let l = path.length()
  let mut i = 0
  while i < l {
    // Check if we are at the start of a path component
    let at_start = i == 0 ||
      (i > 0 && (path[i - 1] == '/' || path[i - 1] == '\\'))
    if at_start && i + 1 < l && path[i] == '.' && path[i + 1] == '.' {
      // ".." at end of string, or followed by separator
      if i + 2 >= l || path[i + 2] == '/' || path[i + 2] == '\\' {
        return true
      }
    }
    i += 1
  }
  false
}

///|
/// Skip local ZIP file header, return offset past header+name+extra
fn slzh(d : FixedArray[Byte], b : Int) -> Int raise FzipError {
  b + 30 + b2(d, b + 26) + b2(d, b + 28)
}

///|
/// Read central directory header
/// Returns (compression, compressed_size, uncompressed_size, filename, next_offset, local_offset)
fn zh(
  d : FixedArray[Byte],
  b : Int,
  z : Bool,
) -> (Int, Int, Int, String, Int, Int) raise FzipError {
  let fnl = b2(d, b + 28)
  let is_utf8 = (b2(d, b + 8) & 2048) != 0
  let fn_str = str_from_u8(d, latin1=not(is_utf8), offset=b + 46, len=fnl)
  let es = b + 46 + fnl
  let bs = b4(d, b + 20)
  let (sc, su, off) = if z && bs == 4294967295U {
    z64e(d, es)
  } else {
    (
      bs.reinterpret_as_int(),
      b4(d, b + 24).reinterpret_as_int(),
      b4(d, b + 42).reinterpret_as_int(),
    )
  }
  (b2(d, b + 10), sc, su, fn_str, es + b2(d, b + 30) + b2(d, b + 32), off)
}

///|
/// Read ZIP64 extra field
fn z64e(d : FixedArray[Byte], b : Int) -> (Int, Int, Int) raise FzipError {
  let mut b = b
  while b + 4 <= d.length() && b2(d, b) != 1 {
    let field_len = b2(d, b + 2)
    if b + 4 + field_len > d.length() {
      raise fzip_err(InvalidZipData, msg="invalid zip64 extra field")
    }
    b += 4 + field_len
  }
  if b + 28 > d.length() {
    raise fzip_err(InvalidZipData, msg="invalid zip64 extra field")
  }
  if b2(d, b) != 1 {
    raise fzip_err(InvalidZipData, msg="invalid zip64 extra field")
  }
  (b8(d, b + 12).to_int(), b8(d, b + 4).to_int(), b8(d, b + 20).to_int())
}

///|
/// Calculate extra field length
fn exfl(ex : Array[(Int, FixedArray[Byte])]) -> Int {
  let mut le = 0
  for i in 0..<ex.length() {
    let (_, data) = ex[i]
    le += data.length() + 4
  }
  le
}

///|
/// Deflate bit flag for ZIP
fn dbf(l : Int) -> Int {
  if l == 1 {
    3
  } else if l < 6 {
    2
  } else if l == 9 {
    1
  } else {
    0
  }
}

///|
/// Write ZIP file header (local or central directory)
/// If ce is >= 0, writes central directory header; otherwise local header.
fn wzh(
  d : FixedArray[Byte],
  b : Int,
  fn_data : FixedArray[Byte],
  is_utf8 : Bool,
  compression : Int,
  flag : Int,
  crc_val : Int,
  c_size : Int,
  u_size : Int,
  mtime : Int,
  os : Int,
  attrs : Int,
  extra : Array[(Int, FixedArray[Byte])],
  ce : Int, // central directory entry offset, -1 for local header
  comment : FixedArray[Byte]?,
) -> Int {
  let fl = fn_data.length()
  let exl = exfl(extra)
  let col = match comment {
    Some(c) => c.length()
    None => 0
  }
  let mut b = b
  // signature
  if ce >= 0 {
    wbytes(d, b, 0x02014B50)
  } else {
    wbytes(d, b, 0x04034B50)
  }
  b += 4
  if ce >= 0 {
    d[b] = b'\x14' // version made by
    b += 1
    d[b] = os.to_byte()
    b += 1
  }
  d[b] = b'\x14' // version needed
  b += 2
  // flags
  d[b] = (flag << 1).to_byte()
  d[b + 1] = if is_utf8 { b'\x08' } else { b'\x00' }
  b += 2
  d[b] = (compression & 255).to_byte()
  d[b + 1] = (compression >> 8).to_byte()
  b += 2
  // mtime as DOS datetime
  let mtime_val = if mtime != 0 { mtime } else { 0 }
  // Convert unix timestamp to DOS datetime
  // Simplified: store raw value (would need proper conversion for real use)
  if mtime_val != 0 {
    // Simple DOS datetime encoding
    // DOS date = ((year-1980)<<9) | (month<<5) | day
    // DOS time = (hour<<11) | (minute<<5) | (second/2)
    // For simplicity, store 0 if no mtime
    wbytes(d, b, mtime_val)
  }
  b += 4
  // CRC-32
  wbytes(d, b, crc_val)
  // compressed size
  wbytes(d, b + 4, c_size)
  // uncompressed size
  wbytes(d, b + 8, u_size)
  // filename length
  wbytes(d, b + 12, fl)
  // extra field length
  wbytes(d, b + 14, exl)
  b += 16
  if ce >= 0 {
    wbytes(d, b, col) // comment length
    // skip disk number (2 bytes) + internal attrs (2 bytes)
    wbytes(d, b + 6, attrs) // external attrs
    wbytes(d, b + 10, ce) // local header offset
    b += 14
  }
  // filename
  fn_data.blit_to(d, len=fl, src_offset=0, dst_offset=b)
  b += fl
  // extra fields
  if exl > 0 {
    for i in 0..<extra.length() {
      let (k, exf) = extra[i]
      let l = exf.length()
      wbytes(d, b, k)
      wbytes(d, b + 2, l)
      exf.blit_to(d, len=l, src_offset=0, dst_offset=b + 4)
      b += 4 + l
    }
  }
  // comment
  match comment {
    Some(co) => {
      co.blit_to(d, len=col, src_offset=0, dst_offset=b)
      b += col
    }
    None => ()
  }
  b
}

///|
/// Write ZIP end of central directory record
fn wzf(o : FixedArray[Byte], b : Int, c : Int, d : Int, e : Int) -> Unit {
  wbytes(o, b, 0x06054B50)
  // skip disk numbers (4 bytes = 0)
  wbytes(o, b + 8, c) // entries on this disk
  wbytes(o, b + 10, c) // total entries
  wbytes(o, b + 12, d) // central directory size
  wbytes(o, b + 16, e) // offset to central directory
}

///|
/// Create a ZIP archive from a list of (filename, data) pairs
pub fn zip_sync(
  files : Array[(String, FixedArray[Byte])],
  opts? : ZipEntryOptions = ZipEntryOptions::default(),
) -> FixedArray[Byte] {
  let entries : Array[
    (
      FixedArray[Byte],
      FixedArray[Byte],
      FixedArray[Byte],
      Bool,
      Int,
      Int,
      Int,
      Int,
    ),
  ] = []
  let mut o = 0
  let mut tot = 0
  for i in 0..<files.length() {
    let (fn_str, file) = files[i]
    let compression = if opts.level == 0 { 0 } else { 8 }
    let f = str_to_u8(fn_str)
    let s = f.length()
    let exl = exfl(opts.extra)
    let (d, c_len) = if compression != 0 {
      dopt(
        file,
        { level: opts.level, mem: opts.mem, dictionary: None },
        0,
        0,
        None,
      )
    } else {
      (file, file.length())
    }
    let crc_v = crc32(file)
    let is_utf8 = s != fn_str.length()
    entries.push(
      (f, file, d, is_utf8, crc_v.reinterpret_as_int(), file.length(), c_len, o),
    )
    o += 30 + s + exl + c_len
    tot += 76 + 2 * (s + exl) + c_len
  }
  let out = FixedArray::make(tot + 22, b'\x00')
  let oe = o
  let cdl = tot - o
  let mut cd_offset = o
  for i in 0..<entries.length() {
    let (fn_data, _file, compressed, is_utf8, crc_val, u_size, c_size, local_off
    ) = entries[i]
    let flag = dbf(opts.level)
    let compression = if opts.level == 0 { 0 } else { 8 }
    // Write local header
    let end_local = wzh(
      out,
      local_off,
      fn_data,
      is_utf8,
      compression,
      flag,
      crc_val,
      c_size,
      u_size,
      opts.mtime,
      opts.os,
      opts.attrs,
      opts.extra,
      -1,
      None,
    )
    // Copy compressed data after local header
    compressed.blit_to(out, len=c_size, src_offset=0, dst_offset=end_local)
    // Write central directory entry
    let comment_bytes : FixedArray[Byte]? = if opts.comment.length() > 0 {
      Some(str_to_u8(opts.comment))
    } else {
      None
    }
    cd_offset = wzh(
      out,
      cd_offset,
      fn_data,
      is_utf8,
      compression,
      flag,
      crc_val,
      c_size,
      u_size,
      opts.mtime,
      opts.os,
      opts.attrs,
      opts.extra,
      local_off,
      comment_bytes,
    )
  }
  wzf(out, cd_offset, entries.length(), cdl, oe)
  out
}

///|
/// Extract files from a ZIP archive
pub fn unzip_sync(
  data : FixedArray[Byte],
) -> Array[(String, FixedArray[Byte])] raise FzipError {
  if data.length() < 22 {
    raise fzip_err(InvalidZipData, msg="data too short for zip archive")
  }
  let files : Array[(String, FixedArray[Byte])] = []
  // Find end of central directory
  let mut e = data.length() - 22
  while e >= 0 && b4(data, e) != 0x06054B50U {
    e -= 1
    if data.length() - e > 65558 {
      raise fzip_err(InvalidZipData)
    }
  }
  if e < 0 {
    raise fzip_err(InvalidZipData)
  }
  let mut c = b2(data, e + 8)
  if c == 0 {
    return files
  }
  let mut o = b4(data, e + 16).reinterpret_as_int()
  let mut z = o == -1 || c == 65535
  if z {
    let ze = b4(data, e - 12).reinterpret_as_int()
    z = b4(data, ze) == 0x06064B50U
    if z {
      c = b4(data, ze + 32).reinterpret_as_int()
      o = b4(data, ze + 48).reinterpret_as_int()
    }
  }
  for _i in 0..<c {
    let (comp, sc, su, fn_str, no, off) = zh(data, o, z)
    if is_unsafe_path(fn_str) {
      raise fzip_err(
        InvalidZipData,
        msg="zip entry contains unsafe path: " + fn_str,
      )
    }
    let b_off = slzh(data, off)
    o = no
    if comp == 0 {
      files.push((fn_str, slc(data, b_off, e=b_off + sc)))
    } else if comp == 8 {
      let out = FixedArray::make(su, b'\x00')
      let (buf, _len) = inflt(
        data,
        InflateState::new(2),
        Some(out),
        None,
        dat_off=b_off,
        dat_end=b_off + sc,
      )
      files.push((fn_str, buf))
    } else {
      raise fzip_err(
        UnknownCompressionMethod,
        msg="unknown compression type " + comp.to_string(),
      )
    }
  }
  files
}

///|
/// List files in a ZIP archive without extracting
pub fn unzip_list(
  data : FixedArray[Byte],
) -> Array[UnzipFileInfo] raise FzipError {
  if data.length() < 22 {
    raise fzip_err(InvalidZipData, msg="data too short for zip archive")
  }
  let infos : Array[UnzipFileInfo] = []
  let mut e = data.length() - 22
  while e >= 0 && b4(data, e) != 0x06054B50U {
    e -= 1
    if data.length() - e > 65558 {
      raise fzip_err(InvalidZipData)
    }
  }
  if e < 0 {
    raise fzip_err(InvalidZipData)
  }
  let mut c = b2(data, e + 8)
  if c == 0 {
    return infos
  }
  let mut o = b4(data, e + 16).reinterpret_as_int()
  let mut z = o == -1 || c == 65535
  if z {
    let ze = b4(data, e - 12).reinterpret_as_int()
    z = b4(data, ze) == 0x06064B50U
    if z {
      c = b4(data, ze + 32).reinterpret_as_int()
      o = b4(data, ze + 48).reinterpret_as_int()
    }
  }
  for _i in 0..<c {
    let (comp, sc, su, fn_str, no, _off) = zh(data, o, z)
    o = no
    infos.push({ name: fn_str, size: sc, original_size: su, compression: comp })
  }
  infos
}
