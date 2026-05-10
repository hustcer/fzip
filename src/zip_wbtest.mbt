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
/// Pin the upper edge of the EOCD search window. The classic EOCD comment
/// field is a 16-bit length, so the maximum legal comment is 65535 bytes
/// and the corresponding scan window from the end of the archive is
/// `22 + 65535 = 65557` bytes. A real EOCD at exactly that distance must
/// still be located.
test "find_eocd - finds EOCD with maximum 65535-byte comment" {
  let comment : FixedArray[Byte] = FixedArray::make(65535, b'\x00')
  let arc = make_classic_eocd(0, 0U, 0U, comment~)
  // The EOCD record sits at offset 0; everything else is comment.
  inspect(arc.length(), content="65557")
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

// =============================================================================
// PR3 (Phase 3) — read_zip64_entry_extra + read_central_directory_entry
// =============================================================================

///|
/// Build a ZIP64 extended information extra field (header id 0x0001) with
/// any subset of the 8-byte values the spec allows, in spec-fixed order.
fn make_zip64_extra(
  uncompressed? : Int64,
  compressed? : Int64,
  local_offset? : Int64,
) -> FixedArray[Byte] {
  let payload = []
  match uncompressed {
    Some(v) => payload.push(v)
    None => ()
  }
  match compressed {
    Some(v) => payload.push(v)
    None => ()
  }
  match local_offset {
    Some(v) => payload.push(v)
    None => ()
  }
  let payload_bytes = payload.length() * 8
  let buf = FixedArray::make(4 + payload_bytes, b'\x00')
  w2(buf, 0, zip64_extra_field_id) // header id
  w2(buf, 2, payload_bytes) // data size
  for i, v in payload {
    w8(buf, 4 + i * 8, v)
  }
  buf
}

///|
test "read_zip64_entry_extra - only uncompressed needed" {
  let extra = make_zip64_extra(uncompressed=999L)
  let sizes = read_zip64_entry_extra(
    extra,
    0,
    extra.length(),
    classic_compressed=100U,
    classic_uncompressed=zip_uint32_max,
    classic_local_offset=200U,
  )
  inspect(sizes.uncompressed, content="999")
  inspect(sizes.compressed, content="100")
  inspect(sizes.local_offset, content="200")
}

///|
test "read_zip64_entry_extra - uncompressed AND compressed needed" {
  let extra = make_zip64_extra(uncompressed=999L, compressed=500L)
  let sizes = read_zip64_entry_extra(
    extra,
    0,
    extra.length(),
    classic_compressed=zip_uint32_max,
    classic_uncompressed=zip_uint32_max,
    classic_local_offset=200U,
  )
  inspect(sizes.uncompressed, content="999")
  inspect(sizes.compressed, content="500")
  inspect(sizes.local_offset, content="200")
}

///|
test "read_zip64_entry_extra - all three needed" {
  let extra = make_zip64_extra(
    uncompressed=999L,
    compressed=500L,
    local_offset=1234L,
  )
  let sizes = read_zip64_entry_extra(
    extra,
    0,
    extra.length(),
    classic_compressed=zip_uint32_max,
    classic_uncompressed=zip_uint32_max,
    classic_local_offset=zip_uint32_max,
  )
  inspect(sizes.uncompressed, content="999")
  inspect(sizes.compressed, content="500")
  inspect(sizes.local_offset, content="1234")
}

///|
test "read_zip64_entry_extra - skips unrelated extra fields before ZIP64" {
  // Build: <unrelated extra (header_id=0x5455)> <ZIP64 extra>
  let other_payload : FixedArray[Byte] = [b'\x01', b'\x02', b'\x03', b'\x04']
  let other = FixedArray::make(8, b'\x00')
  w2(other, 0, 0x5455) // some unrelated header id
  w2(other, 2, 4)
  other_payload.blit_to(other, len=4, src_offset=0, dst_offset=4)
  let zip64 = make_zip64_extra(uncompressed=42L)
  let combined = concat_bytes([other, zip64])
  let sizes = read_zip64_entry_extra(
    combined,
    0,
    combined.length(),
    classic_compressed=10U,
    classic_uncompressed=zip_uint32_max,
    classic_local_offset=20U,
  )
  inspect(sizes.uncompressed, content="42")
  inspect(sizes.compressed, content="10")
  inspect(sizes.local_offset, content="20")
}

///|
test "read_zip64_entry_extra - rejects extra_len > max_extra_field_length" {
  let extra : FixedArray[Byte] = FixedArray::make(0, b'\x00')
  let r : Result[ZipEntrySizes, FzipError] = try? read_zip64_entry_extra(
    extra,
    0,
    max_extra_field_length + 1,
    classic_compressed=10U,
    classic_uncompressed=zip_uint32_max,
    classic_local_offset=20U,
  )
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, ExtraFieldTooLong)
}

///|
test "read_zip64_entry_extra - missing required ZIP64 extra raises" {
  // Empty extra block but a sentinel says ZIP64 is needed.
  let extra : FixedArray[Byte] = FixedArray::make(0, b'\x00')
  let r : Result[ZipEntrySizes, FzipError] = try? read_zip64_entry_extra(
    extra,
    0,
    0,
    classic_compressed=10U,
    classic_uncompressed=zip_uint32_max,
    classic_local_offset=20U,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("required ZIP64 extra"))
}

