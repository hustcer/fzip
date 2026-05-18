///|
/// Encode a `String` into bytes.
///
/// By default this returns UTF-8 bytes. When `latin1` is `true`, each UTF-16
/// code unit is truncated to one byte, which is useful for legacy ZIP metadata
/// that is explicitly stored as Latin-1 compatible byte data.
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
  trim_buf(ar, ai)
}

///|
/// Decode bytes into a `String`.
///
/// The selected byte range is decoded as strict UTF-8 per RFC 3629. Any of the
/// following raise `InvalidUTF8`:
///
/// * continuation bytes (`0x80`-`0xBF`) appearing as a sequence start;
/// * overlong encodings (`0xC0 0x80` → U+0000, etc.);
/// * a continuation byte without the `10xxxxxx` prefix;
/// * surrogate code points (`U+D800`-`U+DFFF`);
/// * code points above `U+10FFFF`;
/// * 5- or 6-byte legacy UTF-8 sequences (start byte `>= 0xF5`).
///
/// Earlier versions of this function silently accepted these patterns, which
/// produced fzip-specific decoder output that disagreed with standard
/// libraries — a parser-differential risk for ZIP filenames where strict
/// rejection is preferred over silent corruption.
///
/// When `latin1` is `true`, every byte is mapped directly to the same Unicode
/// code point. `offset` and `len` select the input range.
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
    if c < 0x80 {
      // ASCII
      buf.write_char(c.unsafe_to_char())
      i += 1
    } else if c < 0xC2 {
      // 0x80-0xBF: continuation bytes cannot start a sequence.
      // 0xC0, 0xC1: would be overlong encodings of <= U+007F.
      raise fzip_err(InvalidUTF8)
    } else if c < 0xE0 {
      // 2-byte sequence: 0xC2-0xDF.
      if i + 1 >= end {
        raise fzip_err(InvalidUTF8)
      }
      let c1 = data[i + 1].to_int()
      if (c1 & 0xC0) != 0x80 {
        raise fzip_err(InvalidUTF8)
      }
      let cp = ((c & 0x1F) << 6) | (c1 & 0x3F)
      buf.write_char(cp.unsafe_to_char())
      i += 2
    } else if c < 0xF0 {
      // 3-byte sequence: 0xE0-0xEF.
      if i + 2 >= end {
        raise fzip_err(InvalidUTF8)
      }
      let c1 = data[i + 1].to_int()
      let c2 = data[i + 2].to_int()
      if (c1 & 0xC0) != 0x80 || (c2 & 0xC0) != 0x80 {
        raise fzip_err(InvalidUTF8)
      }
      let cp = ((c & 0x0F) << 12) | ((c1 & 0x3F) << 6) | (c2 & 0x3F)
      // Reject overlong encodings (codepoint < U+0800) and UTF-16 surrogate
      // code points (U+D800 .. U+DFFF) which are not valid Unicode scalars.
      if cp < 0x800 || (cp >= 0xD800 && cp <= 0xDFFF) {
        raise fzip_err(InvalidUTF8)
      }
      buf.write_char(cp.unsafe_to_char())
      i += 3
    } else if c < 0xF5 {
      // 4-byte sequence: 0xF0-0xF4.
      if i + 3 >= end {
        raise fzip_err(InvalidUTF8)
      }
      let c1 = data[i + 1].to_int()
      let c2 = data[i + 2].to_int()
      let c3 = data[i + 3].to_int()
      if (c1 & 0xC0) != 0x80 || (c2 & 0xC0) != 0x80 || (c3 & 0xC0) != 0x80 {
        raise fzip_err(InvalidUTF8)
      }
      let cp = ((c & 0x07) << 18) |
        ((c1 & 0x3F) << 12) |
        ((c2 & 0x3F) << 6) |
        (c3 & 0x3F)
      // 4-byte minimum is U+10000; max is U+10FFFF.
      if cp < 0x10000 || cp > 0x10FFFF {
        raise fzip_err(InvalidUTF8)
      }
      // Emit as a UTF-16 surrogate pair.
      let v = cp - 0x10000
      buf.write_char((0xD800 | (v >> 10)).unsafe_to_char())
      buf.write_char((0xDC00 | (v & 0x3FF)).unsafe_to_char())
      i += 4
    } else {
      // 0xF5-0xFF: outside RFC 3629 (legacy 5/6-byte starts or invalid).
      raise fzip_err(InvalidUTF8)
    }
  }
  buf.to_string()
}
