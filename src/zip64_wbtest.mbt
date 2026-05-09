///|
test "zip64_to_int - rejects negative" {
  let r : Result[Int, FzipError] = try? zip64_to_int(-1L, "compressed_size")
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, Zip64ValueTooLarge)
}

///|
test "zip64_to_int - rejects values past Int range" {
  let too_big = max_int_val().to_int64() + 1L
  let r : Result[Int, FzipError] = try? zip64_to_int(
    too_big, "central_dir_size",
  )
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, Zip64ValueTooLarge)
}

///|
test "zip64_to_int - accepts representable values" {
  inspect(zip64_to_int(0L, "x"), content="0")
  inspect(zip64_to_int(123L, "x"), content="123")
  inspect(
    zip64_to_int(max_int_val().to_int64(), "x"),
    content=max_int_val().to_string(),
  )
}

///|
test "read_zip64_int - reads small low-word value" {
  let d : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  // Little-endian 8-byte 0x0000_0000_0000_002A
  d[0] = b'\x2A'
  inspect(read_zip64_int(d, 0, "size"), content="42")
}

///|
test "read_zip64_int - rejects high word non-zero (> 2^32)" {
  let d : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  // Set byte 4 = 1 -> high 32-bit word = 1, value = 2^32.
  d[4] = b'\x01'
  let r : Result[Int, FzipError] = try? read_zip64_int(
    d, 0, "uncompressed_size",
  )
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, Zip64ValueTooLarge)
}

///|
test "read_zip64_int - rejects low word past Int range" {
  let d : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  // Low word = 0x80000000 = 2147483648, which exceeds max_int_val (2^31 - 1).
  d[3] = b'\x80'
  let r : Result[Int, FzipError] = try? read_zip64_int(d, 0, "local_offset")
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, Zip64ValueTooLarge)
}

///|
test "read_zip64_int - accepts max_int_val low word" {
  let d : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  d[0] = b'\xFF'
  d[1] = b'\xFF'
  d[2] = b'\xFF'
  d[3] = b'\x7F'
  inspect(read_zip64_int(d, 0, "x"), content=max_int_val().to_string())
}

///|
test "write_zip64_int - validates and writes 8 bytes" {
  let d : FixedArray[Byte] = FixedArray::make(16, b'\xFF')
  write_zip64_int(d, 0, 1L, "size")
  inspect(d[0].to_int(), content="1")
  for i in 1..<8 {
    assert_eq(d[i].to_int(), 0)
  }
  // Untouched suffix preserved.
  for i in 8..<16 {
    assert_eq(d[i].to_int(), 255)
  }
}

///|
test "write_zip64_int - rejects negative value before writing" {
  let d : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  let r : Result[Unit, FzipError] = try? write_zip64_int(
    d, 0, -1L, "compressed_size",
  )
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, Zip64ValueTooLarge)
}

///|
test "constants - ZIP64 signatures and sentinels" {
  // Renamed: the old misnamed constant kept its value (0x06064B50).
  inspect(zip64_eocd_signature, content="101075792")
  // Locator (separate 0x07064B50).
  inspect(zip64_locator_signature, content="117853008")
  inspect(zip64_extra_field_id, content="1")
  inspect(zip_uint16_max, content="65535")
  inspect(zip_uint32_max, content="4294967295")
  inspect(max_extra_field_length, content="4096")
}