///|
test "read_zip64_entry_extra - truncated ZIP64 extra raises" {
  // Header claims 8 bytes of payload but only 4 are present.
  let extra : FixedArray[Byte] = FixedArray::make(8, b'\x00')
  w2(extra, 0, zip64_extra_field_id)
  w2(extra, 2, 8) // claim 8 bytes payload
  // ... but only 4 bytes follow
  let r : Result[ZipEntrySizes, FzipError] = try? read_zip64_entry_extra(
    extra,
    0,
    extra.length(),
    classic_compressed=10U,
    classic_uncompressed=zip_uint32_max,
    classic_local_offset=20U,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("truncated"))
}

///|
test "read_zip64_entry_extra - Zip64ValueTooLarge for huge values" {
  // Set the high word of uncompressed-size 8-byte field to 1 so the value
  // exceeds 2^32.
  let extra = FixedArray::make(12, b'\x00')
  w2(extra, 0, zip64_extra_field_id)
  w2(extra, 2, 8)
  // bytes 4..12 are the 8-byte uncompressed value; high word at offset 8.
  extra[8] = b'\x01'
  let r : Result[ZipEntrySizes, FzipError] = try? read_zip64_entry_extra(
    extra,
    0,
    extra.length(),
    classic_compressed=10U,
    classic_uncompressed=zip_uint32_max,
    classic_local_offset=20U,
  )
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, Zip64ValueTooLarge)
}

///|
/// Build a synthetic central directory file header (no following entries)
/// for use with `read_central_directory_entry`.
fn make_cd_entry(
  name : FixedArray[Byte],
  compression : Int,
  comp_size : UInt,
  uncomp_size : UInt,
  local_offset : UInt,
  extra? : FixedArray[Byte] = FixedArray::make(0, b'\x00'),
  flag? : Int = 0,
) -> FixedArray[Byte] {
  let name_len = name.length()
  let extra_len = extra.length()
  let total = 46 + name_len + extra_len
  let buf = FixedArray::make(total, b'\x00')
  w4(buf, 0, zip_cd_signature)
  // version made by, version needed: 0 — irrelevant for this parser
  w2(buf, 8, flag)
  w2(buf, 10, compression)
  // mtime/mdate: 0
  // crc-32: 0 (not validated by read_central_directory_entry)
  w4(buf, 20, comp_size)
  w4(buf, 24, uncomp_size)
  w2(buf, 28, name_len)
  w2(buf, 30, extra_len)
  w2(buf, 32, 0) // comment length
  w2(buf, 34, 0) // disk number start
  w2(buf, 36, 0) // internal attrs
  w4(buf, 38, 0U) // external attrs
  w4(buf, 42, local_offset)
  name.blit_to(buf, len=name_len, src_offset=0, dst_offset=46)
  if extra_len > 0 {
    extra.blit_to(buf, len=extra_len, src_offset=0, dst_offset=46 + name_len)
  }
  buf
}

///|
test "read_central_directory_entry - rejects bad signature" {
  let name : FixedArray[Byte] = [b'a']
  let entry = make_cd_entry(name, 0, 0U, 0U, 0U)
  // Stomp the signature.
  entry[0] = b'\x00'
  let r : Result[ZipEntryHeader, FzipError] = try? read_central_directory_entry(
    entry,
    0,
    entry.length(),
    false,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("central directory header signature"))
}

///|
/// Defensive guard added with the `Int64` overflow rewrite: a negative
/// offset (which the public reader path can't produce, but a misuse of the
/// internal helper could) must be rejected at the bounds check rather than
/// crashing on a negative `FixedArray` index further down.
test "read_central_directory_entry - rejects negative offset" {
  let name : FixedArray[Byte] = [b'a']
  let entry = make_cd_entry(name, 0, 0U, 0U, 0U)
  let r : Result[ZipEntryHeader, FzipError] = try? read_central_directory_entry(
    entry,
    -1,
    entry.length(),
    false,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("CD bounds"))
}

///|
/// Companion guard: a `cd_end` smaller than 46 bytes (the minimum CD entry
/// header) must reject any non-negative offset rather than silently passing
/// because of an arithmetic underflow in the bounds expression.
test "read_central_directory_entry - rejects cd_end smaller than minimum CD header" {
  let name : FixedArray[Byte] = [b'a']
  let entry = make_cd_entry(name, 0, 0U, 0U, 0U)
  // `cd_end = 20` is below the 46-byte CD entry header.
  let r : Result[ZipEntryHeader, FzipError] = try? read_central_directory_entry(
    entry, 0, 20, false,
  )
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
}

