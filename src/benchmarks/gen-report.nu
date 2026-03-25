#!/usr/bin/env nu

# Generate benchmark report from bench.json and sizes.json

def main [] {
    let data = open ($env.FILE_PWD)/bench.json
    let meta = $data.metadata

    # Load size data if available
    let sizes_path = ($env.FILE_PWD) | path join 'sizes.json'
    let sizes = if ($sizes_path | path exists) {
        open $sizes_path
    } else {
        []
    }

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
    gen_deflate_compress $benches $sizes

    # DEFLATE Decompress
    gen_deflate_decompress $benches

    # GZIP
    gen_gzip $benches $sizes

    # Zlib
    gen_zlib $benches $sizes

    # ZIP
    gen_zip $benches $sizes

    # Checksum
    gen_checksum $benches

    # Auto-detect
    gen_auto_detect $benches
}

# Format compression ratio as percentage string
def fmt_ratio [name: string, sizes: list]: nothing -> string {
    let entry = $sizes | where name == $name
    if ($entry | is-empty) {
        '-'
    } else {
        let e = $entry | get 0
        let ratio = $e.compressed / $e.original * 100.0
        let rounded = $ratio | math round -p 1
        if $rounded >= 100.0 {
            $'($rounded)% ⚠️'
        } else {
            $'($rounded)%'
        }
    }
}

# Try to get a benchmark entry, return null if not found
def get_bench [benches: list, name: string]: nothing -> any {
    let found = $benches | where name == $name
    if ($found | is-empty) { null } else { $found | get 0 }
}

# Generate DEFLATE compress table
def gen_deflate_compress [benches: list, sizes: list] {
    print "## DEFLATE Compress\n"

    let patterns = [zeros seq random]
    let size_labels = ['1k' '100k']

    let rows = $patterns | each {|pattern|
        $size_labels | each {|size|
            let prefix = $'deflate/compress/($pattern)_($size)/'
            let fzip = $benches | where name == $'($prefix)fzip' | get 0
            let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
            let zipc = $benches | where name == $'($prefix)zipc' | get 0
            let bkl = get_bench $benches $'($prefix)bkl'
            let libs = {fzip: $fzip, moonzip: $moonzip, zipc: $zipc}
            let libs = if $bkl != null { $libs | merge {bkl: $bkl} } else { $libs }
            let stats = calc_stats $libs

            let row = {
                Pattern: $pattern,
                Size: ($size | str upcase),
                fzip: (fmt_time $fzip),
                moonzip: (fmt_time $moonzip),
                zipc: (fmt_time $zipc),
                bkl: (if $bkl != null { fmt_time $bkl } else { '-' }),
                Winner: $stats.winner,
                'Max-Min Ratio': $'($stats.ratio)x',
                'fzip Ratio': (fmt_ratio $'($prefix)fzip' $sizes),
                'moonzip Ratio': (fmt_ratio $'($prefix)moonzip' $sizes),
                'zipc Ratio': (fmt_ratio $'($prefix)zipc' $sizes),
                'bkl Ratio': (fmt_ratio $'($prefix)bkl' $sizes),
            }
            $row
        }
    } | flatten

    print ($rows | to md)
    print "\n> **⚠️ Note**:\n> - `zipc`  **does not perform real compression** (just stores) for data ≥1000 bytes, so its 100K speed metrics are not comparable. Ratio ≈100%.\n> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.\n> - Compression Ratio = Compressed Size / Original Size, smaller is better.\n"
}

