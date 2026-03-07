///|
/// Internal inflate state
priv struct InflateState {
  mut lm : FixedArray[Int]? // length map
  mut dm : FixedArray[Int]? // distance map
  mut lbt : Int // length bits
  mut dbt : Int // distance bits
  mut final_ : Int // final block flag
  mut pos : Int // bit position
  mut bt : Int // byte count (output position)
  i : Int // state info (0=streaming, 2=one-shot)
}

///|
fn InflateState::new(i : Int) -> InflateState {
  { lm: None, dm: None, lbt: 0, dbt: 0, final_: 0, pos: 0, bt: 0, i }
}

///|
/// Core DEFLATE decompression
fn inflt(
  dat : FixedArray[Byte],
  st : InflateState,
  buf : FixedArray[Byte]?,
  dict : FixedArray[Byte]?,
  dat_off? : Int = 0,
  dat_end? : Int = dat.length(),
) -> (FixedArray[Byte], Int) raise FzipError {
  let sl = dat_end - dat_off
  let dl = match dict {
    Some(d) => d.length()
    None => 0
  }
  if sl == 0 || (st.final_ != 0 && st.lm is None) {
    return match buf {
      Some(b) => (b, st.bt)
      None => (FixedArray::make(0, b'\x00'), 0)
    }
  }
  let no_buf = buf is None
  let resize = no_buf || st.i != 2
  let no_st = st.i
  let mut buf = match buf {
    Some(b) => b
    None => FixedArray::make(sl * 3, b'\x00')
  }
  // Scale buffer growth headroom based on input size to avoid
  // over-allocation for small data (was hardcoded 131072 = 128KB)
  let grow = if sl * 3 < 131072 { sl * 3 + 512 } else { 131072 }
  let tbts = dat_end * 8
  let mut final_ = st.final_
  let mut pos = st.pos + dat_off * 8
  let mut bt = st.bt
  let mut lm = st.lm
  let mut dm = st.dm
  let mut lbt = st.lbt
  let mut dbt = st.dbt
  // main loop over blocks
  let mut continue_loop = true
  while continue_loop {
    if lm is None {
      // If we already read the final block, stop
      if final_ != 0 {
        break
      }
      // read BFINAL
      final_ = bits(dat, pos, 1)
      // read block type
      let btype = bits(dat, pos + 1, 3)
      pos += 3
      if btype == 0 {
        // stored block
        let s = shft(pos) + 4
        let l = dat[s - 4].to_int() | (dat[s - 3].to_int() << 8)
        let t = s + l
        if t > dat_end {
          if no_st != 0 {
            raise fzip_err(UnexpectedEOF)
          }
          break
        }
        if resize {
          buf = ensure_buf(buf, bt + l)
        }
        dat.blit_to(buf, len=l, src_offset=s, dst_offset=bt)
        st.bt = {
          bt += l
          bt
        }
        st.pos = {
          pos = t * 8
          pos
        }
        st.final_ = final_
        continue
      } else if btype == 1 {
        lm = Some(flrm)
        dm = Some(fdrm)
        lbt = 9
        dbt = 5
      } else if btype == 2 {
        let h_lit = bits(dat, pos, 31) + 257
        let hc_len = bits(dat, pos + 10, 15) + 4
        let tl = h_lit + bits(dat, pos + 5, 31) + 1
        pos += 14
        // length+distance tree
        let ldt : FixedArray[Byte] = FixedArray::make(tl, b'\x00')
        // code length tree
        let clt_arr : FixedArray[Byte] = FixedArray::make(19, b'\x00')
        for i in 0..<hc_len {
          clt_arr[clim[i].to_int()] = bits(dat, pos + i * 3, 7).to_byte()
        }
        pos += hc_len * 3
        let clb = max_val(clt_arr)
        let clbmsk = (1 << clb) - 1
        let clm = h_map(clt_arr, clb, 1)
        let mut i = 0
        while i < tl {
          let r = clm[bits(dat, pos, clbmsk)]
          pos += r & 15
          let s = r >> 4
          if s < 16 {
            ldt[i] = s.to_byte()
            i += 1
          } else {
            let mut c = 0
            let mut n = 0
            if s == 16 {
              n = 3 + bits(dat, pos, 3)
              pos += 2
              c = ldt[i - 1].to_int()
            } else if s == 17 {
              n = 3 + bits(dat, pos, 7)
              pos += 3
            } else if s == 18 {
              n = 11 + bits(dat, pos, 127)
              pos += 7
            }
            while n > 0 {
              ldt[i] = c.to_byte()
              i += 1
              n -= 1
            }
          }
        }
        // split into length tree and distance tree
        let lt : FixedArray[Byte] = FixedArray::make(h_lit, b'\x00')
        let dt : FixedArray[Byte] = FixedArray::make(tl - h_lit, b'\x00')
        ldt.blit_to(lt, len=h_lit, src_offset=0, dst_offset=0)
        ldt.blit_to(dt, len=tl - h_lit, src_offset=h_lit, dst_offset=0)
        lbt = max_val(lt)
        dbt = max_val(dt)
        lm = Some(h_map(lt, lbt, 1))
        dm = Some(h_map(dt, dbt, 1))
      } else {
        raise fzip_err(InvalidBlockType)
      }
      if pos > tbts {
        if no_st != 0 {
          raise fzip_err(UnexpectedEOF)
        }
        break
      }
    }
    // decode symbols
    if resize {
      buf = ensure_buf(buf, bt + grow)
    }
    let lms = (1 << lbt) - 1
    let dms = (1 << dbt) - 1
    let mut lpos = pos
    let lm_arr = match lm {
      Some(a) => a
      None => FixedArray::make(0, 0) // should not happen
    }
    let dm_arr = match dm {
      Some(a) => a
      None => FixedArray::make(0, 0)
    }
    let mut break_outer = false
    while true {
      lpos = pos
      let c = lm_arr[bits16(dat, pos) & lms]
      let sym = c >> 4
      pos += c & 15
      if pos > tbts {
        if no_st != 0 {
          raise fzip_err(UnexpectedEOF)
        }
        break_outer = true
        break
      }
      if c == 0 {
        raise fzip_err(InvalidLengthLiteral)
      }
      if sym < 256 {
        buf[bt] = sym.to_byte()
        bt += 1
      } else if sym == 256 {
        lpos = pos
        lm = None
        break
      } else {
        let mut add = sym - 254
        if sym > 264 {
          let idx = sym - 257
          let b = fleb[idx].to_int()
          add = bits(dat, pos, (1 << b) - 1) + fl[idx]
          pos += b
        }
        // distance
        let d = dm_arr[bits16(dat, pos) & dms]
        let dsym = d >> 4
        if d == 0 {
          raise fzip_err(InvalidDistance)
        }
        pos += d & 15
        let mut dt_val = fd[dsym]
        if dsym > 3 {
          let b = fdeb[dsym].to_int()
          dt_val += bits16(dat, pos) & ((1 << b) - 1)
          pos += b
        }
        if pos > tbts {
          if no_st != 0 {
            raise fzip_err(UnexpectedEOF)
          }
          break_outer = true
          break
        }
        if resize {
          buf = ensure_buf(buf, bt + grow)
        }
        let end = bt + add
        // dictionary reference
        if bt < dt_val {
          let shift = dl - dt_val
          let dend = if dt_val < end { dt_val } else { end }
          if shift + bt < 0 {
            raise fzip_err(InvalidDistance)
          }
          match dict {
            Some(dict_arr) =>
              while bt < dend {
                buf[bt] = dict_arr[shift + bt]
                bt += 1
              }
            None => raise fzip_err(InvalidDistance)
          }
        }
        // copy from output (LZ77 back-reference)
        while bt < end {
          buf[bt] = buf[bt - dt_val]
          bt += 1
        }
      }
    }
    if break_outer {
      break
    }
    st.lm = lm
    st.pos = lpos
    st.bt = bt
    st.final_ = final_
    if not(lm is None) {
      final_ = 1
      st.lbt = lbt
      st.dm = dm
      st.dbt = dbt
    }
    if final_ != 0 {
      continue_loop = false
    }
  }
  (buf, bt)
}

///|
/// Ensure buffer has at least `need` capacity
fn ensure_buf(buf : FixedArray[Byte], need : Int) -> FixedArray[Byte] {
  let bl = buf.length()
  if need > bl {
    let new_size = if bl * 2 > need { bl * 2 } else { need }
    let nbuf = FixedArray::make(new_size, b'\x00')
    buf.blit_to(nbuf, len=bl, src_offset=0, dst_offset=0)
    nbuf
  } else {
    buf
  }
}

///|
/// Decompress raw DEFLATE data
pub fn inflate_sync(
  data : FixedArray[Byte],
  opts? : InflateOptions = InflateOptions::default(),
) -> FixedArray[Byte] raise FzipError {
  let (buf, len) = inflt(data, InflateState::new(2), opts.out, opts.dictionary)
  if len < buf.length() {
    slc(buf, 0, e=len)
  } else {
    buf
  }
}