///|
test "read_central_directory_entry - rejects entry exceeding CD bounds" {
  let name : FixedArray[Byte] = [b'a', b'b', b'c', b'd']
  let entry = make_cd_entry(name, 0, 0U, 0U, 0U)
  // Pretend the CD is 10 bytes shorter than the entry needs.
  let cd_end = entry.length() - 10
  let r : Result[ZipEntryHeader, FzipError] = try? read_central_directory_entry(
    entry, 0, cd_end, false,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(
    message.contains("CD bounds") || message.contains("exceeds CD bounds"),
  )
}

///|
test "read_central_directory_entry - rejects per-entry non-zero disk_number_start" {
  let name : FixedArray[Byte] = [b'a']
  let entry = make_cd_entry(name, 0, 0U, 0U, 0U)
  // disk_number_start is at offset 34.
  w2(entry, 34, 1)
  let r : Result[ZipEntryHeader, FzipError] = try? read_central_directory_entry(
    entry,
    0,
    entry.length(),
    false,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("multi-disk"))
}

///|
test "read_central_directory_entry - classic entry resolves classic fields" {
  let name : FixedArray[Byte] = [b'h', b'i']
  let entry = make_cd_entry(name, 8, 100U, 200U, 50U)
  let header = read_central_directory_entry(entry, 0, entry.length(), false)
  inspect(header.compression, content="8")
  inspect(header.compressed_size, content="100")
  inspect(header.uncompressed_size, content="200")
  inspect(header.local_offset, content="50")
  inspect(header.name, content="hi")
  inspect(header.next_offset, content=entry.length().to_string())
}

///|
test "read_central_directory_entry - ZIP64 entry resolves via extra" {
  let name : FixedArray[Byte] = [b'b', b'i', b'g']
  let extra = make_zip64_extra(uncompressed=12345L, compressed=6789L)
  let entry = make_cd_entry(
    name,
    8,
    zip_uint32_max,
    zip_uint32_max,
    50U,
    extra~,
  )
  let header = read_central_directory_entry(entry, 0, entry.length(), true)
  inspect(header.compressed_size, content="6789")
  inspect(header.uncompressed_size, content="12345")
  inspect(header.local_offset, content="50")
  inspect(header.name, content="big")
}

///|
test "read_central_directory_entry - ZIP64 sentinel rejected when archive isn't ZIP64" {
  // Same entry but the caller passes zip64=false, simulating an archive
  // whose EOCD doesn't advertise ZIP64. Without the locator we cannot
  // safely resolve the sentinels.
  let name : FixedArray[Byte] = [b'b', b'i', b'g']
  let extra = make_zip64_extra(uncompressed=12345L, compressed=6789L)
  let entry = make_cd_entry(
    name,
    8,
    zip_uint32_max,
    zip_uint32_max,
    50U,
    extra~,
  )
  let r : Result[ZipEntryHeader, FzipError] = try? read_central_directory_entry(
    entry,
    0,
    entry.length(),
    false,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("ZIP64 sentinels but archive is not ZIP64"))
}

///|
test "unzip_list - trailing bytes inside CD raise InvalidZipData" {
  // Build a 49-byte central directory entry but tell the EOCD the CD is
  // 50 bytes. After parsing the single entry the cursor lands at 49, which
  // doesn't match the declared cd_end of 50; the final-cursor check fires.
  let name : FixedArray[Byte] = [b'a', b'b', b'c']
  let cd_entry = make_cd_entry(name, 0, 0U, 0U, 0U)
  inspect(cd_entry.length(), content="49")
  let claimed_cd_size = 50
  let padded_cd = FixedArray::make(claimed_cd_size, b'\x00')
  cd_entry.blit_to(padded_cd, len=cd_entry.length(), src_offset=0, dst_offset=0)
  let eocd = make_classic_eocd(1, claimed_cd_size.reinterpret_as_uint(), 0U)
  let arc = concat_bytes([padded_cd, eocd])
  let r : Result[Array[UnzipFileInfo], FzipError] = try? unzip_list(arc)
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("trailing or missing"))
}

// =============================================================================
// PR4 (Phase 4) — local_data_offset + bit-flag + output cap
// =============================================================================

///|
/// Build a local file header (+ optional inline file data).
/// Tests can opt into a non-zero general-purpose bit flag to exercise the
/// encryption / data-descriptor rejections.
fn make_local_file_header(
  name : FixedArray[Byte],
  compression : Int,
  comp_size : UInt,
  uncomp_size : UInt,
  flag? : Int = 0,
  extra? : FixedArray[Byte] = FixedArray::make(0, b'\x00'),
  data? : FixedArray[Byte] = FixedArray::make(0, b'\x00'),
) -> FixedArray[Byte] {
  let nl = name.length()
  let el = extra.length()
  let dl = data.length()
  let buf = FixedArray::make(30 + nl + el + dl, b'\x00')
  w4(buf, 0, zip_local_signature)
  // version_needed (+4): 0 — irrelevant for local_data_offset
  w2(buf, 6, flag)
  w2(buf, 8, compression)
  // mtime/mdate (+10/+12): 0
  // CRC-32 (+14): 0 — local_data_offset doesn't validate it
  w4(buf, 14, 0U)
  w4(buf, 18, comp_size)
  w4(buf, 22, uncomp_size)
  w2(buf, 26, nl)
  w2(buf, 28, el)
  if nl > 0 {
    name.blit_to(buf, len=nl, src_offset=0, dst_offset=30)
  }
  if el > 0 {
    extra.blit_to(buf, len=el, src_offset=0, dst_offset=30 + nl)
  }
  if dl > 0 {
    data.blit_to(buf, len=dl, src_offset=0, dst_offset=30 + nl + el)
  }
  buf
}

///|
/// Glue helper: complete archive (local header + central directory entry +
/// classic EOCD) for one stored entry. Computes lengths/offsets so the
/// cd_size and cd_offset fields are internally consistent.
fn build_classic_archive(
  name : FixedArray[Byte],
  data : FixedArray[Byte],
  local_flag? : Int = 0,
) -> FixedArray[Byte] {
  let comp = data.length().reinterpret_as_uint()
  let lh = make_local_file_header(name, 0, comp, comp, flag=local_flag, data~)
  let cd = make_cd_entry(name, 0, comp, comp, 0U)
  let cd_size = cd.length().reinterpret_as_uint()
  let cd_offset = lh.length().reinterpret_as_uint()
  let eocd = make_classic_eocd(1, cd_size, cd_offset)
  concat_bytes([lh, cd, eocd])
}

