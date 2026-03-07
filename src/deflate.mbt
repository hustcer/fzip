///|
/// Write a stored (uncompressed) block
/// Returns new bit position
fn wfblk(
  out : FixedArray[Byte],
  pos : Int,
  dat : FixedArray[Byte],
  dat_start : Int,
  dat_len : Int,
) -> Int {
  let o = shft(pos + 2)
  out[o] = (dat_len & 255).to_byte()
  out[o + 1] = (dat_len >> 8).to_byte()
  out[o + 2] = (out[o].to_int() ^ 255).to_byte()
  out[o + 3] = (out[o + 1].to_int() ^ 255).to_byte()
  for i in 0..<dat_len {
    out[o + i + 4] = dat[dat_start + i]
  }
  (o + 4 + dat_len) * 8
}

///|
/// Write symbols with given encoding tables
fn write_syms(
  out : FixedArray[Byte],
  lm_enc : FixedArray[Int],
  ll : FixedArray[Byte],
  dm_enc : FixedArray[Int],
  dl : FixedArray[Byte],
  syms : FixedArray[Int],
  li : Int,
  p : Int,
) -> Int {
  let mut p = p
  for i in 0..<li {
    let sym = syms[i]
    if sym > 255 {
      let len = (sym >> 18) & 31
      wbits16(out, p, lm_enc[len + 257])
      p += ll[len + 257].to_int()
      if len > 7 {
        wbits(out, p, (sym >> 23) & 31)
        p += fleb[len].to_int()
      }
      let dst = sym & 31
      wbits16(out, p, dm_enc[dst])
      p += dl[dst].to_int()
      if dst > 3 {
        wbits16(out, p, (sym >> 5) & 8191)
        p += fdeb[dst].to_int()
      }
    } else {
      wbits16(out, p, lm_enc[sym])
      p += ll[sym].to_int()
    }
  }
  wbits16(out, p, lm_enc[256])
  p + ll[256].to_int()
}

///|
/// Write a compressed block
fn wblk(
  dat : FixedArray[Byte],
  out : FixedArray[Byte],
  final_ : Int,
  syms : FixedArray[Int],
  lf : FixedArray[Int],
  df : FixedArray[Int],
  eb : Int,
  li : Int,
  bs : Int,
  bl : Int,
  p : Int,
) -> Int {
  let mut p = p
  wbits(out, p, final_)
  p += 1
  lf[256] = lf[256] + 1
  let (dlt, mlb) = h_tree(lf, 15)
  let (ddt, mdb) = h_tree(df, 15)
  let (lclt, nlc) = lc_gen(dlt)
  let (lcdt, ndc) = lc_gen(ddt)
  let lcfreq : FixedArray[Int] = FixedArray::make(19, 0)
  for i in 0..<lclt.length() {
    lcfreq[lclt[i] & 31] += 1
  }
  for i in 0..<lcdt.length() {
    lcfreq[lcdt[i] & 31] += 1
  }
  let (lct, mlcb) = h_tree(lcfreq, 7)
  let mut nlcc = 19
  while nlcc > 4 && lct[clim[nlcc - 1].to_int()].to_int() == 0 {
    nlcc -= 1
  }
  let flen = (bl + 5) << 3
  let ftlen = clen(lf, flt) + clen(df, fdt) + eb
  let dtlen = clen(lf, dlt) +
    clen(df, ddt) +
    eb +
    14 +
    3 * nlcc +
    clen(lcfreq, lct) +
    2 * lcfreq[16] +
    3 * lcfreq[17] +
    7 * lcfreq[18]
  if bs >= 0 && flen <= ftlen && flen <= dtlen {
    return wfblk(out, p, dat, bs, bl)
  }
  if dtlen < ftlen {
    wbits(out, p, 2) // dynamic
    p += 2
    let lm_enc = h_map(dlt, mlb, 0)
    let ll = dlt
    let dm_enc = h_map(ddt, mdb, 0)
    let dl = ddt
    let llm = h_map(lct, mlcb, 0)
    wbits(out, p, nlc - 257)
    wbits(out, p + 5, ndc - 1)
    wbits(out, p + 10, nlcc - 4)
    p += 14
    for i in 0..<nlcc {
      wbits(out, p + 3 * i, lct[clim[i].to_int()].to_int())
    }
    p += 3 * nlcc
    let lcts : Array[FixedArray[Int]] = [lclt, lcdt]
    for it in 0..<2 {
      let clct = lcts[it]
      for i in 0..<clct.length() {
        let len = clct[i] & 31
        wbits(out, p, llm[len])
        p += lct[len].to_int()
        if len > 15 {
          wbits(out, p, (clct[i] >> 5) & 127)
          p += clct[i] >> 12
        }
      }
    }
    write_syms(out, lm_enc, ll, dm_enc, dl, syms, li, p)
  } else {
    wbits(out, p, 1) // fixed
    p += 2
    write_syms(out, flm, flt, fdm, fdt, syms, li, p)
  }
}

