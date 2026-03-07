///|
test "compress/decompress roundtrip (gzip)" {
  let data : FixedArray[Byte] = FixedArray::make(200, b'\x00')
  for i in 0..<200 {
    data[i] = (i % 50).to_byte()
  }
  let compressed = @fzip.compress_sync(data)
  let decompressed = @fzip.decompress_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "decompress auto-detects zlib" {
  let data : FixedArray[Byte] = FixedArray::make(100, b'\x00')
  for i in 0..<100 {
    data[i] = (i % 30).to_byte()
  }
  let compressed = @fzip.zlib_sync(data)
  let decompressed = @fzip.decompress_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "decompress auto-detects gzip" {
  let data : FixedArray[Byte] = FixedArray::make(100, b'\x00')
  for i in 0..<100 {
    data[i] = (i % 20).to_byte()
  }
  let compressed = @fzip.gzip_sync(data)
  let decompressed = @fzip.decompress_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}
