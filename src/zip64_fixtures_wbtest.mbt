// Cross-tool ZIP64 fixtures embedded as byte literals so `moon test` can
// exercise fzip's reader against archives written by independent tools
// (Python `zipfile.ZipFile.open(..., force_zip64=True)` and Info-ZIP
// `zip -X -fz`). Generators live in `tools/zip64-fixtures/`; the .zip
// outputs themselves are gitignored, so these literals are the canonical
// in-repo copy. Regenerate via the scripts and re-embed if the layout
// ever changes — both generators are deterministic, so the SHA-256s
// comments below pin the exact bytes.
//
// Both archives store the same two stored-mode entries:
//   hello.txt -> b"Hello, ZIP64!\n"            (14 bytes)
//   data.bin  -> 0x00 0x01 0x02 ... 0x0F        (16 bytes)
// Each entry advertises version_needed = 0x002D (= 45), the APPNOTE.txt
// marker for ZIP64.

///|
/// SHA-256 of the canonical generator output. If this comment and the
/// byte literal below disagree, regenerate via
/// `tools/zip64-fixtures/gen-python.py` and update both.
/// SHA-256: 3e15b0ee932b51a4057944292e6940f36e534b0e947135267b61bf83d9a84055
/// Bytes:   278
let python_force_zip64_fixture : FixedArray[Byte] = [
  b'\x50', b'\x4B', b'\x03', b'\x04', b'\x2D', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x21', b'\x00', b'\x7D', b'\xA4', b'\xC7', b'\x77',
  b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\x09',
  b'\x00', b'\x14', b'\x00', b'\x68', b'\x65', b'\x6C', b'\x6C', b'\x6F', b'\x2E',
  b'\x74', b'\x78', b'\x74', b'\x01', b'\x00', b'\x10', b'\x00', b'\x0E', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x0E', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x48', b'\x65', b'\x6C', b'\x6C',
  b'\x6F', b'\x2C', b'\x20', b'\x5A', b'\x49', b'\x50', b'\x36', b'\x34', b'\x21',
  b'\x0A', b'\x50', b'\x4B', b'\x03', b'\x04', b'\x2D', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x21', b'\x00', b'\x88', b'\xE2', b'\xCE',
  b'\xCE', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF',
  b'\x08', b'\x00', b'\x14', b'\x00', b'\x64', b'\x61', b'\x74', b'\x61', b'\x2E',
  b'\x62', b'\x69', b'\x6E', b'\x01', b'\x00', b'\x10', b'\x00', b'\x10', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x10', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x01', b'\x02', b'\x03',
  b'\x04', b'\x05', b'\x06', b'\x07', b'\x08', b'\x09', b'\x0A', b'\x0B', b'\x0C',
  b'\x0D', b'\x0E', b'\x0F', b'\x50', b'\x4B', b'\x01', b'\x02', b'\x2D', b'\x03',
  b'\x2D', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x21',
  b'\x00', b'\x7D', b'\xA4', b'\xC7', b'\x77', b'\x0E', b'\x00', b'\x00', b'\x00',
  b'\x0E', b'\x00', b'\x00', b'\x00', b'\x09', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x80', b'\x01',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x68', b'\x65', b'\x6C', b'\x6C', b'\x6F',
  b'\x2E', b'\x74', b'\x78', b'\x74', b'\x50', b'\x4B', b'\x01', b'\x02', b'\x2D',
  b'\x03', b'\x2D', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x21', b'\x00', b'\x88', b'\xE2', b'\xCE', b'\xCE', b'\x10', b'\x00', b'\x00',
  b'\x00', b'\x10', b'\x00', b'\x00', b'\x00', b'\x08', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x80',
  b'\x01', b'\x49', b'\x00', b'\x00', b'\x00', b'\x64', b'\x61', b'\x74', b'\x61',
  b'\x2E', b'\x62', b'\x69', b'\x6E', b'\x50', b'\x4B', b'\x05', b'\x06', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x02', b'\x00', b'\x02', b'\x00', b'\x6D', b'\x00',
  b'\x00', b'\x00', b'\x93', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
]