///|
/// Internal deflate state for streaming
priv struct DeflateState {
  mut head : FixedArray[Int]? // hash head
  mut prev : FixedArray[Int]? // hash chain prev
  mut i : Int // current index
  z : Int // end index
  mut w : Int // wait index
  mut r : Int // remainder byte info
  l : Int // last chunk flag
}

///|
/// Compute memory level for compression
fn compute_mem_level(len : Int) -> Int {
  let mut log_val = 8
  let mut v = len
  while v > 256 {
    v = v >> 1
    log_val += 1
    if log_val >= 10 {
      break
    }
  }
  if log_val < 8 {
    log_val = 8
  }
  (log_val * 3 + 1) / 2
}

///|
/// Core DEFLATE compression function
fn dflt(
  dat : FixedArray[Byte],
  lvl : Int,
  plvl : Int,
  pre : Int,
  post : Int,
  st : DeflateState,
) -> FixedArray[Byte] {
  let s = if st.z != 0 { st.z } else { dat.length() }
  let o_size = pre + s + 5 * (1 + (s + 6999) / 7000) + post
  let o = FixedArray::make(o_size, b'\x00')
  let w_start = pre
  let lst = st.l
  let mut pos = st.r & 7
  if lvl > 0 {
    if pos != 0 {
      o[w_start] = (st.r >> 3).to_byte()
    }
    let opt = deo[lvl - 1]
    let n = opt >> 13
    let c = opt & 8191
    let msk = (1 << plvl) - 1
    let prev = match st.prev {
      Some(p) => p
      None => FixedArray::make(32768, 0)
    }
    let head = match st.head {
      Some(h) => h
      None => FixedArray::make(msk + 1, 0)
    }
    let bs1 = (plvl + 2) / 3
    let bs2 = 2 * bs1
    let syms : FixedArray[Int] = FixedArray::make(25000, 0)
    let lf : FixedArray[Int] = FixedArray::make(288, 0)
    let df : FixedArray[Int] = FixedArray::make(32, 0)
    let mut lc = 0
    let mut eb = 0
    let mut i = if st.i != 0 { st.i } else { 0 }
    let mut li = 0
    let mut wi = if st.w != 0 { st.w } else { 0 }
    let mut bs = 0
    while i + 2 < s {
      let hv = (
          dat[i].to_int() ^
          (dat[i + 1].to_int() << bs1) ^
          (dat[i + 2].to_int() << bs2)
        ) &
        msk
      let imod = i & 32767
      let mut pimod = head[hv]
      prev[imod] = pimod
      head[hv] = imod
      if wi <= i {
        let rem = s - i
        if (lc > 7000 || li > 24576) && (rem > 423 || lst == 0) {
          pos = wblk(
              dat,
              o,
              0,
              syms,
              lf,
              df,
              eb,
              li,
              bs,
              i - bs,
              pos + w_start * 8,
            ) -
            w_start * 8
          li = 0
          lc = 0
          eb = 0
          bs = i
          for j in 0..<286 {
            lf[j] = 0
          }
          for j in 0..<30 {
            df[j] = 0
          }
        }
        let mut l = 2
        let mut d = 0
        let mut ch = c
        let mut dif = (imod - pimod) & 32767
        if rem > 2 &&
          hv ==
          (
            (
              dat[i - dif].to_int() ^
              (dat[i - dif + 1].to_int() << bs1) ^
              (dat[i - dif + 2].to_int() << bs2)
            ) &
            msk
          ) {
          let maxn_val = (if n < rem { n } else { rem }) - 1
          let maxd = if 32767 < i { 32767 } else { i }
          let ml = if 258 < rem { 258 } else { rem }
          while dif <= maxd && ch > 0 && imod != pimod {
            ch -= 1
            if dat[i + l] == dat[i + l - dif] {
              let mut nl = 0
              while nl < ml && dat[i + nl] == dat[i + nl - dif] {
                nl += 1
              }
              if nl > l {
                l = nl
                d = dif
                if nl > maxn_val {
                  break
                }
                let mmd = if dif < nl - 2 { dif } else { nl - 2 }
                let mut md = 0
                for j in 0..<mmd {
                  let ti = (i - dif + j) & 32767
                  let pti = prev[ti]
                  let cd = (ti - pti) & 32767
                  if cd > md {
                    md = cd
                    pimod = ti
                  }
                }
              }
            }
            let old_imod = pimod
            pimod = prev[old_imod]
            dif += (old_imod - pimod) & 32767
          }
        }
        if d != 0 {
          syms[li] = 268435456 | (revfl[l] << 18) | revfd[d]
          li += 1
          let lin = revfl[l] & 31
          let din = revfd[d] & 31
          eb += fleb[lin].to_int() + fdeb[din].to_int()
          lf[257 + lin] += 1
          df[din] += 1
          wi = i + l
          lc += 1
        } else {
          syms[li] = dat[i].to_int()
          li += 1
          lf[dat[i].to_int()] += 1
        }
      }
      i += 1
    }
    let start = if i > wi { i } else { wi }
    let mut j = start
    while j < s {
      syms[li] = dat[j].to_int()
      li += 1
      lf[dat[j].to_int()] += 1
      j += 1
    }
    pos = wblk(dat, o, lst, syms, lf, df, eb, li, bs, j - bs, pos + w_start * 8) -
      w_start * 8
    if lst == 0 {
      st.r = (pos & 7) | (o[w_start + pos / 8].to_int() << 3)
      pos -= 7
      st.head = Some(head)
      st.prev = Some(prev)
      st.i = j
      st.w = wi
    }
  } else {
    let mut i2 = if st.w != 0 { st.w } else { 0 }
    while i2 < s + lst {
      let mut e = i2 + 65535
      if e >= s {
        o[w_start + pos / 8] = lst.to_byte()
        e = s
      }
      pos = wfblk(o, pos + w_start * 8 + 1, dat, i2, e - i2) - w_start * 8
      i2 += 65535
    }
    st.i = s
  }
  slc(o, 0, e=pre + shft(pos) + post)
}

