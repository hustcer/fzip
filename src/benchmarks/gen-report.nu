#!/usr/bin/env nu

# Generate benchmark report from bench.json and sizes.json

# Header used for the mizchi/zlib column. Placed in column titles so the
# library is distinguishable from the "Zlib" format section.
const ZLIB_COL = '[zlib](https://github.com/mizchi/zlib.mbt)'

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
    print "\n> **Note**:\n> - `Max-Min Ratio` is calculated as the slowest mean time divided by the fastest mean time within the same row. `1.0x` means a tie; larger values mean a wider performance spread.\n> - `Compression Ratio` is calculated as compressed size divided by original size. Smaller is better.\n"

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

# Render rows as a markdown table. Nushell's `to md` HTML-encodes "/" as
# "&#x2f;" inside cell text, which breaks the URL in our column header link.
# Decode it back so the link survives in the rendered markdown.
def to_md_table [rows]: nothing -> string {
    $rows | to md | str replace --all '&#x2f;' '/'
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
            let mizchi = $benches | where name == $'($prefix)mizchi' | get 0
            let stats = calc_stats {fzip: $fzip, moonzip: $moonzip, mizchi: $mizchi}

            {
                Pattern: $pattern,
                Size: ($size | str upcase),
                fzip: (fmt_time $fzip),
                moonzip: (fmt_time $moonzip),
                $ZLIB_COL: (fmt_time $mizchi),
                Winner: $stats.winner,
                'Max-Min Ratio': $'($stats.ratio)x',
                'fzip Ratio': (fmt_ratio $'($prefix)fzip' $sizes),
                'moonzip Ratio': (fmt_ratio $'($prefix)moonzip' $sizes),
                $'($ZLIB_COL) Ratio': (fmt_ratio $'($prefix)mizchi' $sizes),
            }
        }
    } | flatten

    print (to_md_table $rows)
    print "\n> **⚠️ Note**:\n> - `fzip` switches to store mode (level 0) upon detecting uncompressible data (e.g., random 100K), skipping LZ77 search, resulting in extremely high speed but no compression effect.\n"
}

# Generate DEFLATE decompress table
def gen_deflate_decompress [benches: list] {
    print "## DEFLATE Decompress\n"

    let rows = ['1k' '100k'] | each {|size|
        let prefix = $'deflate/decompress/($size)/'
        let fzip = $benches | where name == $'($prefix)fzip' | get 0
        let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
        let mizchi = $benches | where name == $'($prefix)mizchi' | get 0
        let stats = calc_stats {fzip: $fzip, moonzip: $moonzip, mizchi: $mizchi}

        {
            Size: ($size | str upcase),
            fzip: (fmt_time $fzip),
            moonzip: (fmt_time $moonzip),
            $ZLIB_COL: (fmt_time $mizchi),
            Winner: $stats.winner,
            'Max-Min Ratio': $'($stats.ratio)x'
        }
    }

    print (to_md_table $rows)
    print "\n> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.\n"
}

# Generate GZIP table
def gen_gzip [benches: list, sizes: list] {
    print "## GZIP\n"

    let rows = [compress decompress] | each {|op|
        ['1k' '100k'] | each {|size|
            let prefix = $'gzip/($op)/($size)/'
            let fzip = $benches | where name == $'($prefix)fzip' | get 0
            let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
            let mizchi = $benches | where name == $'($prefix)mizchi' | get 0
            let stats = calc_stats {fzip: $fzip, moonzip: $moonzip, mizchi: $mizchi}

            if $op == 'compress' {
                {
                    Operation: $op,
                    Size: ($size | str upcase),
                    fzip: (fmt_time $fzip),
                    moonzip: (fmt_time $moonzip),
                    $ZLIB_COL: (fmt_time $mizchi),
                    Winner: $stats.winner,
                    'Max-Min Ratio': $'($stats.ratio)x',
                    'fzip Ratio': (fmt_ratio $'($prefix)fzip' $sizes),
                    'moonzip Ratio': (fmt_ratio $'($prefix)moonzip' $sizes),
                    $'($ZLIB_COL) Ratio': (fmt_ratio $'($prefix)mizchi' $sizes),
                }
            } else {
                {
                    Operation: $op,
                    Size: ($size | str upcase),
                    fzip: (fmt_time $fzip),
                    moonzip: (fmt_time $moonzip),
                    $ZLIB_COL: (fmt_time $mizchi),
                    Winner: $stats.winner,
                    'Max-Min Ratio': $'($stats.ratio)x',
                    'fzip Ratio': '-',
                    'moonzip Ratio': '-',
                    $'($ZLIB_COL) Ratio': '-',
                }
            }
        }
    } | flatten

    print (to_md_table $rows)
    print "\n> **Note**:\n> - Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.\n> - `mizchi/zlib` `gzip_compress` only emits stored blocks (no real compression), so its 1K/100K compression ratios are ≈100%.\n"
}

