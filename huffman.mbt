///|
/// From extra bits, generate base values and reverse index map
/// Returns (b: base values array of 31, r: reverse map)
fn freb(
  eb : FixedArray[Byte],
  start : Int,
) -> (FixedArray[Int], FixedArray[Int]) {
  let b : FixedArray[Int] = FixedArray::make(31, 0)
  let mut s = start
  for i in 0..<31 {
    // In JS: b[i] = start += 1 << eb[i - 1]
    // eb[-1] is undefined in JS, so 1 << undefined = 1
    let shift = if i > 0 { eb[i - 1].to_int() } else { 0 }
    s = s + (1 << shift)
    b[i] = s
  }
  // numbers here are at max 18 bits
  let r : FixedArray[Int] = FixedArray::make(b[30], 0)
  for i in 1..<30 {
    for j in b[i]..<b[i + 1] {
      r[j] = ((j - b[i]) << 5) | i
    }
  }
  (b, r)
}

///|
/// Create Huffman code mapping from code lengths
/// cd: code lengths, mb: max bits, r: 0=encode, 1=decode
fn h_map(cd : FixedArray[Byte], mb : Int, r : Int) -> FixedArray[Int] {
  let s = cd.length()
  // count codes of each length
  let l : FixedArray[Int] = FixedArray::make(mb, 0)
  for i in 0..<s {
    if cd[i].to_int() != 0 {
      l[cd[i].to_int() - 1] = l[cd[i].to_int() - 1] + 1
    }
  }
  // minimum code for each length
  let le : FixedArray[Int] = FixedArray::make(mb, 0)
  for i in 1..<mb {
    le[i] = (le[i - 1] + l[i - 1]) << 1
  }
  let co : FixedArray[Int] = if r != 0 {
    let co2 = FixedArray::make(1 << mb, 0)
    let rvb = 15 - mb
    for i in 0..<s {
      if cd[i].to_int() != 0 {
        let sv = (i << 4) | cd[i].to_int()
        let rb = mb - cd[i].to_int()
        let mut v = le[cd[i].to_int() - 1] << rb
        le[cd[i].to_int() - 1] = le[cd[i].to_int() - 1] + 1
        let m = v | ((1 << rb) - 1)
        while v <= m {
          co2[rev[v] >> rvb] = sv
          v += 1
        }
      }
    }
    co2
  } else {
    let co2 = FixedArray::make(s, 0)
    for i in 0..<s {
      if cd[i].to_int() != 0 {
        co2[i] = rev[le[cd[i].to_int() - 1]] >> (15 - cd[i].to_int())
        le[cd[i].to_int() - 1] = le[cd[i].to_int() - 1] + 1
      }
    }
    co2
  }
  co
}

///|
/// Huffman tree node
priv struct HuffNode {
  s : Int // symbol (-1 for internal)
  f : Int // frequency
  l : HuffNode? // left child
  r : HuffNode? // right child
} derive(Show)

///|
/// Recursively get max depth and assign code lengths
fn ln_node(n : HuffNode, lengths : FixedArray[Int], d : Int) -> Int {
  if n.s == -1 {
    let left_max = match n.l {
      Some(left) => ln_node(left, lengths, d + 1)
      None => d
    }
    let right_max = match n.r {
      Some(right) => ln_node(right, lengths, d + 1)
      None => d
    }
    if left_max > right_max {
      left_max
    } else {
      right_max
    }
  } else {
    lengths[n.s] = d
    d
  }
}

