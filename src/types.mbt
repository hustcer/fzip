///|
pub(all) struct DeflateOptions {
  level : Int // 0-9, default 6
  mem : Int // 0-12, memory level
  dictionary : FixedArray[Byte]? // compression dictionary
} derive(Show)

///|
pub fn DeflateOptions::default() -> DeflateOptions {
  { level: 6, mem: 0, dictionary: None }
}

///|
pub(all) struct InflateOptions {
  out : FixedArray[Byte]? // pre-allocated output buffer
  dictionary : FixedArray[Byte]? // decompression dictionary
  max_output_size : Int // maximum uncompressed size (default 100MB)
  max_input_size : Int // maximum compressed input size (default 1GB)
} derive(Show)

///|
pub fn InflateOptions::default() -> InflateOptions {
  {
    out: None,
    dictionary: None,
    max_output_size: default_max_output_size,
    max_input_size: default_max_input_size,
  }
}

///|
pub(all) struct GzipOptions {
  level : Int
  mem : Int
  dictionary : FixedArray[Byte]?
  mtime : Int // unix timestamp in seconds, 0 = omit
  filename : String
} derive(Show)

///|
pub fn GzipOptions::default() -> GzipOptions {
  { level: 6, mem: 0, dictionary: None, mtime: 0, filename: "" }
}

///|
pub(all) struct GunzipOptions {
  out : FixedArray[Byte]?
  dictionary : FixedArray[Byte]?
  max_output_size : Int // maximum uncompressed size (default 100MB)
  max_input_size : Int // maximum compressed input size (default 1GB)
  verify_checksum : Bool // verify CRC-32 checksum (default true)
} derive(Show)

///|
pub fn GunzipOptions::default() -> GunzipOptions {
  {
    out: None,
    dictionary: None,
    max_output_size: default_max_output_size,
    max_input_size: default_max_input_size,
    verify_checksum: true,
  }
}

///|
pub(all) struct ZlibOptions {
  level : Int
  mem : Int
  dictionary : FixedArray[Byte]?
} derive(Show)

///|
pub fn ZlibOptions::default() -> ZlibOptions {
  { level: 6, mem: 0, dictionary: None }
}

///|
pub(all) struct UnzlibOptions {
  out : FixedArray[Byte]?
  dictionary : FixedArray[Byte]?
  max_output_size : Int // maximum uncompressed size (default 100MB)
  max_input_size : Int // maximum compressed input size (default 1GB)
  verify_checksum : Bool // verify Adler-32 checksum (default true)
} derive(Show)

///|
pub fn UnzlibOptions::default() -> UnzlibOptions {
  {
    out: None,
    dictionary: None,
    max_output_size: default_max_output_size,
    max_input_size: default_max_input_size,
    verify_checksum: true,
  }
}

///|
pub(all) struct ZipEntryOptions {
  level : Int
  mem : Int
  os : Int // operating system, 0=MS-DOS, 3=Unix
  attrs : Int // file attributes
  extra : Array[(Int, FixedArray[Byte])] // extra fields
  comment : String
  mtime : Int // unix timestamp
} derive(Show)

///|
pub fn ZipEntryOptions::default() -> ZipEntryOptions {
  { level: 6, mem: 0, os: 0, attrs: 0, extra: [], comment: "", mtime: 0 }
}

///|
pub(all) struct UnzipFileInfo {
  name : String
  size : Int // compressed size
  original_size : Int // uncompressed size
  compression : Int // compression method (0=store, 8=deflate)
} derive(Show)
