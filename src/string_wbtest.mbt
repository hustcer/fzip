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
