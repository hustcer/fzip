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
