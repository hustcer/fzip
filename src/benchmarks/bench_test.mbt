///|
fn make_zeros(size : Int) -> FixedArray[Byte] {
  FixedArray::make(size, b'\x00')
}

///|
fn make_sequential(size : Int) -> FixedArray[Byte] {
  let data = FixedArray::make(size, b'\x00')
  for i in 0..<size {
    data[i] = (i % 256).to_byte()
  }
  data
}

///|
fn make_random(size : Int, seed : Int) -> FixedArray[Byte] {
  let data = FixedArray::make(size, b'\x00')
  let mut s = seed
  for i in 0..<size {
    s = (s * 1103515245 + 12345) & 0x7FFFFFFF
    data[i] = (s >> 16).to_byte()
  }
  data
}

///|
fn make_zip_files() -> Array[(String, FixedArray[Byte])] {
  [
    ("hello.txt", make_sequential(512)),
    ("data.bin", make_random(2048, 42)),
    ("zeros.dat", make_zeros(1024)),
  ]
}

///|
fn fa_to_bytes(data : FixedArray[Byte]) -> Bytes {
  let arr : Array[Byte] = []
  for i in 0..<data.length() {
    arr.push(data[i])
  }
  Bytes::from_array(arr)
}

// ============================================================
// DEFLATE compress — 3 patterns × 2 sizes × 3 libs = 18
// ============================================================

///|
test "deflate/compress/zeros_1k/fzip" (b : @bench.T) {
  let data = make_zeros(1024)
  b.bench(fn() { b.keep(@fzip.deflate_sync(data)) })
}

///|
test "deflate/compress/zeros_1k/moonzip" (b : @bench.T) {
  let data = make_zeros(1024)
  b.bench(fn() { b.keep(@moonzip.deflate_sync(data)) })
}

///|
test "deflate/compress/zeros_1k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_zeros(1024))
  b.bench(fn() { b.keep(@zlib.deflate_compress(data)) })
}

///|
test "deflate/compress/zeros_100k/fzip" (b : @bench.T) {
  let data = make_zeros(102400)
  b.bench(fn() { b.keep(@fzip.deflate_sync(data)) })
}

///|
test "deflate/compress/zeros_100k/moonzip" (b : @bench.T) {
  let data = make_zeros(102400)
  b.bench(fn() { b.keep(@moonzip.deflate_sync(data)) })
}

///|
test "deflate/compress/zeros_100k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_zeros(102400))
  b.bench(fn() { b.keep(@zlib.deflate_compress(data)) })
}

///|
test "deflate/compress/seq_1k/fzip" (b : @bench.T) {
  let data = make_sequential(1024)
  b.bench(fn() { b.keep(@fzip.deflate_sync(data)) })
}

///|
test "deflate/compress/seq_1k/moonzip" (b : @bench.T) {
  let data = make_sequential(1024)
  b.bench(fn() { b.keep(@moonzip.deflate_sync(data)) })
}

///|
test "deflate/compress/seq_1k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(1024))
  b.bench(fn() { b.keep(@zlib.deflate_compress(data)) })
}

///|
test "deflate/compress/seq_100k/fzip" (b : @bench.T) {
  let data = make_sequential(102400)
  b.bench(fn() { b.keep(@fzip.deflate_sync(data)) })
}

///|
test "deflate/compress/seq_100k/moonzip" (b : @bench.T) {
  let data = make_sequential(102400)
  b.bench(fn() { b.keep(@moonzip.deflate_sync(data)) })
}

///|
test "deflate/compress/seq_100k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(102400))
  b.bench(fn() { b.keep(@zlib.deflate_compress(data)) })
}

///|
test "deflate/compress/random_1k/fzip" (b : @bench.T) {
  let data = make_random(1024, 42)
  b.bench(fn() { b.keep(@fzip.deflate_sync(data)) })
}

///|
test "deflate/compress/random_1k/moonzip" (b : @bench.T) {
  let data = make_random(1024, 42)
  b.bench(fn() { b.keep(@moonzip.deflate_sync(data)) })
}