# Generate DEFLATE decompress table
def gen_deflate_decompress [benches: list] {
    print "## DEFLATE Decompress\n"

    let rows = ['1k' '100k'] | each {|size|
        let prefix = $'deflate/decompress/($size)/'
        let fzip = $benches | where name == $'($prefix)fzip' | get 0
        let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
        let zipc = $benches | where name == $'($prefix)zipc' | get 0
        let bkl = get_bench $benches $'($prefix)bkl'
        let libs = {fzip: $fzip, moonzip: $moonzip, zipc: $zipc}
        let libs = if $bkl != null { $libs | merge {bkl: $bkl} } else { $libs }
        let stats = calc_stats $libs

        {
            Size: ($size | str upcase),
            fzip: (fmt_time $fzip),
            moonzip: (fmt_time $moonzip),
            zipc: (fmt_time $zipc),
            bkl: (if $bkl != null { fmt_time $bkl } else { '-' }),
            Winner: $stats.winner,
            'Max-Min Ratio': $'($stats.ratio)x'
        }
    }

    print ($rows | to md)
    print ""
}

# Generate GZIP table
def gen_gzip [benches: list, sizes: list] {
    print "## GZIP\n"

    let rows = [compress decompress] | each {|op|
        ['1k' '100k'] | each {|size|
            let prefix = $'gzip/($op)/($size)/'
            let fzip = $benches | where name == $'($prefix)fzip' | get 0
            let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
            let zipc = $benches | where name == $'($prefix)zipc' | get 0
            let bkl = get_bench $benches $'($prefix)bkl'
            let libs = {fzip: $fzip, moonzip: $moonzip, zipc: $zipc}
            let libs = if $bkl != null { $libs | merge {bkl: $bkl} } else { $libs }
            let stats = calc_stats $libs

            if $op == 'compress' {
                {
                    Operation: $op,
                    Size: ($size | str upcase),
                    fzip: (fmt_time $fzip),
                    moonzip: (fmt_time $moonzip),
                    zipc: (fmt_time $zipc),
                    bkl: (if $bkl != null { fmt_time $bkl } else { '-' }),
                    Winner: $stats.winner,
                    'Max-Min Ratio': $'($stats.ratio)x',
                    'fzip Ratio': (fmt_ratio $'($prefix)fzip' $sizes),
                    'moonzip Ratio': (fmt_ratio $'($prefix)moonzip' $sizes),
                    'zipc Ratio': (fmt_ratio $'($prefix)zipc' $sizes),
                    'bkl Ratio': (fmt_ratio $'($prefix)bkl' $sizes),
                }
            } else {
                {
                    Operation: $op,
                    Size: ($size | str upcase),
                    fzip: (fmt_time $fzip),
                    moonzip: (fmt_time $moonzip),
                    zipc: (fmt_time $zipc),
                    bkl: (if $bkl != null { fmt_time $bkl } else { '-' }),
                    Winner: $stats.winner,
                    'Max-Min Ratio': $'($stats.ratio)x',
                    'fzip Ratio': '-',
                    'moonzip Ratio': '-',
                    'zipc Ratio': '-',
                    'bkl Ratio': '-',
                }
            }
        }
    } | flatten

    print ($rows | to md)
    print ""
}

# Generate Zlib table
def gen_zlib [benches: list, sizes: list] {
    print "## Zlib\n"

    let rows = [compress decompress] | each {|op|
        ['1k' '100k'] | each {|size|
            let prefix = $'zlib/($op)/($size)/'
            let fzip = $benches | where name == $'($prefix)fzip' | get 0
            let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
            let zipc = $benches | where name == $'($prefix)zipc' | get 0
            let bkl = get_bench $benches $'($prefix)bkl'
            let libs = {fzip: $fzip, moonzip: $moonzip, zipc: $zipc}
            let libs = if $bkl != null { $libs | merge {bkl: $bkl} } else { $libs }
            let stats = calc_stats $libs

            if $op == 'compress' {
                {
                    Operation: $op,
                    Size: ($size | str upcase),
                    fzip: (fmt_time $fzip),
                    moonzip: (fmt_time $moonzip),
                    zipc: (fmt_time $zipc),
                    bkl: (if $bkl != null { fmt_time $bkl } else { '-' }),
                    Winner: $stats.winner,
                    'Max-Min Ratio': $'($stats.ratio)x',
                    'fzip Ratio': (fmt_ratio $'($prefix)fzip' $sizes),
                    'moonzip Ratio': (fmt_ratio $'($prefix)moonzip' $sizes),
                    'zipc Ratio': (fmt_ratio $'($prefix)zipc' $sizes),
                    'bkl Ratio': (fmt_ratio $'($prefix)bkl' $sizes),
                }
            } else {
                {
                    Operation: $op,
                    Size: ($size | str upcase),
                    fzip: (fmt_time $fzip),
                    moonzip: (fmt_time $moonzip),
                    zipc: (fmt_time $zipc),
                    bkl: (if $bkl != null { fmt_time $bkl } else { '-' }),
                    Winner: $stats.winner,
                    'Max-Min Ratio': $'($stats.ratio)x',
                    'fzip Ratio': '-',
                    'moonzip Ratio': '-',
                    'zipc Ratio': '-',
                    'bkl Ratio': '-',
                }
            }
        }
    } | flatten

    print ($rows | to md)
    print ""
}

