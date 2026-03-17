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

// Compressibility detection thresholds

///|
/// Minimum data length to trigger compressibility check (bytes below this are always compressed)
pub let min_compressibility_check_len : Int = 128

///|
/// Full scan threshold: data below this size uses full byte scan instead of sampling
pub let full_scan_threshold : Int = 8192

///|
/// High entropy threshold: unique byte count above this triggers frequency analysis
pub let high_entropy_unique_threshold : Int = 240

///|
/// Frequency skew shift: max_freq > (len >> this) indicates compressible skewed distribution
/// (shift by 5 = divide by 32 = 3.125% threshold)
pub let freq_skew_shift : Int = 5

///|
/// Periodicity check sample size for high-entropy data
pub let periodicity_check_samples : Int = 64

///|
/// Sampling entropy threshold: unique count above this in samples suggests incompressible
pub let sampling_entropy_threshold : Int = 200

///|
/// Sampling divisor: sample every Nth byte for large data compressibility check
pub let sampling_stride : Int = 64

// Memory level computation thresholds

///|
/// Small data threshold for aggressive memory optimization (uses mem_level=10)
pub let small_data_mem_threshold : Int = 2048
