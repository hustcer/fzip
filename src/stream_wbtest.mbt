///|
test "DeflateStream - basic usage" {
  let stream = DeflateStream::new()
  let output : Array[FixedArray[Byte]] = []
  stream.ondata = Some(FlateStreamHandler((data, _) => output.push(data)))
  let data1 : FixedArray[Byte] = [1, 2, 3, 4, 5]
  let data2 : FixedArray[Byte] = [6, 7, 8, 9, 10]
  stream.push(data1, final_=false)
  stream.push(data2, final_=true)
  assert_true(output.length() > 0)
}

///|
test "InflateStream - basic usage" {
  let data : FixedArray[Byte] = [1, 2, 3, 4, 5]
  let compressed = deflate_sync(data)
  let stream = InflateStream::new()
  let output : Array[FixedArray[Byte]] = []
  stream.ondata = Some(FlateStreamHandler((data, _) => output.push(data)))
  stream.push(compressed, final_=true)
  assert_true(output.length() > 0)
  let result = output[0]
  assert_eq(result.length(), 5)
}

///|
test "GzipStream - basic usage" {
  let stream = GzipStream::new()
  let output : Array[FixedArray[Byte]] = []
  stream.ondata = Some(FlateStreamHandler((data, _) => output.push(data)))
  let data : FixedArray[Byte] = [1, 2, 3]
  stream.push(data, final_=true)
  assert_true(output.length() > 0)
}

///|
test "GunzipStream - basic usage" {
  let data : FixedArray[Byte] = [1, 2, 3]
  let compressed = gzip_sync(data)
  let stream = GunzipStream::new()
  let output : Array[FixedArray[Byte]] = []
  stream.ondata = Some(FlateStreamHandler((data, _) => output.push(data)))
  stream.push(compressed, final_=true)
  assert_true(output.length() > 0)
}

///|
test "ZlibStream - basic usage" {
  let stream = ZlibStream::new()
  let output : Array[FixedArray[Byte]] = []
  stream.ondata = Some(FlateStreamHandler((data, _) => output.push(data)))
  let data : FixedArray[Byte] = [1, 2, 3]
  stream.push(data, final_=true)
  assert_true(output.length() > 0)
}

///|
test "UnzlibStream - basic usage" {
  let data : FixedArray[Byte] = [1, 2, 3]
  let compressed = zlib_sync(data)
  let stream = UnzlibStream::new()
  let output : Array[FixedArray[Byte]] = []
  stream.ondata = Some(FlateStreamHandler((data, _) => output.push(data)))
  stream.push(compressed, final_=true)
  assert_true(output.length() > 0)
}

///|
test "DecompressStream - basic usage" {
  let data : FixedArray[Byte] = [1, 2, 3]
  let compressed = gzip_sync(data)
  let stream = DecompressStream::new()
  let output : Array[FixedArray[Byte]] = []
  stream.ondata = Some(FlateStreamHandler((data, _) => output.push(data)))
  stream.push(compressed, final_=true)
  assert_true(output.length() > 0)
}
