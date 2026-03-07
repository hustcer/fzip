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
  // len=1 → log_val stays 8, plvl = (8*3+1)/2 = 12
  assert_eq(compute_mem_level(1), 12)
  // len=256 → log_val stays 8 (while loop: 256 not > 256)
  assert_eq(compute_mem_level(256), 12)
}

///|
test "compute_mem_level - medium inputs" {
  // len=257 → one iteration: v=128, log_val=9, plvl = (9*3+1)/2 = 14
  assert_eq(compute_mem_level(257), 14)
  // len=512 → one iteration: v=256, log_val=9
  assert_eq(compute_mem_level(512), 14)
  // len=513 → v=256, log_val=9 (256 not > 256, loop exits), plvl=14
  assert_eq(compute_mem_level(513), 14)
  // len=514 → v=257→128, log_val=10, breaks at >=10, plvl=15
  assert_eq(compute_mem_level(514), 15)
  // len=1024 → v=512→256, log_val=10, breaks at >=10
  assert_eq(compute_mem_level(1024), 15)
}

///|
test "compute_mem_level - large inputs capped at 15" {
  // 2KB+ all cap at plvl=15 due to log_val >= 10 break
  assert_eq(compute_mem_level(2048), 15)
  assert_eq(compute_mem_level(4096), 15)
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
