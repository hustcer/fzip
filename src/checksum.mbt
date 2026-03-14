///|
/// CRC-32 lookup table (generated from polynomial 0xEDB88320)
let crct : FixedArray[UInt] = {
  let t : FixedArray[UInt] = FixedArray::make(256, 0U)
  for i in 0..<256 {
    let mut c = i.reinterpret_as_uint()
    for _k in 0..<8 {
      c = if (c & 1U) != 0U { 0xEDB88320U ^ (c >> 1) } else { c >> 1 }
    }
    t[i] = c
  }
  t
}

///|
/// Slice-by-4 CRC-32 table 1 (one extra CRC step from crct)
let crct1 : FixedArray[UInt] = {
  let t : FixedArray[UInt] = FixedArray::make(256, 0U)
  for i in 0..<256 {
    let c = crct[i]
    t[i] = crct[(c & 0xFFU).reinterpret_as_int()] ^ (c >> 8)
  }
  t
}

///|
/// Slice-by-4 CRC-32 table 2 (two extra CRC steps from crct)
let crct2 : FixedArray[UInt] = {
  let t : FixedArray[UInt] = FixedArray::make(256, 0U)
  for i in 0..<256 {
    let c = crct1[i]
    t[i] = crct[(c & 0xFFU).reinterpret_as_int()] ^ (c >> 8)
  }
  t
}

///|
/// Slice-by-4 CRC-32 table 3 (three extra CRC steps from crct)
let crct3 : FixedArray[UInt] = {
  let t : FixedArray[UInt] = FixedArray::make(256, 0U)
  for i in 0..<256 {
    let c = crct2[i]
    t[i] = crct[(c & 0xFFU).reinterpret_as_int()] ^ (c >> 8)
  }
  t
}

///|
/// Compute CRC-32 checksum of data (Slice-by-4 algorithm)
pub fn crc32(data : FixedArray[Byte]) -> UInt {
  let mut c = 0xFFFFFFFFU
  let mut i = 0
  let l = data.length()
  while i + 3 < l {
    c = c ^
      (
        data[i].to_uint() |
        (data[i + 1].to_uint() << 8) |
        (data[i + 2].to_uint() << 16) |
        (data[i + 3].to_uint() << 24)
      )
    c = crct3[(c & 0xFFU).reinterpret_as_int()] ^
      crct2[((c >> 8) & 0xFFU).reinterpret_as_int()] ^
      crct1[((c >> 16) & 0xFFU).reinterpret_as_int()] ^
      crct[(c >> 24).reinterpret_as_int()]
    i += 4
  }
  while i < l {
    c = crct[((c ^ data[i].to_uint()) & 0xFFU).reinterpret_as_int()] ^ (c >> 8)
    i += 1
  }
  c ^ 0xFFFFFFFFU
}

///|
/// Incremental CRC-32 state
priv struct CRC32State {
  mut c : UInt
}

///|
fn CRC32State::new() -> CRC32State {
  { c: 0xFFFFFFFFU }
}

///|
/// Feed data into the CRC-32 state (Slice-by-4)
fn CRC32State::push(self : CRC32State, data : FixedArray[Byte]) -> Unit {
  let mut cr = self.c
  let mut i = 0
  let l = data.length()
  while i + 3 < l {
    cr = cr ^
      (
        data[i].to_uint() |
        (data[i + 1].to_uint() << 8) |
        (data[i + 2].to_uint() << 16) |
        (data[i + 3].to_uint() << 24)
      )
    cr = crct3[(cr & 0xFFU).reinterpret_as_int()] ^
      crct2[((cr >> 8) & 0xFFU).reinterpret_as_int()] ^
      crct1[((cr >> 16) & 0xFFU).reinterpret_as_int()] ^
      crct[(cr >> 24).reinterpret_as_int()]
    i += 4
  }
  while i < l {
    cr = crct[((cr ^ data[i].to_uint()) & 0xFFU).reinterpret_as_int()] ^
      (cr >> 8)
    i += 1
  }
  self.c = cr
}

///|
/// Feed partial data into the CRC-32 state (Slice-by-4)
fn CRC32State::push_range(
  self : CRC32State,
  data : FixedArray[Byte],
  offset : Int,
  len : Int,
) -> Unit {
  let mut cr = self.c
  let end = offset + len
  let mut i = offset
  while i + 3 < end {
    cr = cr ^
      (
        data[i].to_uint() |
        (data[i + 1].to_uint() << 8) |
        (data[i + 2].to_uint() << 16) |
        (data[i + 3].to_uint() << 24)
      )
    cr = crct3[(cr & 0xFFU).reinterpret_as_int()] ^
      crct2[((cr >> 8) & 0xFFU).reinterpret_as_int()] ^
      crct1[((cr >> 16) & 0xFFU).reinterpret_as_int()] ^
      crct[(cr >> 24).reinterpret_as_int()]
    i += 4
  }
  while i < end {
    cr = crct[((cr ^ data[i].to_uint()) & 0xFFU).reinterpret_as_int()] ^
      (cr >> 8)
    i += 1
  }
  self.c = cr
}

