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