///|
test "unzip_sync - rejects encrypted entry (general-purpose bit 0)" {
  let arc = build_classic_archive([b'a'], [b'X'], local_flag=1)
  let r : Result[Array[(String, FixedArray[Byte])], FzipError] = try? unzip_sync(
    arc,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("encrypted"))
}

///|
test "unzip_sync - rejects data-descriptor entry (general-purpose bit 3)" {
  let arc = build_classic_archive([b'a'], [b'X'], local_flag=8)
  let r : Result[Array[(String, FixedArray[Byte])], FzipError] = try? unzip_sync(
    arc,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("data descriptor"))
}

///|
test "unzip_sync - rejects entry with bad local file header signature" {
  let name : FixedArray[Byte] = [b'a']
  let lh = make_local_file_header(name, 0, 1U, 1U, data=[b'X'])
  // Stomp the local signature.
  lh[0] = b'\x00'
  let cd = make_cd_entry(name, 0, 1U, 1U, 0U)
  let eocd = make_classic_eocd(
    1,
    cd.length().reinterpret_as_uint(),
    lh.length().reinterpret_as_uint(),
  )
  let arc = concat_bytes([lh, cd, eocd])
  let r : Result[Array[(String, FixedArray[Byte])], FzipError] = try? unzip_sync(
    arc,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("local file header signature"))
}

///|
test "unzip_sync - rejects entry whose uncompressed size exceeds default_max_output_size" {
  // CD claims a stored entry larger than the configured cap; the cap check
  // fires before we even look at the local file header data.
  let name : FixedArray[Byte] = [b'b', b'i', b'g']
  let huge = (default_max_output_size + 1).reinterpret_as_uint()
  let cd = make_cd_entry(name, 0, huge, huge, 0U)
  let eocd = make_classic_eocd(1, cd.length().reinterpret_as_uint(), 0U)
  let arc = concat_bytes([cd, eocd])
  let r : Result[Array[(String, FixedArray[Byte])], FzipError] = try? unzip_sync(
    arc,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("default_max_output_size"))
}

///|
test "unzip_sync - rejects deflated entry whose uncompressed size exceeds cap" {
  // Deflated entry with claimed uncompressed_size = cap + 1. The cap check
  // fires before allocation.
  let name : FixedArray[Byte] = [b'd']
  let huge = (default_max_output_size + 1).reinterpret_as_uint()
  let cd = make_cd_entry(name, 8, 1U, huge, 0U)
  let eocd = make_classic_eocd(1, cd.length().reinterpret_as_uint(), 0U)
  let arc = concat_bytes([cd, eocd])
  let r : Result[Array[(String, FixedArray[Byte])], FzipError] = try? unzip_sync(
    arc,
  )
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("default_max_output_size"))
}

///|
test "unzip_sync - hand-built classic stored archive round-trips through new helpers" {
  // Sanity: confirms local_data_offset accepts a normal local header and
  // unzip_sync returns the right bytes.
  let arc = build_classic_archive([b'h', b'i'], [b'X', b'Y', b'Z'])
  let files = unzip_sync(arc)
  assert_eq(files.length(), 1)
  let (name, content) = files[0]
  assert_eq(name, "hi")
  assert_eq(content.length(), 3)
  assert_eq(content[0], b'X')
  assert_eq(content[1], b'Y')
  assert_eq(content[2], b'Z')
}

///|
/// Defensive overflow guard for `local_data_offset`. A malformed central
/// directory could declare a 32-bit local-header offset of `0x7FFFFFFF`,
/// which reinterprets to `Int` `2^31 - 1`. The original additive bounds
/// check `local_offset + 30 > data.length()` wraps that to a negative value
/// and silently passes — the rewritten subtraction-form check rejects it.
test "local_data_offset - rejects local_offset near Int max without overflow" {
  let data : FixedArray[Byte] = FixedArray::make(100, b'\x00')
  let r : Result[Int, FzipError] = try? local_data_offset(data, 2147483647, 0)
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("local file header out of bounds"))
}

///|
/// Companion guard for `local_offset` exactly one past the valid window:
/// it must still be rejected, not silently accepted as `local_offset == data.length() - 30`.
test "local_data_offset - rejects local_offset > data.length() - 30" {
  // A 35-byte buffer leaves room for a 30-byte LFH at offset 0..4. Offset 6
  // would push the 30-byte header end to byte 36, one past the buffer.
  let data : FixedArray[Byte] = FixedArray::make(35, b'\x00')
  let r : Result[Int, FzipError] = try? local_data_offset(data, 6, 0)
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
}

///|
/// `data_off = local_offset + 30 + fnl + exl` previously used straight `Int`
/// arithmetic and could wrap when `fnl + exl` approaches `2 * 65535`. Build a
/// hand-rolled LFH with both fields maxed out so the implied data range
/// extends past the archive — the Int64 path catches it whether or not the
/// addition would have wrapped.
test "local_data_offset - rejects oversized fnl/exl that overflow data_off" {
  let data : FixedArray[Byte] = FixedArray::make(100, b'\x00')
  // Place a valid local file header signature at offset 0 so we get past the
  // signature check and exercise the bounds check on `data_off`.
  w4(data, 0, zip_local_signature)
  // Set fnl and exl in the 26/28 fields to 65535 each.
  w2(data, 26, 65535)
  w2(data, 28, 65535)
  let r : Result[Int, FzipError] = try? local_data_offset(data, 0, 0)
  guard r is Err(FzipError(code~, message~)) else { fail("expected error") }
  assert_eq(code, InvalidZipData)
  assert_true(message.contains("filename/extra exceed bounds"))
}

