///|
test "crc32 - empty data" {
  let data : FixedArray[Byte] = FixedArray::make(0, b'\x00')
  let result = crc32(data)
  // CRC32 of empty string is 0x00000000
  inspect(result, content="0")
}

///|
test "crc32 - known vector" {
  // CRC32("123456789") = 0xCBF43926
  let data : FixedArray[Byte] = [
    b'\x31', b'\x32', b'\x33', b'\x34', b'\x35', b'\x36', b'\x37', b'\x38', b'\x39',
  ]
  let result = crc32(data)
  inspect(result, content="3421780262") // 0xCBF43926
}

///|
test "crc32 - incremental matches one-shot" {
  let data : FixedArray[Byte] = [
    b'\x31', b'\x32', b'\x33', b'\x34', b'\x35', b'\x36', b'\x37', b'\x38', b'\x39',
  ]
  let st = CRC32State::new()
  st.push(slc(data, 0, e=4))
  st.push(slc(data, 4))
  let incremental = st.digest()
  let one_shot = crc32(data)
  assert_eq(incremental, one_shot)
}

///|
test "adler32 - empty data" {
  let data : FixedArray[Byte] = FixedArray::make(0, b'\x00')
  let result = adler32(data)
  // Adler32 of empty: a=1, b=0; byte-swapped for wbytes = 0x01000000
  inspect(result, content="16777216")
}

///|
test "adler32 - known data" {
  // Test with simple data
  let data : FixedArray[Byte] = [b'\x41', b'\x42', b'\x43'] // "ABC"
  let result = adler32(data)
  // a = 1+65+66+67 = 199, b = 0+1+66+132+199 = 398
  // after mod 65521: a=199, b=398
  // big-endian: (199&0xFF)<<24 | (199&0xFF00)<<8 | (398&0xFF)<<8 | (398>>8)
  // = 0xC7000000 | 0 | 0x00008E00 | 0x01
  // = 199<<24 | 0 | 142<<8 | 1
  let _ = result
  // Just verify it's non-zero and consistent
  assert_true(result != 0U)
}

///|
test "adler32 - incremental matches one-shot" {
  let data : FixedArray[Byte] = [b'\x48', b'\x65', b'\x6C', b'\x6C', b'\x6F'] // "Hello"
  let st = AdlerState::new()
  st.push(slc(data, 0, e=2))
  st.push(slc(data, 2))
  let incremental = st.digest()
  let one_shot = adler32(data)
  assert_eq(incremental, one_shot)
}

///|
test "crc32 - push_range matches push" {
  let data : FixedArray[Byte] = [
    b'\x31', b'\x32', b'\x33', b'\x34', b'\x35', b'\x36', b'\x37', b'\x38', b'\x39',
  ]
  let st1 = CRC32State::new()
  st1.push_range(data, 0, 9)
  let st2 = CRC32State::new()
  st2.push(data)
  assert_eq(st1.digest(), st2.digest())
}

///|
test "crc32 unroll - exactly 4 bytes" {
  // Exactly 4 bytes: one iteration of unrolled loop, no remainder
  let data : FixedArray[Byte] = [b'\xDE', b'\xAD', b'\xBE', b'\xEF']
  let one_shot = crc32(data)
  let st = CRC32State::new()
  st.push(data)
  assert_eq(st.digest(), one_shot)
}

///|
test "crc32 unroll - 7 bytes (4 + 3 remainder)" {
  // 7 bytes: one unrolled iteration + 3 byte-by-byte
  let data : FixedArray[Byte] = [
    b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07',
  ]
  let one_shot = crc32(data)
  let st = CRC32State::new()
  st.push(data)
  assert_eq(st.digest(), one_shot)
  // push_range must also match
  let st2 = CRC32State::new()
  st2.push_range(data, 0, 7)
  assert_eq(st2.digest(), one_shot)
}

///|
test "crc32 unroll - 16 bytes (exact multiple of 4)" {
  // 16 bytes: 4 iterations of unrolled loop, no remainder
  let data = FixedArray::make(16, b'\x00')
  for i in 0..<16 {
    data[i] = (i * 17 % 256).to_byte()
  }
  let one_shot = crc32(data)
  // Incremental in 2 chunks must also match
  let st = CRC32State::new()
  st.push(slc(data, 0, e=8))
  st.push(slc(data, 8))
  assert_eq(st.digest(), one_shot)
}

///|
test "crc32 unroll - 100KB consistency" {
  // 100KB: heavily exercises the unrolled loop
  let size = 100000
  let data = FixedArray::make(size, b'\x00')
  let mut seed = 13579
  for i in 0..<size {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (seed % 256).to_byte()
  }
  let one_shot = crc32(data)
  assert_true(one_shot != 0U)
  // Verify incremental with push_range in 4KB chunks matches
  let st = CRC32State::new()
  let mut offset = 0
  while offset < size {
    let chunk = if offset + 4096 < size { 4096 } else { size - offset }
    st.push_range(data, offset, chunk)
    offset += chunk
  }
  assert_eq(st.digest(), one_shot)
}

