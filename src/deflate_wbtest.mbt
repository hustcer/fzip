///|
test "deflate/inflate roundtrip - empty" {
  let data : FixedArray[Byte] = FixedArray::make(0, b'\x00')
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 0)
}

///|
test "deflate/inflate roundtrip - simple data" {
  let data : FixedArray[Byte] = FixedArray::make(100, b'\x00')
  for i in 0..<100 {
    data[i] = (i % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "deflate/inflate roundtrip - repeated data" {
  let data : FixedArray[Byte] = FixedArray::make(1000, b'\x00')
  for i in 0..<1000 {
    data[i] = (i % 10).to_byte()
  }
  let compressed = deflate_sync(data)
  // Repeated data should compress well
  assert_true(compressed.length() < data.length())
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "deflate level 0 - store" {
  let data : FixedArray[Byte] = FixedArray::make(50, b'\x41')
  let compressed = deflate_sync(data, opts={
    level: 0,
    mem: 0,
    dictionary: None,
  })
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "deflate level 1 - fast" {
  let data : FixedArray[Byte] = FixedArray::make(200, b'\x00')
  for i in 0..<200 {
    data[i] = (i % 26 + 65).to_byte()
  }
  let compressed = deflate_sync(data, opts={
    level: 1,
    mem: 0,
    dictionary: None,
  })
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "deflate level 9 - best" {
  let data : FixedArray[Byte] = FixedArray::make(200, b'\x00')
  for i in 0..<200 {
    data[i] = (i % 26 + 65).to_byte()
  }
  let compressed = deflate_sync(data, opts={
    level: 9,
    mem: 0,
    dictionary: None,
  })
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
}