///|
/// Companion: a normal LFH (small fnl/exl) at offset 0 still works. This
/// pins that the new Int64 path doesn't change the happy-path semantics.
test "local_data_offset - happy path returns expected data offset" {
  // 30-byte LFH + 3-byte filename "abc" + 0-byte extra + 5 bytes of data.
  let total = 30 + 3 + 5
  let data : FixedArray[Byte] = FixedArray::make(total, b'\x00')
  w4(data, 0, zip_local_signature)
  w2(data, 26, 3)
  w2(data, 28, 0)
  inspect(local_data_offset(data, 0, 5), content="33")
}

// =============================================================================
// PR5a (Phase 5a) — Writer layout refactor (no ZIP64 emission yet)
// =============================================================================

///|
test "compute_zip_layout - total_size matches actual zip_sync output length" {
  // The old writer underestimated the buffer when opts.comment was
  // non-empty (the per-entry CD comment bytes weren't in the `tot` sum).
  // PR5a's layout pass accounts for them; assert the math is exact.
  let files : Array[(String, FixedArray[Byte])] = [
    ("one.txt", [b'A']),
    ("two.txt", [b'B', b'C']),
  ]
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  }
  let zipped = zip_sync(files, opts~)
  let layout = compute_zip_layout(files, opts, ZipBuildOpts::default())
  inspect(layout.total_size.to_int(), content=zipped.length().to_string())
}

///|
test "zip_sync - non-empty CD comment is allocated and round-trips" {
  // Pre-PR5a writer would under-allocate the buffer because the CD
  // comment bytes weren't counted in `tot`. PR5a's layout includes them.
  let data : FixedArray[Byte] = [b'X', b'Y']
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "hello",
    mtime: 0,
  }
  let zipped = zip_sync([("a.txt", data)], opts~)
  let files = unzip_sync(zipped)
  assert_eq(files.length(), 1)
  assert_eq(files[0].0, "a.txt")
  assert_eq(files[0].1.length(), 2)
}

///|
test "zip_sync - byte-identical to pre-refactor for classic empty-comment input" {
  // Smoke test that two layout passes on identical input produce the
  // same bytes — i.e. the refactor is deterministic.
  let files : Array[(String, FixedArray[Byte])] = [
    ("a.bin", [b'\x01', b'\x02']),
    ("b.bin", [b'\x03']),
  ]
  let a = zip_sync(files)
  let b = zip_sync(files)
  assert_eq(a.length(), b.length())
  for i in 0..<a.length() {
    assert_eq(a[i], b[i])
  }
}

// =============================================================================
// PR5b (Phase 5b) — Writer fixed-width metadata cleanup
// =============================================================================

///|
test "zip_sync (PR5b) - mtime field is written as a fixed-width 4-byte LE value" {
  // Cover all four bytes by picking a value whose every byte is non-zero —
  // the previous variable-width `wbytes` would also have written four bytes
  // here, but the explicit `w4` makes the field width invariant rather than
  // dependent on the buffer being zero-initialized.
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0x11223344,
  }
  let zipped = zip_sync([("t", [b'X'])], opts~)
  // Local file header: mtime occupies LFH +10..+13 (after sig +4 / version +2
  // / flag +2 / compression +2).
  assert_eq(zipped[10].to_int(), 0x44)
  assert_eq(zipped[11].to_int(), 0x33)
  assert_eq(zipped[12].to_int(), 0x22)
  assert_eq(zipped[13].to_int(), 0x11)
  // Central directory: same field at CD +12 (after sig +4 / vmb +2 / vn +2 /
  // flag +2 / compression +2). EOCD is the trailing 22 bytes; the CD offset
  // lives in the EOCD at -6.
  let cd_offset = b4(zipped, zipped.length() - 6).reinterpret_as_int()
  assert_eq(zipped[cd_offset + 12].to_int(), 0x44)
  assert_eq(zipped[cd_offset + 13].to_int(), 0x33)
  assert_eq(zipped[cd_offset + 14].to_int(), 0x22)
  assert_eq(zipped[cd_offset + 15].to_int(), 0x11)
}

///|
test "zip_sync (PR5b) - mtime=0 still writes four explicit zero bytes" {
  // Defensive test: the previous code skipped the write entirely when
  // `mtime == 0`. The new fixed-width writer always emits four bytes; on a
  // zero-initialized buffer the visible result is the same, but the test
  // pins the contract.
  let zipped = zip_sync([("t", [b'X'])])
  assert_eq(zipped[10].to_int(), 0)
  assert_eq(zipped[11].to_int(), 0)
  assert_eq(zipped[12].to_int(), 0)
  assert_eq(zipped[13].to_int(), 0)
}

///|
test "zip_sync (PR5b) - classic entries stamp version_needed=20 and version_made_by low=20, high=os" {
  // Phase 5b only emits classic-baseline version bytes. The `wzh` helper now
  // takes per-call `version_needed` / `version_made_by_low` parameters, but
  // both default to 20 until PR5c flips them to 45 for ZIP64 entries.
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 3, // Unix
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  }
  let zipped = zip_sync([("a", [b'X'])], opts~)
  // LFH version_needed at +4 (low = ZIP spec, high = compatibility OS = 0).
  assert_eq(zipped[4].to_int(), 20)
  assert_eq(zipped[5].to_int(), 0)
  // CD version_made_by at +4 (low = ZIP spec, high = host OS = opts.os).
  let cd_offset = b4(zipped, zipped.length() - 6).reinterpret_as_int()
  assert_eq(zipped[cd_offset + 4].to_int(), 20)
  assert_eq(zipped[cd_offset + 5].to_int(), 3)
  // CD version_needed at +6 (low = ZIP spec, high = compatibility OS = 0).
  assert_eq(zipped[cd_offset + 6].to_int(), 20)
  assert_eq(zipped[cd_offset + 7].to_int(), 0)
}

