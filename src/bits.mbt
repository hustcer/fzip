///|
/// Read bits from data starting at bit position p, masked with m
fn bits(d : FixedArray[Byte], p : Int, m : Int) -> Int {
  let o = p / 8
  let v = d[o].to_int() |
    (if o + 1 < d.length() { d[o + 1].to_int() << 8 } else { 0 })
  (v >> (p & 7)) & m
}

///|
/// Read 16+ bits from data starting at bit position p
fn bits16(d : FixedArray[Byte], p : Int) -> Int {
  let o = p / 8
  let v = d[o].to_int() |
    (if o + 1 < d.length() { d[o + 1].to_int() << 8 } else { 0 }) |
    (if o + 2 < d.length() { d[o + 2].to_int() << 16 } else { 0 })
  v >> (p & 7)
}

///|
/// Get end of byte boundary
fn shft(p : Int) -> Int {
  (p + 7) / 8
}

///|
/// Write bits to data at bit position p
fn wbits(d : FixedArray[Byte], p : Int, v : Int) -> Unit {
  let v = v << (p & 7)
  let o = p / 8
  d[o] = (d[o].to_int() | v).to_byte()
  if o + 1 < d.length() {
    d[o + 1] = (d[o + 1].to_int() | (v >> 8)).to_byte()
  }
}

///|
/// Write 16+ bits to data at bit position p
fn wbits16(d : FixedArray[Byte], p : Int, v : Int) -> Unit {
  let v = v << (p & 7)
  let o = p / 8
  d[o] = (d[o].to_int() | v).to_byte()
  if o + 1 < d.length() {
    d[o + 1] = (d[o + 1].to_int() | (v >> 8)).to_byte()
  }
  if o + 2 < d.length() {
    d[o + 2] = (d[o + 2].to_int() | (v >> 16)).to_byte()
  }
}

///|
/// Read 2 bytes (little-endian) from data at offset b
fn b2(d : FixedArray[Byte], b : Int) -> Int {
  d[b].to_int() | (d[b + 1].to_int() << 8)
}

///|
/// Read 4 bytes (little-endian unsigned) from data at offset b
fn b4(d : FixedArray[Byte], b : Int) -> UInt {
  (d[b].to_int() |
  (d[b + 1].to_int() << 8) |
  (d[b + 2].to_int() << 16) |
  (d[b + 3].to_int() << 24)).reinterpret_as_uint()
}

///|
/// Read 8 bytes (little-endian) from data at offset b
fn b8(d : FixedArray[Byte], b : Int) -> Int64 {
  b4(d, b).to_int64() + b4(d, b + 4).to_int64() * 4294967296L
}

///|
/// Write bytes (little-endian) to data at offset b
fn wbytes(d : FixedArray[Byte], b : Int, v : Int) -> Unit {
  let mut v = v.reinterpret_as_uint()
  let mut b = b
  while v > 0U {
    d[b] = v.to_byte()
    v = v >> 8
    b += 1
  }
}

///|
/// Slice a FixedArray (copy)
fn slc(
  v : FixedArray[Byte],
  s : Int,
  e? : Int = v.length(),
) -> FixedArray[Byte] {
  let start = if s < 0 { 0 } else { s }
  let end = if e > v.length() { v.length() } else { e }
  let len = end - start
  if len <= 0 {
    return FixedArray::make(0, b'\x00')
  }
  let result = FixedArray::make(len, b'\x00')
  v.blit_to(result, len~, src_offset=start, dst_offset=0)
  result
}

///|
/// Copy from src to dst at offset
fn fa_set(
  dst : FixedArray[Byte],
  src : FixedArray[Byte],
  offset? : Int = 0,
) -> Unit {
  let len = if src.length() > dst.length() - offset {
    dst.length() - offset
  } else {
    src.length()
  }
  if len > 0 {
    src.blit_to(dst, len~, src_offset=0, dst_offset=offset)
  }
}

///|
/// Find max value in FixedArray
fn max_val(a : FixedArray[Byte]) -> Int {
  let mut m = a[0].to_int()
  for i in 1..<a.length() {
    if a[i].to_int() > m {
      m = a[i].to_int()
    }
  }
  m
}
