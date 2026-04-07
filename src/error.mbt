///|
pub(all) enum FzipErrorCode {
  UnexpectedEOF // 0
  InvalidBlockType // 1
  InvalidLengthLiteral // 2
  InvalidDistance // 3
  StreamFinished // 4
  NoStreamHandler // 5
  InvalidHeader // 6
  NoCallback // 7
  InvalidUTF8 // 8
  ExtraFieldTooLong // 9
  InvalidDate // 10
  FilenameTooLong // 11
  StreamFinishing // 12
  InvalidZipData // 13
  UnknownCompressionMethod // 14
  InvalidChecksum // 15
} derive(Eq, Debug)

///|
pub impl Show for FzipErrorCode with output(self, logger) {
  match self {
    UnexpectedEOF => logger.write_string("UnexpectedEOF")
    InvalidBlockType => logger.write_string("InvalidBlockType")
    InvalidLengthLiteral => logger.write_string("InvalidLengthLiteral")
    InvalidDistance => logger.write_string("InvalidDistance")
    StreamFinished => logger.write_string("StreamFinished")
    NoStreamHandler => logger.write_string("NoStreamHandler")
    InvalidHeader => logger.write_string("InvalidHeader")
    NoCallback => logger.write_string("NoCallback")
    InvalidUTF8 => logger.write_string("InvalidUTF8")
    ExtraFieldTooLong => logger.write_string("ExtraFieldTooLong")
    InvalidDate => logger.write_string("InvalidDate")
    FilenameTooLong => logger.write_string("FilenameTooLong")
    StreamFinishing => logger.write_string("StreamFinishing")
    InvalidZipData => logger.write_string("InvalidZipData")
    UnknownCompressionMethod => logger.write_string("UnknownCompressionMethod")
    InvalidChecksum => logger.write_string("InvalidChecksum")
  }
}

///|
let error_messages : Array[String] = [
  "unexpected EOF", "invalid block type", "invalid length/literal", "invalid distance",
  "stream finished", "no stream handler", "invalid header", "no callback", "invalid UTF-8 data",
  "extra field too long", "date not in range 1980-2099", "filename too long", "stream finishing",
  "invalid zip data", "unknown compression method", "invalid checksum",
]

///|
pub(all) suberror FzipError {
  FzipError(code~ : FzipErrorCode, message~ : String)
}

///|
fn fzip_error_code_to_int(code : FzipErrorCode) -> Int {
  match code {
    UnexpectedEOF => 0
    InvalidBlockType => 1
    InvalidLengthLiteral => 2
    InvalidDistance => 3
    StreamFinished => 4
    NoStreamHandler => 5
    InvalidHeader => 6
    NoCallback => 7
    InvalidUTF8 => 8
    ExtraFieldTooLong => 9
    InvalidDate => 10
    FilenameTooLong => 11
    StreamFinishing => 12
    InvalidZipData => 13
    UnknownCompressionMethod => 14
    InvalidChecksum => 15
  }
}

///|
fn fzip_err(code : FzipErrorCode, msg? : String = "") -> FzipError {
  let message = if msg != "" {
    msg
  } else {
    error_messages[fzip_error_code_to_int(code)]
  }
  FzipError(code~, message~)
}
