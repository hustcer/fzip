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
/// Core DEFLATE decompression with 32-bit bit buffer.
/// Instead of calling bits()/bits16() per read (each doing p/8 division +
/// 2-3 array accesses + boundary checks), we maintain a bit accumulator
/// (bbuf/bcnt) and refill from dat[bpos] only when needed. This reduces
/// array accesses from ~8-12 to ~3-4 per decoded symbol.
fn inflt(
  dat : FixedArray[Byte],
  st : InflateState,
  buf : FixedArray[Byte]?,
  dict : FixedArray[Byte]?,
  max_input_size : Int,
  max_output_size : Int,
  dat_off? : Int = 0,
  dat_end? : Int = dat.length(),
) -> (FixedArray[Byte], Int) raise FzipError {
  let sl = dat_end - dat_off
  // Check input size against configured limit (before any processing)
  if sl > max_input_size {
    raise fzip_err(InvalidZipData, msg="input exceeds max_input_size")
  }
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
    None => {
      // Prevent integer overflow: check if sl * 3 would overflow
      let max_safe = max_output_size / 3
      if sl > max_safe {
        raise fzip_err(
          InvalidZipData,
          msg="input too large for safe allocation",
        )
      }
      let initial_size = sl * 3
      FixedArray::make(initial_size, b'\x00')
    }
  }
  // Scale buffer growth headroom based on input size to avoid
  // over-allocation for small data (was hardcoded 131072 = 128KB)
  let grow = if sl < 43690 { // 131072 / 3
    let safe_grow = sl * 3
    if safe_grow < 131072 {
      safe_grow + 512
    } else {
      131072
    }
  } else {
    131072
  }
  let tbts = dat_end * 8
  let mut final_ = st.final_
  // Initialize 32-bit bit buffer from saved state position
  let init_pos = st.pos + dat_off * 8
  let mut bpos = init_pos >> 3 // next byte to load from dat
  let mut bbuf = 0 // accumulated bits (lowest bits = next to consume)
  let mut bcnt = 0 // number of valid bits in bbuf
  let boff = init_pos & 7
  if boff > 0 && bpos < dat_end {
    bbuf = dat[bpos].to_int() >> boff
    bcnt = 8 - boff
    bpos += 1
  }
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
      // read BFINAL (1 bit) + BTYPE (2 bits) = 3 bits total
      while bcnt < 3 && bpos < dat_end {
        bbuf = bbuf | (dat[bpos].to_int() << bcnt)
        bpos += 1
        bcnt += 8
      }
      final_ = bbuf & 1
      let btype = (bbuf >> 1) & 3
      bbuf = bbuf >> 3
      bcnt -= 3
      if btype == 0 {
        // Stored block: align to byte boundary, reset bit buffer
        let cur_pos = bpos * 8 - bcnt
        let s = shft(cur_pos) + 4
        bbuf = 0
        bcnt = 0
        // Check if we have enough bytes for the stored block header (4 bytes)
        if s > dat_end {
          if no_st != 0 {
            raise fzip_err(UnexpectedEOF)
          }
          break
        }
        let l = dat[s - 4].to_int() | (dat[s - 3].to_int() << 8)
        let t = s + l
        if t > dat_end {
          if no_st != 0 {
            raise fzip_err(UnexpectedEOF)
          }
          break
        }
        if resize {
          buf = ensure_buf(buf, bt + l, max_output_size)
        }
        dat.blit_to(buf, len=l, src_offset=s, dst_offset=bt)
        st.bt = {
          bt += l
          bt
        }
        st.pos = {
          bpos = t
          bpos * 8
        }
        st.final_ = final_
        continue
      } else if btype == 1 {
        lm = Some(flrm)
        dm = Some(fdrm)
        lbt = 9
        dbt = 5
      } else if btype == 2 {
        // Dynamic Huffman: read 14-bit header (HLIT + HDIST + HCLEN)
        while bcnt < 14 && bpos < dat_end {
          bbuf = bbuf | (dat[bpos].to_int() << bcnt)
          bpos += 1
          bcnt += 8
        }
        let h_lit = (bbuf & 31) + 257
        let tl = h_lit + ((bbuf >> 5) & 31) + 1
        let hc_len = ((bbuf >> 10) & 15) + 4
        bbuf = bbuf >> 14
        bcnt -= 14
        // length+distance tree
        let ldt : FixedArray[Byte] = FixedArray::make(tl, b'\x00')
        // code length tree
        let clt_arr : FixedArray[Byte] = FixedArray::make(19, b'\x00')
        // Read code length code lengths (3 bits each)
        for i in 0..<hc_len {
          while bcnt < 3 && bpos < dat_end {
            bbuf = bbuf | (dat[bpos].to_int() << bcnt)
            bpos += 1
            bcnt += 8
          }
          clt_arr[clim[i].to_int()] = (bbuf & 7).to_byte()
          bbuf = bbuf >> 3
          bcnt -= 3
        }
        let clb = max_val(clt_arr)
        let clbmsk = (1 << clb) - 1
        let clm = h_map(clt_arr, clb, 1)
        // Decode the combined length+distance code length tree
        let mut i = 0
        while i < tl {
          while bcnt < clb && bpos < dat_end {
            bbuf = bbuf | (dat[bpos].to_int() << bcnt)
            bpos += 1
            bcnt += 8
          }
          let r = clm[bbuf & clbmsk]
          let rbits = r & 15
          bbuf = bbuf >> rbits
          bcnt -= rbits
          let s = r >> 4
          if s < 16 {
            ldt[i] = s.to_byte()
            i += 1
          } else {
            let mut c = 0
            let mut n = 0
            if s == 16 {
              while bcnt < 2 && bpos < dat_end {
                bbuf = bbuf | (dat[bpos].to_int() << bcnt)
                bpos += 1
                bcnt += 8
              }
              n = 3 + (bbuf & 3)
              bbuf = bbuf >> 2
              bcnt -= 2
              c = ldt[i - 1].to_int()
            } else if s == 17 {
              while bcnt < 3 && bpos < dat_end {
                bbuf = bbuf | (dat[bpos].to_int() << bcnt)
                bpos += 1
                bcnt += 8
              }
              n = 3 + (bbuf & 7)
              bbuf = bbuf >> 3
              bcnt -= 3
            } else if s == 18 {
              while bcnt < 7 && bpos < dat_end {
                bbuf = bbuf | (dat[bpos].to_int() << bcnt)
                bpos += 1
                bcnt += 8
              }
              n = 11 + (bbuf & 127)
              bbuf = bbuf >> 7
              bcnt -= 7
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
      if bpos * 8 - bcnt > tbts {
        if no_st != 0 {
          raise fzip_err(UnexpectedEOF)
        }
        break
      }
    }
    // decode symbols using bit buffer
    if resize {
      buf = ensure_buf(buf, bt + grow, max_output_size)
    }
    let lms = (1 << lbt) - 1
    let dms = (1 << dbt) - 1
    let mut lpos = bpos * 8 - bcnt
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
      lpos = bpos * 8 - bcnt
      // Fill and lookup length/literal Huffman code
      while bcnt < lbt && bpos < dat_end {
        bbuf = bbuf | (dat[bpos].to_int() << bcnt)
        bpos += 1
        bcnt += 8
      }
      let c = lm_arr[bbuf & lms]
      let sym = c >> 4
      let cbits = c & 15
      bbuf = bbuf >> cbits
      bcnt -= cbits
      if bpos * 8 - bcnt > tbts {
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
        lpos = bpos * 8 - bcnt
        lm = None
        break
      } else {
        let mut add = sym - 254
        if sym > 264 {
          let idx = sym - 257
          let b = fleb[idx].to_int()
          // Fill for extra length bits
          while bcnt < b && bpos < dat_end {
            bbuf = bbuf | (dat[bpos].to_int() << bcnt)
            bpos += 1
            bcnt += 8
          }
          add = (bbuf & ((1 << b) - 1)) + fl[idx]
          bbuf = bbuf >> b
          bcnt -= b
        }
        // distance Huffman lookup
        while bcnt < dbt && bpos < dat_end {
          bbuf = bbuf | (dat[bpos].to_int() << bcnt)
          bpos += 1
          bcnt += 8
        }
        let d = dm_arr[bbuf & dms]
        let dsym = d >> 4
        if d == 0 {
          raise fzip_err(InvalidDistance)
        }
        let dbits = d & 15
        bbuf = bbuf >> dbits
        bcnt -= dbits
        let mut dt_val = fd[dsym]
        if dsym > 3 {
          let b = fdeb[dsym].to_int()
          // Fill for extra distance bits
          while bcnt < b && bpos < dat_end {
            bbuf = bbuf | (dat[bpos].to_int() << bcnt)
            bpos += 1
            bcnt += 8
          }
          dt_val += bbuf & ((1 << b) - 1)
          bbuf = bbuf >> b
          bcnt -= b
        }
        if bpos * 8 - bcnt > tbts {
          if no_st != 0 {
            raise fzip_err(UnexpectedEOF)
          }
          break_outer = true
          break
        }
        if resize {
          buf = ensure_buf(buf, bt + grow, max_output_size)
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
        if dt_val == 1 {
          // RLE: fill with single repeated byte
          buf.fill(buf[bt - 1], start=bt, end~)
          bt = end
        } else if dt_val >= add {
          // Non-overlapping: block copy
          buf.blit_to(buf, len=add, src_offset=bt - dt_val, dst_offset=bt)
          bt = end
        } else {
          // Overlapping pattern: copy with doubling strategy
          buf.blit_to(buf, len=dt_val, src_offset=bt - dt_val, dst_offset=bt)
          let mut copied = dt_val
          while copied + copied <= add {
            buf.blit_to(buf, len=copied, src_offset=bt, dst_offset=bt + copied)
            copied += copied
          }
          if copied < add {
            buf.blit_to(
              buf,
              len=add - copied,
              src_offset=bt,
              dst_offset=bt + copied,
            )
          }
          bt = end
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
fn ensure_buf(
  buf : FixedArray[Byte],
  need : Int,
  max_size : Int,
) -> FixedArray[Byte] raise FzipError {
  let bl = buf.length()
  if need > bl {
    // Check against configured maximum output size
    if need > max_size || need < 0 {
      raise fzip_err(
        InvalidZipData,
        msg="uncompressed size exceeds max_output_size",
      )
    }
    // Check for integer overflow in doubling calculation
    let new_size = if bl > 0 && bl < max_size / 2 && bl * 2 > need {
      bl * 2
    } else {
      need
    }
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
  let (buf, len) = inflt(
    data,
    InflateState::new(2),
    opts.out,
    opts.dictionary,
    opts.max_input_size,
    opts.max_output_size,
  )
  trim_buf(buf, len)
}
