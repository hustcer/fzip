#!/usr/bin/env nu

use std/assert

# Agent-oriented MoonBit benchmark capture and comparison tool.
#
# Exit codes for `compare`:
#   0: measurable improvement
#   2: measurable regression
#   3: insufficient samples, inconclusive, or noisy
#   4: incompatible benchmark/environment/source captures
#
# Typical workflow:
#   nu tools/bench-compare.nu capture 66 \
#     --name zip/decompress/fzip \
#     --output .planning/2026-07-10-120000-fzip-perf-zip/S01-r1-before.json
#
#   # Apply exactly one optimization, then capture again.
#   nu tools/bench-compare.nu capture 66 \
#     --name zip/decompress/fzip \
#     --output .planning/2026-07-10-120000-fzip-perf-zip/S01-r1-after.json
#
#   nu tools/bench-compare.nu compare \
#     .planning/2026-07-10-120000-fzip-perf-zip/S01-r1-before.json \
#     .planning/2026-07-10-120000-fzip-perf-zip/S01-r1-after.json \
#     --require-source-change

const schema_version = 2
const tool_version = '1.2.0'
const supported_capture_tool_versions = ['1.1.0' '1.2.0']
const capture_kind = 'moon-bench-capture'
const comparison_kind = 'moon-bench-comparison'
const supported_targets = [wasm wasm-gc js native llvm]

# Parse benchmark declarations in MoonBit source order.
#
# `moon bench -i` uses a zero-based index for these benchmark-shaped tests.
def parse-benchmark-catalog [text: string]: nothing -> table {
  let declarations = (
    $text
    | lines
    | enumerate
    | each --flatten {|entry|
        let rows = (
          $entry.item
          | parse --regex (
              r#'^\s*test\s+"(?P<name>[^"]+)"\s*\(\s*[A-Za-z_]'#
              + r#'[A-Za-z0-9_]*\s*:\s*@bench\.T\s*\)\s*\{'#
            )
        )
        $rows
        | each {|row|
            {
              name: $row.name
              line: ($entry.index + 1)
            }
          }
      }
  )

  $declarations
  | enumerate
  | each {|entry|
      {
        index: $entry.index
        name: $entry.item.name
        line: $entry.item.line
      }
    }
}

# Resolve a required path and prove that it stays inside the Git repository.
def repo-relative-path [input: path, repo_root: path, description: string]: nothing -> string {
  let expanded = $input | path expand --strict
  try {
    $expanded | path relative-to $repo_root
  } catch {
    error make {msg: $'($description) escapes the Git repository: ($expanded)'}
  }
}

# Resolve an existing file and prove that it stays under an expected directory.
def existing-path-under [
  input: path
  base: path
  description: string
]: nothing -> path {
  let expanded_base = $base | path expand --strict
  let expanded = $input | path expand --strict
  try {
    $expanded | path relative-to $expanded_base | ignore
  } catch {
    error make {msg: $'($description) escapes ($expanded_base): ($expanded)'}
  }
  $expanded
}

# Resolve a user-provided worktree root and require the repository top level.
def repository-root [input: path, description: string]: nothing -> path {
  let expanded = $input | path expand --strict
  let result = (^git -C $expanded rev-parse --show-toplevel | complete)
  if $result.exit_code != 0 {
    error make {msg: $'($description) is not inside a Git repository: ($expanded)'}
  }
  let root = $result.stdout | str trim | path expand --strict
  if $expanded != $root {
    error make {
      msg: $'($description) must be the Git repository root: ($expanded)'
      help: $'Use ($root) instead.'
    }
  }
  $root
}

# Fingerprint the current build/source state, including local tracked changes and
# relevant untracked files. The content hash stays stable across a commit when
# the checked-out source bytes are unchanged.
def capture-source-state-at [
  repo_root: path
  source_root: path
  module_file: path
]: nothing -> record {
  let root = repository-root $repo_root 'repository root'
  let source_path = $root | path join $source_root
  let module_path = $root | path join $module_file
  let source_rel = repo-relative-path $source_path $root 'source root'
  let module_rel = repo-relative-path $module_path $root 'module file'
  let pathspecs = [$source_rel $module_rel]

  let untracked_result = (
    ^git -C $root ls-files --others --exclude-standard -- ...$pathspecs | complete
  )
  if $untracked_result.exit_code != 0 {
    error make {msg: $'Could not list untracked source files: ($untracked_result.stderr)'}
  }
  let ignored_result = (
    ^git -C $root ls-files --others --ignored --exclude-standard -- ...$pathspecs
    | complete
  )
  if $ignored_result.exit_code != 0 {
    error make {msg: $'Could not list ignored source files: ($ignored_result.stderr)'}
  }

  let ordinary_untracked_paths = (
    $untracked_result.stdout | lines | where {|line| $line | str trim | is-not-empty }
  )
  let ignored_paths = (
    $ignored_result.stdout | lines | where {|line| $line | str trim | is-not-empty }
  )
  let untracked_paths = $ordinary_untracked_paths | append $ignored_paths | uniq | sort
  let source_pattern = $root | path join $source_rel '**/*'
  let filesystem_paths = (
    glob $source_pattern --no-dir
    | each {|full| $full | path relative-to $root }
    | append $module_rel
    | uniq
    | sort
  )
  let files = (
    $filesystem_paths
    | each {|relative|
        let full = $root | path join $relative
        {
          path: $relative
          sha256: (open --raw $full | hash sha256)
        }
      }
  )
  let tracked_diff_result = (
    ^git -C $root diff --binary HEAD -- ...$pathspecs | complete
  )
  if $tracked_diff_result.exit_code != 0 {
    error make {msg: $'Could not fingerprint tracked source changes: ($tracked_diff_result.stderr)'}
  }
  let head_result = (^git -C $root rev-parse HEAD | complete)
  if $head_result.exit_code != 0 {
    error make {msg: 'Could not resolve Git HEAD for source fingerprinting'}
  }
  let content_sha256 = $files | to json | hash sha256
  let tracked_diff_sha256 = $tracked_diff_result.stdout | hash sha256
  let untracked_files = (
    $files
    | where {|row| $row.path in $untracked_paths }
    | each {|row| $row | insert ignored ($row.path in $ignored_paths) }
  )
  let state_payload = {
    head: ($head_result.stdout | str trim)
    content_sha256: $content_sha256
    tracked_diff_sha256: $tracked_diff_sha256
    untracked_files: $untracked_files
  }

  {
    repository_root: $root
    source_root: $source_rel
    module_file: $module_rel
    git_head: $state_payload.head
    file_count: ($files | length)
    content_sha256: $content_sha256
    tracked_diff_sha256: $tracked_diff_sha256
    untracked_files: $untracked_files
    state_sha256: ($state_payload | to json | hash sha256)
  }
}

