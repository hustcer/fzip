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

///|
test "compute_mem_level - small inputs" {
  // len < 2048 → returns 10 (optimized for small data)
  assert_eq(compute_mem_level(1), 10)
  assert_eq(compute_mem_level(256), 10)
  assert_eq(compute_mem_level(1024), 10)
  assert_eq(compute_mem_level(2047), 10)
}

///|
test "compute_mem_level - medium inputs" {
  // 2048 <= len < 8192 → returns 12
  assert_eq(compute_mem_level(2048), 12)
  assert_eq(compute_mem_level(4096), 12)
  assert_eq(compute_mem_level(8191), 12)
}

///|
test "compute_mem_level - large inputs capped at 15" {
  // len >= 8192 → original algorithm, caps at 15
  assert_eq(compute_mem_level(8192), 15)
  assert_eq(compute_mem_level(65536), 15)
  assert_eq(compute_mem_level(100000), 15)
  assert_eq(compute_mem_level(1000000), 15)
}

///|
test "deflate/inflate roundtrip - 100KB zeros" {
  let size = 100000
  let data : FixedArray[Byte] = FixedArray::make(size, b'\x00')
  let compressed = deflate_sync(data)
  assert_true(compressed.length() < size)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "deflate/inflate roundtrip - 100KB sequential" {
  let size = 100000
  let data : FixedArray[Byte] = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  assert_true(compressed.length() < size)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "deflate/inflate roundtrip - 100KB random" {
  let size = 100000
  let data : FixedArray[Byte] = FixedArray::make(size, b'\x00')
  // Pseudo-random using LCG
  let mut seed = 12345
  for i in 0..<size {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (seed % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "deflate/inflate roundtrip - multi-level 10KB" {
  let size = 10000
  let data : FixedArray[Byte] = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 128).to_byte()
  }
  let levels = [1, 3, 6, 9]
  for i in 0..<levels.length() {
    let compressed = deflate_sync(data, opts={
      level: levels[i],
      mem: 0,
      dictionary: None,
    })
    let decompressed = inflate_sync(compressed)
    assert_eq(decompressed.length(), size)
    for j in 0..<size {
      assert_eq(decompressed[j], data[j])
    }
  }
}

///|
test "deflate/inflate roundtrip - manual mem option" {
  let size = 5000
  let data : FixedArray[Byte] = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 64).to_byte()
  }
  // mem=4 → plvl = 12 + 4 = 16, bypasses compute_mem_level
  let compressed = deflate_sync(data, opts={
    level: 6,
    mem: 4,
    dictionary: None,
  })
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "dflt/dopt returns (buf, len) with len < buf.length()" {
  let data : FixedArray[Byte] = FixedArray::make(500, b'\x00')
  for i in 0..<500 {
    data[i] = (i % 50).to_byte()
  }
  let (buf, len) = dopt(
    data,
    { level: 6, mem: 0, dictionary: None },
    0,
    0,
    None,
  )
  // len should be less than buf.length() (over-allocated output buffer)
  assert_true(len <= buf.length())
  assert_true(len > 0)
  // slc at boundary should produce valid compressed data
  let compressed = slc(buf, 0, e=len)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 500)
  for i in 0..<500 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "dflt/dopt with pre/post returns correct len" {
  let data : FixedArray[Byte] = FixedArray::make(200, b'\x00')
  for i in 0..<200 {
    data[i] = (i % 26 + 65).to_byte()
  }
  let pre = 10
  let post = 8
  let (buf, len) = dopt(
    data,
    { level: 6, mem: 0, dictionary: None },
    pre,
    post,
    None,
  )
  assert_true(len <= buf.length())
  assert_true(len > pre + post)
  // The compressed DEFLATE data starts at offset `pre` and ends at `len - post`
  // Extract just the DEFLATE portion and verify decompression
  let deflate_data = slc(buf, pre, e=len - post)
  let decompressed = inflate_sync(deflate_data)
  assert_eq(decompressed.length(), 200)
  for i in 0..<200 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "zip_sync/unzip_sync multi-file roundtrip after slc optimization" {
  let files : Array[(String, FixedArray[Byte])] = []
  for k in 0..<5 {
    let size = (k + 1) * 200
    let data = FixedArray::make(size, b'\x00')
    for i in 0..<size {
      data[i] = ((i + k * 7) % 256).to_byte()
    }
    files.push(("file" + k.to_string() + ".bin", data))
  }
  let zipped = zip_sync(files)
  let entries = unzip_sync(zipped)
  assert_eq(entries.length(), 5)
  for k in 0..<5 {
    let (name, result) = entries[k]
    let (expected_name, expected_data) = files[k]
    assert_eq(name, expected_name)
    assert_eq(result.length(), expected_data.length())
    for i in 0..<expected_data.length() {
      assert_eq(result[i], expected_data[i])
    }
  }
}

///|
test "perf opt - buffer allocation boundaries" {
  let sizes = [256, 512, 1024, 4096, 8192, 16384, 32768]
  for i in 0..<sizes.length() {
    let size = sizes[i]
    let data = FixedArray::make(size, b'\x00')
    for j in 0..<size {
      data[j] = (j % 256).to_byte()
    }
    let compressed = deflate_sync(data)
    let decompressed = inflate_sync(compressed)
    assert_eq(decompressed.length(), size)
  }
}

///|
test "perf opt - small data compression" {
  let sizes = [100, 256, 512, 1024]
  for i in 0..<sizes.length() {
    let size = sizes[i]
    let data = FixedArray::make(size, b'\x00')
    for j in 0..<size {
      data[j] = ((j * 7 + 13) % 256).to_byte()
    }
    let compressed = deflate_sync(data)
    let decompressed = inflate_sync(compressed)
    assert_eq(decompressed.length(), size)
    for j in 0..<size {
      assert_eq(decompressed[j], data[j])
    }
  }
}

///|
test "perf opt - random data correctness" {
  let size = 10000
  let data = FixedArray::make(size, b'\x00')
  let mut seed = 54321
  for i in 0..<size {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (seed % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "fast incompressible detection - random data" {
  let size = 10000
  let data = FixedArray::make(size, b'\x00')
  let mut seed = 99999
  for i in 0..<size {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (seed % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "fast incompressible detection - threshold 512" {
  let sizes = [256, 512, 1024]
  for i in 0..<sizes.length() {
    let size = sizes[i]
    let data = FixedArray::make(size, b'\x00')
    let mut seed = 11111
    for j in 0..<size {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      data[j] = (seed % 256).to_byte()
    }
    let compressed = deflate_sync(data)
    let decompressed = inflate_sync(compressed)
    assert_eq(decompressed.length(), size)
  }
}

///|
test "deflate array pool reuse" {
  let initial_pool_len = dflt_head_pool.length()
  let data1 = FixedArray::make(100, b'\x42')
  let _ = deflate_sync(data1)
  let pool_len_1 = dflt_head_pool.length()
  assert_true(pool_len_1 > initial_pool_len || pool_len_1 == initial_pool_len)

  let data2 = FixedArray::make(200, b'\x43')
  let _ = deflate_sync(data2)
  let pool_len_2 = dflt_head_pool.length()
  // Since it reuses arrays, length should be stable
  assert_true(pool_len_2 == pool_len_1)
}

///|
test "deflate pool correctness - multiple compressions" {
  // Verify that pool reuse doesn't cause data corruption
  let data1 = FixedArray::make(500, b'\x41')
  let compressed1 = deflate_sync(data1)
  let decompressed1 = inflate_sync(compressed1)
  assert_eq(decompressed1.length(), 500)
  for i in 0..<500 {
    assert_eq(decompressed1[i], b'\x41')
  }

  let data2 = FixedArray::make(300, b'\x42')
  let compressed2 = deflate_sync(data2)
  let decompressed2 = inflate_sync(compressed2)
  assert_eq(decompressed2.length(), 300)
  for i in 0..<300 {
    assert_eq(decompressed2[i], b'\x42')
  }

  // Third compression with different pattern
  let data3 : FixedArray[Byte] = FixedArray::make(400, b'\x00')
  for i in 0..<400 {
    data3[i] = (i % 256).to_byte()
  }
  let compressed3 = deflate_sync(data3)
  let decompressed3 = inflate_sync(compressed3)
  assert_eq(decompressed3.length(), 400)
  for i in 0..<400 {
    assert_eq(decompressed3[i], (i % 256).to_byte())
  }
}

///|
test "deflate - very small data" {
  // Test data < 256 bytes to trigger edge cases in compute_mem_level
  let tiny = FixedArray::make(100, b'x')
  let compressed = deflate_sync(tiny)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 100)
  for i in 0..<100 {
    assert_eq(decompressed[i], b'x')
  }
}

///|
test "deflate - extremely small data" {
  // Test data < 50 bytes
  let micro = FixedArray::make(20, b'a')
  let compressed = deflate_sync(micro)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 20)
}
