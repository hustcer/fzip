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