///|
/// Create code lengths from a frequency table
/// d: frequency table, mb: max allowed bits
/// Returns (t: code lengths, l: max bits used)
fn h_tree(d : FixedArray[Int], mb : Int) -> (FixedArray[Byte], Int) {
  let et : FixedArray[Byte] = FixedArray::make(0, b'\x00')
  // Collect non-zero frequency symbols
  let nodes : Array[HuffNode] = []
  for i in 0..<d.length() {
    if d[i] != 0 {
      nodes.push({ s: i, f: d[i], l: None, r: None })
    }
  }
  let s = nodes.length()
  let t2 : Array[HuffNode] = []
  for i in 0..<s {
    t2.push(nodes[i])
  }
  if s == 0 {
    return (et, 0)
  }
  if s == 1 {
    let v : FixedArray[Byte] = FixedArray::make(nodes[0].s + 1, b'\x00')
    v[nodes[0].s] = b'\x01'
    return (v, 1)
  }
  // Sort by frequency
  nodes.sort_by(fn(a, b) { a.f - b.f })
  // sentinel
  nodes.push({ s: -1, f: 25001, l: None, r: None })
  let l_node = nodes[0]
  let r_node = nodes[1]
  nodes[0] = { s: -1, f: l_node.f + r_node.f, l: Some(l_node), r: Some(r_node) }
  let mut i0 = 0
  let mut i1 = 1
  let mut i2 = 2
  while i1 != s - 1 {
    let left = if nodes[i0].f < nodes[i2].f {
      let n = nodes[i0]
      i0 += 1
      n
    } else {
      let n = nodes[i2]
      i2 += 1
      n
    }
    let right = if i0 != i1 && nodes[i0].f < nodes[i2].f {
      let n = nodes[i0]
      i0 += 1
      n
    } else {
      let n = nodes[i2]
      i2 += 1
      n
    }
    nodes[i1] = { s: -1, f: left.f + right.f, l: Some(left), r: Some(right) }
    i1 += 1
  }
  // Find max symbol
  let mut max_sym = t2[0].s
  for i in 1..<s {
    if t2[i].s > max_sym {
      max_sym = t2[i].s
    }
  }
  // Compute code lengths
  let tr : FixedArray[Int] = FixedArray::make(max_sym + 1, 0)
  let mut mbt = ln_node(nodes[i1 - 1], tr, 0)
  if mbt > mb {
    // Limit code lengths to mb
    let mut i = 0
    let mut dt = 0
    let lft = mbt - mb
    let cst = 1 << lft
    // Sort by code length desc, then frequency asc
    t2.sort_by(fn(a, b) {
      if tr[b.s] != tr[a.s] {
        tr[b.s] - tr[a.s]
      } else {
        a.f - b.f
      }
    })
    while i < s {
      let i2v = t2[i].s
      if tr[i2v] > mb {
        dt += cst - (1 << (mbt - tr[i2v]))
        tr[i2v] = mb
        i += 1
      } else {
        break
      }
    }
    dt = dt >> lft
    while dt > 0 {
      let i2v = t2[i].s
      if tr[i2v] < mb {
        dt -= 1 << (mb - tr[i2v] - 1)
        tr[i2v] = tr[i2v] + 1
      } else {
        i += 1
      }
    }
    // i >= 0 check
    while i > 0 && dt < 0 {
      i -= 1
      let i2v = t2[i].s
      if tr[i2v] == mb {
        tr[i2v] = tr[i2v] - 1
        dt += 1
      }
    }
    mbt = mb
  }
  // Convert to byte array
  let result : FixedArray[Byte] = FixedArray::make(max_sym + 1, b'\x00')
  for i in 0..<=max_sym {
    result[i] = tr[i].to_byte()
  }
  (result, mbt)
}

///|
/// Generate length codes from a code length array
/// Returns (codes array, count of meaningful entries)
fn lc_gen(c : FixedArray[Byte]) -> (FixedArray[Int], Int) {
  let mut s = c.length()
  // Find last nonzero
  while s > 0 && c[s - 1] == b'\x00' {
    s -= 1
  }
  if s == 0 {
    // Return a single zero-length code entry (represents 1 symbol with length 0)
    return (FixedArray::make(1, 0), 1)
  }
  let cl : FixedArray[Int] = FixedArray::make(s * 3, 0)
  let mut cli = 0
  let mut cln = c[0].to_int()
  let mut cls = 1
  for i in 1..<=s {
    if i < s && c[i].to_int() == cln {
      cls += 1
    } else {
      if cln == 0 && cls > 2 {
        while cls > 138 {
          cl[cli] = 32754
          cli += 1
          cls -= 138
        }
        if cls > 2 {
          if cls > 10 {
            cl[cli] = ((cls - 11) << 5) | 28690
          } else {
            cl[cli] = ((cls - 3) << 5) | 12305
          }
          cli += 1
          cls = 0
        }
      } else if cls > 3 {
        cl[cli] = cln
        cli += 1
        cls -= 1
        while cls > 6 {
          cl[cli] = 8304
          cli += 1
          cls -= 6
        }
        if cls > 2 {
          cl[cli] = ((cls - 3) << 5) | 8208
          cli += 1
          cls = 0
        }
      }
      while cls > 0 {
        cl[cli] = cln
        cli += 1
        cls -= 1
      }
      cls = 1
      if i < s {
        cln = c[i].to_int()
      }
    }
  }
  // Return slice of used portion
  let result : FixedArray[Int] = FixedArray::make(cli, 0)
  for i in 0..<cli {
    result[i] = cl[i]
  }
  (result, s)
}

///|
/// Calculate output bit length from frequency and code length tables
fn clen(cf : FixedArray[Int], cl : FixedArray[Byte]) -> Int {
  let mut l = 0
  for i in 0..<cl.length() {
    if i < cf.length() {
      l += cf[i] * cl[i].to_int()
    }
  }
  l
}

///|
// Derived constants from freb
let fl : FixedArray[Int] = {
  let (b, _) = freb(fleb, 2)
  b[28] = 258
  b
}

///|
let revfl : FixedArray[Int] = {
  let (_, r) = freb(fleb, 2)
  r[258] = 28
  r
}

///|
let fd : FixedArray[Int] = {
  let (b, _) = freb(fdeb, 0)
  b
}

///|
let revfd : FixedArray[Int] = {
  let (_, r) = freb(fdeb, 0)
  r
}

///|
/// Fixed length encoding map
let flm : FixedArray[Int] = h_map(flt, 9, 0)

///|
/// Fixed length decoding map
let flrm : FixedArray[Int] = h_map(flt, 9, 1)

///|
/// Fixed distance encoding map
let fdm : FixedArray[Int] = h_map(fdt, 5, 0)

///|
/// Fixed distance decoding map
let fdrm : FixedArray[Int] = h_map(fdt, 5, 1)