# Generate ZIP table
def gen_zip [benches: list, sizes: list] {
    print "## ZIP\n"

    let rows = [compress decompress] | each {|op|
        let prefix = $'zip/($op)/'
        let fzip = $benches | where name == $'($prefix)fzip' | get 0
        let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
        let stats = calc_stats {fzip: $fzip, moonzip: $moonzip}

        if $op == 'compress' {
            {
                Operation: $op,
                fzip: (fmt_time $fzip),
                moonzip: (fmt_time $moonzip),
                Winner: $stats.winner,
                'Max-Min Ratio': $'($stats.ratio)x',
                'fzip Ratio': (fmt_ratio $'($prefix)fzip' $sizes),
                'moonzip Ratio': (fmt_ratio $'($prefix)moonzip' $sizes),
            }
        } else {
            {
                Operation: $op,
                fzip: (fmt_time $fzip),
                moonzip: (fmt_time $moonzip),
                Winner: $stats.winner,
                'Max-Min Ratio': $'($stats.ratio)x',
                'fzip Ratio': '-',
                'moonzip Ratio': '-',
            }
        }
    }

    print ($rows | to md)
    print ""
}

# Generate checksum table
def gen_checksum [benches: list] {
    print "## Checksum\n"

    let rows = [crc32 adler32] | each {|algo|
        ['1k' '100k'] | each {|size|
            let prefix = $'($algo)/($size)/'
            let fzip = $benches | where name == $'($prefix)fzip' | get 0
            let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
            let zipc = $benches | where name == $'($prefix)zipc' | get 0
            let bkl = get_bench $benches $'($prefix)bkl'
            let libs = {fzip: $fzip, moonzip: $moonzip, zipc: $zipc}
            let libs = if $bkl != null { $libs | merge {bkl: $bkl} } else { $libs }
            let stats = calc_stats $libs

            {
                Algorithm: ($algo | str upcase),
                Size: ($size | str upcase),
                fzip: (fmt_time $fzip),
                moonzip: (fmt_time $moonzip),
                zipc: (fmt_time $zipc),
                bkl: (if $bkl != null { fmt_time $bkl } else { '-' }),
                Winner: $stats.winner,
                'Max-Min Ratio': $'($stats.ratio)x'
            }
        }
    } | flatten

    print ($rows | to md)
    print ""
}

# Generate auto-detect table
def gen_auto_detect [benches: list] {
    print "## Auto-detect Decompress\n"

    let rows = ['1k' '100k'] | each {|size|
        let prefix = $'decompress/auto_detect/($size)/'
        let fzip = $benches | where name == $'($prefix)fzip' | get 0
        let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
        let stats = calc_stats {fzip: $fzip, moonzip: $moonzip}

        {
            Size: ($size | str upcase),
            fzip: (fmt_time $fzip),
            moonzip: (fmt_time $moonzip),
            Winner: $stats.winner,
            'Max-Min Ratio': $'($stats.ratio)x'
        }
    }

    print ($rows | to md)
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