# Fingerprint the source state in the current repository.
def capture-source-state [source_root: path, module_file: path]: nothing -> record {
  let root_result = (^git rev-parse --show-toplevel | complete)
  if $root_result.exit_code != 0 {
    error make {msg: 'bench-compare must run inside a Git repository'}
  }
  capture-source-state-at ($root_result.stdout | str trim) $source_root $module_file
}

# Convert a MoonBit benchmark duration to microseconds.
def to-microseconds [value: float, unit: string]: nothing -> float {
  match $unit {
    ps => { $value / 1_000_000.0 }
    ns => { $value / 1_000.0 }
    µs | μs | us => { $value }
    ms => { $value * 1_000.0 }
    s => { $value * 1_000_000.0 }
    _ => {
      error make {msg: $'Unsupported benchmark duration unit: ($unit)'}
    }
  }
}

# Round a number for stable JSON output while retaining useful precision.
def round-number [value: number, precision: int]: nothing -> float {
  $value | into float | math round --precision $precision
}

# Parse exactly one `moon bench` result and verify its benchmark name.
def parse-benchmark-output [
  text: string
  expected_name: string
]: nothing -> record {
  let name_rows = (
    $text
    | lines
    | each --flatten {|line|
        $line | parse --regex r#'\("(?P<name>[^"]+)"\)'#
      }
  )

  if ($name_rows | is-empty) {
    error make {
      msg: 'Could not find a benchmark name in moon bench output'
      help: $text
    }
  }

  if ($name_rows | length) != 1 {
    error make {
      msg: $'Expected one benchmark result, found ($name_rows | length)'
      help: 'Use one package/file/index combination that selects exactly one benchmark.'
    }
  }

  let actual_name = $name_rows.0.name
  if $actual_name != $expected_name {
    error make {
      msg: $'Benchmark index resolved to "($actual_name)", expected "($expected_name)"'
      help: 'The benchmark index may have moved. Re-read bench_test.mbt and update --index.'
    }
  }

  let data_rows = (
    $text
    | lines
    | each --flatten {|line|
        $line | parse --regex (
          r#'(?P<mean>[\d.]+)\s*(?P<mean_unit>ps|ns|µs|μs|us|ms|s)\s*±\s*'#
          + r#'(?P<stddev>[\d.]+)\s*(?P<stddev_unit>ps|ns|µs|μs|us|ms|s)\s+'#
          + r#'(?P<min>[\d.]+)\s*(?P<min_unit>ps|ns|µs|μs|us|ms|s)\s*…\s*'#
          + r#'(?P<max>[\d.]+)\s*(?P<max_unit>ps|ns|µs|μs|us|ms|s)\s+'#
          + r#'in\s+(?P<iterations>\d+)\s*×\s*(?P<runs>\d+)\s+runs'#
        )
      }
  )

  if ($data_rows | is-empty) {
    error make {
      msg: 'Could not parse benchmark timing data'
      help: $text
    }
  }

  if ($data_rows | length) != 1 {
    error make {
      msg: $'Expected one benchmark timing row, found ($data_rows | length)'
    }
  }

  let row = $data_rows.0
  {
    name: $actual_name
    mean_us: (to-microseconds ($row.mean | into float) $row.mean_unit)
    stddev_us: (to-microseconds ($row.stddev | into float) $row.stddev_unit)
    min_us: (to-microseconds ($row.min | into float) $row.min_unit)
    max_us: (to-microseconds ($row.max | into float) $row.max_unit)
    iterations: ($row.iterations | into int)
    runs: ($row.runs | into int)
  }
}

# Summarize repeated benchmark-process means using robust median/MAD statistics.
def summarize-samples [samples: table]: nothing -> record {
  let means = $samples | get mean_us
  let median_us = $means | math median
  let mean_us = $means | math avg
  let min_us = $means | math min
  let max_us = $means | math max
  let stddev_us = if ($means | uniq | length) > 1 {
    $means | math stddev
  } else {
    0.0
  }
  let mad_us = (
    $means
    | each {|value| ($value - $median_us) | math abs }
    | math median
  )
  let relative_mad_pct = if $median_us == 0 {
    0.0
  } else {
    $mad_us / $median_us * 100.0
  }
  let spread_pct = if $median_us == 0 {
    0.0
  } else {
    ($max_us - $min_us) / $median_us * 100.0
  }
  let internal_cv_values = (
    $samples
    | each {|sample|
        if $sample.mean_us == 0 {
          0.0
        } else {
          ($sample.stddev_us? | default 0.0) / $sample.mean_us * 100.0
        }
      }
  )

  {
    rounds: ($means | length)
    median_us: (round-number $median_us 6)
    mean_us: (round-number $mean_us 6)
    stddev_us: (round-number $stddev_us 6)
    mad_us: (round-number $mad_us 6)
    relative_mad_pct: (round-number $relative_mad_pct 4)
    min_us: (round-number $min_us 6)
    max_us: (round-number $max_us 6)
    spread_pct: (round-number $spread_pct 4)
    median_internal_cv_pct: (round-number ($internal_cv_values | math median) 4)
    max_internal_cv_pct: (round-number ($internal_cv_values | math max) 4)
  }
}

