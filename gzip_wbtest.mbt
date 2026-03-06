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
