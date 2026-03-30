set shell := ['nu', '-m', 'light', '-c']

# The export setting causes all just variables
# to be exported as environment variables.

set export := true

JUST_FILE_PATH := justfile()
NU_DIR := parent_directory(`$nu.current-exe`)
[private]
_inc_plugin := if os_family() == 'windows' { 'nu_plugin_inc.exe' } else { 'nu_plugin_inc' }

# Just commands aliases
# alias d := dev
# alias b := build

alias t := test

# Show all available commands by default
default:
    @just --list --list-prefix "··· "

# Update Moonbit dependencies
i: __setup
    moon update

# Format all Moonbit code
fmt: __setup
    moon info
    moon fmt

# Run comprehensive code check
lint:
    moon check --target all

# Build: Build the application in production mode
b: __setup
    moon build --target all

# Bench: Run performance benchmarks
bench:
    moon bench -p benchmarks

# Bench JSON: Run performance benchmarks and output JSON format results
bench-json output='':
    #!/usr/bin/env nu

    let out = '{{ output }}'
    let args = if ($out | is-not-empty) { [--save $out] } else { [] }
    ^moon bench -p benchmarks o+e>| nu --stdin bench/parse-bench.nu ...$args

# Bench RPT: Run performance benchmarks and generate a report
bench-rpt:
    #!/usr/bin/env nu
    let mizchi_path = (($env.MIZCHI_ZLIB_PATH? | default '/Users/hustcer/iWork/github/zlib.mbt') | path expand)
    if not ($mizchi_path | path exists) {
      print $'(ansi r)[ERROR](ansi reset) `mizchi/zlib` not found at: ($mizchi_path)'
      exit 1
    }

    open --raw bench/mizchi/moon.mod.template.json
      | str replace '__MIZCHI_ZLIB_PATH__' $mizchi_path
      | save -f bench/mizchi/moon.mod.json

    mkdir target/bench-rpt
    moon bench -p benchmarks o+e>| nu --stdin bench/parse-bench.nu -s target/bench-rpt/bench.base.json
    moon test src/benchmarks/size_test.mbt --target wasm-gc -v o+e>| nu --stdin bench/parse-sizes.nu -s target/bench-rpt/sizes.base.json
    moon -C bench/mizchi bench -p benchmarks --target wasm-gc o+e>| nu --stdin bench/parse-bench.nu -s target/bench-rpt/bench.mizchi.json
    moon -C bench/mizchi test src/benchmarks/size_test.mbt --target wasm-gc -v o+e>| nu --stdin bench/parse-sizes.nu -s target/bench-rpt/sizes.mizchi.json

    let base_bench = open target/bench-rpt/bench.base.json
    let mizchi_bench = open target/bench-rpt/bench.mizchi.json
    {
      metadata: $base_bench.metadata,
      benchmarks: ([$base_bench.benchmarks $mizchi_bench.benchmarks] | flatten),
    } | to json -i 2 | save -f src/benchmarks/bench.json

    let base_sizes = open target/bench-rpt/sizes.base.json
    let mizchi_sizes = open target/bench-rpt/sizes.mizchi.json
    ([$base_sizes $mizchi_sizes] | flatten) | to json -i 2 | save -f src/benchmarks/sizes.json

    nu src/benchmarks/gen-report.nu o> src/benchmarks/bench.md
    oxfmt src/benchmarks/bench.md src/benchmarks/bench.json src/benchmarks/sizes.json

# Run tests
test:
    moon test --target all

# Clean build directories
clean:
    #!/usr/bin/env nu

    moon clean
    print $'(ansi pb)Directories have been cleaned !(ansi reset)'

# Scan code for spelling errors, requires `typos-cli` installed locally. Usage: `just typos` or `just typos raw`
typos output=('table'):
    #!/usr/bin/env nu

    $env.config.table.mode = 'light'
    $env.config.color_config.leading_trailing_space_bg = { attr: n }
    let output = '{{ output }}'
    if not ((which typos | length) > 0) {
      print $'(ansi y)[WARN]: (ansi reset)`Typos` not installed, please install it by running `brew install typos-cli`...'
      exit 2
    }
    if $output != 'table' { typos .; exit 0 }
    typos . --format brief
      | lines
      | split column :
      | rename file line column correction
      | sort-by correction
      | update line {|l| $'(ansi pb)($l.line)(ansi reset)' }
      | update column {|l| $'(ansi pb)($l.column)(ansi reset)' }
      | upsert author {|l|
          let line = ($l.line | ansi strip)
          git blame $l.file -L $'($line),($line)' --porcelain | lines | get 1 | str replace 'author ' ''
        }
      | move author --before correction

# Check outdated dependencies: `just outdated` checks Node dependencies, `just outdated mbt` checks MoonBit dependencies
outdated:
    #!/usr/bin/env nu

    cd ($env.JUST_FILE_PATH | path dirname)
    moon update
    let diff = (git diff moon.mod.json)
    if ($diff | is-empty) {
      print $'(ansi g)All MoonBit dependencies are up to date!(ansi reset)'
    } else {
      print $'(ansi y)MoonBit dependency updates available:(ansi reset)'
      print $diff
    }

__setup:
    #!/usr/bin/env nu
    let version = moon version | lines | first
    print $'Current moon Version: (ansi g)($version)(ansi reset)'
    print $'(ansi p)------------------------------------->(ansi reset)(char nl)'

# Plugins only need to be registered once
_register_plugins:
    #!/usr/bin/env nu
    let incExists = not (scope commands | where name == 'inc' | is-empty)
    if not $incExists { plugin add {{ join(NU_DIR, _inc_plugin) }} }