# Run a fixed MoonBit benchmark command safely with separated arguments.
def run-benchmark-at [
  root: path
  index: int
  expected_name: string
  package: string
  file: string
  target: string
]: nothing -> record {
  let expanded_root = $root | path expand --strict
  let args = [
    bench
    -p
    $package
    -f
    $file
    -i
    ($index | into string)
    --target
    $target
    --release
    --frozen
  ]
  let result = (^moon -C $expanded_root ...$args | complete)
  let output = (
    [$result.stdout $result.stderr]
    | where {|part| ($part | str trim | is-not-empty) }
    | str join (char nl)
  )

  if $result.exit_code != 0 {
    error make {
      msg: $'moon bench failed with exit code ($result.exit_code)'
      help: $output
    }
  }

  parse-benchmark-output $output $expected_name
}

# Run a benchmark in the current repository.
def run-benchmark [
  index: int
  expected_name: string
  package: string
  file: string
  target: string
]: nothing -> record {
  run-benchmark-at (pwd) $index $expected_name $package $file $target
}

# Return trimmed git output, or null when the current directory is not a repo.
def git-output [...args: string]: nothing -> oneof<string, nothing> {
  let result = (^git ...$args | complete)
  if $result.exit_code == 0 {
    $result.stdout | str trim
  } else {
    null
  }
}

# Return trimmed Git output for a repository root, or null on failure.
def git-output-at [root: path, ...args: string]: nothing -> oneof<string, nothing> {
  let result = (^git -C $root ...$args | complete)
  if $result.exit_code == 0 {
    $result.stdout | str trim
  } else {
    null
  }
}

# Collect enough environment data to reject invalid before/after comparisons.
def capture-environment-at [root: path]: nothing -> record {
  let expanded_root = $root | path expand --strict
  let moon_result = (^moon -C $expanded_root version | complete)
  if $moon_result.exit_code != 0 {
    error make {msg: 'Could not read moon version'}
  }

  let machine_result = (^uname -m | complete)
  let git_status = (git-output-at $expanded_root status -- --porcelain)
  {
    timestamp: (date now | format date '%Y-%m-%dT%H:%M:%S%z')
    cwd: $expanded_root
    moon_version: ($moon_result.stdout | lines | first | str trim)
    nu_version: (version | get version)
    host: (sys host | select name os_version long_os_version kernel_version)
    machine: (if $machine_result.exit_code == 0 {
      $machine_result.stdout | str trim
    } else {
      null
    })
    git: {
      commit: (git-output-at $expanded_root rev-parse HEAD)
      branch: (git-output-at $expanded_root branch -- --show-current)
      dirty: (if $git_status == null { null } else { $git_status | is-not-empty })
    }
  }
}

# Capture environment data for the current repository.
def capture-environment []: nothing -> record {
  capture-environment-at (pwd)
}

# Fingerprint the benchmark harness so code changes cannot silently alter the test.
def capture-harness-at [
  repo_root: path
  source_root: path
  module_file: path
  package: string
  file: string
]: nothing -> table {
  let root = repository-root $repo_root 'repository root'
  let source_path = $root | path join $source_root
  let module_path = $root | path join $module_file
  let expanded_source = $source_path | path expand --strict
  let package_dir = existing-path-under (
    $source_path | path join $package
  ) $expanded_source 'benchmark package'
  let package_file = $source_path | path join $package moon.pkg
  let benchmark_file = $source_path | path join $package $file
  let files = [
    {
      path: (repo-relative-path $module_path $root 'module file')
      expanded: ($module_path | path expand --strict)
    }
    {
      path: (repo-relative-path $package_file $root 'benchmark package file')
      expanded: (existing-path-under $package_file $expanded_source 'benchmark package file')
    }
    {
      path: (repo-relative-path $benchmark_file $root 'benchmark source file')
      expanded: (existing-path-under $benchmark_file $package_dir 'benchmark source file')
    }
  ]

  $files
  | each {|input|
      {
        path: $input.path
        sha256: (open --raw $input.expanded | hash sha256)
      }
    }
}

# Reject an accidental overwrite before running an expensive benchmark.
def ensure-output-available [output: path, force: bool]: nothing -> nothing {
  let expanded = $output | path expand
  if ($expanded | path exists) and not $force {
    error make {
      msg: $'Refusing to overwrite existing file: ($expanded)'
      help: 'Choose a new output path or pass --force explicitly.'
    }
  }
}

# Fingerprint the benchmark harness in the current repository.
def capture-harness [
  source_root: path
  module_file: path
  package: string
  file: string
]: nothing -> table {
  capture-harness-at (pwd) $source_root $module_file $package $file
}

# Save JSON without overwriting an existing artifact unless --force was explicit.
def save-json [value: record, output: path, force: bool]: nothing -> nothing {
  let expanded = $output | path expand
  ensure-output-available $expanded $force

  let parent = $expanded | path dirname
  if not ($parent | path exists) {
    mkdir $parent
  }

  let json = $value | to json --indent 2
  if $force {
    $json | save --force $expanded
  } else {
    $json | save $expanded
  }
}

