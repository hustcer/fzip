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

# 默认显示所有可用命令
default:
    @just --list --list-prefix "··· "

# 更新 Moonbit 依赖
i: __setup
    moon update

# Moonbit 代码全量格式化
fmt: __setup
    moon info
    moon fmt

# 代码全量扫描检查
lint:
    moon check --target all

# Build: 以生产模式构建应用
b: __setup
    moon build --target all

# Bench: 运行性能基准测试
bench:
    moon bench -p benchmarks

# Bench JSON: 运行性能基准测试并输出 JSON 格式结果
bench-json output='':
    #!/usr/bin/env nu

    let out = '{{ output }}'
    let args = if ($out | is-not-empty) { [--save $out] } else { [] }
    ^moon bench -p benchmarks o+e>| nu --stdin bench/parse-bench.nu ...$args

# Bench RPT: 运行性能基准测试并生成报告
bench-rpt:
    #!/usr/bin/env nu
    moon bench -p benchmarks o+e>| nu --stdin bench/parse-bench.nu -s src/benchmarks/bench.json
    nu src/benchmarks/gen-report.nu o> src/benchmarks/bench.md
    oxfmt src/benchmarks/bench.md src/benchmarks/bench.json

# 运行测试
test:
    moon test --target all

# 清理构建目录
clean:
    #!/usr/bin/env nu

    moon clean
    print $'(ansi pb)Directories have been cleaned !(ansi reset)'

# 扫描代码中的拼写错误, 需要本机安装 `typos-cli`, 使用：`just typos` or `just typos raw`
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

# 检查过期依赖: `just outdated` 检查所有 Node 依赖, `just outdated mbt` 检查 MoonBit 依赖
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

# 从 Nu v0.61.0 开始插件只需注册一次即可
_register_plugins:
    #!/usr/bin/env nu
    let incExists = not (scope commands | where name == 'inc' | is-empty)
    if not $incExists { plugin add {{ join(NU_DIR, _inc_plugin) }} }