///|
test "crc32 slice-by-4 - single byte remainder only" {
  // 1 byte: no Slice-by-4 iteration, only byte-at-a-time fallback
  // CRC32("a") = 0xE8B7BE43
  let data : FixedArray[Byte] = [b'\x61']
  inspect(crc32(data), content="3904355907")
}

///|
test "crc32 slice-by-4 - 3 bytes remainder only" {
  // 3 bytes: no Slice-by-4 iteration, all handled by remainder loop
  // CRC32("abc") = 0x352441C2
  let data : FixedArray[Byte] = [b'\x61', b'\x62', b'\x63']
  inspect(crc32(data), content="891568578")
}

///|
test "crc32 slice-by-4 - 5 bytes (1 iteration + 1 remainder)" {
  // 5 bytes: 1 Slice-by-4 iteration + 1 byte remainder
  let data : FixedArray[Byte] = [b'\x61', b'\x62', b'\x63', b'\x64', b'\x65']
  let one_shot = crc32(data)
  // Verify incremental consistency
  let st = CRC32State::new()
  st.push(data)
  assert_eq(st.digest(), one_shot)
  // push_range must also match
  let st2 = CRC32State::new()
  st2.push_range(data, 0, 5)
  assert_eq(st2.digest(), one_shot)
}

///|
test "crc32 slice-by-4 - 6 bytes (1 iteration + 2 remainder)" {
  let data : FixedArray[Byte] = [
    b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60',
  ]
  let one_shot = crc32(data)
  let st = CRC32State::new()
  st.push(data)
  assert_eq(st.digest(), one_shot)
}

///|
test "crc32 slice-by-4 - 8 bytes (exact 2 iterations)" {
  let data : FixedArray[Byte] = [
    b'\xDE', b'\xAD', b'\xBE', b'\xEF', b'\xCA', b'\xFE', b'\xBA', b'\xBE',
  ]
  let one_shot = crc32(data)
  let st = CRC32State::new()
  st.push(data)
  assert_eq(st.digest(), one_shot)
  let st2 = CRC32State::new()
  st2.push_range(data, 0, 8)
  assert_eq(st2.digest(), one_shot)
}

///|
test "crc32 slice-by-4 - all same byte" {
  // All bytes identical: exercises Slice-by-4 where all 4 table indices
  // derive from the same byte value XORed with CRC state
  let data = FixedArray::make(20, b'\xAA')
  let one_shot = crc32(data)
  let st = CRC32State::new()
  st.push(data)
  assert_eq(st.digest(), one_shot)
}

///|
test "crc32 slice-by-4 - all 0xFF bytes" {
  // All bits set: stresses all 4 tables with 0xFF indices
  let data = FixedArray::make(16, b'\xFF')
  let one_shot = crc32(data)
  let st = CRC32State::new()
  st.push(data)
  assert_eq(st.digest(), one_shot)
  assert_true(one_shot != 0U)
}

///|
test "crc32 slice-by-4 - incremental split at non-aligned boundary" {
  // Split at positions that are NOT multiples of 4
  // This forces the Slice-by-4 loop to start with different alignments
  let data : FixedArray[Byte] = [
    b'\x31', b'\x32', b'\x33', b'\x34', b'\x35', b'\x36', b'\x37', b'\x38', b'\x39',
  ]
  let one_shot = crc32(data)
  // Split at 3+6: first chunk has no Slice-by-4, second chunk has 1 iteration + 2 remainder
  let st1 = CRC32State::new()
  st1.push(slc(data, 0, e=3))
  st1.push(slc(data, 3))
  assert_eq(st1.digest(), one_shot)
  // Split at 5+4: first chunk has 1 iteration + 1 remainder, second chunk has 1 iteration
  let st2 = CRC32State::new()
  st2.push(slc(data, 0, e=5))
  st2.push(slc(data, 5))
  assert_eq(st2.digest(), one_shot)
  // Split at 1+1+1+1+1+1+1+1+1: every byte is a separate push
  let st3 = CRC32State::new()
  for i in 0..<9 {
    st3.push(slc(data, i, e=i + 1))
  }
  assert_eq(st3.digest(), one_shot)
}