# Ensure a capture file has the fields required by the comparison contract.
def load-capture [input: path]: nothing -> record {
  let expanded = $input | path expand
  if not ($expanded | path exists) {
    error make {msg: $'Capture file does not exist: ($expanded)'}
  }

  let capture = open $expanded
  if ($capture | describe) !~ '^record' {
    error make {msg: $'Capture file is not a JSON object: ($expanded)'}
  }
  if $capture.kind? != $capture_kind {
    error make {msg: $'Unsupported capture kind in ($expanded)'}
  }
  if $capture.schema_version? != $schema_version {
    error make {msg: $'Unsupported capture schema in ($expanded)'}
  }
  if $capture.tool_version? not-in $supported_capture_tool_versions {
    error make {msg: $'Unsupported capture tool version in ($expanded)'}
  }

  let required_values = [
    $capture.benchmark?.name?
    $capture.benchmark?.package?
    $capture.benchmark?.file?
    $capture.benchmark?.index?
    $capture.benchmark?.target?
    $capture.benchmark?.release?
    $capture.harness?
    $capture.environment?.moon_version?
    $capture.environment?.nu_version?
    $capture.environment?.host?.name?
    $capture.environment?.host?.os_version?
    $capture.environment?.machine?
    $capture.source_state?.git_head?
    $capture.source_state?.content_sha256?
    $capture.source_state?.tracked_diff_sha256?
    $capture.source_state?.state_sha256?
    $capture.summary?.median_us?
    $capture.summary?.rounds?
    $capture.summary?.relative_mad_pct?
    $capture.summary?.spread_pct?
    $capture.summary?.median_internal_cv_pct?
    $capture.summary?.max_internal_cv_pct?
  ]
  if ($required_values | any {|value| $value == null }) {
    error make {msg: $'Capture file is missing required fields: ($expanded)'}
  }
  if $capture.summary.median_us <= 0 {
    error make {msg: $'Capture median must be positive: ($expanded)'}
  }

  $capture
}

# Build a deterministic verdict without performing file I/O or exiting.
def build-comparison [
  before: record
  after: record
  before_source: string
  after_source: string
  thresholds: record
  allow_environment_mismatch: bool
  require_source_change: bool
]: nothing -> record {
  let benchmark_checks = [
    {field: benchmark.name before: $before.benchmark.name after: $after.benchmark.name}
    {field: benchmark.package before: $before.benchmark.package after: $after.benchmark.package}
    {field: benchmark.file before: $before.benchmark.file after: $after.benchmark.file}
    {field: benchmark.index before: $before.benchmark.index after: $after.benchmark.index}
    {field: benchmark.target before: $before.benchmark.target after: $after.benchmark.target}
    {field: benchmark.release before: $before.benchmark.release after: $after.benchmark.release}
    {field: harness before: $before.harness after: $after.harness}
  ]
  let environment_checks = [
    {
      field: environment.moon_version
      before: $before.environment.moon_version
      after: $after.environment.moon_version
    }
    {
      field: environment.nu_version
      before: $before.environment.nu_version
      after: $after.environment.nu_version
    }
    {
      field: environment.host.name
      before: $before.environment.host.name
      after: $after.environment.host.name
    }
    {
      field: environment.host.os_version
      before: $before.environment.host.os_version
      after: $after.environment.host.os_version
    }
    {
      field: environment.machine
      before: $before.environment.machine
      after: $after.environment.machine
    }
  ]
  let benchmark_mismatches = $benchmark_checks | where {|row| $row.before != $row.after }
  let environment_mismatches = $environment_checks | where {|row| $row.before != $row.after }

  let before_us = $before.summary.median_us | into float
  let after_us = $after.summary.median_us | into float
  let improvement_pct = ($before_us - $after_us) / $before_us * 100.0
  let speedup = $before_us / $after_us
  let noise_guard_pct = (
    [
      ($before.summary.relative_mad_pct | into float)
      ($after.summary.relative_mad_pct | into float)
    ]
    | math max
  ) * 2.0
  let required_improvement_pct = (
    [$thresholds.min_improvement_pct $noise_guard_pct] | math max
  )
  let required_regression_pct = (
    [$thresholds.max_regression_pct $noise_guard_pct] | math max
  )
  let observed_spread_pct = (
    [
      ($before.summary.spread_pct | into float)
      ($after.summary.spread_pct | into float)
    ]
    | math max
  )
  let observed_internal_cv_pct = (
    [
      ($before.summary.max_internal_cv_pct | into float)
      ($after.summary.max_internal_cv_pct | into float)
    ]
    | math max
  )
  let source_changed = (
    $before.source_state.content_sha256 != $after.source_state.content_sha256
  )
  let repository_state_changed = (
    $before.source_state.state_sha256 != $after.source_state.state_sha256
  )
  let incompatible = (
    ($benchmark_mismatches | is-not-empty)
    or (
      ($environment_mismatches | is-not-empty)
      and not $allow_environment_mismatch
    )
    or ($require_source_change and not $source_changed)
  )
  let noisy = (
    ($observed_spread_pct > $thresholds.max_spread_pct)
    or ($observed_internal_cv_pct > $thresholds.max_internal_cv_pct)
  )
  let insufficient_samples = (
    $before.summary.rounds < $thresholds.min_rounds
    or $after.summary.rounds < $thresholds.min_rounds
  )
  let verdict = if $incompatible {
    'incompatible'
  } else if $insufficient_samples {
    'insufficient_samples'
  } else if $noisy {
    'noisy'
  } else if $improvement_pct >= $required_improvement_pct {
    'improved'
  } else if $improvement_pct <= (0.0 - $required_regression_pct) {
    'regressed'
  } else {
    'inconclusive'
  }
  let exit_code = match $verdict {
    improved => 0
    regressed => 2
    noisy | inconclusive | insufficient_samples => 3
    incompatible => 4
  }

  {
    schema_version: $schema_version
    tool_version: $tool_version
    kind: $comparison_kind
    verdict: $verdict
    exit_code: $exit_code
    benchmark: $before.benchmark
    before: {
      source: $before_source
      label: ($before.label? | default '')
      git_commit: ($before.environment.git?.commit? | default null)
      source_content_sha256: $before.source_state.content_sha256
      source_state_sha256: $before.source_state.state_sha256
      median_us: (round-number $before_us 6)
      relative_mad_pct: $before.summary.relative_mad_pct
      spread_pct: $before.summary.spread_pct
    }
    after: {
      source: $after_source
      label: ($after.label? | default '')
      git_commit: ($after.environment.git?.commit? | default null)
      source_content_sha256: $after.source_state.content_sha256
      source_state_sha256: $after.source_state.state_sha256
      median_us: (round-number $after_us 6)
      relative_mad_pct: $after.summary.relative_mad_pct
      spread_pct: $after.summary.spread_pct
    }
    delta: {
      absolute_us: (round-number ($before_us - $after_us) 6)
      improvement_pct: (round-number $improvement_pct 4)
      speedup: (round-number $speedup 6)
    }
    thresholds: {
      configured_min_improvement_pct: $thresholds.min_improvement_pct
      configured_max_regression_pct: $thresholds.max_regression_pct
      min_rounds: $thresholds.min_rounds
      max_spread_pct: $thresholds.max_spread_pct
      max_internal_cv_pct: $thresholds.max_internal_cv_pct
      noise_guard_pct: (round-number $noise_guard_pct 4)
      required_improvement_pct: (round-number $required_improvement_pct 4)
      required_regression_pct: (round-number $required_regression_pct 4)
      observed_spread_pct: (round-number $observed_spread_pct 4)
      observed_internal_cv_pct: (round-number $observed_internal_cv_pct 4)
    }
    compatibility: {
      allow_environment_mismatch: $allow_environment_mismatch
      require_source_change: $require_source_change
      source_changed: $source_changed
      repository_state_changed: $repository_state_changed
      benchmark_mismatches: $benchmark_mismatches
      environment_mismatches: $environment_mismatches
    }
  }
}

