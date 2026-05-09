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

// =============================================================================
// PR2 (Phase 2) — Hand-built fixtures for find_eocd + read_central_directory_info
// =============================================================================

///|
/// Build a classic 22-byte EOCD record with optional comment.
/// Entries on disk and total are set to the same value; tweak with `w2`
/// after the call when a multi-disk-style mismatch is needed for tests.
fn make_classic_eocd(
  entries : Int,
  cd_size : UInt,
  cd_offset : UInt,
  comment? : FixedArray[Byte] = FixedArray::make(0, b'\x00'),
) -> FixedArray[Byte] {
  let comment_len = comment.length()
  let buf = FixedArray::make(22 + comment_len, b'\x00')
  w4(buf, 0, zip_eocd_signature)
  w2(buf, 8, entries)
  w2(buf, 10, entries)
  w4(buf, 12, cd_size)
  w4(buf, 16, cd_offset)
  w2(buf, 20, comment_len)
  if comment_len > 0 {
    comment.blit_to(buf, len=comment_len, src_offset=0, dst_offset=22)
  }
  buf
}

///|
/// Build a 56-byte ZIP64 EOCD record (record_size = 44).
/// All disk/entries/size/offset fields default to zero.
fn make_zip64_eocd_record(
  entries? : Int64 = 0L,
  cd_size? : Int64 = 0L,
  cd_offset? : Int64 = 0L,
) -> FixedArray[Byte] {
  let buf = FixedArray::make(56, b'\x00')
  w4(buf, 0, zip64_eocd_signature)
  // record size = 44 (bytes after this field)
  w8(buf, 4, 44L)
  // version_made_by (+12), version_needed (+14): zero for tests
  // disk number (+16), disk-with-CD (+20): zero
  w8(buf, 24, entries)
  w8(buf, 32, entries)
  w8(buf, 40, cd_size)
  w8(buf, 48, cd_offset)
  buf
}

///|
/// Build a 20-byte ZIP64 EOCD locator pointing at `zip64_eocd_offset`.
fn make_zip64_locator(zip64_eocd_offset : Int64) -> FixedArray[Byte] {
  let buf = FixedArray::make(20, b'\x00')
  w4(buf, 0, zip64_locator_signature)
  // disk-containing-zip64-EOCD (+4): zero
  w8(buf, 8, zip64_eocd_offset)
  w4(buf, 16, 1U) // total disks
  buf
}

///|
/// Concatenate byte buffers into a single FixedArray.
fn concat_bytes(parts : Array[FixedArray[Byte]]) -> FixedArray[Byte] {
  let mut total = 0
  for p in parts {
    total += p.length()
  }
  let buf = FixedArray::make(total, b'\x00')
  let mut o = 0
  for p in parts {
    p.blit_to(buf, len=p.length(), src_offset=0, dst_offset=o)
    o += p.length()
  }
  buf
}

///|
test "find_eocd - basic empty archive" {
  let arc = make_classic_eocd(0, 0U, 0U)
  inspect(find_eocd(arc), content="0")
}

///|
test "find_eocd - data too short raises InvalidZipData" {
  let arc : FixedArray[Byte] = FixedArray::make(10, b'\x00')
  let r : Result[Int, FzipError] = try? find_eocd(arc)
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
}

///|
test "find_eocd - no signature raises InvalidZipData" {
  // 22 bytes, all zeros — signature won't match.
  let arc : FixedArray[Byte] = FixedArray::make(22, b'\x00')
  let r : Result[Int, FzipError] = try? find_eocd(arc)
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
}

///|
test "find_eocd - signature buried in comment is ignored" {
  // Real EOCD at archive offset 0 with a 30-byte comment. Embed an EOCD
  // signature at archive offset 30 (= comment offset 8). Without the
  // comment-length consistency check, the backward scan starts at offset 30
  // and would mis-identify the buried signature as the EOCD. The check
  // rejects it because the implied comment_length doesn't match.
  let comment = FixedArray::make(30, b'\x00')
  w4(comment, 8, zip_eocd_signature)
  // Archive offset 50 (comment offset 28) is what would be read as
  // comment_length for the false candidate. Make it non-zero.
  comment[28] = b'\x01'
  let arc = make_classic_eocd(0, 0U, 0U, comment~)
  inspect(find_eocd(arc), content="0")
}