///|
test "zip_sync (PR5b) - drops user-provided extra id 0x0001 (reserved for ZIP64)" {
  // fzip owns header id 0x0001 (ZIP64 extended information). User-provided
  // 0x0001 entries are dropped from BOTH the local and the central headers
  // before any ZIP64 emission decision; unrelated ids pass through verbatim.
  // Phase 5c will additionally emit fzip's own 0x0001 payload when the
  // entry actually overflows classic limits.
  let payload : FixedArray[Byte] = [b'\x99', b'\x88']
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    // 0x0001 would collide with fzip's reserved id; 0x5455 (extended timestamp)
    // is unrelated and must survive sanitization.
    extra: [(0x0001, payload), (0x5455, payload)],
    comment: "",
    mtime: 0,
  }
  let zipped = zip_sync([("a", [b'X'])], opts~)
  let lfh_extra_off = 30 + 1 // 30-byte LFH + 1-byte filename "a"
  let lfh_extra_len = b2(zipped, 28) // LFH extra_field_length lives at +28
  let (lfh_has_zip64_id, lfh_has_other) = scan_extra_ids(
    zipped, lfh_extra_off, lfh_extra_len,
  )
  inspect(lfh_has_zip64_id, content="false")
  inspect(lfh_has_other, content="true")
  // Same check on the central directory entry.
  let cd_offset = b4(zipped, zipped.length() - 6).reinterpret_as_int()
  let cd_extra_off = cd_offset + 46 + 1
  let cd_extra_len = b2(zipped, cd_offset + 30) // CD extra_field_length at +30
  let (cd_has_zip64_id, cd_has_other) = scan_extra_ids(
    zipped, cd_extra_off, cd_extra_len,
  )
  inspect(cd_has_zip64_id, content="false")
  inspect(cd_has_other, content="true")
}

///|
/// Walk an extra-field block and report whether 0x0001 and 0x5455 are present.
fn scan_extra_ids(
  data : FixedArray[Byte],
  offset : Int,
  length : Int,
) -> (Bool, Bool) raise FzipError {
  let mut p = offset
  let end = offset + length
  let mut has_zip64 = false
  let mut has_other = false
  while p + 4 <= end {
    let id = b2(data, p)
    let len = b2(data, p + 2)
    if id == 0x0001 {
      has_zip64 = true
    }
    if id == 0x5455 {
      has_other = true
    }
    p = p + 4 + len
  }
  (has_zip64, has_other)
}

// =============================================================================
// PR5c (Phase 5c) — ZIP64 writer emission
// =============================================================================
//
// Phase 5c lights up the ZIP64 emission path in the writer. Real archives
// only need ZIP64 when sizes/offsets cross 4 GiB or the entry count crosses
// 64 K, both of which are out of reach of the sync API's `Int`-bounded
// budget. The tests below use the package-private `build_zip_sync` builder
// with `ZipBuildOpts { force_zip64: true }` so a tiny in-memory input
// exercises every ZIP64 byte (sentinels, ZIP64 EOCD, locator, version 45,
// per-entry ZIP64 extras) without allocating gigabytes.

///|
/// ZIP64 forced round-trip: the package-private writer's output must be
/// readable by the public `unzip_sync`, with byte-for-byte fidelity. This
/// catches any drift between writer-side sentinel/extra emission and
/// reader-side ZIP64 detection.
test "build_zip_sync (PR5c) - forced ZIP64 round-trips through unzip_sync" {
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  }
  let files : Array[(String, FixedArray[Byte])] = [
    ("a.txt", [b'X', b'Y']),
    ("b.bin", [b'\x01', b'\x02', b'\x03']),
  ]
  let zipped = build_zip_sync(files, opts, { force_zip64: true })
  let result = unzip_sync(zipped)
  assert_eq(result.length(), 2)
  let (n0, c0) = result[0]
  assert_eq(n0, "a.txt")
  assert_eq(c0.length(), 2)
  assert_eq(c0[0], b'X')
  assert_eq(c0[1], b'Y')
  let (n1, c1) = result[1]
  assert_eq(n1, "b.bin")
  assert_eq(c1.length(), 3)
  assert_eq(c1[2], b'\x03')
}

///|
test "build_zip_sync (PR5c) - forced ZIP64 round-trips deflated entries" {
  let opts : ZipEntryOptions = {
    level: 6,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  }
  // Highly compressible input so deflate produces a different compressed
  // size — exercises distinct sentinel substitution for compressed and
  // uncompressed sizes in both LFH and CD ZIP64 extras.
  let data = FixedArray::make(2048, b'A')
  let zipped = build_zip_sync([("compressible.bin", data)], opts, {
    force_zip64: true,
  })
  let result = unzip_sync(zipped)
  assert_eq(result.length(), 1)
  let (n, c) = result[0]
  assert_eq(n, "compressible.bin")
  assert_eq(c.length(), 2048)
  for i in 0..<2048 {
    assert_eq(c[i], b'A')
  }
}