# Render a comparison for an Agent (JSON default) or a human terminal.
def render-comparison [report: record, format: string]: nothing -> string {
  match $format {
    json => { $report | to json --indent 2 }
    text => {
      [
        $'verdict: ($report.verdict)'
        $'benchmark: ($report.benchmark.name)'
        $'before: ($report.before.median_us) us'
        $'after: ($report.after.median_us) us'
        $'improvement: ($report.delta.improvement_pct)%'
        $'speedup: ($report.delta.speedup)x'
        $'source_changed: ($report.compatibility.source_changed)'
        $'exit_code: ($report.exit_code)'
      ]
      | str join (char nl)
    }
    _ => {
      error make {msg: $'Unsupported output format: ($format). Use json or text.'}
    }
  }
}

# Build a deterministic pair-by-pair schedule. Alternating which side runs
# first balances persistent first/second-position effects across recorded rounds.
def interleaved-schedule [rounds: int]: nothing -> table {
  if $rounds < 0 {
    error make {msg: 'schedule rounds must be non-negative'}
  }
  0..<$rounds
  | each --flatten {|round|
      let sides = if ($round mod 2) == 0 {
        [before after]
      } else {
        [after before]
      }
      let pair_order = $sides | str join '-'
      $sides
      | enumerate
      | each {|entry|
          {
            round: ($round + 1)
            side: $entry.item
            sequence: ($round * 2 + $entry.index + 1)
            pair_order: $pair_order
            pair_position: ($entry.index + 1)
          }
        }
    }
}

# Validate shared benchmark arguments before starting expensive work.
def validate-capture-request [
  index: int
  name: string
  target: string
  rounds: int
  warmup: int
]: nothing -> nothing {
  if ($name | is-empty) {
    error make {msg: '--name is required to guard against benchmark index drift'}
  }
  if $rounds < 1 {
    error make {msg: '--rounds must be at least 1'}
  }
  if $warmup < 0 {
    error make {msg: '--warmup must be non-negative'}
  }
  if $index < 0 {
    error make {msg: 'benchmark index must be non-negative'}
  }
  if $target not-in $supported_targets {
    error make {
      msg: $'Unsupported target: ($target)'
      help: $'Supported targets: ($supported_targets | str join ", ")'
    }
  }
}

# Add execution-order metadata to one benchmark sample.
def run-scheduled-benchmark [
  step: record
  before_root: path
  after_root: path
  index: int
  name: string
  package: string
  file: string
  target: string
]: nothing -> record {
  let root = match $step.side {
    before => $before_root
    after => $after_root
    _ => { error make {msg: $'Unsupported interleave side: ($step.side)'} }
  }
  run-benchmark-at $root $index $name $package $file $target
  | merge $step
}

# Construct a normal capture artifact from pre-validated metadata and samples.
def build-capture-artifact [
  label: string
  benchmark: record
  harness: table
  source_state: record
  environment: record
  sampling: record
  samples: table
]: nothing -> record {
  {
    schema_version: $schema_version
    tool_version: $tool_version
    kind: $capture_kind
    label: $label
    benchmark: $benchmark
    harness: $harness
    source_state: $source_state
    environment: $environment
    sampling: $sampling
    summary: (summarize-samples $samples)
    samples: $samples
  }
}

# Create a synthetic capture for the built-in self-test.
def fixture-capture [
  means: list<float>
  target: string = 'wasm-gc'
  internal_cv_pct: float = 0.0
  source_id: string = 'fixture-source'
]: nothing -> record {
  let samples = (
    $means
    | enumerate
    | each {|entry|
        {
          round: ($entry.index + 1)
          mean_us: $entry.item
          stddev_us: ($entry.item * $internal_cv_pct / 100.0)
        }
      }
  )
  {
    schema_version: $schema_version
    tool_version: $tool_version
    kind: $capture_kind
    label: fixture
    benchmark: {
      name: zip/decompress/fzip
      package: benchmarks
      file: bench_test.mbt
      index: 66
      target: $target
      release: true
    }
    harness: [
      {path: moon.mod.json sha256: fixture-module}
      {path: src/benchmarks/moon.pkg sha256: fixture-package}
      {path: src/benchmarks/bench_test.mbt sha256: fixture-benchmark}
    ]
    environment: {
      moon_version: 'moon fixture'
      nu_version: '0.114.0'
      host: {name: Darwin os_version: fixture}
      machine: arm64
      git: {commit: fixture}
    }
    source_state: {
      git_head: fixture
      content_sha256: $source_id
      tracked_diff_sha256: $source_id
      state_sha256: $source_id
    }
    summary: (summarize-samples $samples)
    samples: $samples
  }
}