///|
test "find_eocd - finds EOCD with non-empty comment" {
  let comment : FixedArray[Byte] = [b'h', b'e', b'l', b'l', b'o']
  let arc = make_classic_eocd(0, 0U, 0U, comment~)
  inspect(find_eocd(arc), content="0")
}

///|
test "read_central_directory_info - basic classic archive" {
  let arc = make_classic_eocd(0, 0U, 0U)
  let eocd = find_eocd(arc)
  let cd = read_central_directory_info(arc, eocd)
  inspect(cd.entries, content="0")
  inspect(cd.size, content="0")
  inspect(cd.offset, content="0")
  inspect(cd.zip64, content="false")
}

///|
test "read_central_directory_info - rejects non-zero disk_num (multi-disk)" {
  let arc = make_classic_eocd(0, 0U, 0U)
  // Override disk_num at +4 from 0 to 1.
  w2(arc, 4, 1)
  let eocd = find_eocd(arc)
  let r : Result[ZipCdInfo, FzipError] = try? read_central_directory_info(
    arc, eocd,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("multi-disk"))
}

///|
test "read_central_directory_info - rejects mismatched entries_disk vs entries_total" {
  let arc = make_classic_eocd(5, 0U, 0U)
  // entries_disk at +8, entries_total at +10. Make them differ.
  w2(arc, 8, 5)
  w2(arc, 10, 7)
  let eocd = find_eocd(arc)
  let r : Result[ZipCdInfo, FzipError] = try? read_central_directory_info(
    arc, eocd,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("multi-disk"))
}

///|
test "read_central_directory_info - rejects CD bounds beyond archive" {
  // Claim CD size of 100 bytes starting at offset 1000 in a 22-byte archive.
  let arc = make_classic_eocd(1, 100U, 1000U)
  let eocd = find_eocd(arc)
  let r : Result[ZipCdInfo, FzipError] = try? read_central_directory_info(
    arc, eocd,
  )
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
}

///|
test "read_central_directory_info - 65535 entries without locator stays classic" {
  // Classic archive with exactly 65535 entries and no ZIP64 metadata is
  // legal and must NOT be misclassified as ZIP64.
  let arc = make_classic_eocd(65535, 0U, 0U)
  let eocd = find_eocd(arc)
  let cd = read_central_directory_info(arc, eocd)
  inspect(cd.entries, content="65535")
  inspect(cd.zip64, content="false")
}

///|
test "read_central_directory_info - sentinel CD offset without locator raises" {
  // CD-offset sentinel without a ZIP64 locator must error rather than silently
  // truncating to a bogus 32-bit value.
  let arc = make_classic_eocd(1, 0U, 0xFFFFFFFFU)
  let eocd = find_eocd(arc)
  let r : Result[ZipCdInfo, FzipError] = try? read_central_directory_info(
    arc, eocd,
  )
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
}

///|
test "read_central_directory_info - reads ZIP64 EOCD/locator" {
  // Tiny empty ZIP64 archive: ZIP64 EOCD record at offset 0, locator at 56,
  // classic EOCD with sentinels at 76. Total 98 bytes.
  let z64_record = make_zip64_eocd_record()
  let z64_loc = make_zip64_locator(0L)
  let classic = make_classic_eocd(0xFFFF, 0U, 0U)
  let arc = concat_bytes([z64_record, z64_loc, classic])
  inspect(arc.length(), content="98")
  let eocd = find_eocd(arc)
  inspect(eocd, content="76")
  let cd = read_central_directory_info(arc, eocd)
  inspect(cd.entries, content="0")
  inspect(cd.size, content="0")
  inspect(cd.offset, content="0")
  inspect(cd.zip64, content="true")
}

