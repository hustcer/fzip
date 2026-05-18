///|
test "str_to_u8 - ASCII" {
  let result = str_to_u8("Hello")
  assert_eq(result.length(), 5)
  assert_eq(result[0], b'\x48')
  assert_eq(result[4], b'\x6F')
}

///|
test "str_to_u8 - latin1" {
  let result = str_to_u8("ABC", latin1=true)
  assert_eq(result.length(), 3)
  assert_eq(result[0], b'\x41')
  assert_eq(result[2], b'\x43')
}

///|
test "str_from_u8 - ASCII" {
  let data : FixedArray[Byte] = [b'\x48', b'\x65', b'\x6C', b'\x6C', b'\x6F']
  let result = str_from_u8(data)
  assert_eq(result, "Hello")
}

///|
test "str_from_u8 - latin1" {
  let data : FixedArray[Byte] = [b'\x41', b'\x42', b'\x43']
  let result = str_from_u8(data, latin1=true)
  assert_eq(result, "ABC")
}

///|
test "str_to_u8/str_from_u8 roundtrip - ASCII" {
  let s = "Hello, World!"
  let encoded = str_to_u8(s)
  let decoded = str_from_u8(encoded)
  assert_eq(decoded, s)
}

///|
test "str_to_u8 - 2-byte UTF-8" {
  // Latin characters with diacritics
  let result = str_to_u8("\u00E9") // e with acute
  assert_eq(result.length(), 2)
  assert_eq(result[0], b'\xC3')
  assert_eq(result[1], b'\xA9')
}

///|
test "str_from_u8 - with offset and len" {
  // "Hello" in bytes, with extra padding
  let data : FixedArray[Byte] = [
    b'\xAA', b'\xBB', b'\x48', b'\x65', b'\x6C', b'\x6C', b'\x6F', b'\xCC',
  ]
  // Read "Hello" from offset 2, len 5
  let result = str_from_u8(data, offset=2, len=5)
  assert_eq(result, "Hello")
}

///|
test "str_from_u8 - offset with latin1" {
  let data : FixedArray[Byte] = [b'\x00', b'\x41', b'\x42', b'\x43', b'\x00']
  let result = str_from_u8(data, latin1=true, offset=1, len=3)
  assert_eq(result, "ABC")
}

///|
test "str_from_u8 - offset defaults to full range" {
  let data : FixedArray[Byte] = [b'\x48', b'\x69']
  // No offset/len → reads entire array
  let result = str_from_u8(data)
  assert_eq(result, "Hi")
}

///|
test "str_from_u8 - offset with multi-byte UTF-8" {
  // é (U+00E9) is [0xC3, 0xA9] in UTF-8
  let data : FixedArray[Byte] = [b'\x00', b'\xC3', b'\xA9', b'\x00']
  let result = str_from_u8(data, offset=1, len=2)
  assert_eq(result, "\u00E9")
}

///|
test "str_to_u8/str_from_u8 roundtrip - 3-byte UTF-8 (CJK)" {
  let s = "你好世界"
  let encoded = str_to_u8(s)
  let decoded = str_from_u8(encoded)
  assert_eq(decoded, s)
}

///|
test "str_from_u8 - 3-byte UTF-8" {
  // "中" (U+4E2D) is [0xE4, 0xB8, 0xAD] in UTF-8
  let data : FixedArray[Byte] = [b'\xE4', b'\xB8', b'\xAD']
  let result = str_from_u8(data)
  assert_eq(result, "中")
}

///|
test "str_to_u8/str_from_u8 roundtrip - 4-byte UTF-8 (emoji)" {
  // U+1F600 (😀) requires 4-byte UTF-8 encoding
  let s = "😀"
  let encoded = str_to_u8(s)
  // 4-byte UTF-8: F0 9F 98 80
  assert_eq(encoded.length(), 4)
  assert_eq(encoded[0], b'\xF0')
  assert_eq(encoded[1], b'\x9F')
  assert_eq(encoded[2], b'\x98')
  assert_eq(encoded[3], b'\x80')
  let decoded = str_from_u8(encoded)
  assert_eq(decoded, s)
}

