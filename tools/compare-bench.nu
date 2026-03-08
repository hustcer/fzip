#!/usr/bin/env nu

# 读取优化前后的基准测试结果
let before = open bench-before.json | get benchmarks
let after = open bench-after.json | get benchmarks

# 只关注 fzip 的测试结果
let before_fzip = $before | where name =~ "fzip"
let after_fzip = $after | where name =~ "fzip"

# 对比结果
let comparison = $before_fzip | each {|b|
    let name = $b.name
    let a = $after_fzip | where name == $name | first
    
    let speedup = $b.mean_us / $a.mean_us
    let improvement_pct = (($b.mean_us - $a.mean_us) / $b.mean_us) * 100
    
    {
        name: $name,
        before_us: $b.mean_us,
        after_us: $a.mean_us,
        speedup: $speedup,
        improvement_pct: $improvement_pct,
        before_runs: $b.runs,
        after_runs: $a.runs
    }
}

# 按性能提升排序
let sorted = $comparison | sort-by -r improvement_pct

print "\n=== 性能优化报告 (Commit 5e6f86b) ===\n"
print "优化内容：数组池化 (Array Pooling)\n"

# 统计信息
let total_tests = ($sorted | length)
let improved = ($sorted | where improvement_pct > 0 | length)
let degraded = ($sorted | where improvement_pct < 0 | length)
let avg_improvement = ($sorted | get improvement_pct | math avg)
let max_improvement = ($sorted | get improvement_pct | math max)
let min_improvement = ($sorted | get improvement_pct | math min)

print $"总测试数: ($total_tests)"
print $"性能提升: ($improved) 个测试"
print $"性能下降: ($degraded) 个测试"
print $"平均提升: ($avg_improvement | math round -p 2)%"
print $"最大提升: ($max_improvement | math round -p 2)%"
print $"最小提升: ($min_improvement | math round -p 2)%\n"

# 详细结果表格
print "=== 详细性能对比 ===\n"
$sorted | select name before_us after_us speedup improvement_pct | each {|row|
    {
        测试名称: ($row.name | str replace "deflate/compress/" "" | str replace "/fzip" ""),
        优化前_us: ($row.before_us | math round -p 2),
        优化后_us: ($row.after_us | math round -p 2),
        加速比: ($row.speedup | math round -p 2),
        提升百分比: ($row.improvement_pct | math round -p 2)
    }
}

# 保存详细报告到文件
let report = {
    summary: {
        total_tests: $total_tests,
        improved: $improved,
        degraded: $degraded,
        avg_improvement_pct: ($avg_improvement | math round -p 2),
        max_improvement_pct: ($max_improvement | math round -p 2),
        min_improvement_pct: ($min_improvement | math round -p 2)
    },
    details: $sorted
}

$report | save -f performance-report.json
print "\n详细报告已保存到 performance-report.json"