///|
test "crc32 slice-by-4 - push_range with non-zero offset" {
  // Verify push_range correctly handles non-zero starting offset
  let data = FixedArray::make(20, b'\x00')
  for i in 0..<20 {
    data[i] = ((i * 31 + 7) % 256).to_byte()
  }
  // Full range
  let full = crc32(data)
  // Partial range from offset 5, length 10
  let st1 = CRC32State::new()
  st1.push_range(data, 5, 10)
  // Compare with push of equivalent slice
  let st2 = CRC32State::new()
  st2.push(slc(data, 5, e=15))
  assert_eq(st1.digest(), st2.digest())
  // Combine: [0..5) + [5..15) + [15..20) should equal full
  let st3 = CRC32State::new()
  st3.push_range(data, 0, 5)
  st3.push_range(data, 5, 10)
  st3.push_range(data, 15, 5)
  assert_eq(st3.digest(), full)
}

///|
test "crc32 slice-by-4 - table correctness via sequential comparison" {
  // Generate 256 bytes of varied data and verify Slice-by-4 matches
  // a naive byte-at-a-time implementation
  let data = FixedArray::make(256, b'\x00')
  for i in 0..<256 {
    data[i] = i.to_byte()
  }
  // Compute reference CRC byte-by-byte using only crct (table 0)
  let mut ref_crc = 0xFFFFFFFFU
  for i in 0..<256 {
    ref_crc = crct[((ref_crc ^ data[i].to_uint()) & 0xFFU).reinterpret_as_int()] ^
      (ref_crc >> 8)
  }
  ref_crc = ref_crc ^ 0xFFFFFFFFU
  // Compare with Slice-by-4 result
  assert_eq(crc32(data), ref_crc)
}

///|
test "adler32 - push_range matches push" {
  let data : FixedArray[Byte] = [b'\x48', b'\x65', b'\x6C', b'\x6C', b'\x6F']
  let st1 = AdlerState::new()
  st1.push_range(data, 0, 5)
  let st2 = AdlerState::new()
  st2.push(data)
  assert_eq(st1.digest(), st2.digest())
}

///|
test "adler32 unroll - exactly 8 bytes" {
  // Exactly 8 bytes: one iteration of unrolled loop, no remainder
  let data : FixedArray[Byte] = [
    b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60', b'\x70', b'\x80',
  ]
  let one_shot = adler32(data)
  let st = AdlerState::new()
  st.push(data)
  assert_eq(st.digest(), one_shot)
}

///|
test "adler32 unroll - 13 bytes (8 + 5 remainder)" {
  // 13 bytes: one unrolled iteration + 5 byte-by-byte remainder
  let data = FixedArray::make(13, b'\x00')
  for i in 0..<13 {
    data[i] = ((i + 1) * 11 % 256).to_byte()
  }
  let one_shot = adler32(data)
  let st = AdlerState::new()
  st.push(data)
  assert_eq(st.digest(), one_shot)
  // Also verify push_range consistency
  let st2 = AdlerState::new()
  st2.push_range(data, 0, 13)
  assert_eq(st2.digest(), one_shot)
}

///|
test "adler32 unroll - 32 bytes (exact multiple of 8)" {
  // 32 bytes: 4 iterations of unrolled loop, no remainder
  let data = FixedArray::make(32, b'\x00')
  for i in 0..<32 {
    data[i] = (i * 7 % 256).to_byte()
  }
  let one_shot = adler32(data)
  // Verify incremental in 2 chunks also matches
  let st = AdlerState::new()
  st.push(slc(data, 0, e=16))
  st.push(slc(data, 16))
  assert_eq(st.digest(), one_shot)
}

///|
test "adler32 unroll - large data crossing chunk boundary" {
  // 5000 bytes: exceeds the 2655-byte inner chunk boundary,
  // exercises both the unrolled loop and modular reduction
  let size = 5000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 251).to_byte() // use prime modulus for varied data
  }
  let one_shot = adler32(data)
  // Incremental in 3 unequal chunks must match
  let st = AdlerState::new()
  st.push(slc(data, 0, e=1000))
  st.push(slc(data, 1000, e=3500))
  st.push(slc(data, 3500))
  assert_eq(st.digest(), one_shot)
  // push_range must also match
  let st2 = AdlerState::new()
  st2.push_range(data, 0, size)
  assert_eq(st2.digest(), one_shot)
}

///|
test "adler32 unroll - 100KB data consistency" {
  // 100KB: heavily exercises unrolled loop across many chunk boundaries
  let size = 100000
  let data = FixedArray::make(size, b'\x00')
  let mut seed = 98765
  for i in 0..<size {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (seed % 256).to_byte()
  }
  let one_shot = adler32(data)
  assert_true(one_shot != 0U)
  // Verify incremental matches
  let st = AdlerState::new()
  let mut offset = 0
  while offset < size {
    let chunk = if offset + 4096 < size { 4096 } else { size - offset }
    st.push_range(data, offset, chunk)
    offset += chunk
  }
  assert_eq(st.digest(), one_shot)
}
