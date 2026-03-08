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