///|
test "deflate/compress/random_1k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_random(1024, 42))
  b.bench(fn() { b.keep(@zlib.deflate_compress(data)) })
}

///|
test "deflate/compress/random_100k/fzip" (b : @bench.T) {
  let data = make_random(102400, 42)
  b.bench(fn() { b.keep(@fzip.deflate_sync(data)) })
}

///|
test "deflate/compress/random_100k/moonzip" (b : @bench.T) {
  let data = make_random(102400, 42)
  b.bench(fn() { b.keep(@moonzip.deflate_sync(data)) })
}

///|
test "deflate/compress/random_100k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_random(102400, 42))
  b.bench(fn() { b.keep(@zlib.deflate_compress(data)) })
}

// ============================================================
// DEFLATE decompress — 2 sizes × 3 libs = 6
// ============================================================

///|
test "deflate/decompress/1k/fzip" (b : @bench.T) {
  let compressed = @fzip.deflate_sync(make_sequential(1024))
  b.bench(fn() { b.keep(try! @fzip.inflate_sync(compressed)) })
}

///|
test "deflate/decompress/1k/moonzip" (b : @bench.T) {
  let compressed = @moonzip.deflate_sync(make_sequential(1024))
  b.bench(fn() { b.keep(try! @moonzip.inflate_sync(compressed)) })
}

///|
test "deflate/decompress/1k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(1024))
  let compressed = @zlib.deflate_compress(data)
  b.bench(fn() { b.keep(try! @zlib.deflate_decompress(compressed)) })
}

///|
test "deflate/decompress/100k/fzip" (b : @bench.T) {
  let compressed = @fzip.deflate_sync(make_sequential(102400))
  b.bench(fn() { b.keep(try! @fzip.inflate_sync(compressed)) })
}

///|
test "deflate/decompress/100k/moonzip" (b : @bench.T) {
  let compressed = @moonzip.deflate_sync(make_sequential(102400))
  b.bench(fn() { b.keep(try! @moonzip.inflate_sync(compressed)) })
}

///|
test "deflate/decompress/100k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(102400))
  let compressed = @zlib.deflate_compress(data)
  b.bench(fn() { b.keep(try! @zlib.deflate_decompress(compressed)) })
}

// ============================================================
// GZIP compress — 2 sizes × 3 libs = 6
// ============================================================

///|
test "gzip/compress/1k/fzip" (b : @bench.T) {
  let data = make_sequential(1024)
  b.bench(fn() { b.keep(@fzip.gzip_sync(data)) })
}

///|
test "gzip/compress/1k/moonzip" (b : @bench.T) {
  let data = make_sequential(1024)
  b.bench(fn() { b.keep(@moonzip.gzip_sync(data)) })
}

///|
test "gzip/compress/1k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(1024))
  b.bench(fn() { b.keep(@zlib.gzip_compress(data)) })
}

///|
test "gzip/compress/100k/fzip" (b : @bench.T) {
  let data = make_sequential(102400)
  b.bench(fn() { b.keep(@fzip.gzip_sync(data)) })
}

///|
test "gzip/compress/100k/moonzip" (b : @bench.T) {
  let data = make_sequential(102400)
  b.bench(fn() { b.keep(@moonzip.gzip_sync(data)) })
}

///|
test "gzip/compress/100k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(102400))
  b.bench(fn() { b.keep(@zlib.gzip_compress(data)) })
}

// ============================================================
// GZIP decompress — 2 sizes × 3 libs = 6
// ============================================================

///|
test "gzip/decompress/1k/fzip" (b : @bench.T) {
  let compressed = @fzip.gzip_sync(make_sequential(1024))
  b.bench(fn() { b.keep(try! @fzip.gunzip_sync(compressed)) })
}

///|
test "gzip/decompress/1k/moonzip" (b : @bench.T) {
  let compressed = @moonzip.gzip_sync(make_sequential(1024))
  b.bench(fn() { b.keep(try! @moonzip.gunzip_sync(compressed)) })
}

