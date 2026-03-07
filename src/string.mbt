///|
/// Convert a string to UTF-8 byte array
pub fn str_to_u8(s : String, latin1? : Bool = false) -> FixedArray[Byte] {
  if latin1 {
    let ar = FixedArray::make(s.length(), b'\x00')
    for i in 0..<s.length() {
      ar[i] = s[i].to_int().to_byte()
    }
    return ar
  }
  let l = s.length()
  let mut ar = FixedArray::make(l + (l >> 1) + 8, b'\x00')
  let mut ai = 0
  let mut i = 0
  while i < l {
    if ai + 5 > ar.length() {
      let n = FixedArray::make(ai + 8 + ((l - i) << 1), b'\x00')
      ar.blit_to(n, len=ai, src_offset=0, dst_offset=0)
      ar = n
    }
    let mut c = s[i].to_int()
    if c < 128 {
      ar[ai] = c.to_byte()
      ai += 1
    } else if c < 2048 {
      ar[ai] = (192 | (c >> 6)).to_byte()
      ai += 1
      ar[ai] = (128 | (c & 63)).to_byte()
      ai += 1
    } else if c > 55295 && c < 57344 {
      // surrogate pair: combine high + low surrogate into a single codepoint
      i += 1
      let low = if i < l { s[i].to_int() } else { 0 }
      c = (65536 + ((c & 1023) << 10)) | (low & 1023)
      ar[ai] = (240 | (c >> 18)).to_byte()
      ai += 1
      ar[ai] = (128 | ((c >> 12) & 63)).to_byte()
      ai += 1
      ar[ai] = (128 | ((c >> 6) & 63)).to_byte()
      ai += 1
      ar[ai] = (128 | (c & 63)).to_byte()
      ai += 1
    } else {
      ar[ai] = (224 | (c >> 12)).to_byte()
      ai += 1
      ar[ai] = (128 | ((c >> 6) & 63)).to_byte()
      ai += 1
      ar[ai] = (128 | (c & 63)).to_byte()
      ai += 1
    }
    i += 1
  }
  slc(ar, 0, e=ai)
}

///|
/// Convert UTF-8 byte array to a string
pub fn str_from_u8(
  data : FixedArray[Byte],
  latin1? : Bool = false,
  offset? : Int = 0,
  len? : Int = -1,
) -> String raise FzipError {
  let actual_len = if len < 0 { data.length() - offset } else { len }
  let end = offset + actual_len
  if latin1 {
    let buf = StringBuilder::new()
    for i in offset..<end {
      buf.write_char(data[i].to_int().unsafe_to_char())
    }
    return buf.to_string()
  }
  let buf = StringBuilder::new()
  let mut i = offset
  while i < end {
    let c = data[i].to_int()
    let eb = (if c > 127 { 1 } else { 0 }) +
      (if c > 223 { 1 } else { 0 }) +
      (if c > 239 { 1 } else { 0 })
    if i + eb >= end && eb > 0 {
      raise fzip_err(InvalidUTF8)
    }
    if eb == 0 {
      buf.write_char(c.unsafe_to_char())
      i += 1
    } else if eb == 3 {
      let v = (
          ((c & 15) << 18) |
          ((data[i + 1].to_int() & 63) << 12) |
          ((data[i + 2].to_int() & 63) << 6) |
          (data[i + 3].to_int() & 63)
        ) -
        65536
      buf.write_char((55296 | (v >> 10)).unsafe_to_char())
      buf.write_char((56320 | (v & 1023)).unsafe_to_char())
      i += 4
    } else if eb == 1 {
      buf.write_char(
        (((c & 31) << 6) | (data[i + 1].to_int() & 63)).unsafe_to_char(),
      )
      i += 2
    } else {
      buf.write_char(
        (((c & 15) << 12) |
        ((data[i + 1].to_int() & 63) << 6) |
        (data[i + 2].to_int() & 63)).unsafe_to_char(),
      )
      i += 3
    }
  }
  buf.to_string()
}