///|
/// SHA-256 of the canonical generator output. If this comment and the
/// byte literal below disagree, regenerate via
/// `tools/zip64-fixtures/gen-zip.sh` and update both.
/// SHA-256: 94463df34e356968bfdbf20bb2cac6280bde9f799a77722d98fb7be2502ffdcd
/// Bytes:   378
let infozip_zip64_fixture : FixedArray[Byte] = [
  b'\x50', b'\x4B', b'\x03', b'\x04', b'\x2D', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x21', b'\x00', b'\x7D', b'\xA4', b'\xC7', b'\x77',
  b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\x09',
  b'\x00', b'\x14', b'\x00', b'\x68', b'\x65', b'\x6C', b'\x6C', b'\x6F', b'\x2E',
  b'\x74', b'\x78', b'\x74', b'\x01', b'\x00', b'\x10', b'\x00', b'\x0E', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x0E', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x48', b'\x65', b'\x6C', b'\x6C',
  b'\x6F', b'\x2C', b'\x20', b'\x5A', b'\x49', b'\x50', b'\x36', b'\x34', b'\x21',
  b'\x0A', b'\x50', b'\x4B', b'\x03', b'\x04', b'\x2D', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x21', b'\x00', b'\x88', b'\xE2', b'\xCE',
  b'\xCE', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF',
  b'\x08', b'\x00', b'\x14', b'\x00', b'\x64', b'\x61', b'\x74', b'\x61', b'\x2E',
  b'\x62', b'\x69', b'\x6E', b'\x01', b'\x00', b'\x10', b'\x00', b'\x10', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x10', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x01', b'\x02', b'\x03',
  b'\x04', b'\x05', b'\x06', b'\x07', b'\x08', b'\x09', b'\x0A', b'\x0B', b'\x0C',
  b'\x0D', b'\x0E', b'\x0F', b'\x50', b'\x4B', b'\x01', b'\x02', b'\x1E', b'\x03',
  b'\x2D', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x21',
  b'\x00', b'\x7D', b'\xA4', b'\xC7', b'\x77', b'\x0E', b'\x00', b'\x00', b'\x00',
  b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\x09', b'\x00', b'\x0C', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x01', b'\x00', b'\x00', b'\x00', b'\xA4', b'\x81',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x68', b'\x65', b'\x6C', b'\x6C', b'\x6F',
  b'\x2E', b'\x74', b'\x78', b'\x74', b'\x01', b'\x00', b'\x08', b'\x00', b'\x0E',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x50', b'\x4B',
  b'\x01', b'\x02', b'\x1E', b'\x03', b'\x2D', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x21', b'\x00', b'\x88', b'\xE2', b'\xCE', b'\xCE',
  b'\x10', b'\x00', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\x08',
  b'\x00', b'\x0C', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\xA4', b'\x81', b'\x49', b'\x00', b'\x00', b'\x00', b'\x64',
  b'\x61', b'\x74', b'\x61', b'\x2E', b'\x62', b'\x69', b'\x6E', b'\x01', b'\x00',
  b'\x08', b'\x00', b'\x10', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x50', b'\x4B', b'\x06', b'\x06', b'\x2C', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x1E', b'\x03', b'\x2D', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x02', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x02', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x85', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x93', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x00', b'\x50', b'\x4B', b'\x06', b'\x07', b'\x00', b'\x00',
  b'\x00', b'\x00', b'\x18', b'\x01', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  b'\x00', b'\x01', b'\x00', b'\x00', b'\x00', b'\x50', b'\x4B', b'\x05', b'\x06',
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x02', b'\x00', b'\x02', b'\x00', b'\x85',
  b'\x00', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\x00', b'\x00',
]

