#!/usr/bin/env nu

# Generate benchmark report from bench.json

def main [] {
    let data = open ($env.FILE_PWD)/bench.json
    let meta = $data.metadata

    # Header
    print $"# fzip Benchmark Report\n"
    print $"- Platform: ($meta.os)"
    print $"- MoonBit: ($meta.moon_version)"
    print $"- Target: ($meta.target)"
    print $"- Date: ($meta.timestamp | into datetime | format date '%Y-%m-%d')"
    print ""

    # Group benchmarks by category
    let benches = $data.benchmarks

    # DEFLATE Compress
    gen_deflate_compress $benches

    # DEFLATE Decompress
    gen_deflate_decompress $benches

    # GZIP
    gen_gzip $benches

    # Zlib
    gen_zlib $benches

    # ZIP
    gen_zip $benches

    # Checksum
    gen_checksum $benches

    # Auto-detect
    gen_auto_detect $benches
}

# Generate DEFLATE compress table
def gen_deflate_compress [benches: list] {
    print "## DEFLATE Compress\n"

    let patterns = [zeros seq random]
    let sizes = ['1k' '100k']

    print "| Pattern | Size | fzip | moonzip | zipc | Winner | Max-Min Ratio |"
    print "|---------|------|------|---------|------|--------|---------------|"

    for pattern in $patterns {
        for size in $sizes {
            let prefix = $'deflate/compress/($pattern)_($size)/'
            let fzip = $benches | where name == $'($prefix)fzip' | get 0
            let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
            let zipc = $benches | where name == $'($prefix)zipc' | get 0
            let stats = calc_stats {fzip: $fzip, moonzip: $moonzip, zipc: $zipc}

            print $"| ($pattern) | ($size | str upcase) | (fmt_time $fzip) | (fmt_time $moonzip) | (fmt_time $zipc) | ($stats.winner) | ($stats.ratio)x |"
        }
    }
    print ""
}

# Generate DEFLATE decompress table
def gen_deflate_decompress [benches: list] {
    print "## DEFLATE Decompress\n"
    print "| Size | fzip | moonzip | zipc | Winner | Max-Min Ratio |"
    print "|------|------|---------|------|--------|---------------|"

    for size in ['1k' '100k'] {
        let prefix = $'deflate/decompress/($size)/'
        let fzip = $benches | where name == $'($prefix)fzip' | get 0
        let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
        let zipc = $benches | where name == $'($prefix)zipc' | get 0
        let stats = calc_stats {fzip: $fzip, moonzip: $moonzip, zipc: $zipc}

        print $"| ($size | str upcase) | (fmt_time $fzip) | (fmt_time $moonzip) | (fmt_time $zipc) | ($stats.winner) | ($stats.ratio)x |"
    }
    print ""
}

# Generate GZIP table
def gen_gzip [benches: list] {
    print "## GZIP\n"
    print "| Operation | Size | fzip | moonzip | zipc | Winner | Max-Min Ratio |"
    print "|-----------|------|------|---------|------|--------|---------------|"

    for op in [compress decompress] {
        for size in ['1k' '100k'] {
            let prefix = $'gzip/($op)/($size)/'
            let fzip = $benches | where name == $'($prefix)fzip' | get 0
            let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
            let zipc = $benches | where name == $'($prefix)zipc' | get 0
            let stats = calc_stats {fzip: $fzip, moonzip: $moonzip, zipc: $zipc}

            print $"| ($op) | ($size | str upcase) | (fmt_time $fzip) | (fmt_time $moonzip) | (fmt_time $zipc) | ($stats.winner) | ($stats.ratio)x |"
        }
    }
    print ""
}