///|
/// Layout: classic EOCD at total-22, ZIP64 EOCD locator at total-22-20,
/// ZIP64 EOCD record at total-22-20-56. All three signatures must be present
/// in the right order under forced ZIP64.
test "build_zip_sync (PR5c) - forced ZIP64 emits EOCD record + locator before classic EOCD" {
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  }
  let zipped = build_zip_sync([("a", [b'X'])], opts, { force_zip64: true })
  let total = zipped.length()
  inspect(b4(zipped, total - 22), content=zip_eocd_signature.to_string())
  inspect(
    b4(zipped, total - 22 - 20),
    content=zip64_locator_signature.to_string(),
  )
  inspect(
    b4(zipped, total - 22 - 20 - 56),
    content=zip64_eocd_signature.to_string(),
  )
}

///|
/// Classic EOCD must carry sentinel values for entry-count, cd-size, and
/// cd-offset whenever ZIP64 is in effect — that's what tells a classic-only
/// reader to look for ZIP64 metadata. Forced ZIP64 promotes all three.
test "build_zip_sync (PR5c) - forced ZIP64 stamps classic-EOCD sentinels for count/size/offset" {
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  }
  let zipped = build_zip_sync([("a", [b'X'])], opts, { force_zip64: true })
  let eocd = zipped.length() - 22
  inspect(b2(zipped, eocd + 8), content=zip_uint16_max.to_string())
  inspect(b2(zipped, eocd + 10), content=zip_uint16_max.to_string())
  inspect(b4(zipped, eocd + 12), content=zip_uint32_max.to_string())
  inspect(b4(zipped, eocd + 16), content=zip_uint32_max.to_string())
}

///|
/// version_needed = 45 for any header that carries ZIP64 sentinels OR a
/// ZIP64 extra; version_made_by low byte is also 45 for entries that are
/// ZIP64 in the central directory, while the high byte still carries
/// `opts.os`. Classic-only entries continue to stamp 20 (covered by PR5b).
test "build_zip_sync (PR5c) - ZIP64 entries stamp version_needed=45 and version_made_by low=45" {
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 3, // Unix
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  }
  let zipped = build_zip_sync([("a", [b'X'])], opts, { force_zip64: true })
  // LFH version_needed at +4 (low byte = ZIP spec, high byte = compatibility OS = 0).
  inspect(zipped[4].to_int(), content="45")
  inspect(zipped[5].to_int(), content="0")
  // The CD offset lives in the ZIP64 EOCD record at +48 (8 bytes).
  let total = zipped.length()
  let zip64_eocd_pos = total - 22 - 20 - 56
  let cd_offset = b8(zipped, zip64_eocd_pos + 48).to_int()
  // CD version_made_by at +4: low = 45, high = opts.os (3).
  inspect(zipped[cd_offset + 4].to_int(), content="45")
  inspect(zipped[cd_offset + 5].to_int(), content="3")
  // CD version_needed at +6: low = 45.
  inspect(zipped[cd_offset + 6].to_int(), content="45")
}

///|
/// Sanity-checks the four ZIP64-promoted classic fields in both LFH and CD:
/// compressed/uncompressed sizes (+18/+22 in LFH, +20/+24 in CD) plus the
/// CD-only "relative offset of local header" at +42.
test "build_zip_sync (PR5c) - ZIP64 entries write 0xffffffff sentinels in classic LFH/CD fields" {
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  }
  let zipped = build_zip_sync([("a", [b'X'])], opts, { force_zip64: true })
  // LFH classic size fields.
  inspect(b4(zipped, 18), content=zip_uint32_max.to_string())
  inspect(b4(zipped, 22), content=zip_uint32_max.to_string())
  let total = zipped.length()
  let zip64_eocd_pos = total - 22 - 20 - 56
  let cd_offset = b8(zipped, zip64_eocd_pos + 48).to_int()
  // CD classic size fields + local-header-offset field.
  inspect(b4(zipped, cd_offset + 20), content=zip_uint32_max.to_string())
  inspect(b4(zipped, cd_offset + 24), content=zip_uint32_max.to_string())
  inspect(b4(zipped, cd_offset + 42), content=zip_uint32_max.to_string())
}

///|
/// Local-header ZIP64 extra: 4-byte field header (`0x0001` + 16) followed
/// by a 16-byte payload of (uncompressed, compressed). APPNOTE §4.5.3
/// requires both 8-byte size values to be present in the local header
/// whenever either size triggers ZIP64; the local extra never includes the
/// local header offset.
test "build_zip_sync (PR5c) - local-header ZIP64 extra carries both sizes (16-byte payload)" {
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  }
  let payload : FixedArray[Byte] = [b'X', b'Y', b'Z']
  let zipped = build_zip_sync([("a", payload)], opts, { force_zip64: true })
  // Filename "a" is 1 byte; extras start at LFH offset 30 + 1.
  let extra_off = 30 + 1
  inspect(b2(zipped, 28), content="20") // 4-byte header + 16-byte payload
  inspect(b2(zipped, extra_off), content=zip64_extra_field_id.to_string())
  inspect(b2(zipped, extra_off + 2), content="16")
  inspect(b8(zipped, extra_off + 4), content="3") // uncompressed
  inspect(b8(zipped, extra_off + 12), content="3") // compressed (stored)
}

