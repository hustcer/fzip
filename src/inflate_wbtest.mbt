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

///|
/// Test inflt() with dat_off/dat_end: embed compressed data in a larger buffer
test "inflt/offset/basic" {
  let data = FixedArray::make(256, b'\x00')
  for i in 0..<256 {
    data[i] = (i % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  let cl = compressed.length()
  // Embed compressed data at offset 10 inside a larger buffer
  let prefix = 10
  let suffix = 7
  let padded = FixedArray::make(prefix + cl + suffix, b'\xAA')
  compressed.blit_to(padded, len=cl, src_offset=0, dst_offset=prefix)
  let (result, result_len) = inflt(
    padded,
    InflateState::new(2),
    None,
    None,
    dat_off=prefix,
    dat_end=prefix + cl,
  )
  assert_eq(result_len, 256)
  for i in 0..<256 {
    assert_eq(result[i], data[i])
  }
}

///|
/// Test inflt() with dat_off/dat_end and pre-allocated output buffer
test "inflt/offset/with_output_buf" {
  let data = FixedArray::make(512, b'\x00')
  for i in 0..<512 {
    data[i] = (i % 128).to_byte()
  }
  let compressed = deflate_sync(data)
  let cl = compressed.length()
  let prefix = 20
  let padded = FixedArray::make(prefix + cl + 5, b'\xFF')
  compressed.blit_to(padded, len=cl, src_offset=0, dst_offset=prefix)
  let out = FixedArray::make(512, b'\x00')
  let (result, result_len) = inflt(
    padded,
    InflateState::new(2),
    Some(out),
    None,
    dat_off=prefix,
    dat_end=prefix + cl,
  )
  assert_eq(result_len, 512)
  for i in 0..<512 {
    assert_eq(result[i], data[i])
  }
}

///|
/// Test gzip roundtrip with larger data (exercises gunzip_sync offset path)
test "inflt/offset/gzip_roundtrip_8kb" {
  let data = FixedArray::make(8192, b'\x00')
  for i in 0..<8192 {
    data[i] = (i % 256).to_byte()
  }
  let compressed = gzip_sync(data)
  let decompressed = gunzip_sync(compressed)
  assert_eq(decompressed.length(), 8192)
  for i in 0..<8192 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test zlib roundtrip with larger data (exercises unzlib_sync offset path)
test "inflt/offset/zlib_roundtrip_8kb" {
  let data = FixedArray::make(8192, b'\x00')
  for i in 0..<8192 {
    data[i] = (i % 256).to_byte()
  }
  let compressed = zlib_sync(data)
  let decompressed = unzlib_sync(compressed)
  assert_eq(decompressed.length(), 8192)
  for i in 0..<8192 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test zip roundtrip (exercises unzip_sync offset path)
test "inflt/offset/zip_roundtrip" {
  let data = FixedArray::make(4096, b'\x00')
  for i in 0..<4096 {
    data[i] = (i % 256).to_byte()
  }
  let zipped = zip_sync([("test.bin", data)])
  let entries = unzip_sync(zipped)
  assert_eq(entries.length(), 1)
  let (name, result) = entries[0]
  assert_eq(name, "test.bin")
  assert_eq(result.length(), 4096)
  for i in 0..<4096 {
    assert_eq(result[i], data[i])
  }
}

///|
test "inflt/tuple_return/no_buf" {
  // Without pre-allocated buffer, inflt returns oversized buf with valid len
  let data = FixedArray::make(300, b'\x00')
  for i in 0..<300 {
    data[i] = (i % 64).to_byte()
  }
  let compressed = deflate_sync(data)
  let (buf, len) = inflt(compressed, InflateState::new(2), None, None)
  assert_eq(len, 300)
  // buf may be larger than len (over-allocated)
  assert_true(buf.length() >= len)
  for i in 0..<300 {
    assert_eq(buf[i], data[i])
  }
}

///|
test "inflt/tuple_return/exact_buf" {
  // With exact-size buffer, len should equal buf.length()
  let data = FixedArray::make(256, b'\x00')
  for i in 0..<256 {
    data[i] = (i % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  let out = FixedArray::make(256, b'\x00')
  let (buf, len) = inflt(compressed, InflateState::new(2), Some(out), None)
  assert_eq(len, 256)
  assert_eq(buf.length(), 256)
  for i in 0..<256 {
    assert_eq(buf[i], data[i])
  }
}

///|
test "inflt/tuple_return/oversized_buf" {
  // With oversized buffer, len < buf.length()
  let data = FixedArray::make(100, b'\x00')
  for i in 0..<100 {
    data[i] = (i % 50).to_byte()
  }
  let compressed = deflate_sync(data)
  let out = FixedArray::make(500, b'\x00')
  let (buf, len) = inflt(compressed, InflateState::new(2), Some(out), None)
  assert_eq(len, 100)
  assert_eq(buf.length(), 500)
  for i in 0..<100 {
    assert_eq(buf[i], data[i])
  }
}