///|
test "read_central_directory_info - rejects ZIP64 EOCD with wrong record signature" {
  let z64_record = make_zip64_eocd_record()
  // Corrupt the ZIP64 EOCD record signature.
  z64_record[0] = b'\x00'
  let z64_loc = make_zip64_locator(0L)
  let classic = make_classic_eocd(0xFFFF, 0U, 0U)
  let arc = concat_bytes([z64_record, z64_loc, classic])
  let eocd = find_eocd(arc)
  let r : Result[ZipCdInfo, FzipError] = try? read_central_directory_info(
    arc, eocd,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("ZIP64 EOCD record signature"))
}

///|
test "read_central_directory_info - rejects locator with non-zero disks (multi-disk)" {
  let z64_record = make_zip64_eocd_record()
  let z64_loc = make_zip64_locator(0L)
  // Force disk-containing-ZIP64-EOCD = 1 in the locator (offset +4).
  w4(z64_loc, 4, 1U)
  let classic = make_classic_eocd(0xFFFF, 0U, 0U)
  let arc = concat_bytes([z64_record, z64_loc, classic])
  let eocd = find_eocd(arc)
  let r : Result[ZipCdInfo, FzipError] = try? read_central_directory_info(
    arc, eocd,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("multi-disk"))
}

///|
test "read_central_directory_info - rejects ZIP64 EOCD record size < 44" {
  let z64_record = make_zip64_eocd_record()
  // Stomp the record size to 43.
  w8(z64_record, 4, 43L)
  let z64_loc = make_zip64_locator(0L)
  let classic = make_classic_eocd(0xFFFF, 0U, 0U)
  let arc = concat_bytes([z64_record, z64_loc, classic])
  let eocd = find_eocd(arc)
  let r : Result[ZipCdInfo, FzipError] = try? read_central_directory_info(
    arc, eocd,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("ZIP64 EOCD record size too small"))
}

///|
test "read_central_directory_info - Zip64ValueTooLarge for huge CD size" {
  let z64_record = make_zip64_eocd_record()
  // Set CD size at +40 to a value with high word = 1 (= 2^32, beyond Int range).
  z64_record[40 + 4] = b'\x01'
  let z64_loc = make_zip64_locator(0L)
  let classic = make_classic_eocd(0xFFFF, 0xFFFFFFFFU, 0U)
  let arc = concat_bytes([z64_record, z64_loc, classic])
  let eocd = find_eocd(arc)
  let r : Result[ZipCdInfo, FzipError] = try? read_central_directory_info(
    arc, eocd,
  )
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, Zip64ValueTooLarge)
}

///|
test "read_central_directory_info - rejects ZIP64 EOCD record overlapping locator" {
  // Locator at offset 100 claims the ZIP64 EOCD lives at offset 95: only 5
  // bytes before the locator, less than the 12-byte minimum header. The
  // overlap check must reject this before signature/size reads happen.
  let prefix : FixedArray[Byte] = FixedArray::make(100, b'\x00')
  let z64_loc = make_zip64_locator(95L)
  // Set both entries AND CD-offset sentinels so the parser must follow the
  // locator (the count-only fallback would otherwise hide the bug).
  let classic = make_classic_eocd(0xFFFF, 0U, 0xFFFFFFFFU)
  let arc = concat_bytes([prefix, z64_loc, classic])
  let eocd = find_eocd(arc)
  let r : Result[ZipCdInfo, FzipError] = try? read_central_directory_info(
    arc, eocd,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("overlaps locator"))
}

///|
test "unzip_sync / unzip_list - empty ZIP64 archive end-to-end" {
  // Build the same archive used by `read_central_directory_info` and verify
  // both public APIs accept it.
  let arc = concat_bytes([
    make_zip64_eocd_record(),
    make_zip64_locator(0L),
    make_classic_eocd(0xFFFF, 0U, 0U),
  ])
  let files = unzip_sync(arc)
  inspect(files.length(), content="0")
  let infos = unzip_list(arc)
  inspect(infos.length(), content="0")
}
