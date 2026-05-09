///|
/// Default maximum uncompressed output size for defensive decompression.
///
/// Used as the default value in decompression option structs.
pub let default_max_output_size : Int = 104857600

///|
/// Default maximum compressed input size for defensive decompression.
///
/// Used as the default value in decompression option structs.
pub let default_max_input_size : Int = 1073741824

///|
/// ZIP central directory file-header signature.
pub let zip_cd_signature : UInt = 0x02014B50U

///|
/// ZIP local file-header signature.
pub let zip_local_signature : UInt = 0x04034B50U

///|
/// ZIP end-of-central-directory signature.
pub let zip_eocd_signature : UInt = 0x06054B50U

///|
/// ZIP64 end-of-central-directory record signature (PKWARE APPNOTE §4.3.14).
///
/// Replaces the misnamed `zip64_eocd_locator_signature`, which is kept as a
/// deprecated alias for source compatibility. The actual ZIP64 EOCD locator
/// signature is `zip64_locator_signature` below.
#alias(zip64_eocd_locator_signature, deprecated)
pub let zip64_eocd_signature : UInt = 0x06064B50U

///|
/// ZIP64 end-of-central-directory locator signature (PKWARE APPNOTE §4.3.15).
pub let zip64_locator_signature : UInt = 0x07064B50U

///|
/// ZIP64 extended information extra field header id (PKWARE APPNOTE §4.5.3).
let zip64_extra_field_id : Int = 0x0001

///|
/// Maximum value for a 16-bit ZIP field. Used as the ZIP64 promotion sentinel
/// for the entry-count field in the classic EOCD record.
let zip_uint16_max : Int = 65535

///|
/// Maximum value for a 32-bit ZIP field. Used as the ZIP64 promotion sentinel
/// for size/offset fields in classic ZIP headers and the EOCD record.
let zip_uint32_max : UInt = 0xffffffffU

///|
/// Maximum total extra-field length accepted on a single local or central
/// directory entry. Larger values are rejected with `ExtraFieldTooLong`
/// before scanning individual extra fields, so an oversized declared length
/// cannot drive a long parser scan.
let max_extra_field_length : Int = 4096

///|
/// Maximum filename length accepted while reading ZIP central directory entries.
pub let max_filename_length : Int = 4096

// Compressibility detection thresholds

///|
/// Minimum input length before the compressor samples data for compressibility.
pub let min_compressibility_check_len : Int = 128

///|
/// Size below which compressibility detection scans the whole input.
pub let full_scan_threshold : Int = 8192

///|
/// Unique-byte threshold that marks small inputs as high entropy candidates.
pub let high_entropy_unique_threshold : Int = 240

///|
/// Frequency-skew divisor used to detect compressible high-entropy inputs.
pub let freq_skew_shift : Int = 5

///|
/// Number of positions sampled when checking high-entropy data for periodicity.
pub let periodicity_check_samples : Int = 64

///|
/// Unique-byte threshold in sampled large inputs that suggests incompressibility.
pub let sampling_entropy_threshold : Int = 200

///|
/// Sampling stride used by large-input compressibility detection.
pub let sampling_stride : Int = 64

// Memory level computation thresholds

///|
/// Size below which compression uses a smaller hash table to reduce overhead.
pub let small_data_mem_threshold : Int = 2048