///|
/// The expected uncompressed bytes for hello.txt in both fixtures.
let zip64_fixture_hello_bytes : FixedArray[Byte] = [
  b'\x48', b'\x65', b'\x6C', b'\x6C', b'\x6F', b'\x2C', b'\x20', b'\x5A', b'\x49',
  b'\x50', b'\x36', b'\x34', b'\x21', b'\x0A',
]

///|
/// The expected uncompressed bytes for data.bin in both fixtures.
let zip64_fixture_data_bytes : FixedArray[Byte] = [
  b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
  b'\x09', b'\x0A', b'\x0B', b'\x0C', b'\x0D', b'\x0E', b'\x0F',
]

///|
/// Helper: assert that `unzip_list` reports the canonical two-entry
/// stored-mode layout shared by both cross-tool fixtures.
fn assert_cross_tool_listing(fixture : FixedArray[Byte]) -> Unit raise {
  let infos = unzip_list(fixture)
  assert_eq(infos.length(), 2)
  assert_eq(infos[0].name, "hello.txt")
  assert_eq(infos[0].original_size, 14)
  assert_eq(infos[0].size, 14)
  assert_eq(infos[0].compression, 0)
  assert_eq(infos[1].name, "data.bin")
  assert_eq(infos[1].original_size, 16)
  assert_eq(infos[1].size, 16)
  assert_eq(infos[1].compression, 0)
}

///|
/// Helper: assert that `unzip_sync` extracts the canonical bytes for both
/// entries in the cross-tool fixture.
fn assert_cross_tool_extraction(fixture : FixedArray[Byte]) -> Unit raise {
  let files = unzip_sync(fixture)
  assert_eq(files.length(), 2)
  let (n0, c0) = files[0]
  assert_eq(n0, "hello.txt")
  assert_eq(c0.length(), zip64_fixture_hello_bytes.length())
  for i in 0..<c0.length() {
    assert_eq(c0[i], zip64_fixture_hello_bytes[i])
  }
  let (n1, c1) = files[1]
  assert_eq(n1, "data.bin")
  assert_eq(c1.length(), zip64_fixture_data_bytes.length())
  for i in 0..<c1.length() {
    assert_eq(c1[i], zip64_fixture_data_bytes[i])
  }
}

///|
test "cross-tool ZIP64 (Python zipfile force_zip64=True) - unzip_list" {
  assert_cross_tool_listing(python_force_zip64_fixture)
}

///|
test "cross-tool ZIP64 (Python zipfile force_zip64=True) - unzip_sync" {
  assert_cross_tool_extraction(python_force_zip64_fixture)
}

///|
test "cross-tool ZIP64 (Info-ZIP zip -X -fz) - unzip_list" {
  assert_cross_tool_listing(infozip_zip64_fixture)
}

///|
test "cross-tool ZIP64 (Info-ZIP zip -X -fz) - unzip_sync" {
  assert_cross_tool_extraction(infozip_zip64_fixture)
}

///|
/// Surface the writer's own ZIP64 sentinel + extra-field layout in CD by
/// inspecting the per-entry `version_needed` byte. A canonical Python /
/// Info-ZIP ZIP64 archive must show 0x2D (= 45) in the low byte of both
/// the local-file-header `version_needed` and the central directory
/// `version_made_by` / `version_needed` fields. The exact CD start
/// position is found through the trailing classic EOCD's CD-offset
/// field; both fixtures keep CD offset under 4 GiB so the classic
/// 32-bit field carries the real value (no ZIP64 promotion of cd_offset
/// is needed for these tiny archives — only the per-entry sizes are
/// promoted via the local-header ZIP64 extra).
test "cross-tool ZIP64 fixtures - both stamp version_needed=45 in LFH" {
  // LFH version_needed at offset +4 (low byte = ZIP spec, high byte = OS
  // compatibility marker; Python uses 0, Info-ZIP also uses 0).
  assert_eq(python_force_zip64_fixture[4].to_int(), 45)
  assert_eq(infozip_zip64_fixture[4].to_int(), 45)
}
