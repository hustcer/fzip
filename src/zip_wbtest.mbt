///|
test "zip/unzip roundtrip - single file" {
  let data : FixedArray[Byte] = FixedArray::make(100, b'\x00')
  for i in 0..<100 {
    data[i] = (i % 256).to_byte()
  }
  let files : Array[(String, FixedArray[Byte])] = [("test.txt", data)]
  let zipped = zip_sync(files)
  let result = unzip_sync(zipped)
  assert_eq(result.length(), 1)
  let (name, content) = result[0]
  assert_eq(name, "test.txt")
  assert_eq(content.length(), data.length())
  for i in 0..<data.length() {
    assert_eq(content[i], data[i])
  }
}

///|
test "zip/unzip roundtrip - multiple files" {
  let data1 : FixedArray[Byte] = FixedArray::make(50, b'\x41')
  let data2 : FixedArray[Byte] = FixedArray::make(30, b'\x42')
  let files : Array[(String, FixedArray[Byte])] = [
    ("file1.txt", data1),
    ("file2.txt", data2),
  ]
  let zipped = zip_sync(files)
  let result = unzip_sync(zipped)
  assert_eq(result.length(), 2)
}

///|
test "zip/unzip roundtrip - stored (level 0)" {
  let data : FixedArray[Byte] = FixedArray::make(50, b'\x43')
  let files : Array[(String, FixedArray[Byte])] = [("stored.bin", data)]
  let zipped = zip_sync(files, opts={
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  })
  let result = unzip_sync(zipped)
  assert_eq(result.length(), 1)
  let (name, content) = result[0]
  assert_eq(name, "stored.bin")
  assert_eq(content.length(), data.length())
}

///|
test "unzip_list" {
  let data : FixedArray[Byte] = FixedArray::make(50, b'\x44')
  let files : Array[(String, FixedArray[Byte])] = [("info.dat", data)]
  let zipped = zip_sync(files)
  let infos = unzip_list(zipped)
  assert_eq(infos.length(), 1)
  assert_eq(infos[0].name, "info.dat")
  assert_eq(infos[0].original_size, 50)
}

///|
test "zip - multiple files (5 files)" {
  let files : Array[(String, FixedArray[Byte])] = []
  for i in 0..<5 {
    let data = FixedArray::make(100 + i * 10, (65 + i).to_byte())
    files.push(("file\{i}.txt", data))
  }
  let zipped = zip_sync(files)
  let result = unzip_sync(zipped)
  assert_eq(result.length(), 5)
  for i in 0..<5 {
    let (name, content) = result[i]
    assert_eq(name, "file\{i}.txt")
    assert_eq(content.length(), 100 + i * 10)
  }
}

///|
test "unzip_list - multiple files" {
  let files : Array[(String, FixedArray[Byte])] = []
  for i in 0..<3 {
    files.push(("test\{i}.bin", FixedArray::make(50 + i * 20, b'\x00')))
  }
  let zipped = zip_sync(files)
  let infos = unzip_list(zipped)
  assert_eq(infos.length(), 3)
  for i in 0..<3 {
    assert_eq(infos[i].name, "test\{i}.bin")
    assert_eq(infos[i].original_size, 50 + i * 20)
  }
}

///|
test "zip with options - mtime" {
  let data : FixedArray[Byte] = [1, 2, 3]
  let files : Array[(String, FixedArray[Byte])] = [("test.txt", data)]
  let zipped = zip_sync(files, opts={
    level: 6,
    mem: 0,
    os: 3,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 1234567890,
  })
  let result = unzip_sync(zipped)
  assert_eq(result.length(), 1)
  assert_eq(result[0].0, "test.txt")
}

///|
test "zip - empty file" {
  let empty : FixedArray[Byte] = []
  let files : Array[(String, FixedArray[Byte])] = [("empty.txt", empty)]
  let zipped = zip_sync(files)
  let result = unzip_sync(zipped)
  assert_eq(result.length(), 1)
  assert_eq(result[0].0, "empty.txt")
  assert_eq(result[0].1.length(), 0)
}

///|
test "zip - normal compression ratio accepted" {
  // Test that normal compression ratios (< 1000:1) work fine
  let data = FixedArray::make(1000, b'A')
  let files : Array[(String, FixedArray[Byte])] = [("test.bin", data)]
  let zipped = zip_sync(files)
  let result = unzip_sync(zipped)
  assert_eq(result.length(), 1)
  assert_eq(result[0].1.length(), 1000)
}

///|
test "zip - deflated entry writes correct CRC in local and central headers" {
  let size = 50000
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 64).to_byte()
  }
  let zipped = zip_sync([("crc.bin", data)])
  let expected = crc32(data)
  // Local file header CRC-32 starts at byte 14
  assert_eq(b4(zipped, 14), expected)
  // EOCD is 22 bytes with empty comment; central directory offset is at +16
  let cd_offset = b4(zipped, zipped.length() - 6).reinterpret_as_int()
  // Central directory CRC-32 starts at byte 16 from the CD header start
  assert_eq(b4(zipped, cd_offset + 16), expected)
}

///|
test "zip - stored entry writes correct CRC in local and central headers" {
  let data = FixedArray::make(1024, b'\x00')
  for i in 0..<1024 {
    data[i] = (i % 251).to_byte()
  }
  let zipped = zip_sync([("stored-crc.bin", data)], opts={
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  })
  let expected = crc32(data)
  assert_eq(b4(zipped, 14), expected)
  let cd_offset = b4(zipped, zipped.length() - 6).reinterpret_as_int()
  assert_eq(b4(zipped, cd_offset + 16), expected)
}
