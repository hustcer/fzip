///|
/// Test inflate roundtrip for very small input (1 byte)
test "inflate/small_buffer/1_byte" {
  let data : FixedArray[Byte] = [0x42]
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 1)
  assert_eq(decompressed[0], b'\x42')
}

///|
/// Test inflate roundtrip for tiny input (10 bytes)
test "inflate/small_buffer/10_bytes" {
  let data = FixedArray::make(10, b'\x00')
  for i in 0..<10 {
    data[i] = (i * 25).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 10)
  for i in 0..<10 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test inflate roundtrip at 1KB — the size where the old 128KB allocation was wasteful
test "inflate/small_buffer/1kb" {
  let data = FixedArray::make(1024, b'\x00')
  for i in 0..<1024 {
    data[i] = (i % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 1024)
  for i in 0..<1024 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test inflate roundtrip near the threshold where grow switches from dynamic to 131072
/// Threshold: sl * 3 == 131072 → sl ≈ 43690 bytes compressed
/// Use ~44KB input to produce compressed data around the boundary
test "inflate/buffer_threshold/near_boundary" {
  let data = FixedArray::make(44000, b'\x00')
  for i in 0..<44000 {
    data[i] = (i % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 44000)
  for i in 0..<44000 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test inflate with large input (100KB) — should use original 131072 grow value
test "inflate/large_buffer/100kb" {
  let data = FixedArray::make(102400, b'\x00')
  for i in 0..<102400 {
    data[i] = (i % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 102400)
  // Spot-check some values
  assert_eq(decompressed[0], b'\x00')
  assert_eq(decompressed[255], b'\xFF')
  assert_eq(decompressed[256], b'\x00')
  assert_eq(decompressed[102399], (102399 % 256).to_byte())
}

///|
/// Test unzlib_sync roundtrip for small data — also affected by P0 fix
test "inflate/unzlib_small/1kb" {
  let data = FixedArray::make(1024, b'\x00')
  for i in 0..<1024 {
    data[i] = (i % 128).to_byte()
  }
  let compressed = zlib_sync(data)
  let decompressed = unzlib_sync(compressed)
  assert_eq(decompressed.length(), 1024)
  for i in 0..<1024 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test inflate with all-zeros (best compression ratio, output >> compressed size)
test "inflate/high_ratio/zeros_4kb" {
  let data = FixedArray::make(4096, b'\x00')
  let compressed = deflate_sync(data)
  // All-zeros compress extremely well, output buffer needs to grow significantly
  assert_true(compressed.length() < 100)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 4096)
  for i in 0..<4096 {
    assert_eq(decompressed[i], b'\x00')
  }
}

///|
/// Test inflate with random-like data (worst compression ratio, output ≈ compressed size)
test "inflate/low_ratio/random_1kb" {
  let data = FixedArray::make(1024, b'\x00')
  let mut s = 42
  for i in 0..<1024 {
    s = (s * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (s >> 16).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 1024)
  for i in 0..<1024 {
    assert_eq(decompressed[i], data[i])
  }
}
