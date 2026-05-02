///|
/// Error categories reported by fzip operations.
///
/// Most public decompression and archive-reading APIs raise `FzipError` with
/// one of these codes. The code is intended for programmatic handling while the
/// error message gives a human-readable explanation.
pub(all) enum FzipErrorCode {
  /// The input ended before the current format could be fully decoded.
  UnexpectedEOF
  /// A DEFLATE block used an invalid block type.
  InvalidBlockType
  /// A DEFLATE length or literal code was invalid.
  InvalidLengthLiteral
  /// A DEFLATE back-reference distance was invalid.
  InvalidDistance
  /// Reserved for stream state errors after a stream has finished.
  StreamFinished
  /// Reserved for stream APIs that require an `ondata` handler.
  NoStreamHandler
  /// A container header, such as GZIP or Zlib, is malformed or unsupported.
  InvalidHeader
  /// Reserved for APIs that require a callback.
  NoCallback
  /// Byte data could not be decoded as valid UTF-8.
  InvalidUTF8
  /// Reserved for ZIP extra fields that exceed supported lengths.
  ExtraFieldTooLong
  /// Reserved for ZIP timestamps outside the supported date range.
  InvalidDate
  /// Reserved for filenames that exceed supported lengths.
  FilenameTooLong
  /// Reserved for stream state errors while finishing.
  StreamFinishing
  /// ZIP data is malformed, unsafe, or violates configured safety limits.
  InvalidZipData
  /// A ZIP entry uses a compression method fzip does not support.
  UnknownCompressionMethod
  /// A checksum footer does not match the decompressed data.
  InvalidChecksum
} derive(Eq, Debug)

///|
/// Write the symbolic error-code name, such as `"InvalidHeader"`.
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
/// Error raised by fzip decoding, decompression, and archive-reading APIs.
///
/// `code` is stable enough for branching in callers. `message` may include
/// additional context such as the failed format check or violated safety limit.
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
