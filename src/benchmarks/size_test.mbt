///|
test "sizes" {
  // Output compressed sizes as key=value pairs for gen-report.nu to parse
  // DEFLATE compress
  let z1k = make_zeros(1024)
  let z100k = make_zeros(102400)
  let s1k = make_sequential(1024)
  let s100k = make_sequential(102400)
  let r1k = make_random(1024, 42)
  let r100k = make_random(102400, 42)
  // DEFLATE zeros
  println(
    "SIZE deflate/compress/zeros_1k/fzip \{@fzip.deflate_sync(z1k).length()} 1024",
  )
  println(
    "SIZE deflate/compress/zeros_1k/moonzip \{@moonzip.deflate_sync(z1k).length()} 1024",
  )
  println(
    "SIZE deflate/compress/zeros_1k/zipc \{@deflate.deflate_of_bytes(fa_to_bytes(z1k), @deflate.level_default()).length()} 1024",
  )
  println(
    "SIZE deflate/compress/zeros_100k/fzip \{@fzip.deflate_sync(z100k).length()} 102400",
  )
  println(
    "SIZE deflate/compress/zeros_100k/moonzip \{@moonzip.deflate_sync(z100k).length()} 102400",
  )
  println(
    "SIZE deflate/compress/zeros_100k/zipc \{@deflate.deflate_of_bytes(fa_to_bytes(z100k), @deflate.level_default()).length()} 102400",
  )
  // DEFLATE seq
  println(
    "SIZE deflate/compress/seq_1k/fzip \{@fzip.deflate_sync(s1k).length()} 1024",
  )
  println(
    "SIZE deflate/compress/seq_1k/moonzip \{@moonzip.deflate_sync(s1k).length()} 1024",
  )
  println(
    "SIZE deflate/compress/seq_1k/zipc \{@deflate.deflate_of_bytes(fa_to_bytes(s1k), @deflate.level_default()).length()} 1024",
  )
  println(
    "SIZE deflate/compress/seq_100k/fzip \{@fzip.deflate_sync(s100k).length()} 102400",
  )
  println(
    "SIZE deflate/compress/seq_100k/moonzip \{@moonzip.deflate_sync(s100k).length()} 102400",
  )
  println(
    "SIZE deflate/compress/seq_100k/zipc \{@deflate.deflate_of_bytes(fa_to_bytes(s100k), @deflate.level_default()).length()} 102400",
  )
  // DEFLATE random
  println(
    "SIZE deflate/compress/random_1k/fzip \{@fzip.deflate_sync(r1k).length()} 1024",
  )
  println(
    "SIZE deflate/compress/random_1k/moonzip \{@moonzip.deflate_sync(r1k).length()} 1024",
  )
  println(
    "SIZE deflate/compress/random_1k/zipc \{@deflate.deflate_of_bytes(fa_to_bytes(r1k), @deflate.level_default()).length()} 1024",
  )
  println(
    "SIZE deflate/compress/random_100k/fzip \{@fzip.deflate_sync(r100k).length()} 102400",
  )
  println(
    "SIZE deflate/compress/random_100k/moonzip \{@moonzip.deflate_sync(r100k).length()} 102400",
  )
  println(
    "SIZE deflate/compress/random_100k/zipc \{@deflate.deflate_of_bytes(fa_to_bytes(r100k), @deflate.level_default()).length()} 102400",
  )
  // GZIP
  println(
    "SIZE gzip/compress/1k/fzip \{@fzip.gzip_sync(s1k).length()} 1024",
  )
  println(
    "SIZE gzip/compress/1k/moonzip \{@moonzip.gzip_sync(s1k).length()} 1024",
  )
  println(
    "SIZE gzip/compress/1k/zipc \{@deflate.gzip_of_bytes(fa_to_bytes(s1k), @deflate.level_default(), None, None).length()} 1024",
  )
  println(
    "SIZE gzip/compress/100k/fzip \{@fzip.gzip_sync(s100k).length()} 102400",
  )
  println(
    "SIZE gzip/compress/100k/moonzip \{@moonzip.gzip_sync(s100k).length()} 102400",
  )
  println(
    "SIZE gzip/compress/100k/zipc \{@deflate.gzip_of_bytes(fa_to_bytes(s100k), @deflate.level_default(), None, None).length()} 102400",
  )
  // Zlib
  println(
    "SIZE zlib/compress/1k/fzip \{@fzip.zlib_sync(s1k).length()} 1024",
  )
  println(
    "SIZE zlib/compress/1k/moonzip \{@moonzip.zlib_sync(s1k).length()} 1024",
  )
  println(
    "SIZE zlib/compress/1k/zipc \{@deflate.zlib_of_bytes(fa_to_bytes(s1k), @deflate.level_default()).length()} 1024",
  )
  println(
    "SIZE zlib/compress/100k/fzip \{@fzip.zlib_sync(s100k).length()} 102400",
  )
  println(
    "SIZE zlib/compress/100k/moonzip \{@moonzip.zlib_sync(s100k).length()} 102400",
  )
  println(
    "SIZE zlib/compress/100k/zipc \{@deflate.zlib_of_bytes(fa_to_bytes(s100k), @deflate.level_default()).length()} 102400",
  )
  // ZIP
  let files = make_zip_files()
  let zip_original = 512 + 2048 + 1024
  println(
    "SIZE zip/compress/fzip \{@fzip.zip_sync(files).length()} \{zip_original}",
  )
  println(
    "SIZE zip/compress/moonzip \{@moonzip.zip_sync(files).length()} \{zip_original}",
  )
}
