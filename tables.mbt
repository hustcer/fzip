///|
/// Fixed length extra bits (32 entries)
let fleb : FixedArray[Byte] = [
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x01',
  b'\x01', b'\x01', b'\x01', b'\x02', b'\x02', b'\x02', b'\x02', b'\x03', b'\x03',
  b'\x03', b'\x03', b'\x04', b'\x04', b'\x04', b'\x04', b'\x05', b'\x05', b'\x05',
  b'\x05', b'\x00', b'\x00', b'\x00', b'\x00',
]

///|
/// Fixed distance extra bits (32 entries)
let fdeb : FixedArray[Byte] = [
  b'\x00', b'\x00', b'\x00', b'\x00', b'\x01', b'\x01', b'\x02', b'\x02', b'\x03',
  b'\x03', b'\x04', b'\x04', b'\x05', b'\x05', b'\x06', b'\x06', b'\x07', b'\x07',
  b'\x08', b'\x08', b'\x09', b'\x09', b'\x0A', b'\x0A', b'\x0B', b'\x0B', b'\x0C',
  b'\x0C', b'\x0D', b'\x0D', b'\x00', b'\x00',
]

///|
/// Code length index map (19 entries)
let clim : FixedArray[Byte] = [
  b'\x10', b'\x11', b'\x12', b'\x00', b'\x08', b'\x07', b'\x09', b'\x06', b'\x0A',
  b'\x05', b'\x0B', b'\x04', b'\x0C', b'\x03', b'\x0D', b'\x02', b'\x0E', b'\x01',
  b'\x0F',
]

///|
/// 15-bit reversal table (32768 entries)
let rev : FixedArray[Int] = {
  let t : FixedArray[Int] = FixedArray::make(32768, 0)
  for i in 0..<32768 {
    let mut x = ((i & 0xAAAA) >> 1) | ((i & 0x5555) << 1)
    x = ((x & 0xCCCC) >> 2) | ((x & 0x3333) << 2)
    x = ((x & 0xF0F0) >> 4) | ((x & 0x0F0F) << 4)
    t[i] = (((x & 0xFF00) >> 8) | ((x & 0x00FF) << 8)) >> 1
  }
  t
}

///|
/// Fixed length tree (288 entries)
let flt : FixedArray[Byte] = {
  let t : FixedArray[Byte] = FixedArray::make(288, b'\x00')
  for i in 0..<144 {
    t[i] = b'\x08'
  }
  for i in 144..<256 {
    t[i] = b'\x09'
  }
  for i in 256..<280 {
    t[i] = b'\x07'
  }
  for i in 280..<288 {
    t[i] = b'\x08'
  }
  t
}

///|
/// Fixed distance tree (32 entries, all 5)
let fdt : FixedArray[Byte] = FixedArray::make(32, b'\x05')

///|
/// Deflate options table: (nice << 13) | chain
/// 9 entries for levels 1-9
let deo : FixedArray[Int] = [
  65540, 131080, 131088, 131104, 262176, 1048704, 1048832, 2114560, 2117632,
]
