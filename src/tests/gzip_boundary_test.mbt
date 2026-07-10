///|
fn concat_gzip_members(members : Array[FixedArray[Byte]]) -> FixedArray[Byte] {
  let total = members.fold(init=0, (size, part) => size + part.length())
  let result = FixedArray::make(total, b'\x00')
  let mut offset = 0
  for part in members {
    part.blit_to(result, len=part.length(), dst_offset=offset)
    offset += part.length()
  }
  result
}

///|
fn with_optional_gzip_header(
  base : FixedArray[Byte],
  flags : Byte,
  fields : FixedArray[Byte],
) -> FixedArray[Byte] {
  let header_len = 10 + fields.length()
  let crc_len = if (flags.to_int() & 2) != 0 { 2 } else { 0 }
  let result = FixedArray::make(
    base.length() + fields.length() + crc_len,
    b'\x00',
  )
  base.blit_to(result, len=10, dst_offset=0)
  result[3] = flags
  fields.blit_to(result, len=fields.length(), dst_offset=10)
  if crc_len != 0 {
    let header = FixedArray::make(header_len, b'\x00')
    result.blit_to(header, len=header_len, dst_offset=0)
    let checksum = @fzip.crc32(header)
    result[header_len] = checksum.to_byte()
    result[header_len + 1] = (checksum >> 8).to_byte()
  }
  base.blit_to(
    result,
    len=base.length() - 10,
    src_offset=10,
    dst_offset=header_len + crc_len,
  )
  result
}

///|
test "gunzip concatenates default short members" {
  let first : FixedArray[Byte] = [b'o', b'n', b'e']
  let second : FixedArray[Byte] = [b't', b'w', b'o']
  let compressed = concat_gzip_members([
    @fzip.gzip_sync(first),
    @fzip.gzip_sync(second),
  ])
  let decompressed = @fzip.gunzip_sync(compressed)
  let expected : FixedArray[Byte] = [b'o', b'n', b'e', b't', b'w', b'o']
  assert_eq(decompressed.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(decompressed[i], expected[i])
  }
}

///|
test "gunzip enforces max_input_size on the complete gzip stream" {
  let data : FixedArray[Byte] = [b'i', b'n', b'p', b'u', b't']
  let compressed = @fzip.gzip_sync(data)
  let exact = @fzip.gunzip_sync(compressed, opts={
    out: None,
    dictionary: None,
    max_output_size: 1024,
    max_input_size: compressed.length(),
    verify_checksum: true,
  })
  assert_eq(exact.length(), data.length())
  try
    @fzip.gunzip_sync(compressed, opts={
      out: None,
      dictionary: None,
      max_output_size: 1024,
      max_input_size: compressed.length() - 1,
      verify_checksum: true,
    })
  catch {
    FzipError(code~, ..) => assert_eq(code, InvalidZipData)
  } noraise {
    _ => fail("expected the complete gzip stream to exceed max_input_size")
  }
}

///|
test "gunzip accepts optional header fields and verifies FHCRC" {
  let data : FixedArray[Byte] = [b'h', b'e', b'a', b'd', b'e', b'r']
  let fields : FixedArray[Byte] = [
    b'\x03', b'\x00', b'x', b'y', b'z', b'f', b'i', b'l', b'e', b'.', b't', b'x',
    b't', b'\x00', b'n', b'o', b't', b'e', b'\x00',
  ]
  let compressed = with_optional_gzip_header(
    @fzip.gzip_sync(data),
    b'\x1E',
    fields,
  )
  let decompressed = @fzip.gunzip_sync(compressed)
  assert_eq(decompressed.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(decompressed[i], data[i])
  }
  let corrupted = compressed.copy()
  corrupted[10 + fields.length()] = corrupted[10 + fields.length()] ^ b'\x01'
  try @fzip.gunzip_sync(corrupted) catch {
    FzipError(code~, ..) => assert_eq(code, InvalidChecksum)
  } noraise {
    _ => fail("expected a mismatched FHCRC to be rejected")
  }
  try
    @fzip.gunzip_sync(corrupted, opts={
      out: None,
      dictionary: None,
      max_output_size: 1024,
      max_input_size: corrupted.length(),
      verify_checksum: false,
    })
  catch {
    FzipError(code~, ..) => assert_eq(code, InvalidChecksum)
  } noraise {
    _ => fail("expected FHCRC validation even when footer checks are disabled")
  }
}