# List benchmark names and their current zero-based `moon bench -i` indexes.
def "main list" [
  --filter: string = ''              # Optional case-sensitive name substring
  --format (-f): string = 'json'     # json (Agent) or text (human)
  --package (-p): string = 'benchmarks'
  --file: string = 'bench_test.mbt'
  --source-root: path = 'src'
]: nothing -> string {
  let input = existing-path-under (
    $source_root | path join $package | path join $file
  ) $source_root 'benchmark source file'
  let catalog = parse-benchmark-catalog (open --raw $input)
  let filtered = if ($filter | is-empty) {
    $catalog
  } else {
    $catalog | where {|row| $row.name | str contains $filter }
  }

  match $format {
    json => { $filtered | to json --indent 2 }
    text => {
      let tab = char tab
      $filtered
      | each {|row| $'($row.index)($tab)($row.name)($tab)line ($row.line)' }
      | prepend $'index($tab)name($tab)source'
      | str join (char nl)
    }
    _ => {
      error make {msg: $'Unsupported output format: ($format). Use json or text.'}
    }
  }
}

# Capture one benchmark repeatedly and save a self-describing JSON artifact.
def "main capture" [
  index: int                      # Current index in bench_test.mbt
  --name (-n): string = ''        # Expected benchmark name; guards index drift
  --output (-o): path = 'bench-capture.json'
  --package (-p): string = 'benchmarks'
  --file (-f): string = 'bench_test.mbt'
  --source-root: path = 'src'      # Source directory used for harness hashing
  --module-file: path = 'moon.mod.json' # Module metadata hashed with harness
  --target (-t): string = 'wasm-gc'
  --rounds (-r): int = 5          # Recorded benchmark-process runs
  --warmup (-w): int = 1          # Discarded benchmark-process runs
  --label (-l): string = ''
  --force                         # Explicitly allow overwriting --output
]: nothing -> string {
  validate-capture-request $index $name $target $rounds $warmup
  ensure-output-available $output $force
  let source_before = capture-source-state $source_root $module_file
  let harness_before = capture-harness $source_root $module_file $package $file

  0..<$warmup
  | each {|_| run-benchmark $index $name $package $file $target }
  | ignore

  let samples = (
    0..<$rounds
    | each {|round|
        run-benchmark $index $name $package $file $target
        | insert round ($round + 1)
      }
  )
  let harness_after = capture-harness $source_root $module_file $package $file
  let source_after = capture-source-state $source_root $module_file
  if $harness_before != $harness_after {
    error make {msg: 'Benchmark harness changed while capture was running'}
  }
  if $source_before.state_sha256 != $source_after.state_sha256 {
    error make {
      msg: 'Source state changed while capture was running'
      help: 'Discard this run, stop concurrent edits, and capture again into a new file.'
    }
  }
  let capture = {
    schema_version: $schema_version
    tool_version: $tool_version
    kind: $capture_kind
    label: $label
    benchmark: {
      name: $name
      package: $package
      file: $file
      index: $index
      target: $target
      release: true
    }
    harness: $harness_before
    source_state: $source_before
    environment: (capture-environment)
    sampling: {warmup: $warmup rounds: $rounds}
    summary: (summarize-samples $samples)
    samples: $samples
  }
  save-json $capture $output $force

  {
    status: captured
    output: ($output | path expand)
    benchmark: $capture.benchmark
    summary: $capture.summary
  }
  | to json --indent 2
}

# Capture the same benchmark from two worktrees in alternating A/B pairs.
# The resulting files remain ordinary capture artifacts accepted by `compare`.
def "main interleave" [
  index: int                         # Current index in both benchmark harnesses
  before_root: path                  # Repository root for the before revision
  after_root: path                   # Repository root for the after revision
  --name (-n): string = ''           # Expected benchmark name; guards index drift
  --before-output: path = 'bench-before.json'
  --after-output: path = 'bench-after.json'
  --package (-p): string = 'benchmarks'
  --file (-f): string = 'bench_test.mbt'
  --source-root: path = 'src'        # Source directory used for fingerprinting
  --module-file: path = 'moon.mod.json'
  --target (-t): string = 'wasm-gc'
  --rounds (-r): int = 5             # Recorded A/B pairs
  --warmup (-w): int = 1             # Discarded A/B pairs
  --before-label: string = 'before'
  --after-label: string = 'after'
  --force                            # Explicitly allow overwriting both outputs
]: nothing -> string {
  validate-capture-request $index $name $target $rounds $warmup

  let before_repo = repository-root $before_root 'before root'
  let after_repo = repository-root $after_root 'after root'
  if $before_repo == $after_repo {
    error make {
      msg: 'before and after roots must be different Git worktrees'
      help: 'Create one detached worktree for each revision being compared.'
    }
  }

  let before_path = $before_output | path expand
  let after_path = $after_output | path expand
  if $before_path == $after_path {
    error make {msg: 'before and after output paths must be different'}
  }
  ensure-output-available $before_path $force
  ensure-output-available $after_path $force

  let before_source_before = (
    capture-source-state-at $before_repo $source_root $module_file
  )
  let after_source_before = (
    capture-source-state-at $after_repo $source_root $module_file
  )
  let before_harness_before = (
    capture-harness-at $before_repo $source_root $module_file $package $file
  )
  let after_harness_before = (
    capture-harness-at $after_repo $source_root $module_file $package $file
  )
  if $before_harness_before != $after_harness_before {
    error make {
      msg: 'before and after benchmark harnesses do not match'
      help: 'Use revisions with identical module, package, and benchmark source files.'
    }
  }

  interleaved-schedule $warmup
  | each {|step|
      (run-scheduled-benchmark
          $step $before_repo $after_repo $index $name $package $file $target)
    }
  | ignore

  let all_samples = (
    interleaved-schedule $rounds
    | each {|step|
        (run-scheduled-benchmark
            $step $before_repo $after_repo $index $name $package $file $target)
      }
  )
  let before_samples = $all_samples | where side == before
  let after_samples = $all_samples | where side == after

  let before_harness_after = (
    capture-harness-at $before_repo $source_root $module_file $package $file
  )
  let after_harness_after = (
    capture-harness-at $after_repo $source_root $module_file $package $file
  )
  let before_source_after = (
    capture-source-state-at $before_repo $source_root $module_file
  )
  let after_source_after = (
    capture-source-state-at $after_repo $source_root $module_file
  )
  if (
    $before_harness_before != $before_harness_after
    or $after_harness_before != $after_harness_after
  ) {
    error make {msg: 'Benchmark harness changed while interleaved capture was running'}
  }
  if (
    $before_source_before.state_sha256 != $before_source_after.state_sha256
    or $after_source_before.state_sha256 != $after_source_after.state_sha256
  ) {
    error make {
      msg: 'Source state changed while interleaved capture was running'
      help: 'Discard this run, stop concurrent edits, and capture again into new files.'
    }
  }

  let benchmark = {
    name: $name
    package: $package
    file: $file
    index: $index
    target: $target
    release: true
  }
  let session_id = random uuid
  let sampling = {
    warmup: $warmup
    rounds: $rounds
    mode: interleaved
    pair_order: alternating
    starts_with: before
    session_id: $session_id
  }
  let before_capture = (build-capture-artifact
      $before_label
      $benchmark
      $before_harness_before
      $before_source_before
      (capture-environment-at $before_repo)
      $sampling
      $before_samples)
  let after_capture = (build-capture-artifact
      $after_label
      $benchmark
      $after_harness_before
      $after_source_before
      (capture-environment-at $after_repo)
      $sampling
      $after_samples)

  # Recheck both destinations immediately before writing either artifact.
  ensure-output-available $before_path $force
  ensure-output-available $after_path $force
  save-json $before_capture $before_path $force
  save-json $after_capture $after_path $force

  {
    status: captured
    mode: interleaved
    session_id: $session_id
    before: {
      output: $before_path
      summary: $before_capture.summary
    }
    after: {
      output: $after_path
      summary: $after_capture.summary
    }
  }
  | to json --indent 2
}

