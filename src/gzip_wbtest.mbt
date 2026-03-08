///|
test "gzip/gunzip roundtrip - simple" {
  let data : FixedArray[Byte] = FixedArray::make(100, b'\x00')
  for i in 0..<100 {
    data[i] = (i % 256).to_byte()
  }
  let compressed = gzip_sync(data)
  // Verify GZIP magic bytes
  assert_eq(compressed[0], b'\x1F')
  assert_eq(compressed[1], b'\x8B')
  assert_eq(compressed[2], b'\x08')
  let decompressed = gunzip_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "gzip/gunzip roundtrip - repeated" {
  let data : FixedArray[Byte] = FixedArray::make(500, b'\x00')
  for i in 0..<500 {
    data[i] = (i % 5).to_byte()
  }
  let compressed = gzip_sync(data)
  let decompressed = gunzip_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "gzip level 0" {
  let data : FixedArray[Byte] = FixedArray::make(50, b'\x42')
  let compressed = gzip_sync(data, opts={
    level: 0,
    mem: 0,
    dictionary: None,
    mtime: 0,
    filename: "",
  })
  let decompressed = gunzip_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "gunzip with verify_checksum=false skips validation" {
  let data : FixedArray[Byte] = [b'\x48', b'\x65', b'\x6C', b'\x6C', b'\x6F']
  let compressed = gzip_sync(data)
  // Corrupt the CRC-32 checksum (last 8 bytes: 4 for CRC, 4 for size)
  let corrupted = slc(compressed, 0)
  corrupted[corrupted.length() - 8] = b'\xFF'
  corrupted[corrupted.length() - 7] = b'\xFF'
  // With verify_checksum=false, should not raise error
  let result = gunzip_sync(corrupted, opts={
    out: None,
    dictionary: None,
    max_output_size: default_max_output_size,
    max_input_size: default_max_input_size,
    verify_checksum: false,
  })
  assert_eq(result.length(), data.length())
}

///|
test "gunzip with verify_checksum=true detects corruption" {
  let data : FixedArray[Byte] = [b'\x48', b'\x65', b'\x6C', b'\x6C', b'\x6F']
  let compressed = gzip_sync(data)
  // Corrupt the CRC-32 checksum
  let corrupted = slc(compressed, 0)
  corrupted[corrupted.length() - 8] = b'\xFF'
  corrupted[corrupted.length() - 7] = b'\xFF'
  // With verify_checksum=true (default), should raise InvalidChecksum error
  let result = try {
    let _ = gunzip_sync(corrupted, opts={
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

///|
test "gzip level 9" {
  let data : FixedArray[Byte] = [1, 2, 3, 4, 5]
  let compressed = gzip_sync(data, opts={
    level: 9,
    mem: 0,
    dictionary: None,
    mtime: 0,
    filename: "",
  })
  let decompressed = gunzip_sync(compressed)
  assert_eq(decompressed.length(), 5)
}

///|
test "gzip with mtime" {
  let data : FixedArray[Byte] = [1, 2, 3]
  let compressed = gzip_sync(data, opts={
    level: 6,
    mem: 0,
    dictionary: None,
    mtime: 1234567890,
    filename: "",
  })
  let decompressed = gunzip_sync(compressed)
  assert_eq(decompressed.length(), 3)
}

///|
test "gzip with filename" {
  let data : FixedArray[Byte] = [1, 2, 3]
  let compressed = gzip_sync(data, opts={
    level: 6,
    mem: 0,
    dictionary: None,
    mtime: 0,
    filename: "test.bin",
  })
  let decompressed = gunzip_sync(compressed)
  assert_eq(decompressed.length(), 3)
}

///|
test "gunzip - invalid CRC-32 checksum" {
  let data : FixedArray[Byte] = FixedArray::make(100, b'A')
  let compressed = gzip_sync(data)
  // Corrupt the CRC-32 (last 8 bytes contain CRC-32 and size)
  let corrupted = slc(compressed, 0, e=compressed.length())
  corrupted[corrupted.length() - 8] = b'\xFF'
  let result = try? gunzip_sync(corrupted)
  assert_true(result is Err(_))
}
