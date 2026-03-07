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