///|
test "gzip/decompress/1k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(1024))
  let compressed = @zlib.gzip_compress(data)
  b.bench(fn() { b.keep(try! @zlib.gzip_decompress(compressed)) })
}

///|
test "gzip/decompress/100k/fzip" (b : @bench.T) {
  let compressed = @fzip.gzip_sync(make_sequential(102400))
  b.bench(fn() { b.keep(try! @fzip.gunzip_sync(compressed)) })
}

///|
test "gzip/decompress/100k/moonzip" (b : @bench.T) {
  let compressed = @moonzip.gzip_sync(make_sequential(102400))
  b.bench(fn() { b.keep(try! @moonzip.gunzip_sync(compressed)) })
}

///|
test "gzip/decompress/100k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(102400))
  let compressed = @zlib.gzip_compress(data)
  b.bench(fn() { b.keep(try! @zlib.gzip_decompress(compressed)) })
}

// ============================================================
// Zlib compress — 2 sizes × 3 libs = 6
// ============================================================

///|
test "zlib/compress/1k/fzip" (b : @bench.T) {
  let data = make_sequential(1024)
  b.bench(fn() { b.keep(@fzip.zlib_sync(data)) })
}

///|
test "zlib/compress/1k/moonzip" (b : @bench.T) {
  let data = make_sequential(1024)
  b.bench(fn() { b.keep(@moonzip.zlib_sync(data)) })
}

///|
test "zlib/compress/1k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(1024))
  b.bench(fn() { b.keep(@zlib.zlib_compress(data)) })
}

///|
test "zlib/compress/100k/fzip" (b : @bench.T) {
  let data = make_sequential(102400)
  b.bench(fn() { b.keep(@fzip.zlib_sync(data)) })
}

///|
test "zlib/compress/100k/moonzip" (b : @bench.T) {
  let data = make_sequential(102400)
  b.bench(fn() { b.keep(@moonzip.zlib_sync(data)) })
}

///|
test "zlib/compress/100k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(102400))
  b.bench(fn() { b.keep(@zlib.zlib_compress(data)) })
}

// ============================================================
// Zlib decompress — 2 sizes × 3 libs = 6
// ============================================================

///|
test "zlib/decompress/1k/fzip" (b : @bench.T) {
  let compressed = @fzip.zlib_sync(make_sequential(1024))
  b.bench(fn() { b.keep(try! @fzip.unzlib_sync(compressed)) })
}

///|
test "zlib/decompress/1k/moonzip" (b : @bench.T) {
  let compressed = @moonzip.zlib_sync(make_sequential(1024))
  b.bench(fn() { b.keep(try! @moonzip.unzlib_sync(compressed)) })
}

///|
test "zlib/decompress/1k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(1024))
  let compressed = @zlib.zlib_compress(data)
  b.bench(fn() { b.keep(try! @zlib.zlib_decompress(compressed)) })
}

///|
test "zlib/decompress/100k/fzip" (b : @bench.T) {
  let compressed = @fzip.zlib_sync(make_sequential(102400))
  b.bench(fn() { b.keep(try! @fzip.unzlib_sync(compressed)) })
}

///|
test "zlib/decompress/100k/moonzip" (b : @bench.T) {
  let compressed = @moonzip.zlib_sync(make_sequential(102400))
  b.bench(fn() { b.keep(try! @moonzip.unzlib_sync(compressed)) })
}

///|
test "zlib/decompress/100k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(102400))
  let compressed = @zlib.zlib_compress(data)
  b.bench(fn() { b.keep(try! @zlib.zlib_decompress(compressed)) })
}

// ============================================================
// ZIP compress — 2 libs = 2 (mizchi/zlib has no ZIP API)
// ============================================================

///|
test "zip/compress/fzip" (b : @bench.T) {
  let files = make_zip_files()
  b.bench(fn() { b.keep(@fzip.zip_sync(files)) })
}

///|
test "zip/compress/moonzip" (b : @bench.T) {
  let files = make_zip_files()
  b.bench(fn() { b.keep(@moonzip.zip_sync(files)) })
}

