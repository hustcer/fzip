///|
/// Default maximum output size for decompression (100MB)
pub let default_max_output_size : Int = 104857600

///|
/// Default maximum input size for decompression (1GB)
pub let default_max_input_size : Int = 1073741824

///|
/// ZIP Central Directory file header signature
pub let zip_cd_signature : UInt = 0x02014B50U

///|
/// ZIP Local File Header signature
pub let zip_local_signature : UInt = 0x04034B50U

///|
/// ZIP End of Central Directory signature
pub let zip_eocd_signature : UInt = 0x06054B50U

///|
/// ZIP64 End of Central Directory locator signature
pub let zip64_eocd_locator_signature : UInt = 0x06064B50U

///|
/// Maximum allowed filename length
pub let max_filename_length : Int = 4096