# Generate Zlib table
def gen_zlib [benches: list] {
    print "## Zlib\n"
    print "| Operation | Size | fzip | moonzip | zipc | Winner | Max-Min Ratio |"
    print "|-----------|------|------|---------|------|--------|---------------|"

    for op in [compress decompress] {
        for size in ['1k' '100k'] {
            let prefix = $'zlib/($op)/($size)/'
            let fzip = $benches | where name == $'($prefix)fzip' | get 0
            let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
            let zipc = $benches | where name == $'($prefix)zipc' | get 0
            let stats = calc_stats {fzip: $fzip, moonzip: $moonzip, zipc: $zipc}

            print $"| ($op) | ($size | str upcase) | (fmt_time $fzip) | (fmt_time $moonzip) | (fmt_time $zipc) | ($stats.winner) | ($stats.ratio)x |"
        }
    }
    print ""
}

# Generate ZIP table
def gen_zip [benches: list] {
    print "## ZIP\n"
    print "| Operation | fzip | moonzip | Winner | Max-Min Ratio |"
    print "|-----------|------|---------|--------|---------------|"

    for op in [compress decompress] {
        let prefix = $'zip/($op)/'
        let fzip = $benches | where name == $'($prefix)fzip' | get 0
        let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
        let stats = calc_stats {fzip: $fzip, moonzip: $moonzip}

        print $"| ($op) | (fmt_time $fzip) | (fmt_time $moonzip) | ($stats.winner) | ($stats.ratio)x |"
    }
    print ""
}

# Generate checksum table
def gen_checksum [benches: list] {
    print "## Checksum\n"
    print "| Algorithm | Size | fzip | moonzip | zipc | Winner | Max-Min Ratio |"
    print "|-----------|------|------|---------|------|--------|---------------|"

    for algo in [crc32 adler32] {
        for size in ['1k' '100k'] {
            let prefix = $'($algo)/($size)/'
            let fzip = $benches | where name == $'($prefix)fzip' | get 0
            let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
            let zipc = $benches | where name == $'($prefix)zipc' | get 0
            let stats = calc_stats {fzip: $fzip, moonzip: $moonzip, zipc: $zipc}

            print $"| ($algo | str upcase) | ($size | str upcase) | (fmt_time $fzip) | (fmt_time $moonzip) | (fmt_time $zipc) | ($stats.winner) | ($stats.ratio)x |"
        }
    }
    print ""
}

# Generate auto-detect table
def gen_auto_detect [benches: list] {
    print "## Auto-detect Decompress\n"
    print "| Size | fzip | moonzip | Winner | Max-Min Ratio |"
    print "|------|------|---------|--------|---------------|"

    for size in ['1k' '100k'] {
        let prefix = $'decompress/auto_detect/($size)/'
        let fzip = $benches | where name == $'($prefix)fzip' | get 0
        let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
        let stats = calc_stats {fzip: $fzip, moonzip: $moonzip}

        print $"| ($size | str upcase) | (fmt_time $fzip) | (fmt_time $moonzip) | ($stats.winner) | ($stats.ratio)x |"
    }
    print ""
}

# Format time with unit
def fmt_time [bench: record]: nothing -> string {
    let val = $bench.mean_us
    let unit = $bench.unit

    if $unit == 'ms' {
        $'($val | into string) ms'
    } else {
        $'($val | into string) µs'
    }
}

# Get time in microseconds for comparison
def get_us [bench: record]: nothing -> float {
    let val = $bench.mean_us
    let unit = $bench.unit

    # Handle both old format (not converted) and new format (already in µs)
    if $unit == 'ms' {
        $val * 1000.0
    } else if $unit == 's' {
        $val * 1_000_000.0
    } else if $unit == 'ns' {
        $val / 1000.0
    } else {
        $val
    }
}

# Calculate winner and max-min ratio
def calc_stats [benches: record]: nothing -> record {
    let times = $benches | transpose name time | each {|row| {name: $row.name, us: (get_us $row.time)}}
    let min = $times | get us | math min
    let max = $times | get us | math max
    let winner = $times | where us == $min | get name.0
    let ratio = $max / $min

    {winner: $winner, ratio: ($ratio | math round -p 1)}
}
