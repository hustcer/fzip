#!/usr/bin/env nu

let data = open performance-report.json

print "\n╔════════════════════════════════════════════════════════════════╗"
print "║     性能优化报告 - Commit 5e6f86b (数组池化优化)              ║"
print "╚════════════════════════════════════════════════════════════════╝\n"

print "📊 总体统计"
print "─────────────────────────────────────────────────────────────────"
print $"  总测试数:     ($data.summary.total_tests)"
print $"  性能提升:     ($data.summary.improved) 个 \(62.5%\)"
print $"  性能下降:     ($data.summary.degraded) 个 \(37.5%\)"
print $"  平均提升:     ($data.summary.avg_improvement_pct)%"
print $"  最大提升:     ($data.summary.max_improvement_pct)%"
print $"  最小提升:     ($data.summary.min_improvement_pct)%\n"

print "🏆 Top 5 性能提升"
print "─────────────────────────────────────────────────────────────────"
$data.details | first 5 | each {|row|
    let name = $row.name | str replace "deflate/compress/" "" | str replace "/fzip" ""
    let improvement = $row.improvement_pct | math round -p 2
    let before = $row.before_us | math round -p 2
    let after = $row.after_us | math round -p 2
    print $"  ($name)"
    print $"    优化前: ($before)µs → 优化后: ($after)µs \(+($improvement)%\)"
}

print "\n📉 Top 3 性能下降"
print "─────────────────────────────────────────────────────────────────"
$data.details | last 3 | reverse | each {|row|
    let name = $row.name | str replace "deflate/" "" | str replace "/fzip" ""
    let change = $row.improvement_pct | math round -p 2
    let before = $row.before_us | math round -p 2
    let after = $row.after_us | math round -p 2
    print $"  ($name)"
    print $"    优化前: ($before)µs → 优化后: ($after)µs \(($change)%\)"
}

print "\n💡 关键发现"
print "─────────────────────────────────────────────────────────────────"
print "  ✓ 小数据压缩提升明显: 3-5% (1k 数据)"
print "  ✓ 内存分配减少: 后续调用 0 字节分配"
print "  ✓ 批量操作节省: 100次压缩节约 7-17MB"
print "  ⚠ 解压缩略有下降: -1% 到 -3%"
print "  ⚠ 大数据提升较小: 0.6-1.6% (100k 数据)\n"

print "📝 详细报告已保存到: PERFORMANCE_ANALYSIS_5e6f86b.md\n"
