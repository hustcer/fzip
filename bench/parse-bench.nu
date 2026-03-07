#!/usr/bin/env -S nu --stdin

# Parse `moon bench` text output to structured JSON.
# Usage:
#   moon bench -p benchmarks | nu bench/parse-bench.nu
#   moon bench -p benchmarks | nu bench/parse-bench.nu --save bench/result.json

# Convert a time value to microseconds
def to-microseconds [value: float, unit: string]: nothing -> float {
  match $unit {
    'ns' => { $value / 1000.0 }
    'µs' => { $value }
    'ms' => { $value * 1000.0 }
    's' => { $value * 1_000_000.0 }
    _ => { $value }
  }
}

# Parse a bench data line like:
#   38.15 µs ±   0.91 µs    37.26 µs …  39.34 µs  in 10 ×   2651 runs
def parse-data-line [name: string, line: string]: nothing -> record {
  let parsed = $line
    | str trim
    | parse --regex '(?P<mean>[\d.]+)\s*(?P<unit>\S+)\s*±\s*(?P<std>[\d.]+)\s*\S+\s+(?P<min>[\d.]+)\s*\S+\s*…\s*(?P<max>[\d.]+)\s*\S+\s+in\s+(?P<iters>\d+)\s*×\s*(?P<runs>\d+)'
    | get -o 0

  if $parsed == null {
    return { name: $name, error: 'parse failed' }
  }

  let unit = $parsed.unit
  let mean = $parsed.mean | into float
  let std = $parsed.std | into float
  let min = $parsed.min | into float
  let max = $parsed.max | into float

  {
    name: $name
    mean_us: (to-microseconds $mean $unit | math round -p 3)
    std_us: (to-microseconds $std $unit | math round -p 3)
    min_us: (to-microseconds $min $unit | math round -p 3)
    max_us: (to-microseconds $max $unit | math round -p 3)
    unit: $unit
    iterations: ($parsed.iters | into int)
    runs: ($parsed.runs | into int)
  }
}

def main [
  --save (-s): string  # Save JSON to file path
]: string -> any {
  let raw = $in | ansi strip
  let lines = $raw | lines

  let moon_version = ^moon version | lines | first
  let os_info = uname

  let meta = {
    timestamp: (date now | format date '%Y-%m-%dT%H:%M:%S%z')
    moon_version: $moon_version
    target: 'wasm-gc'
    os: $'($os_info.operating-system) ($os_info.machine)'
    kernel: $os_info.kernel-version
  }

  # Parse test results: match name lines and data lines
  let results = $lines
    | enumerate
    | where { $in.item | str starts-with '[' }
    | each {|entry|
      let name_line = $entry.item
      # Extract test name from: [hustcer/fzip] bench ...:NN ("name") ok
      let name = $name_line
        | parse --regex '\("(?P<name>[^"]+)"\)'
        | get -o 0.name
        | default 'unknown'

      # Data line is 2 lines after the name line (skip the header line)
      let data_idx = $entry.index + 2
      let data_line = $lines | get -o $data_idx | default ''

      parse-data-line $name $data_line
    }

  let output = {
    metadata: $meta
    benchmarks: $results
  }

  if $save != null {
    $output | to json -i 2 | save -f $save
    print $'Saved ($results | length) benchmark results to ($save)'
  } else {
    $output | to json -i 2
  }
}