///|
test "gunzip rejects a single member whose ISIZE is too small" {
  let compressed = @fzip.gzip_sync([b's', b'm', b'a', b'l', b'l'])
  let footer = compressed.length() - 4
  compressed[footer] = b'\x04'
  compressed[footer + 1] = b'\x00'
  compressed[footer + 2] = b'\x00'
  compressed[footer + 3] = b'\x00'
  try @fzip.gunzip_sync(compressed) catch {
    FzipError(code~, message~) => {
      assert_eq(code, InvalidZipData)
      assert_true(message.contains("ISIZE mismatch"))
    }
  } noraise {
    _ => fail("expected a too-small ISIZE to be rejected")
  }
}

///|
test "gunzip falls back when the first member exceeds the final ISIZE" {
  let first = FixedArray::make(256, b'A')
  let second : FixedArray[Byte] = [b'Z']
  let compressed = concat_gzip_members([
    @fzip.gzip_sync(first),
    @fzip.gzip_sync(second),
  ])
  let decompressed = @fzip.gunzip_sync(compressed)
  assert_eq(decompressed.length(), 257)
  for i in 0..<256 {
    assert_eq(decompressed[i], b'A')
  }
  assert_eq(decompressed[256], b'Z')
}

///|
test "gunzip accepts empty members in a concatenated stream" {
  let empty : FixedArray[Byte] = []
  let payload : FixedArray[Byte] = [b'd', b'a', b't', b'a']
  let compressed = concat_gzip_members([
    @fzip.gzip_sync(empty),
    @fzip.gzip_sync(payload),
    @fzip.gzip_sync(empty),
  ])
  let decompressed = @fzip.gunzip_sync(compressed)
  assert_eq(decompressed.length(), payload.length())
  for i in 0..<payload.length() {
    assert_eq(decompressed[i], payload[i])
  }
}

///|
test "gunzip rejects a corrupted middle member CRC" {
  let middle = @fzip.gzip_sync([b'm', b'i', b'd', b'd', b'l', b'e'])
  middle[middle.length() - 8] = middle[middle.length() - 8] ^ b'\x01'
  let compressed = concat_gzip_members([
    @fzip.gzip_sync([b'f', b'i', b'r', b's', b't']),
    middle,
    @fzip.gzip_sync([b'l', b'a', b's', b't']),
  ])
  try @fzip.gunzip_sync(compressed) catch {
    FzipError(code~, ..) => assert_eq(code, InvalidChecksum)
  } noraise {
    _ => fail("expected the middle member CRC mismatch to be rejected")
  }
}

///|
test "gunzip enforces combined output and caller buffer bounds" {
  let first : FixedArray[Byte] = [b'a', b'b', b'c']
  let second : FixedArray[Byte] = [b'd', b'e', b'f', b'g']
  let compressed = concat_gzip_members([
    @fzip.gzip_sync(first),
    @fzip.gzip_sync(second),
  ])
  let exact_out = FixedArray::make(7, b'\x00')
  let exact = @fzip.gunzip_sync(compressed, opts={
    out: Some(exact_out),
    dictionary: None,
    max_output_size: 7,
    max_input_size: compressed.length(),
    verify_checksum: true,
  })
  assert_eq(exact.length(), 7)
  try
    @fzip.gunzip_sync(compressed, opts={
      out: None,
      dictionary: None,
      max_output_size: 6,
      max_input_size: compressed.length(),
      verify_checksum: true,
    })
  catch {
    FzipError(code~, ..) => assert_eq(code, InvalidZipData)
  } noraise {
    _ => fail("expected combined output to exceed max_output_size")
  }
  try
    @fzip.gunzip_sync(compressed, opts={
      out: Some(FixedArray::make(6, b'\x00')),
      dictionary: None,
      max_output_size: 7,
      max_input_size: compressed.length(),
      verify_checksum: true,
    })
  catch {
    FzipError(code~, message~) => {
      assert_eq(code, InvalidZipData)
      assert_true(message.contains("output buffer too small"))
    }
  } noraise {
    _ => fail("expected the caller output buffer to be rejected")
  }
}

///|
test "gunzip rejects truncated optional header fields" {
  let cases : Array[FixedArray[Byte]] = [
    [
      b'\x1F', b'\x8B', b'\x08', b'\x04', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      b'\x03', b'\x04', b'\x00', b'x',
    ],
    [
      b'\x1F', b'\x8B', b'\x08', b'\x10', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      b'\x03', b'n', b'o', b't', b'e',
    ],
    [
      b'\x1F', b'\x8B', b'\x08', b'\x02', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
      b'\x03', b'\x00',
    ],
  ]
  for input in cases {
    try @fzip.gunzip_sync(input) catch {
      FzipError(code~, ..) => assert_eq(code, InvalidHeader)
    } noraise {
      _ => fail("expected a truncated optional header to be rejected")
    }
  }
}
