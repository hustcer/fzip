///|
/// Convert an `Int64` ZIP64 value to a sync-API-safe `Int`.
///
/// Rejects negative values and values that exceed `max_int_val()` with
/// `Zip64ValueTooLarge`, so the sync APIs never silently allocate or index
/// past `Int` range. `context` is included in the error message to identify
/// which ZIP64 field tripped the check.
fn zip64_to_int(v : Int64, context : String) -> Int raise FzipError {
  if v < 0L {
    raise fzip_err(Zip64ValueTooLarge, msg=context + ": negative value")
  }
  if v > max_int_val().to_int64() {
    raise fzip_err(
      Zip64ValueTooLarge,
      msg=context + ": value exceeds Int range",
    )
  }
  v.to_int()
}

///|
/// Read a ZIP64 8-byte little-endian value as a sync-API-safe `Int`.
///
/// Reads the low and high 32-bit words separately so adversarial values whose
/// `Int64` representation would be negative (or anything past `max_int_val()`)
/// are rejected before they can reach allocation or indexing arithmetic.
/// Prefer this over `b8(...).to_int()` for any ZIP64 size, count, or offset
/// that originates outside the writer.
fn read_zip64_int(
  data : FixedArray[Byte],
  offset : Int,
  context : String,
) -> Int raise FzipError {
  let lo = b4(data, offset)
  let hi = b4(data, offset + 4)
  if hi != 0U {
    raise fzip_err(
      Zip64ValueTooLarge,
      msg=context + ": value > 2^32 not representable",
    )
  }
  if lo > max_int_val().reinterpret_as_uint() {
    raise fzip_err(
      Zip64ValueTooLarge,
      msg=context + ": value exceeds Int range",
    )
  }
  lo.reinterpret_as_int()
}

///|
/// Writer-side checked helper: validates the ZIP64 value fits the sync API's
/// `Int` range, then writes it as a fixed 8-byte little-endian value via `w8`.
fn write_zip64_int(
  data : FixedArray[Byte],
  offset : Int,
  value : Int64,
  context : String,
) -> Unit raise FzipError {
  let _ = zip64_to_int(value, context)
  w8(data, offset, value)
}

///|
/// Resolved per-entry size + offset triple after reconciling the classic
/// 32-bit fields with the ZIP64 extended information extra field. Using a
/// named struct (instead of a positional tuple) prevents callers from
/// confusing compressed size, uncompressed size, and local header offset —
/// which are otherwise indistinguishable `Int`s.
priv struct ZipEntrySizes {
  compressed : Int
  uncompressed : Int
  local_offset : Int
}

///|
/// Parse a central directory entry's ZIP64 extended information extra field
/// (header id `0x0001`, PKWARE APPNOTE §4.5.3).
///
/// The classic 32-bit values are passed in as labeled parameters. For each
/// classic field that holds the sentinel `0xFFFFFFFF`, the matching 8-byte
/// value is read from the ZIP64 extra in spec-fixed order: uncompressed
/// size, compressed size, then local header offset. Unrelated extra fields
/// before the ZIP64 one are skipped. Returns the resolved `ZipEntrySizes`
/// — sentinel values never propagate out as real sizes.
///
/// Errors:
/// * `ExtraFieldTooLong` if `extra_len` exceeds `max_extra_field_length`.
/// * `InvalidZipData` if an extra field is truncated, the ZIP64 extra is
///   missing required size/offset fields, the ZIP64 extra is missing
///   entirely, or a non-zero disk number is present.
/// * `Zip64ValueTooLarge` if a ZIP64 size or offset cannot be represented
///   as the sync API's `Int`.
fn read_zip64_entry_extra(
  data : FixedArray[Byte],
  extra_offset : Int,
  extra_len : Int,
  classic_compressed~ : UInt,
  classic_uncompressed~ : UInt,
  classic_local_offset~ : UInt,
) -> ZipEntrySizes raise FzipError {
  if extra_len > max_extra_field_length {
    raise fzip_err(ExtraFieldTooLong, msg="extra field length exceeds maximum")
  }
  let need_uncomp = classic_uncompressed == zip_uint32_max
  let need_comp = classic_compressed == zip_uint32_max
  let need_local = classic_local_offset == zip_uint32_max
  let end = extra_offset + extra_len
  let mut p = extra_offset
  while p + 4 <= end {
    let header_id = b2(data, p)
    let field_len = b2(data, p + 2)
    if p + 4 + field_len > end {
      raise fzip_err(InvalidZipData, msg="extra field truncated")
    }
    if header_id == zip64_extra_field_id {
      let field_start = p + 4
      let field_end = field_start + field_len
      let mut fp = field_start
      let uncompressed = if need_uncomp {
        if fp + 8 > field_end {
          raise fzip_err(
            InvalidZipData,
            msg="ZIP64 extra missing uncompressed size",
          )
        }
        let v = read_zip64_int(data, fp, "ZIP64 entry uncompressed size")
        fp = fp + 8
        v
      } else {
        classic_uncompressed.reinterpret_as_int()
      }
      let compressed = if need_comp {
        if fp + 8 > field_end {
          raise fzip_err(
            InvalidZipData,
            msg="ZIP64 extra missing compressed size",
          )
        }
        let v = read_zip64_int(data, fp, "ZIP64 entry compressed size")
        fp = fp + 8
        v
      } else {
        classic_compressed.reinterpret_as_int()
      }
      let local_offset = if need_local {
        if fp + 8 > field_end {
          raise fzip_err(
            InvalidZipData,
            msg="ZIP64 extra missing local header offset",
          )
        }
        let v = read_zip64_int(data, fp, "ZIP64 entry local header offset")
        fp = fp + 8
        v
      } else {
        classic_local_offset.reinterpret_as_int()
      }
      // The 4-byte disk-start-number is optional; if present, it must be 0.
      if fp + 4 <= field_end {
        let disk = b4(data, fp)
        if disk != 0U {
          raise fzip_err(
            InvalidZipData,
            msg="multi-disk ZIP archives are not supported",
          )
        }
      }
      return { compressed, uncompressed, local_offset }
    }
    p = p + 4 + field_len
  }
  raise fzip_err(InvalidZipData, msg="required ZIP64 extra field not present")
}

