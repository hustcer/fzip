///|
test "zlib/unzlib roundtrip - simple" {
  let data : FixedArray[Byte] = FixedArray::make(100, b'\x00')
  for i in 0..<100 {
    data[i] = (i % 256).to_byte()
  }
  let compressed = zlib_sync(data)
  // Verify Zlib header: CMF = 0x78
  assert_eq(compressed[0], b'\x78')
  let decompressed = unzlib_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "zlib/unzlib roundtrip - repeated" {
  let data : FixedArray[Byte] = FixedArray::make(500, b'\x00')
  for i in 0..<500 {
    data[i] = (i % 7).to_byte()
  }
  let compressed = zlib_sync(data)
  let decompressed = unzlib_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "zlib level 0" {
  let data : FixedArray[Byte] = FixedArray::make(50, b'\x43')
  let compressed = zlib_sync(data, opts={ level: 0, mem: 0, dictionary: None })
  let decompressed = unzlib_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "unzlib - invalid Adler-32 checksum" {
  let data : FixedArray[Byte] = FixedArray::make(100, b'B')
  let compressed = zlib_sync(data)
  // Corrupt the Adler-32 (last 4 bytes)
  let corrupted = slc(compressed, 0, e=compressed.length())
  corrupted[corrupted.length() - 1] = b'\xFF'
  let result = fzip_result(() => unzlib_sync(corrupted))
  assert_true(result is Err(_))
}

///|
test "checksum fusion - zlib multi-block with verify_checksum" {
  // 100K data spans multiple DEFLATE blocks; Adler-32 fused into both passes
  let size = 100000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 64).to_byte()
  }
  let compressed = zlib_sync(data)
  let decompressed = unzlib_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "checksum fusion - zlib with dictionary and verify_checksum" {
  // Dictionary + fused Adler-32: dict bytes excluded from compression checksum,
  // decompression checksum computed during inflt()
  let dict : FixedArray[Byte] = FixedArray::make(100, b'\x00')
  for i in 0..<100 {
    dict[i] = (i * 3).to_byte()
  }
  let data : FixedArray[Byte] = FixedArray::make(500, b'\x00')
  for i in 0..<500 {
    data[i] = (i % 50).to_byte()
  }
  let compressed = zlib_sync(data, opts={
    level: 6,
    mem: 0,
    dictionary: Some(dict),
  })
  let decompressed = unzlib_sync(compressed, opts={
    out: None,
    dictionary: Some(dict),
    max_output_size: default_max_output_size,
    max_input_size: default_max_input_size,
    verify_checksum: true,
  })
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "checksum fusion - zlib incompressible data with verify_checksum" {
  // Random data triggers stored-block path; Adler-32 must still be correct
  let size = 2000
  let data = FixedArray::make(size, b'\x00')
  let mut seed = 42
  for i in 0..<size {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (seed >> 16).to_byte()
  }
  let compressed = zlib_sync(data)
  let decompressed = unzlib_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "unzlib with verify_checksum=false skips validation" {
  let data : FixedArray[Byte] = [b'\x54', b'\x65', b'\x73', b'\x74']
  let compressed = zlib_sync(data)
  // Corrupt the Adler-32 checksum (last 4 bytes)
  let corrupted = slc(compressed, 0)
  corrupted[corrupted.length() - 1] = b'\xFF'
  corrupted[corrupted.length() - 2] = b'\xFF'
  // With verify_checksum=false, should not raise error
  let result = unzlib_sync(corrupted, opts={
    out: None,
    dictionary: None,
    max_output_size: default_max_output_size,
    max_input_size: default_max_input_size,
    verify_checksum: false,
  })
  assert_eq(result.length(), data.length())
}

///|
test "unzlib with verify_checksum=true detects corruption" {
  let data : FixedArray[Byte] = [b'\x54', b'\x65', b'\x73', b'\x74']
  let compressed = zlib_sync(data)
  // Corrupt the Adler-32 checksum
  let corrupted = slc(compressed, 0)
  corrupted[corrupted.length() - 1] = b'\xFF'
  corrupted[corrupted.length() - 2] = b'\xFF'
  // With verify_checksum=true (default), should raise InvalidChecksum error
  let result = try {
    let _ = unzlib_sync(corrupted, opts={
      out: None,
      dictionary: None,
      max_output_size: default_max_output_size,
      max_input_size: default_max_input_size,
      verify_checksum: true,
    })
    None
  } catch {
    FzipError(code~, ..) => Some(code)
  }
  assert_true(result == Some(InvalidChecksum), msg="expected InvalidChecksum")
}

///|
test "zlib dictionary ID uses RFC 1950 Adler-32 value" {
  let dict : FixedArray[Byte] = [1, 2, 3, 4, 5]
  let data : FixedArray[Byte] = [1, 2, 3, 4, 5, 1, 2, 3, 4, 5]
  let compressed = zlib_sync(data, opts={
    level: 6,
    mem: 0,
    dictionary: Some(dict),
  })
  // RFC 1950 DICTID is the canonical Adler-32 value 0x00280010 in
  // network byte order, independent of fzip's footer-oriented UInt layout.
  assert_eq(compressed[2], b'\x00')
  assert_eq(compressed[3], b'\x28')
  assert_eq(compressed[4], b'\x00')
  assert_eq(compressed[5], b'\x10')
}

///|
test "unzlib accepts an RFC 1950 dictionary stream from Python zlib" {
  let dict : FixedArray[Byte] = [1, 2, 3, 4, 5]
  let compressed : FixedArray[Byte] = [
    b'\x78', b'\xBB', b'\x00', b'\x28', b'\x00', b'\x10', b'\x63', b'\x84', b'\x13',
    b'\x00', b'\x00', b'\x9B', b'\x00', b'\x1F',
  ]
  let decompressed = unzlib_sync(compressed, opts={
    out: None,
    dictionary: Some(dict),
    max_output_size: default_max_output_size,
    max_input_size: default_max_input_size,
    verify_checksum: true,
  })
  let expected : FixedArray[Byte] = [1, 2, 3, 4, 5, 1, 2, 3, 4, 5]
  assert_eq(decompressed.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(decompressed[i], expected[i])
  }
}

///|
test "unzlib rejects mismatched dictionary when checksum verification is disabled" {
  let dict : FixedArray[Byte] = [1, 2, 3, 4, 5]
  let wrong_dict : FixedArray[Byte] = [9, 9, 9, 9, 9]
  let data : FixedArray[Byte] = [1, 2, 3, 4, 5, 1, 2, 3, 4, 5]
  let compressed = zlib_sync(data, opts={
    level: 6,
    mem: 0,
    dictionary: Some(dict),
  })
  let result : Result[FixedArray[Byte], FzipError] = fzip_result(() => {
    unzlib_sync(compressed, opts={
      out: None,
      dictionary: Some(wrong_dict),
      max_output_size: default_max_output_size,
      max_input_size: default_max_input_size,
      verify_checksum: false,
    })
  })
  guard result is Err(FzipError(code~, message~)) else {
    fail("expected mismatched dictionary to be rejected")
  }
  assert_eq(code, InvalidChecksum)
  assert_true(message.contains("dictionary"))
}
