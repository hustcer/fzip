#!/usr/bin/env -S nu --stdin

# Parse `moon test` output for SIZE lines and produce sizes.json
# Usage:
#   moon test src/benchmarks/size_test.mbt --target wasm-gc -v | nu bench/parse-sizes.nu
#   moon test src/benchmarks/size_test.mbt --target wasm-gc -v | nu bench/parse-sizes.nu --save src/benchmarks/sizes.json

def main [
  --save (-s): string  # Save JSON to file path
]: string -> any {
  let raw = $in | ansi strip
  let results = $raw
    | lines
    | where { $in | str starts-with 'SIZE ' }
    | each {|line|
      let parts = $line | split row ' '
      {
        name: ($parts | get 1),
        compressed: ($parts | get 2 | into float),
        original: ($parts | get 3 | into float),
      }
    }

  if $save != null {
    $results | to json -i 2 | save -f $save
    print $'Saved ($results | length) size entries to ($save)'
  } else {
    $results | to json -i 2
  }
}
