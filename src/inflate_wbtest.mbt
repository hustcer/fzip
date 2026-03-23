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
    default_max_input_size,
    default_max_input_size,
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
    default_max_input_size,
    default_max_input_size,
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
  let (buf, len) = inflt(
    compressed,
    InflateState::new(2),
    None,
    None,
    default_max_input_size,
    default_max_input_size,
  )
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
  let (buf, len) = inflt(
    compressed,
    InflateState::new(2),
    Some(out),
    None,
    default_max_input_size,
    default_max_input_size,
  )
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
  let (buf, len) = inflt(
    compressed,
    InflateState::new(2),
    Some(out),
    None,
    default_max_input_size,
    default_max_input_size,
  )
  assert_eq(len, 100)
  assert_eq(buf.length(), 500)
  for i in 0..<100 {
    assert_eq(buf[i], data[i])
  }
}

///|
test "inflate - corrupted data error" {
  // Test error handling with corrupted data
  let corrupted = FixedArray::make(10, b'\xff')
  let result = try? inflate_sync(corrupted)
  assert_true(result is Err(_))
}

///|
test "inflate - truncated data error" {
  // Test error handling with truncated compressed data
  let data = FixedArray::make(100, b'x')
  let compressed = deflate_sync(data)
  // Take only first half of compressed data
  let truncated = slc(compressed, 0, e=compressed.length() / 2)
  let result = try? inflate_sync(truncated)
  assert_true(result is Err(_))
}

///|
test "inflate - custom max_output_size limit" {
  // Test that max_output_size is enforced
  let data = FixedArray::make(1000, b'A')
  let compressed = deflate_sync(data)
  // Set max_output_size to 500 bytes (less than actual output)
  let result = try? inflate_sync(compressed, opts={
    out: None,
    dictionary: None,
    max_output_size: 500,
    max_input_size: default_max_input_size,
  })
  assert_true(result is Err(_))
}