///|
/// Deflate with options
fn dopt(
  dat : FixedArray[Byte],
  opt : DeflateOptions,
  pre : Int,
  post : Int,
  st : DeflateState?,
) -> FixedArray[Byte] {
  let (dat, st) = match st {
    Some(s) => (dat, s)
    None => {
      let s : DeflateState = {
        head: None,
        prev: None,
        i: 0,
        z: 0,
        w: 0,
        r: 0,
        l: 1,
      }
      match opt.dictionary {
        Some(dict) => {
          let dict_slice = if dict.length() > 32768 {
            slc(dict, dict.length() - 32768)
          } else {
            dict
          }
          let new_dat = FixedArray::make(
            dict_slice.length() + dat.length(),
            b'\x00',
          )
          fa_set(new_dat, dict_slice)
          fa_set(new_dat, dat, offset=dict_slice.length())
          s.w = dict_slice.length()
          (new_dat, s)
        }
        None => (dat, s)
      }
    }
  }
  let level = opt.level
  let mem = if opt.mem != 0 {
    12 + opt.mem
  } else if st.l != 0 {
    compute_mem_level(dat.length())
  } else {
    20
  }
  dflt(dat, level, mem, pre, post, st)
}

///|
/// Compress data with DEFLATE
pub fn deflate_sync(
  data : FixedArray[Byte],
  opts? : DeflateOptions = DeflateOptions::default(),
) -> FixedArray[Byte] {
  dopt(data, opts, 0, 0, None)
}
