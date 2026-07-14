///|
/// Write GZIP header
fn gzh(c : FixedArray[Byte], o : GzipOptions) -> Unit {
  c[0] = b'\x1F' // magic 1
  c[1] = b'\x8B' // magic 2
  c[2] = b'\x08' // CM = deflate
  let xfl : Byte = if o.level < 2 {
    b'\x04'
  } else if o.level == 9 {
    b'\x02'
  } else {
    b'\x00'
  }
  c[8] = xfl
  c[9] = b'\x03' // OS = Unix
  if o.mtime != 0 {
    wbytes(c, 4, o.mtime)
  }
  if o.filename.length() > 0 {
    c[3] = b'\x08' // FNAME flag
    let fn_bytes = o.filename
    for i in 0..<fn_bytes.length() {
      c[i + 10] = fn_bytes[i].to_int().to_byte()
    }
    c[fn_bytes.length() + 10] = b'\x00' // null terminator
  }
}

///|
/// Parse GZIP header and return data start offset
fn gzs(d : FixedArray[Byte], offset? : Int = 0) -> Int raise FzipError {
  if offset < 0 || offset > d.length() - 10 {
    raise fzip_err(InvalidHeader, msg="invalid gzip data")
  }
  if d[offset] != b'\x1F' ||
    d[offset + 1] != b'\x8B' ||
    d[offset + 2] != b'\x08' {
    raise fzip_err(InvalidHeader, msg="invalid gzip data")
  }
  let flg = d[offset + 3].to_int()
  if (flg & 0xE0) != 0 {
    raise fzip_err(InvalidHeader, msg="invalid gzip data")
  }
  if flg == 0 {
    return offset + 10
  }
  let mut st = offset + 10
  if (flg & 4) != 0 {
    if st > d.length() - 2 {
      raise fzip_err(InvalidHeader, msg="invalid gzip data")
    }
    let extra_len = d[st].to_int() | (d[st + 1].to_int() << 8)
    st += 2
    if extra_len > d.length() - st {
      raise fzip_err(InvalidHeader, msg="invalid gzip data")
    }
    st += extra_len
  }
  // skip FNAME and FCOMMENT
  let mut zs = ((flg >> 3) & 1) + ((flg >> 4) & 1)
  while zs > 0 {
    if st >= d.length() {
      raise fzip_err(InvalidHeader, msg="invalid gzip data")
    }
    if d[st] == b'\x00' {
      zs -= 1
    }
    st += 1
  }
  // validate and skip FHCRC
  if (flg & 2) != 0 {
    if st > d.length() - 2 {
      raise fzip_err(InvalidHeader, msg="invalid gzip data")
    }
    let expected_crc = d[st].to_uint() | (d[st + 1].to_uint() << 8)
    let crc = CRC32State::new()
    crc.push_range(d, offset, st - offset)
    if (crc.digest() & 0xFFFFU) != expected_crc {
      raise fzip_err(InvalidChecksum, msg="gzip header CRC-16 mismatch")
    }
    st += 2
  }
  st
}

///|
/// Read a sync-API-safe GZIP ISIZE value from a member footer.
fn gzl(d : FixedArray[Byte], footer : Int) -> Int raise FzipError {
  if footer < 0 || footer > d.length() - 8 {
    raise fzip_err(InvalidHeader, msg="invalid gzip data")
  }
  let raw = b4(d, footer + 4)
  if raw > max_int_val().reinterpret_as_uint() {
    raise fzip_err(InvalidZipData, msg="gzip ISIZE exceeds Int range")
  }
  raw.reinterpret_as_int()
}

///|
/// Calculate GZIP header length
fn gzhl(o : GzipOptions) -> Int {
  10 + (if o.filename.length() > 0 { o.filename.length() + 1 } else { 0 })
}

///|
/// Select the fixed output buffer for the single-member fast path.
fn single_member_gunzip_buffer(
  isize : Int,
  out : FixedArray[Byte]?,
) -> FixedArray[Byte] raise FzipError {
  match out {
    Some(buf) => {
      if isize > buf.length() {
        raise fzip_err(InvalidZipData, msg="output buffer too small")
      }
      buf
    }
    None => FixedArray::make(isize, b'\x00')
  }
}

///|
/// Try the fixed-buffer one-shot path used by ordinary single-member streams.
/// Return `None` when the first DEFLATE stream ends before the final footer or
/// the final ISIZE-sized candidate buffer is insufficient. The caller then
/// falls back to concatenated-member decoding and produces the definitive error.
fn try_gunzip_single_member(
  data : FixedArray[Byte],
  data_start : Int,
  footer : Int,
  isize : Int,
  opts : GunzipOptions,
) -> FixedArray[Byte]? raise FzipError {
  let crc_st : CRC32State? = if opts.verify_checksum {
    Some(CRC32State::new())
  } else {
    None
  }
  let inflate_st = InflateState::new(2)
  let output = single_member_gunzip_buffer(isize, opts.out)
  let (buf, len) = try
    inflt(
      data,
      inflate_st,
      Some(output),
      opts.dictionary,
      opts.max_input_size,
      opts.max_output_size,
      dat_off=data_start,
      dat_end=footer,
      crc_state=crc_st,
    )
  catch {
    FzipError(code=InvalidZipData, ..) => return None
    err => raise err
  } noraise {
    result => result
  }
  if inflate_st.final_ == 0 || !(inflate_st.lm is None) {
    raise fzip_err(UnexpectedEOF, msg="truncated gzip DEFLATE data")
  }
  let actual_footer = shft(inflate_st.pos)
  if actual_footer < data_start || actual_footer > footer {
    raise fzip_err(InvalidHeader, msg="invalid gzip data")
  }
  if actual_footer != footer {
    return None
  }
  match crc_st {
    Some(cs) => {
      let expected_crc = b4(data, footer)
      if cs.digest() != expected_crc {
        raise fzip_err(InvalidChecksum, msg="gzip CRC-32 mismatch")
      }
    }
    None => ()
  }
  if len != isize {
    raise fzip_err(InvalidZipData, msg="gzip ISIZE mismatch")
  }
  Some(trim_buf(buf, len))
}

