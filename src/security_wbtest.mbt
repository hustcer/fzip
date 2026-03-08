///|
test "security/gzip - empty input" {
  let empty : FixedArray[Byte] = []
  let result = try? gunzip_sync(empty)
  assert_true(result is Err(_))
}

///|
test "security/gzip - too short input" {
  let short : FixedArray[Byte] = [b'\x1F', b'\x8B']
  let result = try? gunzip_sync(short)
  assert_true(result is Err(_))
}

///|
test "security/gzip - 9 bytes input" {
  let short : FixedArray[Byte] = [
    b'\x1F', b'\x8B', b'\x08', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00',
  ]
  let result = try? gunzip_sync(short)
  assert_true(result is Err(_))
}

///|
test "security/gzip - FNAME flag but truncated" {
  // GZIP header with FNAME flag (0x08) set but no actual filename data
  let truncated : FixedArray[Byte] = [
    b'\x1F', b'\x8B', b'\x08', b'\x08', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x03',
  ]
  let result = try? gunzip_sync(truncated)
  assert_true(result is Err(_))
}

///|
test "security/zlib - empty input" {
  let empty : FixedArray[Byte] = []
  let result = try? unzlib_sync(empty)
  assert_true(result is Err(_))
}

///|
test "security/zlib - 1 byte input" {
  let short : FixedArray[Byte] = [b'\x78']
  let result = try? unzlib_sync(short)
  assert_true(result is Err(_))
}

///|
test "security/zlib - header only (no compressed data)" {
  // Valid zlib header (0x78 0x9C) but no compressed data or checksum
  let short : FixedArray[Byte] = [b'\x78', b'\x9C']
  let result = try? unzlib_sync(short)
  assert_true(result is Err(_))
}

///|
test "security/zip - empty input" {
  let empty : FixedArray[Byte] = []
  let result = try? unzip_sync(empty)
  assert_true(result is Err(_))
}

///|
test "security/zip - too short input" {
  let short : FixedArray[Byte] = [b'\x50', b'\x4B', b'\x05', b'\x06']
  let result = try? unzip_sync(short)
  assert_true(result is Err(_))
}

///|
test "security/zip - unzip_list empty input" {
  let empty : FixedArray[Byte] = []
  let result = try? unzip_list(empty)
  assert_true(result is Err(_))
}

///|
test "security/zip - path traversal detection" {
  // Test the is_unsafe_path function directly
  assert_true(is_unsafe_path("../etc/passwd"))
  assert_true(is_unsafe_path("foo/../../../etc/passwd"))
  assert_true(is_unsafe_path("..\\windows\\system32"))
  assert_true(is_unsafe_path("/etc/passwd"))
  assert_true(is_unsafe_path("\\windows\\system32"))
  assert_true(is_unsafe_path("C:\\windows\\system32"))
  assert_true(is_unsafe_path("c:/windows/system32"))
  assert_true(is_unsafe_path(".."))
  assert_true(is_unsafe_path("foo/.."))
  assert_true(is_unsafe_path("foo\\.."))
  // Safe paths
  assert_eq(is_unsafe_path("file.txt"), false)
  assert_eq(is_unsafe_path("dir/file.txt"), false)
  assert_eq(is_unsafe_path("dir/subdir/file.txt"), false)
  assert_eq(is_unsafe_path("..hidden"), false)
  assert_eq(is_unsafe_path("dir/..hidden/file.txt"), false)
  assert_eq(is_unsafe_path(""), false)
}

///|
test "security/decompress - 2 byte input no crash" {
  // decompress_sync with exactly 2 bytes should not crash
  // (previously accessed data[2] with only length >= 2 check)
  let data : FixedArray[Byte] = [b'\x00', b'\x00']
  let result = try? decompress_sync(data)
  // It's OK if this errors, just shouldn't crash with out-of-bounds
  let _ = result
}

///|
test "security/decompress - 1 byte input" {
  let data : FixedArray[Byte] = [b'\x00']
  let result = try? decompress_sync(data)
  let _ = result
}

///|
test "security/decompress - empty input" {
  let data : FixedArray[Byte] = []
  let result = try? decompress_sync(data)
  let _ = result
}
