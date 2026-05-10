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
/// Validate a local file header and return the offset of the entry's data.
///
/// Replaces the old `slzh`. The previous helper only added 30 + filename +
/// extra to the local offset without validating the local header signature,
/// the general-purpose bit flag, or that the data range stayed inside the
/// archive. This helper performs all of those checks before returning.
///
/// Specifically:
/// * `local_offset >= 0` and `local_offset + 30 <= data.length()` so the
///   fixed-size header is fully present.
/// * The 4-byte signature equals `zip_local_signature`.
/// * General-purpose bit 0 (encryption) is not set — fzip does not implement
///   ZIP encryption.
/// * General-purpose bit 3 (data descriptor) is not set — Phase 1 defers
///   data descriptor support to Phase 2; the user explicitly opted for the
///   "reject and document" path. Reader streaming will revisit this.
/// * Filename and extra lengths fit inside `data`.
/// * `data_offset + compressed_size <= data.length()`, so slicing or
///   inflating the entry's bytes never reads past the archive.
fn local_data_offset(
  data : FixedArray[Byte],
  local_offset : Int,
  compressed_size : Int,
) -> Int raise FzipError {
  // Use subtraction-form for the upper bound: an additive form
  // (`local_offset + 30 > data.length()`) wraps to a negative Int when
  // `local_offset` is near `Int` max — for example, a malformed central
  // directory whose 32-bit local header offset is `0x7FFFFFFF` reinterprets
  // to `2^31 - 1`. The wrap silently bypasses the check and lets the parser
  // index past the archive end.
  if local_offset < 0 || local_offset > data.length() - 30 {
    raise fzip_err(InvalidZipData, msg="local file header out of bounds")
  }
  if b4(data, local_offset) != zip_local_signature {
    raise fzip_err(InvalidZipData, msg="invalid local file header signature")
  }
  let flag = b2(data, local_offset + 6)
  if (flag & 1) != 0 {
    raise fzip_err(
      InvalidZipData,
      msg="encrypted ZIP entries are not supported",
    )
  }
  if (flag & 8) != 0 {
    raise fzip_err(
      InvalidZipData,
      msg="ZIP data descriptors (bit 3) are deferred to Phase 2",
    )
  }
  let fnl = b2(data, local_offset + 26)
  let exl = b2(data, local_offset + 28)
  // `fnl` and `exl` are 16-bit values so each fits in `Int`, but their sum
  // with `local_offset + 30` can overflow when `local_offset` is close to
  // `Int` max. Compute in `Int64`, then range-check against the archive
  // before storing back.
  let data_off_64 = local_offset.to_int64() +
    30L +
    fnl.to_int64() +
    exl.to_int64()
  if data_off_64 > data.length().to_int64() {
    raise fzip_err(
      InvalidZipData,
      msg="local header filename/extra exceed bounds",
    )
  }
  let data_off = data_off_64.to_int()
  if compressed_size < 0 {
    raise fzip_err(InvalidZipData, msg="negative compressed size")
  }
  if data_off > data.length() - compressed_size {
    raise fzip_err(InvalidZipData, msg="entry data range exceeds bounds")
  }
  data_off
}

///|
/// Resolved central directory entry. Replaces the old positional 6-tuple
/// returned by `zh` with named fields so callers can't accidentally swap
/// `compressed_size` and `uncompressed_size` (or `local_offset` and either
/// of the sizes — they're all `Int`).
priv struct ZipEntryHeader {
  compression : Int
  compressed_size : Int
  uncompressed_size : Int
  name : String
  next_offset : Int
  local_offset : Int
}