// ============================================================
// ZIP decompress — 2 libs = 2 (mizchi/zlib has no ZIP API)
// ============================================================

///|
test "zip/decompress/fzip" (b : @bench.T) {
  let compressed = @fzip.zip_sync(make_zip_files())
  b.bench(fn() { b.keep(try! @fzip.unzip_sync(compressed)) })
}

///|
test "zip/decompress/moonzip" (b : @bench.T) {
  let compressed = @moonzip.zip_sync(make_zip_files())
  b.bench(fn() { b.keep(try! @moonzip.unzip_sync(compressed)) })
}

// ============================================================
// CRC-32 — 2 sizes × 3 libs = 6
// ============================================================

///|
test "crc32/1k/fzip" (b : @bench.T) {
  let data = make_sequential(1024)
  b.bench(fn() { b.keep(@fzip.crc32(data)) })
}

///|
test "crc32/1k/moonzip" (b : @bench.T) {
  let data = make_sequential(1024)
  b.bench(fn() { b.keep(@moonzip.crc32(data)) })
}

///|
test "crc32/1k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(1024))
  b.bench(fn() { b.keep(@zlib.crc32(data)) })
}

///|
test "crc32/100k/fzip" (b : @bench.T) {
  let data = make_sequential(102400)
  b.bench(fn() { b.keep(@fzip.crc32(data)) })
}

///|
test "crc32/100k/moonzip" (b : @bench.T) {
  let data = make_sequential(102400)
  b.bench(fn() { b.keep(@moonzip.crc32(data)) })
}

///|
test "crc32/100k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(102400))
  b.bench(fn() { b.keep(@zlib.crc32(data)) })
}

// ============================================================
// Adler-32 — 2 sizes × 3 libs = 6
// ============================================================

///|
test "adler32/1k/fzip" (b : @bench.T) {
  let data = make_sequential(1024)
  b.bench(fn() { b.keep(@fzip.adler32(data)) })
}

///|
test "adler32/1k/moonzip" (b : @bench.T) {
  let data = make_sequential(1024)
  b.bench(fn() { b.keep(@moonzip.adler32(data)) })
}

///|
test "adler32/1k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(1024))
  b.bench(fn() { b.keep(@zlib.adler32(data)) })
}

///|
test "adler32/100k/fzip" (b : @bench.T) {
  let data = make_sequential(102400)
  b.bench(fn() { b.keep(@fzip.adler32(data)) })
}

///|
test "adler32/100k/moonzip" (b : @bench.T) {
  let data = make_sequential(102400)
  b.bench(fn() { b.keep(@moonzip.adler32(data)) })
}

///|
test "adler32/100k/mizchi" (b : @bench.T) {
  let data = fa_to_bytes(make_sequential(102400))
  b.bench(fn() { b.keep(@zlib.adler32(data)) })
}

// ============================================================
// decompress_sync (auto-detect) — 2 sizes × 2 libs = 4 (mizchi N/A)
// ============================================================

///|
test "decompress/auto_detect/1k/fzip" (b : @bench.T) {
  let compressed = @fzip.gzip_sync(make_sequential(1024))
  b.bench(fn() { b.keep(try! @fzip.decompress_sync(compressed)) })
}

///|
test "decompress/auto_detect/1k/moonzip" (b : @bench.T) {
  let compressed = @moonzip.gzip_sync(make_sequential(1024))
  b.bench(fn() { b.keep(try! @moonzip.decompress_sync(compressed)) })
}

///|
test "decompress/auto_detect/100k/fzip" (b : @bench.T) {
  let compressed = @fzip.gzip_sync(make_sequential(102400))
  b.bench(fn() { b.keep(try! @fzip.decompress_sync(compressed)) })
}

///|
test "decompress/auto_detect/100k/moonzip" (b : @bench.T) {
  let compressed = @moonzip.gzip_sync(make_sequential(102400))
  b.bench(fn() { b.keep(try! @moonzip.decompress_sync(compressed)) })
}
