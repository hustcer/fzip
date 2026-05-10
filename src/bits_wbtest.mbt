///|
/// Read bits from data starting at bit position p, masked with m (test-only)
fn bits(d : FixedArray[Byte], p : Int, m : Int) -> Int {
  let o = p / 8
  let v = d[o].to_int() |
    (if o + 1 < d.length() { d[o + 1].to_int() << 8 } else { 0 })
  (v >> (p & 7)) & m
}

///|
/// Read 16+ bits from data starting at bit position p (test-only)
fn bits16(d : FixedArray[Byte], p : Int) -> Int {
  let o = p / 8
  let v = d[o].to_int() |
    (if o + 1 < d.length() { d[o + 1].to_int() << 8 } else { 0 }) |
    (if o + 2 < d.length() { d[o + 2].to_int() << 16 } else { 0 })
  v >> (p & 7)
}

///|
/// Read 8 bytes (little-endian) from data at offset b (test-only).
///
/// Production parsers must not use this for adversarial ZIP64 size /
/// offset / count fields — the result is a signed `Int64` and a value
/// with the high bit set silently overflows to negative. Use
/// `read_zip64_int` for any field that originates outside the writer.
/// `b8` stays here because the test fixtures need a quick raw 8-byte
/// reader and the inputs are trusted.
fn b8(d : FixedArray[Byte], b : Int) -> Int64 raise FzipError {
  if b + 7 >= d.length() {
    raise fzip_err(UnexpectedEOF, msg="not enough bytes for b8")
  }
  b4(d, b).to_int64() + b4(d, b + 4).to_int64() * 4294967296L
}

///|
test "bits - read bits from byte array" {
  let d : FixedArray[Byte] = [b'\xAB', b'\xCD', b'\xEF', b'\x00']
  inspect(bits(d, 0, 0xFF), content="171") // 0xAB
  inspect(bits(d, 0, 0x0F), content="11") // low nibble of 0xAB
  inspect(bits(d, 4, 0x0F), content="10") // high nibble of 0xAB = 0xA
  inspect(bits(d, 8, 0xFF), content="205") // 0xCD
}

///|
test "bits16 - read 16+ bits" {
  let d : FixedArray[Byte] = [b'\x01', b'\x02', b'\x03', b'\x00']
  let v = bits16(d, 0)
  inspect(v & 0xFFFF, content="513") // 0x0201
}

///|
test "shft - byte boundary" {
  inspect(shft(0), content="0")
  inspect(shft(1), content="1")
  inspect(shft(7), content="1")
  inspect(shft(8), content="1")
  inspect(shft(9), content="2")
}

///|
test "wbits / wbits16 - write bits" {
  let d : FixedArray[Byte] = FixedArray::make(4, b'\x00')
  wbits(d, 0, 0x05)
  inspect(d[0].to_int(), content="5")
  let d2 : FixedArray[Byte] = FixedArray::make(4, b'\x00')
  wbits16(d2, 0, 0x010203)
  inspect(d2[0].to_int(), content="3")
  inspect(d2[1].to_int(), content="2")
  inspect(d2[2].to_int(), content="1")
}

///|
test "b2 / b4 / b8 - read multi-byte values" {
  let d : FixedArray[Byte] = [
    b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
  ]
  inspect(b2(d, 0), content="513") // 0x0201
  inspect(b4(d, 0), content="67305985") // 0x04030201
  inspect(b8(d, 0), content="578437695752307201") // 0x0807060504030201
}

///|
test "wbytes - write little-endian bytes" {
  let d : FixedArray[Byte] = FixedArray::make(8, b'\x00')
  wbytes(d, 0, 0x04030201)
  inspect(d[0].to_int(), content="1")
  inspect(d[1].to_int(), content="2")
  inspect(d[2].to_int(), content="3")
  inspect(d[3].to_int(), content="4")
}

///|
test "slc - slice array" {
  let d : FixedArray[Byte] = [b'\x01', b'\x02', b'\x03', b'\x04', b'\x05']
  let s = slc(d, 1, e=4)
  inspect(s.length(), content="3")
  inspect(s[0].to_int(), content="2")
  inspect(s[2].to_int(), content="4")
}

///|
test "fa_set - copy array" {
  let dst : FixedArray[Byte] = FixedArray::make(5, b'\x00')
  let src : FixedArray[Byte] = [b'\x0A', b'\x0B', b'\x0C']
  fa_set(dst, src, offset=1)
  inspect(dst[0].to_int(), content="0")
  inspect(dst[1].to_int(), content="10")
  inspect(dst[3].to_int(), content="12")
}

///|
test "w2 - emits both bytes including leading zero" {
  let d : FixedArray[Byte] = FixedArray::make(4, b'\xFF')
  w2(d, 0, 0x002D) // version_needed = 45
  inspect(d[0].to_int(), content="45")
  inspect(d[1].to_int(), content="0")
  // Untouched bytes after the field stay as we left them.
  inspect(d[2].to_int(), content="255")
  // Full 16-bit value spans both bytes.
  w2(d, 2, 0xABCD)
  inspect(d[2].to_int(), content="205")
  inspect(d[3].to_int(), content="171")
}

///|
test "w4 - writes a four-byte little-endian unsigned value" {
  let d : FixedArray[Byte] = FixedArray::make(8, b'\x00')
  // Sentinel 0xFFFFFFFF must round-trip as four 0xFF bytes.
  w4(d, 0, 0xFFFFFFFFU)
  for i in 0..<4 {
    assert_eq(d[i].to_int(), 255)
  }
  // Mid-value with leading zero high byte must still emit four bytes.
  w4(d, 4, 0x00010203U)
  inspect(d[4].to_int(), content="3")
  inspect(d[5].to_int(), content="2")
  inspect(d[6].to_int(), content="1")
  inspect(d[7].to_int(), content="0")
}

///|
test "w8 - writes an eight-byte little-endian value" {
  let d : FixedArray[Byte] = FixedArray::make(16, b'\x00')
  // Small positive value: only the low byte is set; the upper seven must be 0.
  w8(d, 0, 1L)
  inspect(d[0].to_int(), content="1")
  for i in 1..<8 {
    assert_eq(d[i].to_int(), 0)
  }
  // Value larger than 32 bits crosses the 4-byte boundary.
  w8(d, 8, 0x0000_0001_0000_0000L)
  for i in 8..<12 {
    assert_eq(d[i].to_int(), 0)
  }
  inspect(d[12].to_int(), content="1")
  inspect(d[13].to_int(), content="0")
  inspect(d[14].to_int(), content="0")
  inspect(d[15].to_int(), content="0")
}
