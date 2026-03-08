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
/// Compute CRC-32 checksum of data
pub fn crc32(data : FixedArray[Byte]) -> UInt {
  let mut c = 0xFFFFFFFFU
  for i in 0..<data.length() {
    c = crct[((c ^ data[i].to_uint()) & 0xFFU).reinterpret_as_int()] ^ (c >> 8)
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
/// Feed data into the CRC-32 state
fn CRC32State::push(self : CRC32State, data : FixedArray[Byte]) -> Unit {
  let mut cr = self.c
  for i in 0..<data.length() {
    cr = crct[((cr ^ data[i].to_uint()) & 0xFFU).reinterpret_as_int()] ^
      (cr >> 8)
  }
  self.c = cr
}

///|
/// Feed partial data into the CRC-32 state (offset and length)
fn CRC32State::push_range(
  self : CRC32State,
  data : FixedArray[Byte],
  offset : Int,
  len : Int,
) -> Unit {
  let mut cr = self.c
  let end = offset + len
  for i in offset..<end {
    cr = crct[((cr ^ data[i].to_uint()) & 0xFFU).reinterpret_as_int()] ^
      (cr >> 8)
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