# Compare two capture artifacts and exit with a stable machine-readable status.
def "main compare" [
  before: path
  after: path
  --output (-o): string = ''       # Optional JSON report path
  --format (-f): string = 'json'   # json (Agent) or text (human)
  --min-improvement-pct: float = 2.0 # Minimum positive median delta
  --max-regression-pct: float = 1.0  # Minimum negative delta called regression
  --min-rounds: int = 3            # Reject captures with fewer recorded rounds
  --max-spread-pct: float = 10.0   # Maximum cross-round spread
  --max-internal-cv-pct: float = 15.0 # Maximum within-run CV across all rounds
  --allow-environment-mismatch     # Escape hatch; avoid for decisions
  --require-source-change          # Reject same-source before/after comparisons
  --force
]: nothing -> nothing {
  if (
    $min_improvement_pct < 0
    or $max_regression_pct < 0
    or $min_rounds < 1
    or $max_spread_pct < 0
    or $max_internal_cv_pct < 0
  ) {
    error make {msg: 'comparison thresholds must be non-negative'}
  }
  if ($output | is-not-empty) {
    ensure-output-available $output $force
  }

  let before_capture = load-capture $before
  let after_capture = load-capture $after
  let thresholds = {
    min_improvement_pct: $min_improvement_pct
    max_regression_pct: $max_regression_pct
    min_rounds: $min_rounds
    max_spread_pct: $max_spread_pct
    max_internal_cv_pct: $max_internal_cv_pct
  }
  let report = (
    build-comparison
      $before_capture
      $after_capture
      ($before | path expand)
      ($after | path expand)
      $thresholds
      $allow_environment_mismatch
      $require_source_change
  )

  if ($output | is-not-empty) {
    save-json $report $output $force
  }

  print (render-comparison $report $format)
  if $report.exit_code != 0 {
    exit $report.exit_code
  }
}