///|
test "str_from_u8 - 4-byte UTF-8 (musical symbol)" {
  // U+1D11E (𝄞 MUSICAL SYMBOL G CLEF) = [0xF0, 0x9D, 0x84, 0x9E]
  let data : FixedArray[Byte] = [b'\xF0', b'\x9D', b'\x84', b'\x9E']
  let result = str_from_u8(data)
  let roundtrip = str_to_u8(result)
  assert_eq(roundtrip.length(), 4)
  assert_eq(roundtrip[0], b'\xF0')
  assert_eq(roundtrip[1], b'\x9D')
  assert_eq(roundtrip[2], b'\x84')
  assert_eq(roundtrip[3], b'\x9E')
}

///|
test "str_to_u8/str_from_u8 roundtrip - mixed byte lengths" {
  // Mix of 1-byte (A), 2-byte (é), 3-byte (中), and 4-byte (😀)
  let s = "Aé中😀"
  let encoded = str_to_u8(s)
  let decoded = str_from_u8(encoded)
  assert_eq(decoded, s)
}

///|
fn assert_invalid_utf8(data : FixedArray[Byte]) -> Unit raise {
  let result = try? str_from_u8(data)
  guard result is Err(FzipError(code~, ..)) else {
    fail("expected InvalidUTF8 for byte sequence")
  }
  assert_eq(code, InvalidUTF8)
}

///|
/// S-001 regression: continuation bytes (0x80-0xBF) cannot start a UTF-8
/// sequence. The previous implementation treated them as a 2-byte start and
/// silently produced a low-codepoint character, causing parser-differential
/// decoding versus standard UTF-8 decoders.
test "str_from_u8 - rejects continuation byte as sequence start (S-001)" {
  // 0x80 (lowest continuation byte) followed by ASCII tail.
  assert_invalid_utf8([b'\x80', b'\x41'])
  // 0xBF (highest continuation byte) followed by ASCII.
  assert_invalid_utf8([b'\xBF', b'\x41'])
  // Bare continuation byte at end of buffer.
  assert_invalid_utf8([b'\x80'])
}

///|
/// S-002 regression: every continuation byte must match the `10xxxxxx`
/// pattern. The previous implementation masked `& 0x3F` without checking the
/// high bits, so a non-continuation second byte was happily decoded.
test "str_from_u8 - rejects malformed continuation byte (S-002)" {
  // 2-byte sequence header 0xC3 followed by an ASCII byte (not a
  // continuation byte): used to silently produce a junk codepoint.
  assert_invalid_utf8([b'\xC3', b'\x41'])
  // 3-byte sequence header 0xE4 followed by a valid continuation and then
  // an ASCII byte where another continuation should be.
  assert_invalid_utf8([b'\xE4', b'\xB8', b'\x41'])
  // 4-byte sequence header 0xF0 with one bad continuation in slot 2.
  assert_invalid_utf8([b'\xF0', b'\x41', b'\x80', b'\x80'])
}

///|
/// S-003 regression: overlong encodings must be rejected even though the
/// continuation bytes look well-formed. RFC 3629 forbids them because each
/// codepoint must use the shortest encoding (avoids NUL-byte injection
/// via `0xC0 0x80` and similar tricks).
test "str_from_u8 - rejects overlong encoding (S-003)" {
  // Overlong 2-byte encoding of U+0000 (`0xC0 0x80` style — caught by the
  // 0xC0/0xC1 reject branch).
  assert_invalid_utf8([b'\xC0', b'\x80'])
  // Overlong 2-byte encoding of U+007F.
  assert_invalid_utf8([b'\xC1', b'\xBF'])
  // Overlong 3-byte encoding of U+007F (`0xE0 0x81 0xBF`).
  assert_invalid_utf8([b'\xE0', b'\x81', b'\xBF'])
  // Overlong 3-byte encoding of U+07FF (`0xE0 0x9F 0xBF`).
  assert_invalid_utf8([b'\xE0', b'\x9F', b'\xBF'])
  // Overlong 4-byte encoding of U+FFFF (`0xF0 0x8F 0xBF 0xBF`).
  assert_invalid_utf8([b'\xF0', b'\x8F', b'\xBF', b'\xBF'])
}