# Generate Zlib table
def gen_zlib [benches: list, sizes: list] {
    print "## Zlib\n"

    let rows = [compress decompress] | each {|op|
        ['1k' '100k'] | each {|size|
            let prefix = $'zlib/($op)/($size)/'
            let fzip = $benches | where name == $'($prefix)fzip' | get 0
            let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
            let mizchi = $benches | where name == $'($prefix)mizchi' | get 0
            let stats = calc_stats {fzip: $fzip, moonzip: $moonzip, mizchi: $mizchi}

            if $op == 'compress' {
                {
                    Operation: $op,
                    Size: ($size | str upcase),
                    fzip: (fmt_time $fzip),
                    moonzip: (fmt_time $moonzip),
                    $ZLIB_COL: (fmt_time $mizchi),
                    Winner: $stats.winner,
                    'Max-Min Ratio': $'($stats.ratio)x',
                    'fzip Ratio': (fmt_ratio $'($prefix)fzip' $sizes),
                    'moonzip Ratio': (fmt_ratio $'($prefix)moonzip' $sizes),
                    $'($ZLIB_COL) Ratio': (fmt_ratio $'($prefix)mizchi' $sizes),
                }
            } else {
                {
                    Operation: $op,
                    Size: ($size | str upcase),
                    fzip: (fmt_time $fzip),
                    moonzip: (fmt_time $moonzip),
                    $ZLIB_COL: (fmt_time $mizchi),
                    Winner: $stats.winner,
                    'Max-Min Ratio': $'($stats.ratio)x',
                    'fzip Ratio': '-',
                    'moonzip Ratio': '-',
                    $'($ZLIB_COL) Ratio': '-',
                }
            }
        }
    } | flatten

    print (to_md_table $rows)
    print "\n> **Note**: Decompress benchmarks use self-produced streams: each library decompresses data produced by its own compressor for that format.\n"
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

    print (to_md_table $rows)
    print "\n> **Note**: `mizchi/zlib` does not provide a ZIP API, so it is omitted from this table.\n"
}

# Generate checksum table
def gen_checksum [benches: list] {
    print "## Checksum\n"

    let rows = [crc32 adler32] | each {|algo|
        ['1k' '100k'] | each {|size|
            let prefix = $'($algo)/($size)/'
            let fzip = $benches | where name == $'($prefix)fzip' | get 0
            let moonzip = $benches | where name == $'($prefix)moonzip' | get 0
            let mizchi = $benches | where name == $'($prefix)mizchi' | get 0
            let stats = calc_stats {fzip: $fzip, moonzip: $moonzip, mizchi: $mizchi}

            {
                Algorithm: ($algo | str upcase),
                Size: ($size | str upcase),
                fzip: (fmt_time $fzip),
                moonzip: (fmt_time $moonzip),
                $ZLIB_COL: (fmt_time $mizchi),
                Winner: $stats.winner,
                'Max-Min Ratio': $'($stats.ratio)x'
            }
        }
    } | flatten

    print (to_md_table $rows)
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

    print (to_md_table $rows)
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
    let winner_label = if $winner == 'mizchi' { 'mizchi/zlib' } else { $winner }
    let ratio = $max / $min

    {winner: $winner_label, ratio: ($ratio | math round -p 1)}
}
