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
