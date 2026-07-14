///|
/// Convert fzip's little-endian footer representation to the canonical
/// Adler-32 value used by RFC 1950 DICTID fields.
fn footer_adler_to_rfc1950(value : UInt) -> UInt {
  ((value & 0x000000FFU) << 24) |
  ((value & 0x0000FF00U) << 8) |
  ((value & 0x00FF0000U) >> 8) |
  ((value & 0xFF000000U) >> 24)
}

///|
/// Write a Zlib DICTID in RFC 1950 network byte order.
fn write_zlib_dict_id(
  data : FixedArray[Byte],
  offset : Int,
  value : UInt,
) -> Unit {
  data[offset] = (value >> 24).to_byte()
  data[offset + 1] = (value >> 16).to_byte()
  data[offset + 2] = (value >> 8).to_byte()
  data[offset + 3] = value.to_byte()
}

///|
/// Read a Zlib DICTID in RFC 1950 network byte order.
fn read_zlib_dict_id(
  data : FixedArray[Byte],
  offset : Int,
) -> UInt raise FzipError {
  if offset < 0 || offset > data.length() - 4 {
    raise fzip_err(InvalidHeader, msg="invalid zlib dictionary ID")
  }
  (data[offset].to_uint() << 24) |
  (data[offset + 1].to_uint() << 16) |
  (data[offset + 2].to_uint() << 8) |
  data[offset + 3].to_uint()
}

///|
/// Write Zlib header
fn zlh(c : FixedArray[Byte], o : ZlibOptions) -> Unit {
  let lv = o.level
  let fl_val = if lv == 0 {
    0
  } else if lv < 6 {
    1
  } else if lv == 9 {
    3
  } else {
    2
  }
  c[0] = b'\x78' // CMF: CM=8, CINFO=7
  let has_dict = match o.dictionary {
    Some(_) => 32
    None => 0
  }
  c[1] = ((fl_val << 6) | has_dict).to_byte()
  // fix check bits
  let check = ((c[0].to_int() << 8) | c[1].to_int()) % 31
  c[1] = (c[1].to_int() | (31 - check)).to_byte()
  match o.dictionary {
    Some(dict) => {
      let h = AdlerState::new()
      h.push(dict)
      write_zlib_dict_id(c, 2, footer_adler_to_rfc1950(h.digest()))
    }
    None => ()
  }
}

///|
/// Parse Zlib header and return data start offset
fn zls(
  d : FixedArray[Byte],
  dictionary : FixedArray[Byte]?,
) -> Int raise FzipError {
  if d.length() < 2 {
    raise fzip_err(InvalidHeader, msg="invalid zlib data")
  }
  if (d[0].to_int() & 15) != 8 ||
    d[0].to_int() >> 4 > 7 ||
    ((d[0].to_int() << 8) | d[1].to_int()) % 31 != 0 {
    raise fzip_err(InvalidHeader, msg="invalid zlib data")
  }
  let dict_flag = (d[1].to_int() >> 5) & 1
  match (dict_flag, dictionary) {
    (1, None) =>
      raise fzip_err(InvalidHeader, msg="invalid zlib data: need dictionary")
    (0, Some(_)) =>
      raise fzip_err(
        InvalidHeader,
        msg="invalid zlib data: unexpected dictionary",
      )
    (1, Some(dict)) => {
      let expected_dict_id = read_zlib_dict_id(d, 2)
      if footer_adler_to_rfc1950(adler32(dict)) != expected_dict_id {
        raise fzip_err(InvalidChecksum, msg="zlib dictionary Adler-32 mismatch")
      }
      6
    }
    _ => 2
  }
}

///|
/// Compress data into a Zlib stream.
///
/// The output contains a Zlib header, a raw DEFLATE payload, and an Adler-32
/// checksum footer. If `ZlibOptions.dictionary` is set, the dictionary checksum
/// is written into the header and callers must provide the same dictionary when
/// decompressing.
pub fn zlib_sync(
  data : FixedArray[Byte],
  opts? : ZlibOptions = ZlibOptions::default(),
) -> FixedArray[Byte] {
  let a = AdlerState::new()
  let pre = match opts.dictionary {
    Some(_) => 6
    None => 2
  }
  let (d, len) = dopt(
    data,
    { level: opts.level, mem: opts.mem, dictionary: opts.dictionary },
    pre,
    4,
    None,
    adler_state=Some(a),
  )
  zlh(d, opts)
  wbytes(d, len - 4, a.digest().reinterpret_as_int())
  trim_buf(d, len)
}

///|
/// Decompress a Zlib stream.
///
/// The Zlib header is validated before inflating the inner DEFLATE payload. The
/// Adler-32 footer is verified by default and can be disabled with
/// `UnzlibOptions.verify_checksum` for trusted inputs. For dictionary streams,
/// fzip always verifies that the header DICTID matches the provided dictionary,
/// even when footer checksum verification is disabled.
pub fn unzlib_sync(
  data : FixedArray[Byte],
  opts? : UnzlibOptions = UnzlibOptions::default(),
) -> FixedArray[Byte] raise FzipError {
  let st = zls(data, opts.dictionary)
  let end = data.length() - 4
  if end < st {
    raise fzip_err(InvalidHeader, msg="invalid zlib data")
  }
  let adler_st : AdlerState? = if opts.verify_checksum {
    Some(AdlerState::new())
  } else {
    None
  }
  let (buf, len) = inflt(
    data,
    InflateState::new(2),
    opts.out,
    opts.dictionary,
    opts.max_input_size,
    opts.max_output_size,
    dat_off=st,
    dat_end=end,
    adler_state=adler_st,
  )
  match adler_st {
    Some(a_s) => {
      let expected_adler = b4(data, end)
      if a_s.digest() != expected_adler {
        raise fzip_err(InvalidChecksum, msg="zlib Adler-32 mismatch")
      }
    }
    None => ()
  }
  trim_buf(buf, len)
}