///|
/// S-004 regression: 4-byte sequences must decode to U+10000..U+10FFFF.
/// Bytes `>= 0xF5` are outside the modern UTF-8 spec (RFC 3629 dropped the
/// 5- and 6-byte legacy forms). Surrogate code points are also rejected.
test "str_from_u8 - rejects out-of-range start bytes and surrogates (S-004)" {
  // 0xF5..0xF7: 4-byte form, but decodes above U+10FFFF.
  assert_invalid_utf8([b'\xF5', b'\x80', b'\x80', b'\x80'])
  assert_invalid_utf8([b'\xF7', b'\xBF', b'\xBF', b'\xBF'])
  // 0xF8..0xFF: legacy 5/6-byte starts, never valid in UTF-8.
  assert_invalid_utf8([b'\xF8', b'\x80', b'\x80', b'\x80'])
  assert_invalid_utf8([b'\xFF'])
  // Surrogate code points (U+D800..U+DFFF) are not valid Unicode scalars.
  // U+D800 = 0xED 0xA0 0x80
  assert_invalid_utf8([b'\xED', b'\xA0', b'\x80'])
  // U+DFFF = 0xED 0xBF 0xBF
  assert_invalid_utf8([b'\xED', b'\xBF', b'\xBF'])
}

///|
/// Truncated multi-byte sequences must raise (existing behavior; covered
/// here as a regression because the rewrite changed how the bounds check
/// is structured).
test "str_from_u8 - rejects truncated multi-byte sequence" {
  assert_invalid_utf8([b'\xC3']) // 2-byte header, no continuation
  assert_invalid_utf8([b'\xE4', b'\xB8']) // 3-byte header, one continuation
  assert_invalid_utf8([b'\xF0', b'\x9F', b'\x98']) // 4-byte header, two
}

///|
/// Boundary acceptance: ensure the strict path still accepts the smallest
/// and largest valid codepoints for each multi-byte length.
test "str_from_u8 - accepts valid multi-byte boundaries" {
  // U+0080 (smallest 2-byte): 0xC2 0x80
  let s2 = str_from_u8([b'\xC2', b'\x80'])
  let r2 = str_to_u8(s2)
  assert_eq(r2.length(), 2)
  assert_eq(r2[0], b'\xC2')
  assert_eq(r2[1], b'\x80')
  // U+07FF (largest 2-byte): 0xDF 0xBF
  let s2b = str_from_u8([b'\xDF', b'\xBF'])
  let r2b = str_to_u8(s2b)
  assert_eq(r2b.length(), 2)
  assert_eq(r2b[0], b'\xDF')
  assert_eq(r2b[1], b'\xBF')
  // U+0800 (smallest 3-byte): 0xE0 0xA0 0x80
  let s3 = str_from_u8([b'\xE0', b'\xA0', b'\x80'])
  let r3 = str_to_u8(s3)
  assert_eq(r3.length(), 3)
  assert_eq(r3[0], b'\xE0')
  // U+FFFD (largest BMP non-surrogate, just below private use): 0xEF 0xBF 0xBD
  let _ = str_from_u8([b'\xEF', b'\xBF', b'\xBD'])
  // U+10000 (smallest supplementary): 0xF0 0x90 0x80 0x80
  let _ = str_from_u8([b'\xF0', b'\x90', b'\x80', b'\x80'])
  // U+10FFFF (largest Unicode codepoint): 0xF4 0x8F 0xBF 0xBF
  let _ = str_from_u8([b'\xF4', b'\x8F', b'\xBF', b'\xBF'])
}
