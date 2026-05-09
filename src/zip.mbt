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
  // Validate filename length (max `max_filename_length` bytes is reasonable)
  if fnl > max_filename_length {
    raise fzip_err(InvalidZipData, msg="zip filename too long")
  }
  // Check bounds before reading filename
  if b + 46 + fnl > d.length() {
    raise fzip_err(InvalidZipData, msg="zip filename exceeds data bounds")
  }
  let is_utf8 = (b2(d, b + 8) & 2048) != 0
  let fn_str = str_from_u8(d, latin1=!is_utf8, offset=b + 46, len=fnl)
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
    wbytes(d, b, zip_cd_signature.reinterpret_as_int())
  } else {
    wbytes(d, b, zip_local_signature.reinterpret_as_int())
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
  wbytes(o, b, zip_eocd_signature.reinterpret_as_int())
  // skip disk numbers (4 bytes = 0)
  wbytes(o, b + 8, c) // entries on this disk
  wbytes(o, b + 10, c) // total entries
  wbytes(o, b + 12, d) // central directory size
  wbytes(o, b + 16, e) // offset to central directory
}

///|
/// Create a ZIP archive from `(filename, data)` entries.
///
/// Each entry is written with the same `ZipEntryOptions`. Entry names are
/// encoded as UTF-8 when needed, and `level = 0` stores files without DEFLATE
/// compression. The returned bytes are a complete ZIP archive containing local
/// file headers, central directory entries, and the end-of-central-directory
/// record.
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
    let crc_c = CRC32State::new()
    let (d, c_len) = if compression != 0 {
      dopt(
        file,
        { level: opts.level, mem: opts.mem, dictionary: None },
        0,
        0,
        None,
        crc_state=Some(crc_c),
      )
    } else {
      crc_c.push(file)
      (file, file.length())
    }
    let crc_v = crc_c.digest()
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
/// Information collected from a ZIP archive's central directory.
///
/// Phase 1 stores values as `Int`; structurally valid ZIP64 metadata that
/// cannot be safely indexed by the current sync API is rejected at parse
/// time with `Zip64ValueTooLarge` rather than landing here as out-of-range.
/// `entries` stays `Int` even though the spec field is 64 bits because real
/// archives never come close to `max_int_val()` entries — even at 30 bytes
/// per local header, that would be tens of GiB of metadata.
priv struct ZipCdInfo {
  entries : Int
  offset : Int
  size : Int
  zip64 : Bool
}

///|
/// Locate the End-Of-Central-Directory record by scanning back from the end
/// of the input.
///
/// The record may carry up to 65535 bytes of comment between the EOCD
/// signature and the end of the input, so the search window is
/// `22 + 65535 + 1` bytes (the `+1` is the loop sentinel from the original
/// implementation).
///
/// A matching signature is only treated as a real EOCD when its declared
/// comment length is consistent with the candidate's distance from the end
/// of `data`. Without that check, a `0x06054B50` byte sequence inside the
/// EOCD comment or earlier payload could be mistaken for the record itself.
fn find_eocd(data : FixedArray[Byte]) -> Int raise FzipError {
  if data.length() < 22 {
    raise fzip_err(InvalidZipData, msg="data too short for zip archive")
  }
  let mut e = data.length() - 22
  while e >= 0 {
    if b4(data, e) == zip_eocd_signature {
      let comment_length = b2(data, e + 20)
      if e + 22 + comment_length == data.length() {
        return e
      }
    }
    e -= 1
    if data.length() - e > 65558 {
      break
    }
  }
  raise fzip_err(InvalidZipData, msg="EOCD signature not found")
}