///|
/// Get the final CRC-32 value
fn CRC32State::digest(self : CRC32State) -> UInt {
  self.c ^ 0xFFFFFFFFU
}

///|
/// Compute Adler-32 checksum of data
pub fn adler32(data : FixedArray[Byte]) -> UInt {
  let mut a : UInt = 1U
  let mut b : UInt = 0U
  let l = data.length()
  let mut i = 0
  while i < l {
    let e = if i + 2655 < l { i + 2655 } else { l }
    while i + 7 < e {
      let b0 = data[i].to_uint()
      let b1 = data[i + 1].to_uint()
      let b2 = data[i + 2].to_uint()
      let b3 = data[i + 3].to_uint()
      let b4 = data[i + 4].to_uint()
      let b5 = data[i + 5].to_uint()
      let b6 = data[i + 6].to_uint()
      let b7 = data[i + 7].to_uint()
      a = a + b0
      b = b + a
      a = a + b1
      b = b + a
      a = a + b2
      b = b + a
      a = a + b3
      b = b + a
      a = a + b4
      b = b + a
      a = a + b5
      b = b + a
      a = a + b6
      b = b + a
      a = a + b7
      b = b + a
      i += 8
    }
    while i < e {
      a = a + data[i].to_uint()
      b = b + a
      i += 1
    }
    a = (a & 65535U) + 15U * (a >> 16)
    b = (b & 65535U) + 15U * (b >> 16)
  }
  a = a % 65521U
  b = b % 65521U
  ((a & 0xFFU) << 24) | ((a & 0xFF00U) << 8) | ((b & 0xFFU) << 8) | (b >> 8)
}

///|
/// Incremental Adler-32 state
priv struct AdlerState {
  mut a : UInt
  mut b : UInt
}

///|
fn AdlerState::new() -> AdlerState {
  { a: 1U, b: 0U }
}

///|
/// Feed data into the Adler-32 state
fn AdlerState::push(self : AdlerState, data : FixedArray[Byte]) -> Unit {
  let mut n = self.a
  let mut m = self.b
  let l = data.length()
  let mut i = 0
  while i < l {
    let e = if i + 2655 < l { i + 2655 } else { l }
    while i + 7 < e {
      let b0 = data[i].to_uint()
      let b1 = data[i + 1].to_uint()
      let b2 = data[i + 2].to_uint()
      let b3 = data[i + 3].to_uint()
      let b4 = data[i + 4].to_uint()
      let b5 = data[i + 5].to_uint()
      let b6 = data[i + 6].to_uint()
      let b7 = data[i + 7].to_uint()
      n = n + b0
      m = m + n
      n = n + b1
      m = m + n
      n = n + b2
      m = m + n
      n = n + b3
      m = m + n
      n = n + b4
      m = m + n
      n = n + b5
      m = m + n
      n = n + b6
      m = m + n
      n = n + b7
      m = m + n
      i += 8
    }
    while i < e {
      n = n + data[i].to_uint()
      m = m + n
      i += 1
    }
    n = (n & 65535U) + 15U * (n >> 16)
    m = (m & 65535U) + 15U * (m >> 16)
  }
  self.a = n
  self.b = m
}

///|
/// Feed partial data into the Adler-32 state (offset and length)
fn AdlerState::push_range(
  self : AdlerState,
  data : FixedArray[Byte],
  offset : Int,
  len : Int,
) -> Unit {
  let mut n = self.a
  let mut m = self.b
  let end = offset + len
  let mut i = offset
  while i < end {
    let e = if i + 2655 < end { i + 2655 } else { end }
    while i + 7 < e {
      let b0 = data[i].to_uint()
      let b1 = data[i + 1].to_uint()
      let b2 = data[i + 2].to_uint()
      let b3 = data[i + 3].to_uint()
      let b4 = data[i + 4].to_uint()
      let b5 = data[i + 5].to_uint()
      let b6 = data[i + 6].to_uint()
      let b7 = data[i + 7].to_uint()
      n = n + b0
      m = m + n
      n = n + b1
      m = m + n
      n = n + b2
      m = m + n
      n = n + b3
      m = m + n
      n = n + b4
      m = m + n
      n = n + b5
      m = m + n
      n = n + b6
      m = m + n
      n = n + b7
      m = m + n
      i += 8
    }
    while i < e {
      n = n + data[i].to_uint()
      m = m + n
      i += 1
    }
    n = (n & 65535U) + 15U * (n >> 16)
    m = (m & 65535U) + 15U * (m >> 16)
  }
  self.a = n
  self.b = m
}

///|
/// Get the final Adler-32 value
fn AdlerState::digest(self : AdlerState) -> UInt {
  let a = self.a % 65521U
  let b = self.b % 65521U
  ((a & 0xFFU) << 24) | ((a & 0xFF00U) << 8) | ((b & 0xFFU) << 8) | (b >> 8)
}
