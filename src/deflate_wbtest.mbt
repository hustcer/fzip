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

///|
test "deflate with dictionary" {
  let dict : FixedArray[Byte] = [1, 2, 3, 4, 5]
  let data : FixedArray[Byte] = [3, 4, 5, 6, 7]
  let compressed = deflate_sync(data, opts={
    level: 6,
    mem: 0,
    dictionary: Some(dict),
  })
  let decompressed = inflate_sync(compressed, opts={
    out: None,
    dictionary: Some(dict),
    max_output_size: default_max_output_size,
    max_input_size: default_max_input_size,
  })
  assert_eq(decompressed.length(), 5)
  for i in 0..<5 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "adaptive chain depth - high entropy triggers low chain depth" {
  // Large random data triggers >100 hash searches with low success rate,
  // exercising the success_100 < total_searches * 5 branch (chain depth = c/4)
  let size = 50000
  let data = FixedArray::make(size, b'\x00')
  let mut seed = 77777
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
test "adaptive chain depth - repetitive data triggers high chain depth" {
  // Highly repetitive data has high match success rate,
  // exercising the full chain depth c (success_100 >= total_searches * 20)
  let size = 50000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 16).to_byte()
  }
  let compressed = deflate_sync(data)
  assert_true(compressed.length() < size / 2)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "match loop unrolling - long identical runs" {
  // Long runs of identical bytes produce max-length matches (258),
  // heavily exercising the 4-byte unrolled match loop
  let size = 10000
  let data = FixedArray::make(size, b'\xAA')
  let compressed = deflate_sync(data)
  assert_true(compressed.length() < size / 10)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "match loop unrolling - 4-byte repeating pattern" {
  // Repeating 4-byte units produce match lengths that are exact multiples of 4,
  // so the unrolled loop handles them entirely without byte-by-byte fallback
  let size = 8000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    let phase = i % 4
    data[i] = if phase == 0 {
      b'\x10'
    } else if phase == 1 {
      b'\x20'
    } else if phase == 2 {
      b'\x30'
    } else {
      b'\x40'
    }
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
test "match loop unrolling - 5-byte repeating pattern" {
  // 5-byte units produce match lengths not divisible by 4 (5, 10, 15...),
  // testing the transition from unrolled loop to byte-by-byte remainder
  let size = 8000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 5 + 1).to_byte()
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
test "match loop unrolling - 3-byte repeating pattern" {
  // 3-byte match lengths: too short for 4-byte unrolled loop,
  // ensuring the byte-by-byte fallback handles short matches correctly
  let size = 6000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 3 + 0x61).to_byte() // 'a', 'b', 'c' repeating
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
test "match loop unrolling - mixed match lengths" {
  // Alternating between long matches (repetitive) and short matches (varied),
  // exercises both the unrolled loop and the byte-by-byte fallback
  let size = 10000
  let data = FixedArray::make(size, b'\x00')
  let mut seed = 42
  for i in 0..<size {
    if i % 500 < 400 {
      // Long repetitive region: triggers long matches via unrolled loop
      data[i] = (i % 7).to_byte()
    } else {
      // Short varied region: triggers short or no matches
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      data[i] = (seed % 256).to_byte()
    }
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "adaptive chain depth - mixed data exercises medium chain depth" {
  // Data mixing compressible and random regions triggers medium success rate,
  // exercising the success_100 < total_searches * 20 branch (chain depth = c/2)
  let size = 50000
  let data = FixedArray::make(size, b'\x00')
  let mut seed = 33333
  for i in 0..<size {
    if i % 200 < 100 {
      // Compressible region: repetitive pattern
      data[i] = (i % 8).to_byte()
    } else {
      // Random region
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      data[i] = (seed % 256).to_byte()
    }
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "lazy hash skip - long matches skip hash insertion" {
  // Data with long repetitive regions (match length > 16) triggers lazy hash skip.
  let size = 20000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i / 100 % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  assert_true(compressed.length() < size / 2)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "lazy hash skip - very long identical runs" {
  // Worst case: entire buffer is one byte repeated, all matches max length (258).
  let size = 30000
  let data = FixedArray::make(size, b'\x55')
  let compressed = deflate_sync(data)
  assert_true(compressed.length() < size / 10)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "lazy hash skip - alternating compressible and random regions" {
  // Mixed data: 100 bytes compressible, 100 bytes random.
  // Exercises lazy skip in compressible regions and normal matching in random.
  let size = 50000
  let data = FixedArray::make(size, b'\x00')
  let mut seed = 44444
  for i in 0..<size {
    if i % 200 < 100 {
      data[i] = (i % 8).to_byte()
    } else {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      data[i] = (seed % 256).to_byte()
    }
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "lazy hash skip - short matches below threshold not skipped" {
  // Short matches (< 16 bytes) should not trigger skip.
  let size = 10000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 10 + 0x30).to_byte()
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
test "lazy hash skip - near end of data guard" {
  // Long matches near the end, rem > 500 guard prevents skipping.
  let size = 2000
  let data = FixedArray::make(size, b'\x00')
  let mut seed = 12345
  for i in 0..<1500 {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (seed % 64).to_byte()
  }
  for i in 1500..<size {
    data[i] = (i % 4).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "higher compression levels produce better ratios" {
  let size = 50000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 128).to_byte()
  }
  let c1 = deflate_sync(data, opts={ level: 1, mem: 0, dictionary: None })
  let c6 = deflate_sync(data, opts={ level: 6, mem: 0, dictionary: None })
  let c9 = deflate_sync(data, opts={ level: 9, mem: 0, dictionary: None })
  assert_true(c6.length() <= c1.length())
  assert_true(c9.length() <= c6.length())
}

///|
test "is_compressible - random 1K detected as incompressible" {
  // LCG random data: high byte diversity, no periodicity
  let data = FixedArray::make(1024, b'\x00')
  let mut s = 42
  for i in 0..<1024 {
    s = (s * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (s >> 16).to_byte()
  }
  assert_false(is_compressible(data, 0, 1024))
}

///|
test "is_compressible - sequential 1K detected as compressible" {
  // Sequential data: 256 unique values but perfect periodicity at distance 256
  let data = FixedArray::make(1024, b'\x00')
  for i in 0..<1024 {
    data[i] = (i % 256).to_byte()
  }
  assert_true(is_compressible(data, 0, 1024))
}

///|
test "is_compressible - zeros always compressible" {
  let data = FixedArray::make(1024, b'\x00')
  assert_true(is_compressible(data, 0, 1024))
}

///|
test "is_compressible - small data always compressible" {
  // Data < 128 bytes always returns true
  let data = FixedArray::make(100, b'\x00')
  let mut s = 99
  for i in 0..<100 {
    s = (s * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (s >> 16).to_byte()
  }
  assert_true(is_compressible(data, 0, 100))
}

///|
test "is_compressible - random data roundtrip correctness" {
  // Even when detected as incompressible, deflate_sync must still produce
  // valid output (stored blocks) that decompresses correctly
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
test "is_compressible - skewed distribution with high diversity" {
  // 241 unique values but one byte dominates (50%) → still compressible
  let data = FixedArray::make(1024, b'\x41')
  for i in 0..<512 {
    data[i] = (i % 241).to_byte()
  }
  // unique_count > 240, but max_freq > 1024/32 → compressible
  assert_true(is_compressible(data, 0, 1024))
}

///|
test "is_compressible - 4K random data detected as incompressible" {
  // Tests the extended scan range (< 8192)
  let data = FixedArray::make(4096, b'\x00')
  let mut s = 12345
  for i in 0..<4096 {
    s = (s * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (s >> 16).to_byte()
  }
  assert_false(is_compressible(data, 0, 4096))
}

///|
test "is_compressible - 4K random data roundtrip correctness" {
  let data = FixedArray::make(4096, b'\x00')
  let mut s = 12345
  for i in 0..<4096 {
    s = (s * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (s >> 16).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 4096)
  for i in 0..<4096 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "ensure_out - no-op when buffer is large enough" {
  let buf = FixedArray::make(100, b'\x42')
  let result = ensure_out(buf, 50)
  // Should return the same buffer (no reallocation)
  assert_eq(result.length(), 100)
  assert_eq(result[0], b'\x42')
  assert_eq(result[99], b'\x42')
}

///|
test "ensure_out - no-op at exact boundary" {
  let buf = FixedArray::make(100, b'\x42')
  let result = ensure_out(buf, 100)
  assert_eq(result.length(), 100)
  assert_eq(result[0], b'\x42')
}

///|
test "ensure_out - grows with doubling when need is small" {
  let buf = FixedArray::make(100, b'\x42')
  // need=101 > 100, but 100*2=200 > 101, so new_size = 200
  let result = ensure_out(buf, 101)
  assert_eq(result.length(), 200)
  // Original data preserved
  assert_eq(result[0], b'\x42')
  assert_eq(result[99], b'\x42')
  // New area zero-initialized
  assert_eq(result[100], b'\x00')
}

///|
test "ensure_out - grows to exact need when doubling is insufficient" {
  let buf = FixedArray::make(100, b'\x42')
  // need=300 > 100*2=200, so new_size = 300
  let result = ensure_out(buf, 300)
  assert_eq(result.length(), 300)
  assert_eq(result[0], b'\x42')
  assert_eq(result[99], b'\x42')
  assert_eq(result[100], b'\x00')
}

///|
test "ensure_out - preserves all original content" {
  let buf = FixedArray::make(50, b'\x00')
  for i in 0..<50 {
    buf[i] = (i + 1).to_byte()
  }
  let result = ensure_out(buf, 80)
  for i in 0..<50 {
    assert_eq(result[i], (i + 1).to_byte())
  }
}

///|
test "out_capacity_need - computes normal capacity correctly" {
  assert_eq(out_capacity_need(10, 17, 99, 8), 128)
}

///|
test "out_capacity_need - saturates on large inputs" {
  let max_i = max_int_val()
  assert_eq(out_capacity_need(max_i - 4, 8, 32, 16), max_i)
}

///|
test "grown_out_capacity - doubles when safe" {
  assert_eq(grown_out_capacity(100, 101), 200)
  assert_eq(grown_out_capacity(100, 300), 300)
}

///|
test "grown_out_capacity - avoids doubling overflow" {
  let max_i = max_int_val()
  assert_eq(grown_out_capacity(max_i / 2 + 1, max_i - 16), max_i)
}

///|
test "reduced initial allocation - lvl>0 s>512 uses smaller buffer" {
  // Verify that the (buf, len) returned by dopt has a tighter fit
  // when compression ratio is good
  let size = 10000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 16).to_byte() // highly compressible
  }
  let (buf, len) = dopt(
    data,
    { level: 6, mem: 0, dictionary: None },
    0,
    0,
    None,
  )
  // With reduced allocation, initial buffer should be roughly s/2 + overhead
  // rather than s + overhead. For highly compressible data, len << buf.length()
  assert_true(len > 0)
  assert_true(len <= buf.length())
  // Verify the output is valid
  let compressed = trim_buf(buf, len)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "ensure_out triggered - data that expands beyond initial estimate" {
  // Low-compressibility data with lvl>0 may need ensure_out to grow buffer
  // since initial allocation is s/2 + 128 + headers
  let size = 2000
  let data = FixedArray::make(size, b'\x00')
  let mut seed = 55555
  for i in 0..<size {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (seed % 200).to_byte() // high but not full entropy
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "multi-block compression triggers ensure_out correctly" {
  // Large data producing multiple DEFLATE blocks exercises the
  // intermediate wblk ensure_out path (lc > 7000 || li > 24576)
  let size = 200000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 128).to_byte()
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
test "level 0 path unaffected by reduced allocation" {
  // Level 0 (stored blocks) should use full-size allocation, not reduced
  let size = 1000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 256).to_byte()
  }
  let compressed = deflate_sync(data, opts={
    level: 0,
    mem: 0,
    dictionary: None,
  })
  // Stored blocks expand: compressed > data
  assert_true(compressed.length() >= size)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "gzip roundtrip with reduced dflt allocation" {
  // GZIP uses dflt() internally via dopt(); verify it works with reduced allocation
  let size = 50000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 64).to_byte()
  }
  let compressed = gzip_sync(data)
  let decompressed = gunzip_sync(compressed)
  assert_eq(decompressed.length(), size)
  for i in 0..<size {
    assert_eq(decompressed[i], data[i])
  }
}

///|
test "checksum fusion - dopt fused CRC matches separate crc32" {
  let size = 5000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 128).to_byte()
  }
  let crc_st = CRC32State::new()
  let _ = dopt(
    data,
    { level: 6, mem: 0, dictionary: None },
    0,
    0,
    None,
    crc_state=Some(crc_st),
  )
  let fused_crc = crc_st.digest()
  let separate_crc = crc32(data)
  assert_eq(fused_crc, separate_crc)
}

///|
test "checksum fusion - dopt fused Adler matches separate adler32" {
  let size = 5000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 128).to_byte()
  }
  let adler_st = AdlerState::new()
  let _ = dopt(
    data,
    { level: 6, mem: 0, dictionary: None },
    0,
    0,
    None,
    adler_state=Some(adler_st),
  )
  let fused_adler = adler_st.digest()
  let separate_adler = adler32(data)
  assert_eq(fused_adler, separate_adler)
}

///|
test "checksum fusion - multi-block fused CRC" {
  // Large data triggers multiple DEFLATE blocks (lc > 7000 || li > 24576),
  // exercising incremental CRC updates at block flush boundaries
  let size = 200000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 64).to_byte()
  }
  let crc_st = CRC32State::new()
  let _ = dopt(
    data,
    { level: 6, mem: 0, dictionary: None },
    0,
    0,
    None,
    crc_state=Some(crc_st),
  )
  assert_eq(crc_st.digest(), crc32(data))
}

///|
test "checksum fusion - incompressible data fused CRC" {
  // Random data triggers is_compressible() → false → stored blocks,
  // exercising the level-0 fallback checksum path in dflt()
  let size = 2000
  let data = FixedArray::make(size, b'\x00')
  let mut seed = 42
  for i in 0..<size {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (seed >> 16).to_byte()
  }
  let crc_st = CRC32State::new()
  let _ = dopt(
    data,
    { level: 6, mem: 0, dictionary: None },
    0,
    0,
    None,
    crc_state=Some(crc_st),
  )
  assert_eq(crc_st.digest(), crc32(data))
}

///|
test "checksum fusion - level 0 stored blocks fused CRC" {
  // Explicit level=0 bypasses LZ77, exercises the stored-block checksum path
  let size = 1000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 256).to_byte()
  }
  let crc_st = CRC32State::new()
  let _ = dopt(
    data,
    { level: 0, mem: 0, dictionary: None },
    0,
    0,
    None,
    crc_state=Some(crc_st),
  )
  assert_eq(crc_st.digest(), crc32(data))
}

///|
test "checksum fusion - dictionary excluded from fused CRC" {
  // With dictionary, checksum must cover only the user data, not dict prefix
  let dict : FixedArray[Byte] = FixedArray::make(100, b'\x00')
  for i in 0..<100 {
    dict[i] = (i * 3).to_byte()
  }
  let data : FixedArray[Byte] = FixedArray::make(500, b'\x00')
  for i in 0..<500 {
    data[i] = (i % 50).to_byte()
  }
  let crc_st = CRC32State::new()
  let _ = dopt(
    data,
    { level: 6, mem: 0, dictionary: Some(dict) },
    0,
    0,
    None,
    crc_state=Some(crc_st),
  )
  // Fused CRC should match CRC of user data only (not dict+data)
  assert_eq(crc_st.digest(), crc32(data))
}

///|
test "checksum fusion - empty data fused CRC" {
  let data : FixedArray[Byte] = FixedArray::make(0, b'\x00')
  let crc_st = CRC32State::new()
  let _ = dopt(
    data,
    { level: 6, mem: 0, dictionary: None },
    0,
    0,
    None,
    crc_state=Some(crc_st),
  )
  assert_eq(crc_st.digest(), crc32(data))
}

///|
test "zlib roundtrip with reduced dflt allocation" {
  let size = 50000
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