///|
test "inflate - custom max_input_size limit" {
  // Test that max_input_size is enforced
  // Use larger data to ensure compressed size exceeds limit
  let data = FixedArray::make(10000, b'B')
  for i in 0..<10000 {
    data[i] = (i % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  // Set max_input_size smaller than compressed size
  let result = try? inflate_sync(compressed, opts={
    out: None,
    dictionary: None,
    max_output_size: default_max_output_size,
    max_input_size: 100,
  })
  assert_true(result is Err(_))
}

///|
test "inflate - large limits allow decompression" {
  // Test that setting large limits allows normal decompression
  let data = FixedArray::make(5000, b'C')
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed, opts={
    out: None,
    dictionary: None,
    max_output_size: 10000,
    max_input_size: 10000,
  })
  assert_eq(decompressed.length(), 5000)
  for i in 0..<5000 {
    assert_eq(decompressed[i], b'C')
  }
}

///|
/// Test bit buffer with stored block (BTYPE=0) - verifies byte-alignment
/// and bit buffer reset logic when switching from compressed to stored blocks
test "inflt/bitbuf/stored_block" {
  // level=0 forces stored blocks, testing the bit buffer reset path
  let data = FixedArray::make(200, b'\x00')
  for i in 0..<200 {
    data[i] = (i % 256).to_byte()
  }
  let compressed = deflate_sync(data, opts={
    level: 0,
    mem: 0,
    dictionary: None,
  })
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 200)
  for i in 0..<200 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test bit buffer with fixed Huffman (BTYPE=1) - the most common fast path
/// where lbt=9, dbt=5 and the fill-peek-consume loop runs tightest
test "inflt/bitbuf/fixed_huffman" {
  // Small data with moderate repetition triggers fixed Huffman encoding
  let data = FixedArray::make(64, b'\x00')
  for i in 0..<64 {
    data[i] = (i % 16).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 64)
  for i in 0..<64 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test bit buffer with dynamic Huffman (BTYPE=2) - exercises the 14-bit
/// header read (HLIT+HDIST+HCLEN) and code length tree parsing
test "inflt/bitbuf/dynamic_huffman" {
  // Larger data with varied byte distribution triggers dynamic Huffman
  let data = FixedArray::make(4096, b'\x00')
  for i in 0..<4096 {
    data[i] = ((i * 7 + 13) % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 4096)
  for i in 0..<4096 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test bit buffer with heavy back-references (RLE-like data)
/// Exercises extra length bits and distance bits fill paths
test "inflt/bitbuf/long_backrefs" {
  // Repeating 4-byte pattern creates long back-references
  let data = FixedArray::make(2048, b'\x00')
  for i in 0..<2048 {
    data[i] = [b'\xDE', b'\xAD', b'\xBE', b'\xEF'][i % 4]
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 2048)
  for i in 0..<2048 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test bit buffer with non-byte-aligned initial position via gzip
/// (gzip header is 10 bytes, so dat_off=10 → init_pos is byte-aligned,
/// but this verifies the offset calculation path)
test "inflt/bitbuf/gzip_offset_init" {
  let data = FixedArray::make(512, b'\x00')
  for i in 0..<512 {
    data[i] = (i % 200).to_byte()
  }
  let gz = gzip_sync(data)
  let result = gunzip_sync(gz)
  assert_eq(result.length(), 512)
  for i in 0..<512 {
    assert_eq(result[i], data[i])
  }
}

///|
/// Test bit buffer handles all-same-byte data (extreme RLE)
/// This maximizes back-reference usage and tests the distance=1 hot path
test "inflt/bitbuf/rle_single_byte" {
  let data = FixedArray::make(8192, b'\x42')
  let compressed = deflate_sync(data)
  // Extreme RLE should compress very well
  assert_true(compressed.length() < 100)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 8192)
  for i in 0..<8192 {
    assert_eq(decompressed[i], b'\x42')
  }
}

///|
/// Test bit buffer with mixed content: text-like + binary + repetition
/// Exercises varied symbol distributions in the Huffman decode loop
test "inflt/bitbuf/mixed_content" {
  let data = FixedArray::make(3000, b'\x00')
  // First 1000: ASCII text-like
  for i in 0..<1000 {
    data[i] = (65 + i % 26).to_byte() // A-Z repeating
  }
  // Next 1000: binary pattern
  for i in 1000..<2000 {
    data[i] = ((i * 31 + 17) % 256).to_byte()
  }
  // Last 1000: highly repetitive
  for i in 2000..<3000 {
    data[i] = (i % 4).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 3000)
  for i in 0..<3000 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test back-reference copy: RLE path (dt_val==1)
/// All-zeros data produces long runs decoded via buf.fill()
test "inflt/backref/rle_zeros_16k" {
  let data = FixedArray::make(16384, b'\x00')
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 16384)
  for i in 0..<16384 {
    assert_eq(decompressed[i], b'\x00')
  }
}

///|
/// Test back-reference copy: RLE path with non-zero byte
/// Repeated 0xFF triggers the same dt_val==1 fill path
test "inflt/backref/rle_0xff" {
  let data = FixedArray::make(4096, b'\xFF')
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 4096)
  for i in 0..<4096 {
    assert_eq(decompressed[i], b'\xFF')
  }
}

///|
/// Test back-reference copy: overlapping doubling (dt_val==2)
/// Alternating 2-byte pattern AB AB AB... triggers dt_val=2 with add >> 2
test "inflt/backref/overlap_2byte_pattern" {
  let data = FixedArray::make(4096, b'\x00')
  for i in 0..<4096 {
    data[i] = [b'\xAA', b'\x55'][i % 2]
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 4096)
  for i in 0..<4096 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test back-reference copy: overlapping doubling (dt_val==3)
/// Repeating 3-byte pattern ABC exercises the doubling loop with non-power-of-2 stride
test "inflt/backref/overlap_3byte_pattern" {
  let data = FixedArray::make(6000, b'\x00')
  for i in 0..<6000 {
    data[i] = [b'\x01', b'\x02', b'\x03'][i % 3]
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 6000)
  for i in 0..<6000 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test back-reference copy: overlapping doubling (dt_val==4)
/// 4-byte repeating pattern DEADBEEF exercises doubling with power-of-2 stride
test "inflt/backref/overlap_4byte_pattern" {
  let data = FixedArray::make(8192, b'\x00')
  for i in 0..<8192 {
    data[i] = [b'\xDE', b'\xAD', b'\xBE', b'\xEF'][i % 4]
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 8192)
  for i in 0..<8192 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test back-reference copy: non-overlapping path (dt_val >= add)
/// Data with short repeated fragments separated by unique bytes creates
/// back-references where distance >= match length (non-overlapping blit_to)
test "inflt/backref/non_overlapping" {
  let data = FixedArray::make(4096, b'\x00')
  // Blocks of 32 unique bytes followed by 4 repeated bytes from far back
  for i in 0..<4096 {
    let block = i / 36
    let pos = i % 36
    if pos < 32 {
      // Unique section: use block number + position for variety
      data[i] = ((block * 7 + pos * 3 + 11) % 256).to_byte()
    } else {
      // Short repeat of earlier bytes at distance >> match length
      data[i] = data[block * 36 + pos - 32]
    }
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 4096)
  for i in 0..<4096 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test back-reference copy: mixed RLE + pattern + non-overlapping in one stream
/// Exercises all three backref paths within a single decompression call
test "inflt/backref/mixed_paths" {
  let data = FixedArray::make(12000, b'\x00')
  // Section 1 (0-3999): RLE run → dt_val==1 path
  for i in 0..<4000 {
    data[i] = b'\x42'
  }
  // Section 2 (4000-7999): 5-byte repeating pattern → overlapping doubling
  for i in 4000..<8000 {
    data[i] = [b'\x10', b'\x20', b'\x30', b'\x40', b'\x50'][(i - 4000) % 5]
  }
  // Section 3 (8000-11999): varied data with scattered short matches
  for i in 8000..<12000 {
    data[i] = ((i * 13 + 7) % 256).to_byte()
  }
  let compressed = deflate_sync(data)
  let decompressed = inflate_sync(compressed)
  assert_eq(decompressed.length(), 12000)
  for i in 0..<12000 {
    assert_eq(decompressed[i], data[i])
  }
}

///|
/// Test back-reference via gzip roundtrip (exercises backref paths through wrapper)
test "inflt/backref/gzip_rle_pattern" {
  let data = FixedArray::make(10000, b'\x00')
  // Alternating RLE and pattern sections
  for i in 0..<5000 {
    data[i] = b'\x77' // RLE section
  }
  for i in 5000..<10000 {
    data[i] = [b'\x0A', b'\x0B', b'\x0C'][i % 3] // 3-byte pattern
  }
  let gz = gzip_sync(data)
  let result = gunzip_sync(gz)
  assert_eq(result.length(), 10000)
  for i in 0..<10000 {
    assert_eq(result[i], data[i])
  }
}