# Validate the parser, unit conversion, verdicts, and exit-code contract.
def "main self-test" []: nothing -> string {
  let raw = [
    '[hustcer/fzip] bench benchmarks/bench_test.mbt:520 ("zip/decompress/fzip") ok'
    'time (mean ± σ)         range (min … max)'
    '   3.87 µs ± 369.21 ns     3.24 µs …   4.24 µs  in 10 ×  25259 runs'
    'Total tests: 1, passed: 1, failed: 0.'
  ] | str join (char nl)
  let parsed = parse-benchmark-output $raw zip/decompress/fzip
  assert equal $parsed.name zip/decompress/fzip
  assert equal $parsed.mean_us 3.87
  assert (((($parsed.stddev_us - 0.36921) | math abs) < 0.000001))
  assert error { parse-benchmark-output $raw zip/compress/fzip }

  let catalog_source = [
    'test "first/bench" (b : @bench.T) {'
    'test "ordinary/test" {'
    '  test "second/bench" (runner : @bench.T) {'
  ] | str join (char nl)
  let catalog = parse-benchmark-catalog $catalog_source
  assert equal ($catalog | length) 2
  assert equal $catalog.0 {index: 0 name: first/bench line: 1}
  assert equal $catalog.1 {index: 1 name: second/bench line: 3}

  assert equal (interleaved-schedule 0 | length) 0
  let schedule = interleaved-schedule 3
  assert equal ($schedule | length) 6
  assert equal $schedule.0 {round: 1 side: before sequence: 1 pair_order: before-after pair_position: 1}
  assert equal $schedule.1 {round: 1 side: after sequence: 2 pair_order: before-after pair_position: 2}
  assert equal $schedule.2 {round: 2 side: after sequence: 3 pair_order: after-before pair_position: 1}
  assert equal $schedule.3 {round: 2 side: before sequence: 4 pair_order: after-before pair_position: 2}
  assert equal $schedule.4 {round: 3 side: before sequence: 5 pair_order: before-after pair_position: 1}
  assert equal $schedule.5 {round: 3 side: after sequence: 6 pair_order: before-after pair_position: 2}
  assert error { interleaved-schedule (-1) }
  assert error { validate-capture-request (-1) benchmark wasm-gc 1 0 }
  assert error { validate-capture-request 0 '' wasm-gc 1 0 }
  assert error { validate-capture-request 0 benchmark invalid 1 0 }
  assert error { validate-capture-request 0 benchmark wasm-gc 0 0 }
  assert error { validate-capture-request 0 benchmark wasm-gc 1 (-1) }

  let thresholds = {
    min_improvement_pct: 2.0
    max_regression_pct: 1.0
    min_rounds: 3
    max_spread_pct: 10.0
    max_internal_cv_pct: 15.0
  }
  let baseline = fixture-capture [10.0 10.0 10.0 10.0 10.0] wasm-gc 0.0 baseline
  let improved = fixture-capture [8.0 8.0 8.0 8.0 8.0] wasm-gc 0.0 candidate
  let regressed = fixture-capture [11.0 11.0 11.0 11.0 11.0] wasm-gc 0.0 candidate
  let close = fixture-capture [9.95 9.95 9.95 9.95 9.95] wasm-gc 0.0 candidate
  let noisy = fixture-capture [8.0 10.0 12.0 9.0 11.0] wasm-gc 0.0 candidate
  let internal_samples = $improved.samples | update 0.stddev_us 1.6
  let internally_noisy = (
    $improved
    | update samples $internal_samples
    | update summary (summarize-samples $internal_samples)
  )
  let incompatible = fixture-capture [8.0 8.0 8.0 8.0 8.0] native 0.0 candidate
  let one_round = fixture-capture [8.0] wasm-gc 0.0 candidate
  let same_source = fixture-capture [8.0 8.0 8.0 8.0 8.0] wasm-gc 0.0 baseline
  let harness_changed = $improved | update harness.0.sha256 changed

  let improved_report = build-comparison $baseline $improved before after $thresholds false true
  let regressed_report = build-comparison $baseline $regressed before after $thresholds false true
  let close_report = build-comparison $baseline $close before after $thresholds false true
  let noisy_report = build-comparison $baseline $noisy before after $thresholds false true
  let internally_noisy_report = (
    build-comparison $baseline $internally_noisy before after $thresholds false true
  )
  let incompatible_report = (
    build-comparison $baseline $incompatible before after $thresholds false true
  )
  let one_round_report = build-comparison $baseline $one_round before after $thresholds false true
  let harness_changed_report = (
    build-comparison $baseline $harness_changed before after $thresholds false true
  )
  let same_source_report = (
    build-comparison $baseline $same_source before after $thresholds false true
  )

  assert equal $improved_report.verdict improved
  assert equal $improved_report.exit_code 0
  assert equal $regressed_report.verdict regressed
  assert equal $regressed_report.exit_code 2
  assert equal $close_report.verdict inconclusive
  assert equal $close_report.exit_code 3
  assert equal $noisy_report.verdict noisy
  assert equal $noisy_report.exit_code 3
  assert equal $internally_noisy_report.verdict noisy
  assert equal $internally_noisy_report.exit_code 3
  assert equal $internally_noisy.summary.median_internal_cv_pct 0.0
  assert equal $internally_noisy.summary.max_internal_cv_pct 20.0
  assert equal $incompatible_report.verdict incompatible
  assert equal $incompatible_report.exit_code 4
  assert equal $one_round_report.verdict insufficient_samples
  assert equal $one_round_report.exit_code 3
  assert equal $harness_changed_report.verdict incompatible
  assert equal $harness_changed_report.exit_code 4
  assert equal $same_source_report.verdict incompatible
  assert equal $same_source_report.exit_code 4
  assert equal $same_source_report.compatibility.source_changed false

  let tmp = mktemp --suffix .json
  try {
    assert error { ensure-output-available $tmp false }
  } finally {
    rm --force $tmp
  }

  let artifact_samples = (
    $improved.samples
    | enumerate
    | each {|entry|
        $entry.item
        | merge {
            side: before
            sequence: ($entry.index * 2 + 1)
            pair_order: before-after
            pair_position: 1
          }
      }
  )
  let artifact = (build-capture-artifact
      interleaved-fixture
      $improved.benchmark
      $improved.harness
      $improved.source_state
      $improved.environment
      {warmup: 1 rounds: 5 mode: interleaved}
      $artifact_samples)
  assert equal $artifact.summary.rounds 5
  assert equal $artifact.samples.0.sequence 1

  let compatible_tmp = mktemp --suffix .json
  try {
    $artifact | update tool_version '1.1.0' | to json | save --force $compatible_tmp
    let compatible_capture = load-capture $compatible_tmp
    assert equal $compatible_capture.tool_version '1.1.0'
    let cross_version_report = (build-comparison
        $compatible_capture $artifact before after $thresholds false false)
    assert equal $cross_version_report.compatibility.benchmark_mismatches []
  } finally {
    rm --force $compatible_tmp
  }

  {status: ok tests: 47} | to json --indent 2
}

def main []: nothing -> nothing {
  print (
    [
      'Usage:'
      '  nu tools/bench-compare.nu list [--filter <substring>]'
      '  nu tools/bench-compare.nu capture <index> --name <benchmark> --output <file>'
      '  nu tools/bench-compare.nu interleave <index> <before-root> <after-root> --name <benchmark>'
      '  nu tools/bench-compare.nu compare <before.json> <after.json> [--require-source-change]'
      '  nu tools/bench-compare.nu self-test'
      'Compare exit codes: 0 improved, 2 regressed, 3 insufficient/inconclusive/noisy, 4 incompatible.'
    ]
    | str join (char nl)
  )
}