///|
/// Parse the End-Of-Central-Directory record (and ZIP64 EOCD when present)
/// into a unified `ZipCdInfo`.
///
/// Multi-disk archives are rejected. ZIP64 metadata is parsed via
/// `read_zip64_int`, so adversarial size/offset/count values that cannot be
/// represented by the sync API are rejected with `Zip64ValueTooLarge` before
/// any allocation happens.
///
/// Compatibility note: a classic archive whose only sentinel-like value is
/// the entry-count field hitting exactly `0xffff` is treated as a regular
/// 65535-entry classic archive when no valid ZIP64 locator precedes the EOCD.
/// If any other classic field is a sentinel, ZIP64 metadata is required.
fn read_central_directory_info(
  data : FixedArray[Byte],
  eocd : Int,
) -> ZipCdInfo raise FzipError {
  // Classic EOCD layout (offsets relative to the signature):
  //   +0   signature (4)        +4   disk number (2)
  //   +6   start-disk-of-CD (2) +8   entries on this disk (2)
  //   +10  total entries (2)    +12  CD size (4)
  //   +16  CD offset (4)        +20  comment length (2)
  let disk_num = b2(data, eocd + 4)
  let cd_disk = b2(data, eocd + 6)
  let entries_disk = b2(data, eocd + 8)
  let entries_total = b2(data, eocd + 10)
  let cd_size_classic = b4(data, eocd + 12)
  let cd_offset_classic = b4(data, eocd + 16)
  if disk_num != 0 || cd_disk != 0 {
    raise fzip_err(
      InvalidZipData,
      msg="multi-disk ZIP archives are not supported",
    )
  }
  let count_sentinel = entries_total == zip_uint16_max
  let size_sentinel = cd_size_classic == zip_uint32_max
  let offset_sentinel = cd_offset_classic == zip_uint32_max
  let any_sentinel = count_sentinel || size_sentinel || offset_sentinel
  if !any_sentinel {
    if entries_disk != entries_total {
      raise fzip_err(
        InvalidZipData,
        msg="multi-disk ZIP archives are not supported",
      )
    }
    let size = cd_size_classic.reinterpret_as_int()
    let offset = cd_offset_classic.reinterpret_as_int()
    if offset > data.length() || size > data.length() - offset {
      raise fzip_err(
        InvalidZipData,
        msg="central directory bounds exceed archive",
      )
    }
    return { entries: entries_total, size, offset, zip64: false }
  }
  // Sentinel set — try to find a valid ZIP64 locator immediately before EOCD.
  let locator_present = eocd >= 20 &&
    b4(data, eocd - 20) == zip64_locator_signature
  if !locator_present {
    // Compatibility: a classic archive with exactly 65535 entries (and no
    // other sentinel) is valid even without ZIP64 metadata.
    if count_sentinel && !size_sentinel && !offset_sentinel {
      if entries_disk != entries_total {
        raise fzip_err(
          InvalidZipData,
          msg="multi-disk ZIP archives are not supported",
        )
      }
      let size = cd_size_classic.reinterpret_as_int()
      let offset = cd_offset_classic.reinterpret_as_int()
      if offset > data.length() || size > data.length() - offset {
        raise fzip_err(
          InvalidZipData,
          msg="central directory bounds exceed archive",
        )
      }
      return { entries: zip_uint16_max, size, offset, zip64: false }
    }
    raise fzip_err(
      InvalidZipData,
      msg="ZIP64 sentinel set but no valid ZIP64 locator",
    )
  }
  // Locator layout:
  //   +0   signature (4) = 0x07064B50
  //   +4   disk-with-zip64-EOCD (4)
  //   +8   ZIP64-EOCD offset (8)
  //   +16  total disks (4)
  let locator_off = eocd - 20
  let zip64_eocd_disk = b4(data, locator_off + 4)
  let total_disks = b4(data, locator_off + 16)
  if zip64_eocd_disk != 0U || total_disks != 1U {
    raise fzip_err(
      InvalidZipData,
      msg="multi-disk ZIP archives are not supported",
    )
  }
  let zip64_eocd_off = read_zip64_int(
    data,
    locator_off + 8,
    "zip64 EOCD offset",
  )
  // The ZIP64 EOCD record must precede the locator with at least 12 bytes
  // for its own header (signature + size field).
  if zip64_eocd_off > locator_off - 12 {
    raise fzip_err(
      InvalidZipData,
      msg="ZIP64 EOCD record offset overlaps locator",
    )
  }
  if b4(data, zip64_eocd_off) != zip64_eocd_signature {
    raise fzip_err(InvalidZipData, msg="ZIP64 EOCD record signature missing")
  }
  // ZIP64 EOCD record layout:
  //   +0   signature (4)         +4   record size (8)   — bytes following
  //   +12  version made by (2)   +14  version needed (2)
  //   +16  disk number (4)       +20  disk-with-CD (4)
  //   +24  entries on this disk (8) +32 total entries (8)
  //   +40  CD size (8)           +48  CD offset (8)
  let record_size_raw = read_zip64_int(
    data,
    zip64_eocd_off + 4,
    "ZIP64 EOCD record size",
  )
  if record_size_raw < 44 {
    raise fzip_err(InvalidZipData, msg="ZIP64 EOCD record size too small")
  }
  let max_record_size = locator_off - zip64_eocd_off - 12
  if record_size_raw > max_record_size {
    raise fzip_err(
      InvalidZipData,
      msg="ZIP64 EOCD record exceeds locator boundary",
    )
  }
  let z64_disk = b4(data, zip64_eocd_off + 16)
  let z64_disk_with_cd = b4(data, zip64_eocd_off + 20)
  let z64_entries_disk = read_zip64_int(
    data,
    zip64_eocd_off + 24,
    "ZIP64 entries on disk",
  )
  let z64_entries_total = read_zip64_int(
    data,
    zip64_eocd_off + 32,
    "ZIP64 total entries",
  )
  let z64_size = read_zip64_int(
    data,
    zip64_eocd_off + 40,
    "ZIP64 central directory size",
  )
  let z64_offset = read_zip64_int(
    data,
    zip64_eocd_off + 48,
    "ZIP64 central directory offset",
  )
  if z64_disk != 0U || z64_disk_with_cd != 0U {
    raise fzip_err(
      InvalidZipData,
      msg="multi-disk ZIP archives are not supported",
    )
  }
  if z64_entries_disk != z64_entries_total {
    raise fzip_err(
      InvalidZipData,
      msg="multi-disk ZIP archives are not supported",
    )
  }
  // Validate central directory bounds against the archive.
  if z64_offset > data.length() || z64_size > data.length() - z64_offset {
    raise fzip_err(
      InvalidZipData,
      msg="ZIP64 central directory bounds exceed archive",
    )
  }
  {
    entries: z64_entries_total,
    size: z64_size,
    offset: z64_offset,
    zip64: true,
  }
}

