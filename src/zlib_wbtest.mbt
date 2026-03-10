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
  let result = try? unzlib_sync(corrupted)
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
  assert_eq(result, Some(InvalidChecksum))
}
