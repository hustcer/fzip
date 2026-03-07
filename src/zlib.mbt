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
      let dv = h.digest().reinterpret_as_int()
      wbytes(c, 2, dv)
    }
    None => ()
  }
}

///|
/// Parse Zlib header and return data start offset
fn zls(d : FixedArray[Byte], has_dict : Bool) -> Int raise FzipError {
  if (d[0].to_int() & 15) != 8 ||
    d[0].to_int() >> 4 > 7 ||
    ((d[0].to_int() << 8) | d[1].to_int()) % 31 != 0 {
    raise fzip_err(InvalidHeader, msg="invalid zlib data")
  }
  let dict_flag = (d[1].to_int() >> 5) & 1
  if dict_flag == 1 && not(has_dict) {
    raise fzip_err(InvalidHeader, msg="invalid zlib data: need dictionary")
  }
  if dict_flag == 0 && has_dict {
    raise fzip_err(
      InvalidHeader,
      msg="invalid zlib data: unexpected dictionary",
    )
  }
  // header size: 2 bytes + optional 4 bytes for dict checksum
  let extra = if ((d[1].to_int() >> 3) & 4) != 0 { 4 } else { 0 }
  extra + 2
}

///|
/// Compress data with Zlib
pub fn zlib_sync(
  data : FixedArray[Byte],
  opts? : ZlibOptions = ZlibOptions::default(),
) -> FixedArray[Byte] {
  let a = AdlerState::new()
  a.push(data)
  let pre = match opts.dictionary {
    Some(_) => 6
    None => 2
  }
  let d = dopt(
    data,
    { level: opts.level, mem: opts.mem, dictionary: opts.dictionary },
    pre,
    4,
    None,
  )
  zlh(d, opts)
  wbytes(d, d.length() - 4, a.digest().reinterpret_as_int())
  d
}

///|
/// Decompress Zlib data
pub fn unzlib_sync(
  data : FixedArray[Byte],
  opts? : UnzlibOptions = UnzlibOptions::default(),
) -> FixedArray[Byte] raise FzipError {
  let has_dict = match opts.dictionary {
    Some(_) => true
    None => false
  }
  let st = zls(data, has_dict)
  let end = data.length() - 4
  inflt(
    data,
    InflateState::new(2),
    opts.out,
    opts.dictionary,
    dat_off=st,
    dat_end=end,
  )
}