///|
/// Extract all supported files from a ZIP archive.
///
/// The result preserves archive order as `(filename, data)` pairs. fzip supports
/// stored entries (`method 0`) and deflated entries (`method 8`), rejects unsafe
/// paths such as absolute paths or `..` components, and applies decompression
/// ratio checks to reduce zip-bomb risk.
pub fn unzip_sync(
  data : FixedArray[Byte],
) -> Array[(String, FixedArray[Byte])] raise FzipError {
  let files : Array[(String, FixedArray[Byte])] = []
  let eocd = find_eocd(data)
  let cd = read_central_directory_info(data, eocd)
  if cd.entries == 0 {
    return files
  }
  let cd_end = cd.offset + cd.size
  let mut o = cd.offset
  for _i in 0..<cd.entries {
    if o >= cd_end {
      raise fzip_err(
        InvalidZipData,
        msg="central directory entry exceeds CD bounds",
      )
    }
    let (comp, sc, su, fn_str, no, off) = zh(data, o, cd.zip64)
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
      // Check compression ratio to detect potential zip bombs
      // Reject if uncompressed size > 1000x compressed size
      if sc > 0 && su / sc > 1000 {
        raise fzip_err(
          InvalidZipData,
          msg="zip compression ratio too high (potential zip bomb)",
        )
      }
      let out = FixedArray::make(su, b'\x00')
      let (buf, _len) = inflt(
        data,
        InflateState::new(2),
        Some(out),
        None,
        default_max_input_size,
        default_max_input_size,
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
/// List ZIP entries without extracting their contents.
///
/// This reads the central directory and returns entry names, compressed sizes,
/// original sizes, and compression methods. It is useful for inspecting an
/// archive before deciding whether to call `unzip_sync`.
pub fn unzip_list(
  data : FixedArray[Byte],
) -> Array[UnzipFileInfo] raise FzipError {
  let infos : Array[UnzipFileInfo] = []
  let eocd = find_eocd(data)
  let cd = read_central_directory_info(data, eocd)
  if cd.entries == 0 {
    return infos
  }
  let cd_end = cd.offset + cd.size
  let mut o = cd.offset
  for _i in 0..<cd.entries {
    if o >= cd_end {
      raise fzip_err(
        InvalidZipData,
        msg="central directory entry exceeds CD bounds",
      )
    }
    let (comp, sc, su, fn_str, no, _off) = zh(data, o, cd.zip64)
    o = no
    infos.push({ name: fn_str, size: sc, original_size: su, compression: comp })
  }
  infos
}