///|
/// Compress data into a GZIP stream.
///
/// The output contains a GZIP header, a DEFLATE payload, and a footer with the
/// CRC-32 checksum and original input size. `GzipOptions` controls compression
/// level, optional dictionary use, and header metadata such as timestamp and
/// original filename. When a dictionary is used, callers must pass the same
/// dictionary to `gunzip_sync`; the GZIP format does not carry a dictionary ID.
pub fn gzip_sync(
  data : FixedArray[Byte],
  opts? : GzipOptions = GzipOptions::default(),
) -> FixedArray[Byte] {
  let c = CRC32State::new()
  let l = data.length()
  let (d, len) = dopt(
    data,
    { level: opts.level, mem: opts.mem, dictionary: opts.dictionary },
    gzhl(opts),
    8,
    None,
    crc_state=Some(c),
  )
  gzh(d, opts)
  wbytes(d, len - 8, c.digest().reinterpret_as_int())
  wbytes(d, len - 4, l)
  trim_buf(d, len)
}

///|
/// Decompress a GZIP stream.
///
/// Every concatenated GZIP member is parsed and inflated in order, and their
/// outputs are joined. Each member's ISIZE is always validated and its CRC-32
/// footer is verified by default. Optional FHCRC header checksums are always
/// validated when present. `max_input_size` applies to the complete compressed
/// stream. Set `verify_checksum` to `false` in `GunzipOptions` only when footer
/// checksum validation is handled elsewhere.
pub fn gunzip_sync(
  data : FixedArray[Byte],
  opts? : GunzipOptions = GunzipOptions::default(),
) -> FixedArray[Byte] raise FzipError {
  if data.length() == 0 {
    raise fzip_err(InvalidHeader, msg="invalid gzip data")
  }
  if opts.max_input_size < 0 {
    raise fzip_err(InvalidZipData, msg="input exceeds max_input_size")
  }
  if data.length() > opts.max_input_size {
    raise fzip_err(InvalidZipData, msg="input exceeds max_input_size")
  }
  if opts.max_output_size < 0 {
    raise fzip_err(
      InvalidZipData,
      msg="uncompressed size exceeds max_output_size",
    )
  }
  let data_start = gzs(data)
  let final_footer = data.length() - 8
  if data_start > final_footer {
    raise fzip_err(InvalidHeader, msg="invalid gzip data")
  }
  let final_isize = gzl(data, final_footer)
  if final_isize > opts.max_output_size {
    raise fzip_err(InvalidZipData, msg="gzip ISIZE exceeds max_output_size")
  }
  match
    try_gunzip_single_member(data, data_start, final_footer, final_isize, opts) {
    Some(result) => return result
    None => ()
  }
  let chunks : Array[FixedArray[Byte]] = []
  let mut member_offset = 0
  let mut total_output = 0
  while member_offset < data.length() {
    let data_start = gzs(data, offset=member_offset)
    if data_start > data.length() - 8 {
      raise fzip_err(InvalidHeader, msg="invalid gzip data")
    }
    let output_remaining = opts.max_output_size - total_output
    let input_remaining = data.length() - data_start
    let initial_size = if input_remaining < output_remaining {
      if input_remaining < 32768 {
        input_remaining
      } else {
        32768
      }
    } else if output_remaining < 32768 {
      output_remaining
    } else {
      32768
    }
    let crc_st : CRC32State? = if opts.verify_checksum {
      Some(CRC32State::new())
    } else {
      None
    }
    let inflate_st = InflateState::new(0)
    let (member_buf, member_len) = inflt(
      data,
      inflate_st,
      Some(FixedArray::make(initial_size, b'\x00')),
      opts.dictionary,
      opts.max_input_size,
      output_remaining,
      dat_off=data_start,
      dat_end=data.length(),
      crc_state=crc_st,
    )
    if inflate_st.final_ == 0 || !(inflate_st.lm is None) {
      raise fzip_err(UnexpectedEOF, msg="truncated gzip DEFLATE data")
    }
    let footer = shft(inflate_st.pos)
    if footer < data_start || footer > data.length() - 8 {
      raise fzip_err(InvalidHeader, msg="invalid gzip data")
    }
    match crc_st {
      Some(cs) => {
        let expected_crc = b4(data, footer)
        if cs.digest() != expected_crc {
          raise fzip_err(InvalidChecksum, msg="gzip CRC-32 mismatch")
        }
      }
      None => ()
    }
    let isize = gzl(data, footer)
    if isize > output_remaining {
      raise fzip_err(InvalidZipData, msg="gzip ISIZE exceeds max_output_size")
    }
    if member_len != isize {
      raise fzip_err(InvalidZipData, msg="gzip ISIZE mismatch")
    }
    chunks.push(trim_buf(member_buf, member_len))
    total_output += member_len
    member_offset = footer + 8
  }
  match opts.out {
    Some(out) => {
      if total_output > out.length() {
        raise fzip_err(InvalidZipData, msg="output buffer too small")
      }
      let mut offset = 0
      for i in 0..<chunks.length() {
        let chunk = chunks[i]
        chunk.blit_to(out, len=chunk.length(), dst_offset=offset)
        offset += chunk.length()
      }
      trim_buf(out, total_output)
    }
    None => if chunks.length() == 1 { chunks[0] } else { concat_chunks(chunks) }
  }
}