///|
/// Build the 16-byte payload for a ZIP64 extended information extra field
/// stored inside a LOCAL file header (PKWARE APPNOTE §4.5.3 + §4.4.8/§4.4.9
/// notes on local-header interoperability). When either size in the local
/// header needs the 32-bit sentinel, the local-header ZIP64 extra MUST carry
/// BOTH 8-byte size values in the spec-fixed order: uncompressed then
/// compressed. Local headers never include the local header offset — that
/// belongs to the central directory only.
///
/// Returned bytes are the field PAYLOAD only; the surrounding 4-byte
/// `(header_id, data_size)` pair is stamped in by the writer when this
/// payload is appended to the entry's extras list.
fn build_zip64_extra_local_payload(
  uncompressed : Int64,
  compressed : Int64,
) -> FixedArray[Byte] raise FzipError {
  let _ = zip64_to_int(uncompressed, "ZIP64 local extra uncompressed size")
  let _ = zip64_to_int(compressed, "ZIP64 local extra compressed size")
  let buf = FixedArray::make(16, b'\x00')
  w8(buf, 0, uncompressed)
  w8(buf, 8, compressed)
  buf
}

///|
/// Build the variable-length payload for a ZIP64 extended information extra
/// field stored inside a CENTRAL DIRECTORY entry. Each value is included
/// only when the matching classic field is being written as the 32-bit
/// sentinel. The order is fixed by APPNOTE §4.5.3: uncompressed, compressed,
/// local header offset.
///
/// `None` for any of the three values means "the classic 32-bit field still
/// holds the real value, do not include this field in the ZIP64 extra".
fn build_zip64_extra_cd_payload(
  uncompressed : Int64?,
  compressed : Int64?,
  local_offset : Int64?,
) -> FixedArray[Byte] raise FzipError {
  let values : Array[(Int64, String)] = []
  match uncompressed {
    Some(v) => values.push((v, "ZIP64 CD extra uncompressed size"))
    None => ()
  }
  match compressed {
    Some(v) => values.push((v, "ZIP64 CD extra compressed size"))
    None => ()
  }
  match local_offset {
    Some(v) => values.push((v, "ZIP64 CD extra local offset"))
    None => ()
  }
  let buf = FixedArray::make(values.length() * 8, b'\x00')
  for i, kv in values {
    let (v, ctx) = kv
    let _ = zip64_to_int(v, ctx)
    w8(buf, i * 8, v)
  }
  buf
}

///|
/// Write a ZIP64 end-of-central-directory record (PKWARE APPNOTE §4.3.14).
/// fzip emits the minimum 56-byte form: a 12-byte fixed header (signature +
/// 8-byte `record size`) followed by the 44-byte field block. The
/// version_made_by / version_needed bytes are stamped at 45 (low byte) /
/// 0 (high byte = compatibility OS) per APPNOTE §4.4.3.2. Disk numbers are
/// zero — multi-disk ZIP is unsupported. Each 64-bit count/size/offset is
/// validated through `write_zip64_int` so values beyond the sync API's
/// `Int` ceiling raise `Zip64ValueTooLarge` rather than silently
/// overflowing.
fn write_zip64_eocd_record(
  d : FixedArray[Byte],
  b : Int,
  entries : Int64,
  cd_size : Int64,
  cd_offset : Int64,
) -> Unit raise FzipError {
  w4(d, b, zip64_eocd_signature)
  // record size = 44 (bytes after this field)
  w8(d, b + 4, 44L)
  // version made by (low = 45 spec, high = 0 OS), version needed = 45.
  w2(d, b + 12, 45)
  w2(d, b + 14, 45)
  // disk number (+16) and disk-with-CD (+20): zero for single-disk archives.
  // entries on this disk == total entries
  write_zip64_int(d, b + 24, entries, "ZIP64 EOCD entries on disk")
  write_zip64_int(d, b + 32, entries, "ZIP64 EOCD total entries")
  write_zip64_int(d, b + 40, cd_size, "ZIP64 EOCD central directory size")
  write_zip64_int(d, b + 48, cd_offset, "ZIP64 EOCD central directory offset")
}

///|
/// Write a 20-byte ZIP64 end-of-central-directory locator (PKWARE APPNOTE
/// §4.3.15). Single-disk archives only — disk-containing-zip64-EOCD = 0,
/// total disks = 1.
fn write_zip64_locator(
  d : FixedArray[Byte],
  b : Int,
  zip64_eocd_offset : Int64,
) -> Unit raise FzipError {
  w4(d, b, zip64_locator_signature)
  // disk-containing-zip64-EOCD at +4: zero.
  write_zip64_int(d, b + 8, zip64_eocd_offset, "ZIP64 EOCD locator offset")
  w4(d, b + 16, 1U) // total disks
}