///|
/// Parse one central directory file header into a `ZipEntryHeader`.
///
/// Differences from the previous `zh`/`z64e` pair:
/// * Validates the central directory header signature (`zip_cd_signature`).
/// * Bounds-checks the full entry size (header + filename + extra + comment)
///   against the central directory's declared end (`cd_end`).
/// * Rejects per-entry multi-disk indicators (non-zero disk-number-start).
/// * Detects ZIP64 by checking ALL three sentinels (compressed size,
///   uncompressed size, local header offset) instead of just compressed
///   size, then resolves them via `read_zip64_entry_extra` so a sentinel
///   value never propagates as a real number.
fn read_central_directory_entry(
  data : FixedArray[Byte],
  offset : Int,
  cd_end : Int,
  zip64 : Bool,
) -> ZipEntryHeader raise FzipError {
  // Subtraction-form bounds checks. `offset + 46 > cd_end` would wrap on
  // `offset >= 2^31 - 46`, which is reachable in a multi-GiB archive whose
  // CD lives near the upper edge of `Int` range; silently bypassing the
  // check would let the parser index past `cd_end`.
  if offset < 0 || cd_end < 46 || offset > cd_end - 46 {
    raise fzip_err(
      InvalidZipData,
      msg="central directory header exceeds CD bounds",
    )
  }
  if b4(data, offset) != zip_cd_signature {
    raise fzip_err(
      InvalidZipData,
      msg="invalid central directory header signature",
    )
  }
  let flag = b2(data, offset + 8)
  let compression = b2(data, offset + 10)
  let comp_size_classic = b4(data, offset + 20)
  let uncomp_size_classic = b4(data, offset + 24)
  let filename_len = b2(data, offset + 28)
  let extra_len = b2(data, offset + 30)
  let comment_len = b2(data, offset + 32)
  let disk_number_start = b2(data, offset + 34)
  let local_offset_classic = b4(data, offset + 42)
  if filename_len > max_filename_length {
    raise fzip_err(InvalidZipData, msg="zip filename too long")
  }
  if disk_number_start != 0 {
    raise fzip_err(
      InvalidZipData,
      msg="multi-disk ZIP archives are not supported",
    )
  }
  // `entry_total` and `offset + entry_total` can each overflow `Int` for
  // adversarial archives (filename_len + extra_len + comment_len ≤ 196605
  // but offset can be near `Int` max). Keep the math in `Int64` for the
  // bounds check, then convert back.
  let entry_total_64 = 46L +
    filename_len.to_int64() +
    extra_len.to_int64() +
    comment_len.to_int64()
  let next_offset_64 = offset.to_int64() + entry_total_64
  if next_offset_64 > cd_end.to_int64() {
    raise fzip_err(
      InvalidZipData,
      msg="central directory entry exceeds CD bounds",
    )
  }
  let entry_total = entry_total_64.to_int()
  let is_utf8 = (flag & 2048) != 0
  let name = str_from_u8(
    data,
    latin1=!is_utf8,
    offset=offset + 46,
    len=filename_len,
  )
  let need_uncomp = uncomp_size_classic == zip_uint32_max
  let need_comp = comp_size_classic == zip_uint32_max
  let need_local = local_offset_classic == zip_uint32_max
  let any_zip64 = need_uncomp || need_comp || need_local
  let (compressed_size, uncompressed_size, local_offset) = if any_zip64 {
    if !zip64 {
      // The archive's EOCD said this isn't a ZIP64 archive, but this entry
      // uses ZIP64 sentinels. Without the ZIP64 EOCD/locator we cannot
      // safely resolve them, so reject rather than treat sentinels as real
      // sizes.
      raise fzip_err(
        InvalidZipData,
        msg="entry uses ZIP64 sentinels but archive is not ZIP64",
      )
    }
    let extra_offset = offset + 46 + filename_len
    let sizes = read_zip64_entry_extra(
      data,
      extra_offset,
      extra_len,
      classic_compressed=comp_size_classic,
      classic_uncompressed=uncomp_size_classic,
      classic_local_offset=local_offset_classic,
    )
    (sizes.compressed, sizes.uncompressed, sizes.local_offset)
  } else {
    (
      comp_size_classic.reinterpret_as_int(),
      uncomp_size_classic.reinterpret_as_int(),
      local_offset_classic.reinterpret_as_int(),
    )
  }
  {
    compression,
    compressed_size,
    uncompressed_size,
    name,
    next_offset: offset + entry_total,
    local_offset,
  }
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
///
/// `cd_local_offset` decides which header layout to emit:
/// * `None` writes a local file header (no central-only fields).
/// * `Some(off)` writes a central directory entry; `off` is the value to
///   stamp in the central directory's "relative offset of local header"
///   field. PR5c writes `0xffffffffU` here when the entry's local-header
///   offset has been promoted to ZIP64 (the real offset lives in the entry's
///   ZIP64 extra payload).
///
/// `c_size` and `u_size` are pre-computed `UInt` values: callers pass
/// `0xffffffffU` when the matching field has been promoted to a ZIP64
/// sentinel and the real value lives in the entry's ZIP64 extra; otherwise
/// the actual classic-range size.
///
/// `version_needed` and `version_made_by_low` are the low ZIP-spec bytes of
/// the matching APPNOTE §4.4.2 / §4.4.3.2 fields. PR5b stamps them at the
/// classic baseline of 20; PR5c flips them to 45 for entries that carry
/// ZIP64 sentinels or a ZIP64 extra field, while still preserving `os` in
/// the high byte of `version made by`.
fn wzh(
  d : FixedArray[Byte],
  b : Int,
  fn_data : FixedArray[Byte],
  is_utf8 : Bool,
  compression : Int,
  flag : Int,
  crc_val : Int,
  c_size : UInt,
  u_size : UInt,
  mtime : Int,
  os : Int,
  attrs : Int,
  extra : Array[(Int, FixedArray[Byte])],
  cd_local_offset : UInt?,
  comment : FixedArray[Byte]?,
  version_needed? : Int = 20,
  version_made_by_low? : Int = 20,
) -> Int {
  let fl = fn_data.length()
  let exl = exfl(extra)
  let col = match comment {
    Some(c) => c.length()
    None => 0
  }
  let mut b = b
  let is_central = cd_local_offset is Some(_)
  // signature
  if is_central {
    w4(d, b, zip_cd_signature)
  } else {
    w4(d, b, zip_local_signature)
  }
  b += 4
  if is_central {
    d[b] = version_made_by_low.to_byte() // ZIP-spec byte
    b += 1
    d[b] = os.to_byte() // host OS
    b += 1
  }
  w2(d, b, version_needed)
  b += 2
  // flags
  d[b] = (flag << 1).to_byte()
  d[b + 1] = if is_utf8 { b'\x08' } else { b'\x00' }
  b += 2
  // compression method
  w2(d, b, compression)
  b += 2
  // mtime: caller supplies the raw 4-byte value. The Unix-seconds-to-DOS
  // conversion is a separate pre-existing bug tracked outside the ZIP64
  // work; this writer only guarantees the field width is invariant.
  w4(d, b, mtime.reinterpret_as_uint())
  b += 4
  // CRC-32
  w4(d, b, crc_val.reinterpret_as_uint())
  b += 4
  // compressed size (sentinel `0xffffffffU` when promoted to ZIP64)
  w4(d, b, c_size)
  b += 4
  // uncompressed size (sentinel `0xffffffffU` when promoted to ZIP64)
  w4(d, b, u_size)
  b += 4
  // filename length
  w2(d, b, fl)
  b += 2
  // extra field length
  w2(d, b, exl)
  b += 2
  if is_central {
    w2(d, b, col) // comment length
    b += 2
    // disk number start (2) + internal attrs (2): zero
    b += 4
    w4(d, b, attrs.reinterpret_as_uint()) // external attrs
    b += 4
    match cd_local_offset {
      Some(off) => w4(d, b, off)
      None => ()
    }
    b += 4
  }
  // filename
  fn_data.blit_to(d, len=fl, src_offset=0, dst_offset=b)
  b += fl
  // extra fields
  if exl > 0 {
    for i in 0..<extra.length() {
      let (k, exf) = extra[i]
      let l = exf.length()
      w2(d, b, k)
      w2(d, b + 2, l)
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
/// Write the classic end-of-central-directory record.
///
/// The four 16/32-bit overflow fields (entries on disk + total entries +
/// central directory size + central directory offset) are independently
/// promoted to their respective 0xffff / 0xffffffff sentinels when the
/// real value crosses the classic limit OR when `force_all_sentinels` is
/// true (test-only forced ZIP64). When any field is sentinel-promoted the
/// archive must already include a ZIP64 EOCD record + locator immediately
/// before this classic EOCD; the writer caller is responsible for that
/// ordering.
fn wzf(
  o : FixedArray[Byte],
  b : Int,
  entries : Int64,
  cd_size : Int64,
  cd_offset : Int64,
  force_all_sentinels : Bool,
) -> Unit raise FzipError {
  w4(o, b, zip_eocd_signature)
  // disk numbers (4 bytes = 0)
  let entry_field = if force_all_sentinels ||
    entries >= zip_uint16_max.to_int64() {
    zip_uint16_max
  } else {
    entries.to_int()
  }
  w2(o, b + 8, entry_field) // entries on this disk
  w2(o, b + 10, entry_field) // total entries
  let cd_size_field = if force_all_sentinels ||
    cd_size >= zip_uint32_max.to_int64() {
    zip_uint32_max
  } else {
    let v = zip64_to_int(cd_size, "central directory size")
    v.reinterpret_as_uint()
  }
  w4(o, b + 12, cd_size_field) // central directory size
  let cd_offset_field = if force_all_sentinels ||
    cd_offset >= zip_uint32_max.to_int64() {
    zip_uint32_max
  } else {
    let v = zip64_to_int(cd_offset, "central directory offset")
    v.reinterpret_as_uint()
  }
  w4(o, b + 16, cd_offset_field) // offset of central directory
  // comment length (2 bytes = 0)
}

///|
/// Knobs that change `compute_zip_layout` / `build_zip_sync` behavior
/// independently of the user-facing `ZipEntryOptions`. Today only
/// `force_zip64` is exposed; tests use it to drive the ZIP64 emission
/// paths with small inputs, since real archives never hit the 4 GiB / 64 K
/// thresholds inside the sync API's `Int`-bounded budget.
priv struct ZipBuildOpts {
  force_zip64 : Bool
}

///|
/// Default writer options: classic emission, ZIP64 only when sizes/offsets
/// or the entry count actually overflow.
fn ZipBuildOpts::default() -> ZipBuildOpts {
  { force_zip64: false }
}

///|
/// Pass-A intermediate result: per-entry compressed bytes + CRC + the
/// `zip64_local` decision (sizes-only, fixed once compression is done).
/// `zip64_cd` flags depend on the cumulative local-header offset and are
/// resolved in pass B inside `compute_zip_layout`.
priv struct ZipEntryComputed {
  fn_data : FixedArray[Byte]
  compressed : FixedArray[Byte]
  is_utf8 : Bool
  crc_val : Int
  compressed_size : Int64
  uncompressed_size : Int64
  zip64_local : Bool
}

///|
/// Per-entry layout decision computed during the writer's two passes.
///
/// `zip64_local` is true when the LOCAL file header carries a ZIP64 extra
/// (16-byte payload with both 8-byte size values, never an offset).
///
/// `cd_overflow_*` are the per-field overflow flags for the CENTRAL
/// directory entry. Each flag independently controls whether the
/// matching classic field is written as the 32-bit sentinel and whether
/// its 8-byte value is appended to the central-directory ZIP64 extra
/// payload. `zip64_cd` (= any of the three) is computed on demand in
/// the build phase.
priv struct ZipEntryLayout {
  fn_data : FixedArray[Byte]
  compressed : FixedArray[Byte]
  is_utf8 : Bool
  crc_val : Int
  compressed_size : Int64
  uncompressed_size : Int64
  local_offset : Int64
  zip64_local : Bool
  cd_overflow_uncompressed : Bool
  cd_overflow_compressed : Bool
  cd_overflow_local_offset : Bool
}

///|
/// Aggregate layout for a whole archive. All offsets and sizes are
/// `Int64` so the writer can detect ZIP64 thresholds without hitting `Int`
/// overflow during arithmetic. Each `Int64` value gets range-checked
/// before it is converted back for `FixedArray` indexing.
///
/// `archive_zip64` is true when the writer must emit a ZIP64 EOCD record
/// and locator before the classic EOCD: any per-entry promotion, any
/// archive-level field overflow, or `build_opts.force_zip64`.
///
/// `sanitized_extra` is the user's `opts.extra` with reserved-id `0x0001`
/// (ZIP64 extended information) entries removed — fzip owns that id.
priv struct ZipLayout {
  entries : Array[ZipEntryLayout]
  cd_offset : Int64
  cd_size : Int64
  total_size : Int64
  archive_zip64 : Bool
  sanitized_extra : Array[(Int, FixedArray[Byte])]
}

///|
/// Drop user-provided extra fields whose header id is reserved by fzip
/// for its own ZIP64 metadata (`0x0001`). PR5b documents the policy and
/// removes any conflicting entries; PR5c emits a real ZIP64 extra field
/// for entries that need one. Other extra fields pass through.
fn sanitize_user_extra(
  extra : Array[(Int, FixedArray[Byte])],
) -> Array[(Int, FixedArray[Byte])] {
  let result : Array[(Int, FixedArray[Byte])] = []
  for kv in extra {
    let (id, _) = kv
    if id != zip64_extra_field_id {
      result.push(kv)
    }
  }
  result
}

///|
/// Two-pass layout calculation. Pass A compresses each entry, computes
/// CRCs, and decides per-entry `zip64_local` from sizes alone. Pass B
/// walks the computed entries to assign cumulative local offsets,
/// resolve per-field central-directory overflow flags, validate the
/// per-header extra-field length, and accumulate the total archive size.
///
/// Convergence note: `zip64_local` depends only on per-entry sizes (fixed
/// after compression), so pass A's local-header sizes are final on first
/// computation. `zip64_cd` flags depend on the (already final) local
/// offsets and entry sizes, so pass B is also one-shot. There is no
/// fixpoint iteration because adding a ZIP64 extra in the central
/// directory does not shift any local-header offset.
fn compute_zip_layout(
  files : Array[(String, FixedArray[Byte])],
  opts : ZipEntryOptions,
  build_opts : ZipBuildOpts,
) -> ZipLayout raise FzipError {
  let force = build_opts.force_zip64
  let sanitized_extra = sanitize_user_extra(opts.extra)
  let comment_len_per_entry = if opts.comment.length() > 0 {
    str_to_u8(opts.comment).length()
  } else {
    0
  }
  let user_extra_len = exfl(sanitized_extra)
  // Pass A: compress entries; decide zip64_local from sizes alone.
  let computed : Array[ZipEntryComputed] = []
  for i in 0..<files.length() {
    let (fn_str, file) = files[i]
    let compression = if opts.level == 0 { 0 } else { 8 }
    let fn_data = str_to_u8(fn_str)
    let crc_c = CRC32State::new()
    let (compressed, c_len) = if compression != 0 {
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
    let crc_val = crc_c.digest().reinterpret_as_int()
    let is_utf8 = fn_data.length() != fn_str.length()
    let compressed_size = c_len.to_int64()
    let uncompressed_size = file.length().to_int64()
    let zip64_local = force ||
      compressed_size >= zip_uint32_max.to_int64() ||
      uncompressed_size >= zip_uint32_max.to_int64()
    computed.push({
      fn_data,
      compressed,
      is_utf8,
      crc_val,
      compressed_size,
      uncompressed_size,
      zip64_local,
    })
  }
  // Pass B: assign local offsets + cd overflow flags, accumulate sizes.
  let entries : Array[ZipEntryLayout] = []
  let mut local_offset = 0L
  let mut cd_size = 0L
  let mut any_entry_zip64 = false
  let max_extra_64 = max_extra_field_length.to_int64()
  let user_extra_len_64 = user_extra_len.to_int64()
  let comment_len_per_entry_64 = comment_len_per_entry.to_int64()
  for c in computed {
    let cd_overflow_uncompressed = force ||
      c.uncompressed_size >= zip_uint32_max.to_int64()
    let cd_overflow_compressed = force ||
      c.compressed_size >= zip_uint32_max.to_int64()
    let cd_overflow_local_offset = force ||
      local_offset >= zip_uint32_max.to_int64()
    let zip64_cd = cd_overflow_uncompressed ||
      cd_overflow_compressed ||
      cd_overflow_local_offset
    if c.zip64_local || zip64_cd {
      any_entry_zip64 = true
    }
    // Local-header ZIP64 extra: 4-byte field header + 16-byte payload.
    let local_zip64_bytes = if c.zip64_local { 20L } else { 0L }
    // Central-header ZIP64 extra: 4-byte header + 8 bytes per overflowing field.
    let cd_zip64_bytes = if zip64_cd {
      let mut total = 4L
      if cd_overflow_uncompressed {
        total += 8L
      }
      if cd_overflow_compressed {
        total += 8L
      }
      if cd_overflow_local_offset {
        total += 8L
      }
      total
    } else {
      0L
    }
    let total_extra_local = user_extra_len_64 + local_zip64_bytes
    if total_extra_local > max_extra_64 {
      raise fzip_err(
        ExtraFieldTooLong,
        msg="local-header extra fields exceed maximum",
      )
    }
    let total_extra_cd = user_extra_len_64 + cd_zip64_bytes
    if total_extra_cd > max_extra_64 {
      raise fzip_err(
        ExtraFieldTooLong,
        msg="central-directory extra fields exceed maximum",
      )
    }
    entries.push({
      fn_data: c.fn_data,
      compressed: c.compressed,
      is_utf8: c.is_utf8,
      crc_val: c.crc_val,
      compressed_size: c.compressed_size,
      uncompressed_size: c.uncompressed_size,
      local_offset,
      zip64_local: c.zip64_local,
      cd_overflow_uncompressed,
      cd_overflow_compressed,
      cd_overflow_local_offset,
    })
    let local_total = 30L +
      c.fn_data.length().to_int64() +
      total_extra_local +
      c.compressed_size
    let cd_total = 46L +
      c.fn_data.length().to_int64() +
      total_extra_cd +
      comment_len_per_entry_64
    local_offset = local_offset + local_total
    cd_size = cd_size + cd_total
  }
  let cd_offset = local_offset
  let archive_zip64 = force ||
    any_entry_zip64 ||
    entries.length() >= zip_uint16_max ||
    cd_size >= zip_uint32_max.to_int64() ||
    cd_offset >= zip_uint32_max.to_int64()
  // ZIP64 EOCD record (56) + ZIP64 EOCD locator (20) when promoted.
  let zip64_section = if archive_zip64 { 76L } else { 0L }
  let total_size = cd_offset + cd_size + zip64_section + 22L
  // Validate the final archive size fits the sync API's `Int` budget.
  let _ = zip64_to_int(total_size, "archive total size")
  { entries, cd_offset, cd_size, total_size, archive_zip64, sanitized_extra }
}

///|
/// Build a complete ZIP archive byte buffer. Shared raising builder used by
/// both the non-raising `zip_sync` (which traps on raise) and the public
/// raising `zip_sync_checked`. Emits ZIP64 sentinels, ZIP64 extra fields,
/// and ZIP64 EOCD record + locator whenever `compute_zip_layout` decides
/// the archive needs them.
fn build_zip_sync(
  files : Array[(String, FixedArray[Byte])],
  opts : ZipEntryOptions,
  build_opts : ZipBuildOpts,
) -> FixedArray[Byte] raise FzipError {
  let layout = compute_zip_layout(files, opts, build_opts)
  let total_int = zip64_to_int(layout.total_size, "archive total size")
  let out = FixedArray::make(total_int, b'\x00')
  let comment_bytes : FixedArray[Byte]? = if opts.comment.length() > 0 {
    Some(str_to_u8(opts.comment))
  } else {
    None
  }
  let flag = dbf(opts.level)
  let compression = if opts.level == 0 { 0 } else { 8 }
  // Local headers + compressed data
  for entry in layout.entries {
    let lo = entry.local_offset.to_int()
    let local_extras : Array[(Int, FixedArray[Byte])] = []
    for kv in layout.sanitized_extra {
      local_extras.push(kv)
    }
    if entry.zip64_local {
      let payload = build_zip64_extra_local_payload(
        entry.uncompressed_size,
        entry.compressed_size,
      )
      local_extras.push((zip64_extra_field_id, payload))
    }
    let c_size_field = if entry.zip64_local {
      zip_uint32_max
    } else {
      entry.compressed_size.to_int().reinterpret_as_uint()
    }
    let u_size_field = if entry.zip64_local {
      zip_uint32_max
    } else {
      entry.uncompressed_size.to_int().reinterpret_as_uint()
    }
    let version_needed = if entry.zip64_local { 45 } else { 20 }
    let end_local = wzh(
      out,
      lo,
      entry.fn_data,
      entry.is_utf8,
      compression,
      flag,
      entry.crc_val,
      c_size_field,
      u_size_field,
      opts.mtime,
      opts.os,
      opts.attrs,
      local_extras,
      None, // local file header
      None, // no comment in local header
      version_needed~,
    )
    entry.compressed.blit_to(
      out,
      len=entry.compressed_size.to_int(),
      src_offset=0,
      dst_offset=end_local,
    )
  }
  // Central directory entries
  let mut cd_off = layout.cd_offset.to_int()
  for entry in layout.entries {
    let zip64_cd = entry.cd_overflow_uncompressed ||
      entry.cd_overflow_compressed ||
      entry.cd_overflow_local_offset
    let cd_extras : Array[(Int, FixedArray[Byte])] = []
    for kv in layout.sanitized_extra {
      cd_extras.push(kv)
    }
    if zip64_cd {
      let u = if entry.cd_overflow_uncompressed {
        Some(entry.uncompressed_size)
      } else {
        None
      }
      let c = if entry.cd_overflow_compressed {
        Some(entry.compressed_size)
      } else {
        None
      }
      let lo_v = if entry.cd_overflow_local_offset {
        Some(entry.local_offset)
      } else {
        None
      }
      let payload = build_zip64_extra_cd_payload(u, c, lo_v)
      cd_extras.push((zip64_extra_field_id, payload))
    }
    let c_size_field = if entry.cd_overflow_compressed {
      zip_uint32_max
    } else {
      entry.compressed_size.to_int().reinterpret_as_uint()
    }
    let u_size_field = if entry.cd_overflow_uncompressed {
      zip_uint32_max
    } else {
      entry.uncompressed_size.to_int().reinterpret_as_uint()
    }
    let local_offset_field = if entry.cd_overflow_local_offset {
      zip_uint32_max
    } else {
      entry.local_offset.to_int().reinterpret_as_uint()
    }
    // version_needed: 45 if the entry's local OR central header carries
    // ZIP64 metadata. version_made_by low byte: 45 only when this entry
    // itself is ZIP64 in the central directory; otherwise classic 20 with
    // opts.os in the high byte.
    let version_needed = if entry.zip64_local || zip64_cd { 45 } else { 20 }
    let version_made_by_low = if zip64_cd { 45 } else { 20 }
    cd_off = wzh(
      out,
      cd_off,
      entry.fn_data,
      entry.is_utf8,
      compression,
      flag,
      entry.crc_val,
      c_size_field,
      u_size_field,
      opts.mtime,
      opts.os,
      opts.attrs,
      cd_extras,
      Some(local_offset_field),
      comment_bytes,
      version_needed~,
      version_made_by_low~,
    )
  }
  // ZIP64 EOCD record + locator (only when the archive needs ZIP64 metadata)
  if layout.archive_zip64 {
    let zip64_eocd_pos = cd_off
    write_zip64_eocd_record(
      out,
      zip64_eocd_pos,
      layout.entries.length().to_int64(),
      layout.cd_size,
      layout.cd_offset,
    )
    let locator_pos = zip64_eocd_pos + 56
    write_zip64_locator(out, locator_pos, zip64_eocd_pos.to_int64())
    cd_off = locator_pos + 20
  }
  // Classic EOCD (always last). When the archive is ZIP64, the writer
  // sentinel-promotes overflowing entry-count / cd-size / cd-offset
  // fields so a classic-only reader can locate the record while a ZIP64
  // reader follows the locator above.
  wzf(
    out,
    cd_off,
    layout.entries.length().to_int64(),
    layout.cd_size,
    layout.cd_offset,
    build_opts.force_zip64,
  )
  out
}

///|
/// Create a ZIP archive from `(filename, data)` entries.
///
/// Each entry is written with the same `ZipEntryOptions`. Entry names are
/// encoded as UTF-8 when needed, and `level = 0` stores files without DEFLATE
/// compression. The returned bytes are a complete ZIP archive containing local
/// file headers, central directory entries, and the end-of-central-directory
/// record. ZIP64 metadata (per-entry ZIP64 extras, ZIP64 EOCD record, ZIP64
/// locator) is emitted automatically when an entry crosses the classic 32-bit
/// size limit, when the archive carries 65 535 or more entries, or when the
/// central directory itself crosses the 32-bit size or offset limit.
///
/// This function preserves its existing non-raising signature for source
/// compatibility. The shared raising builder it delegates to may detect
/// metadata or layout values that exceed the sync API's `Int`/`FixedArray`
/// budget. When that happens this wrapper traps deterministically with a
/// stable abort message rather than returning a partial or corrupt archive.
/// Callers that prefer to recover from such failures should use
/// `zip_sync_checked`.
pub fn zip_sync(
  files : Array[(String, FixedArray[Byte])],
  opts? : ZipEntryOptions = ZipEntryOptions::default(),
) -> FixedArray[Byte] {
  build_zip_sync(files, opts, ZipBuildOpts::default()) catch {
    FzipError(message~, ..) =>
      abort(
        "fzip.zip_sync failed; use zip_sync_checked for recoverable errors: " +
        message,
      )
  }
}

///|
/// Create a ZIP archive from `(filename, data)` entries with recoverable
/// failure semantics.
///
/// Behaves exactly like `zip_sync` but raises `FzipError` instead of trapping
/// when the writer encounters a value or layout that cannot be represented in
/// the current sync API. Today this happens for two specific failure modes:
///
/// * `Zip64ValueTooLarge` — a metadata count, size, offset, or the final
///   archive size cannot fit in MoonBit's 32-bit signed `Int` or be safely
///   indexed in a `FixedArray`.
/// * `ExtraFieldTooLong` — the user's `opts.extra` plus the writer-generated
///   ZIP64 extra would exceed `max_extra_field_length` for a local or central
///   directory entry.
///
/// Both APIs share the same underlying builder, so any successful build
/// produces byte-identical output.
pub fn zip_sync_checked(
  files : Array[(String, FixedArray[Byte])],
  opts? : ZipEntryOptions = ZipEntryOptions::default(),
) -> FixedArray[Byte] raise FzipError {
  build_zip_sync(files, opts, ZipBuildOpts::default())
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
    let header = read_central_directory_entry(data, o, cd_end, cd.zip64)
    if is_unsafe_path(header.name) {
      raise fzip_err(
        InvalidZipData,
        msg="zip entry contains unsafe path: " + header.name,
      )
    }
    o = header.next_offset
    let sc = header.compressed_size
    let su = header.uncompressed_size
    // Cap output size before allocating, regardless of compression method.
    if su > default_max_output_size {
      raise fzip_err(
        InvalidZipData,
        msg="entry uncompressed size exceeds default_max_output_size",
      )
    }
    let b_off = local_data_offset(data, header.local_offset, sc)
    if header.compression == 0 {
      files.push((header.name, slc(data, b_off, e=b_off + sc)))
    } else if header.compression == 8 {
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
        default_max_output_size,
        dat_off=b_off,
        dat_end=b_off + sc,
      )
      files.push((header.name, buf))
    } else {
      raise fzip_err(
        UnknownCompressionMethod,
        msg="unknown compression type " + header.compression.to_string(),
      )
    }
  }
  if o != cd_end {
    raise fzip_err(
      InvalidZipData,
      msg="central directory has trailing or missing bytes",
    )
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
    let header = read_central_directory_entry(data, o, cd_end, cd.zip64)
    o = header.next_offset
    infos.push({
      name: header.name,
      size: header.compressed_size,
      original_size: header.uncompressed_size,
      compression: header.compression,
    })
  }
  if o != cd_end {
    raise fzip_err(
      InvalidZipData,
      msg="central directory has trailing or missing bytes",
    )
  }
  infos
}
