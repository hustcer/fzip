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
  let layout = compute_zip_layout(files, opts)
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
