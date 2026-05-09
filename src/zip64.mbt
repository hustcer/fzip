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