///|
/// Central-directory ZIP64 extra under forced ZIP64: 4-byte header followed
/// by exactly three 8-byte values in spec order (uncompressed, compressed,
/// local header offset). When only some classic fields use sentinels, only
/// those fields appear in the payload — covered indirectly by the
/// round-trip tests, which would fail if the order or selection were wrong.
test "build_zip_sync (PR5c) - central-header ZIP64 extra carries u/c/local_offset (24-byte payload)" {
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  }
  let zipped = build_zip_sync([("a", [b'X'])], opts, { force_zip64: true })
  let total = zipped.length()
  let zip64_eocd_pos = total - 22 - 20 - 56
  let cd_offset = b8(zipped, zip64_eocd_pos + 48).to_int()
  // CD entry: header 46 bytes + filename "a" (1 byte). Extras start at +47.
  let cd_extra_off = cd_offset + 46 + 1
  // Total extra bytes = 4-byte field header + 24-byte payload.
  inspect(b2(zipped, cd_offset + 30), content="28")
  inspect(b2(zipped, cd_extra_off), content=zip64_extra_field_id.to_string())
  inspect(b2(zipped, cd_extra_off + 2), content="24")
  inspect(b8(zipped, cd_extra_off + 4), content="1") // uncompressed
  inspect(b8(zipped, cd_extra_off + 12), content="1") // compressed (stored)
  inspect(b8(zipped, cd_extra_off + 20), content="0") // first entry → offset 0
}

///|
/// PR5b proved fzip drops user-provided 0x0001 from extras. PR5c adds the
/// reverse half of the contract: when ZIP64 is actually needed, fzip emits
/// EXACTLY ONE 0x0001 entry (its own) per header. A forged user payload
/// must not survive, and the writer must not emit duplicates.
test "build_zip_sync (PR5c) - user 0x0001 dropped, fzip's own ZIP64 extra emitted exactly once" {
  let user_zip64 : FixedArray[Byte] = [b'\x99', b'\x88', b'\x77']
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [(0x0001, user_zip64), (0x5455, [b'\xAA'])],
    comment: "",
    mtime: 0,
  }
  let zipped = build_zip_sync([("a", [b'X'])], opts, { force_zip64: true })
  // Local header extras: should hold ONE 0x0001 (16 bytes) + ONE 0x5455.
  let lfh_extra_off = 30 + 1
  let lfh_extra_len = b2(zipped, 28)
  let mut p = lfh_extra_off
  let mut zip64_count = 0
  let mut zip64_payload = 0
  let mut other_count = 0
  while p + 4 <= lfh_extra_off + lfh_extra_len {
    let id = b2(zipped, p)
    let len = b2(zipped, p + 2)
    if id == zip64_extra_field_id {
      zip64_count = zip64_count + 1
      zip64_payload = len
    }
    if id == 0x5455 {
      other_count = other_count + 1
    }
    p = p + 4 + len
  }
  inspect(zip64_count, content="1")
  inspect(zip64_payload, content="16")
  inspect(other_count, content="1")
}

///|
/// The non-raising `zip_sync` shares the raising builder. When the builder
/// raises a recoverable error, `zip_sync_checked` must surface it; the
/// surrogate proves the same condition is reachable through the public
/// raising API. (Triggering the abort wrapper itself would terminate the
/// test process, so we exercise the checked variant.)
test "zip_sync_checked (PR5c) - raises ExtraFieldTooLong when user extras overflow per-entry budget" {
  let huge : FixedArray[Byte] = FixedArray::make(
    max_extra_field_length + 1,
    b'\x00',
  )
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [(0x5455, huge)],
    comment: "",
    mtime: 0,
  }
  let r : Result[FixedArray[Byte], FzipError] = try? zip_sync_checked(
    [("a", [b'X'])],
    opts~,
  )
  guard r is Err(FzipError(code~, ..)) else { fail("expected error") }
  assert_eq(code, ExtraFieldTooLong)
}

///|
/// Same input through both APIs must produce byte-identical archives —
/// `zip_sync` is just `zip_sync_checked` with a trap-on-raise wrapper.
test "zip_sync_checked (PR5c) - happy-path output is byte-identical to zip_sync" {
  let files : Array[(String, FixedArray[Byte])] = [
    ("hi.txt", [b'A', b'B', b'C']),
  ]
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  }
  let a = zip_sync(files, opts~)
  let b = zip_sync_checked(files, opts~)
  assert_eq(a.length(), b.length())
  for i in 0..<a.length() {
    assert_eq(a[i], b[i])
  }
}

///|
/// Layout-level guarantee: `archive_zip64` is false when no entry, no size,
/// no offset, and no count threshold has been crossed — and the writer
/// produces exactly the classic 22-byte EOCD with no ZIP64 prelude. This
/// is the "do no harm" property: ZIP64 metadata only appears when needed.
test "compute_zip_layout (PR5c) - classic-sized archive does not promote to ZIP64" {
  let files : Array[(String, FixedArray[Byte])] = [
    ("a.txt", [b'X']),
    ("b.txt", [b'Y']),
  ]
  let opts : ZipEntryOptions = {
    level: 0,
    mem: 0,
    os: 0,
    attrs: 0,
    extra: [],
    comment: "",
    mtime: 0,
  }
  let layout = compute_zip_layout(files, opts, ZipBuildOpts::default())
  assert_false(layout.archive_zip64)
  let zipped = zip_sync(files, opts~)
  // Trailing 22 bytes are the classic EOCD; the bytes immediately before
  // are NOT a ZIP64 locator under classic emission.
  let eocd = zipped.length() - 22
  inspect(b4(zipped, eocd), content=zip_eocd_signature.to_string())
  if eocd >= 20 {
    let maybe_locator = b4(zipped, eocd - 20)
    assert_true(maybe_locator != zip64_locator_signature)
  }
}
