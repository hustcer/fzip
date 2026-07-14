# fzip Agent 性能优化指南

本文是 Agent 对本仓库执行性能优化时的标准操作规程。目标不是“尽量改快”，而是在不破坏正确性、安全性、兼容性和公共 API 的前提下，产出可复现、可审计、可提交的性能改进。

除非用户明确覆盖，Agent 必须遵守本指南的任务契约、证据要求、策略状态机、回退边界和结束条件。

## 1. 必须使用的能力

- 使用 `moonbit-agent-guide` SKILL 指导 MoonBit 源码导航、实现、测试、公共 API 检查和最终代码审查。
- 使用 `planning-with-files` SKILL 创建隔离的持久化任务记录。
- 修改或审查 `.nu` 文件时使用 `nushell-pro` SKILL。
- 不依赖不存在或不稳定的 slash command 语法；按名称加载并遵循对应 SKILL 即可。

## 2. 开始前固定任务契约

在修改源码前，将以下字段写入本次任务的 `task_plan.md`。用户已经明确的字段不得擅自改变；缺失字段可以根据仓库事实作最小、可撤销的假设，并记录理由。

| 字段                    | 必填内容                                                  |
| ----------------------- | --------------------------------------------------------- |
| scope                   | 本次允许修改的包、功能或调用路径                          |
| primary metric          | latency、throughput、compressed size、memory 或明确的组合 |
| direction               | lower-is-better 或 higher-is-better                       |
| primary target          | 需要证明收益的 MoonBit backend 与 release/debug 模式      |
| primary benchmarks      | 决定策略是否成功的 benchmark 名称                         |
| guard benchmarks        | 可能受影响、用于防止局部优化导致整体退化的 benchmark 名称 |
| thresholds              | 最低收益、最大允许退化和噪声门槛                          |
| correctness constraints | 输出、错误、安全校验、格式兼容和边界行为约束              |
| API constraints         | 公共 API 是否必须保持不变                                 |
| candidate limit         | 本轮最多尝试的有限候选集合或明确的停止条件                |

默认规则：

- 时间指标默认至少提升 2%，并且必须超过动态噪声门槛。
- 未经明确授权，不改变公共 API。
- 不得通过删除格式校验、安全检查、错误处理、边界检查或改变输出语义换取性能。
- 一次只实施一个可独立解释和回退的优化策略。
- benchmark target 由任务契约决定，不得把 `wasm-gc`、native 或某个固定 index 当作全仓库默认事实。

如果任务契约中的关键选择会显著改变优化方向，例如 primary target 或“速度与压缩率”的取舍无法从上下文确定，先向用户确认。

## 3. 创建隔离、可恢复的任务目录

每次性能任务都创建唯一目录，推荐格式：

```text
.planning/YYYY-MM-DD-HHMMSS-fzip-perf-SCOPE/
```

目录内至少维护：

- `task_plan.md`
- `findings.md`
- `progress.md`
- `failing-cases.md`

不得复用固定的 `.planning/fzip-optimize/`，也不得覆盖仓库根目录或其他任务已有的规划文件。

所有性能工件使用 append-only 命名，例如：

```text
S01-r1-before-wasm-gc.json
S01-r1-after-wasm-gc.json
S01-r1-primary-comparison.json
S01-r2-before-wasm-gc.json
S01-post-commit-wasm-gc.json
```

正式性能证据禁止使用 `--force` 覆盖。需要重测时创建新的 round 文件。

## 4. 工作区和所有权预检

开始时执行并记录：

```bash
git status --short
git diff --stat
git log -5 --oneline
moon version
nu -c 'version | get version'
```

将任务开始前已存在的修改和未跟踪文件登记为“用户/其他任务所有”。Agent 必须遵守：

- 不删除、覆盖、暂存、提交或回退非本任务创建的内容。
- 策略失败时只回退该策略自身的改动。
- 如果预存修改与候选策略修改同一代码区域，先尝试绕开；无法安全隔离时停止并向用户说明。
- 不使用 `git reset --hard`、`git checkout --` 等会破坏其他修改的命令。

## 5. 建立事实基础

### 5.1 历史数据只用于发现候选

可以读取：

```bash
git show feature/bench:src/benchmarks/bench.md
```

但必须记录其中的日期、MoonBit 版本、target 和测试环境。它是历史快照，不是当前 baseline。

历史报告、旧 planning 记录和竞品数据只能用于：

- 发现慢场景或潜在热点。
- 识别已尝试、失败或被否决的策略。
- 为候选排序提供线索。

它们不能替代当前机器、当前工具链、同一 target 下生成的 before/after 证据。不同库自行生成的压缩流、不同 fixture 或不同 benchmark harness 也不一定可以直接横向比较。

### 5.2 阅读仓库事实

至少检查：

- 当前实现和相关测试。
- benchmark fixture 与 benchmark 实现。
- 当前任务和历史任务的 `findings.md`、`progress.md`、`failing-cases.md`。
- 相关 Git 历史。
- `moon.mod` 或仓库实际存在的 legacy `moon.mod.json`。
- 对应包的 `moon.pkg` 和 `pkg.generated.mbti`。

不要为了性能任务顺带迁移 `moon.mod.json`，除非用户明确要求。

### 5.3 使用语义导航定位实现

优先使用：

```bash
moon ide outline src
moon ide peek-def SYMBOL
moon ide find-references SYMBOL
moon ide doc QUERY
```

benchmark 报告只能说明“哪个场景慢”，不能证明“哪个函数是热点”。需要热点证据时，可创建不提交的 native 循环 harness，并使用：

```bash
moon run --profile --target native --release PACKAGE
```

native profiling 用于定位 self-time、inclusive-time、分配、复制和运行时成本；最终收益仍必须在任务契约指定的 primary target 上证明。

## 6. 校验 benchmark 工具与发现 index

先运行：

```bash
nu tools/bench-compare.nu self-test
nu -c 'source tools/bench-compare.nu'
```

使用 benchmark 名称发现当前 index，不得长期硬编码 index：

```bash
nu tools/bench-compare.nu list --filter zip/decompress/fzip
```

当前仓库中 `zip/decompress/fzip` 的 index 是 66，但源码中插入 benchmark 后可能变化。每次 `capture` 仍必须同时提供 `--name`；工具会核验实际输出名称，防止 index 漂移后测错对象。

`tools/bench-compare.nu` 只比较 `moon bench` 的时间结果。它不负责压缩体积、峰值内存或其他非时间指标。

## 7. 建立当前 baseline

对每个 primary benchmark 和必要的 guard benchmark，在代码改动前生成独立 baseline。下面是时间指标的 Nushell 示例，实际名称、target 和 plan 目录必须来自任务契约：

```nu
let plan_id = $'((date now | format date "%Y-%m-%d-%H%M%S"))-fzip-perf-zip-decompress'
let plan_dir = '.planning' | path join $plan_id
mkdir $plan_dir

let benchmark_name = 'zip/decompress/fzip'
let matches = (
  nu tools/bench-compare.nu list --filter $benchmark_name
  | from json
  | where name == $benchmark_name
)
if ($matches | length) != 1 {
  error make {msg: $'Expected exactly one benchmark named ($benchmark_name)'}
}
let benchmark = $matches.0

(
  nu tools/bench-compare.nu capture $benchmark.index
    --name $benchmark.name
    --target wasm-gc
    --rounds 5
    --warmup 1
    --label S01-r1-before
    --output ($plan_dir | path join 'S01-r1-before-wasm-gc.json')
)
```

capture 工件会记录：

- benchmark 名称、index、target 和 harness 哈希。
- MoonBit、Nushell、操作系统和机器信息。
- Git HEAD、tracked diff 哈希、相关未跟踪文件哈希和源码内容指纹。
- 多轮样本、median、MAD、spread 和单轮内部 CV。

如果采样期间相关源码状态发生变化，capture 必须失败。停止并发编辑后写入新的工件重测。

## 8. 形成有限候选并维护状态机

在实施前建立按“预期收益、证据强度、风险、成本”排序的有限候选列表。每个策略使用稳定 ID，例如 `S01`、`S02`。

策略状态只能按以下状态机推进：

```text
proposed -> measuring -> accepted
                     -> rejected
                     -> ruled_out
                     -> blocked
```

- `proposed`：有明确假设，但尚未改代码。
- `measuring`：正在进行单策略实现与 before/after 测量。
- `accepted`：满足全部性能、正确性、审查和验证门槛。
- `rejected`：已经实施，但回退、无收益或产生退化。
- `ruled_out`：未实施，已有源码、profiling 或历史失败证据证明不值得重试。
- `blocked`：缺少权限、环境或用户决策，无法安全继续。

已经失败或被否决的策略不得重复，除非出现新的源码变化、profiling 结果或 benchmark 证据。新证据和重试理由必须先写入 `failing-cases.md`。

## 9. 单策略优化闭环

对每个策略严格执行：

1. 将状态改为 `measuring`。
2. 记录假设、热点证据、预计影响的 primary/guard benchmark、正确性风险和回退范围。
3. 在当前有效代码状态上生成该策略专属 before capture。不要用很早以前的 baseline 替代紧邻测量。
4. 只实现该策略所需的最小改动。
5. 同步添加或修改针对性正确性测试。
6. 运行最小范围的 `moon check` 和 targeted tests。
7. 生成 after capture。
8. 比较 primary benchmark，并要求源码确实发生变化。
9. 比较所有 guard benchmark。
10. 根据判定接受、重测或只回退本策略变更。

时间指标的正式比较示例：

```nu
let before = $plan_dir | path join 'S01-r1-before-wasm-gc.json'
let after = $plan_dir | path join 'S01-r1-after-wasm-gc.json'
let report = $plan_dir | path join 'S01-r1-primary-comparison.json'

(
  nu tools/bench-compare.nu compare $before $after
    --require-source-change
    --output $report
)
```

正式证据不得使用 `--allow-environment-mismatch`。该选项只可用于人工诊断，不得用于接受或否决策略。

### 9.1 comparator 判定

| verdict / exit code        | Agent 动作                                             |
| -------------------------- | ------------------------------------------------------ |
| `improved` / 0             | primary 可进入下一道门槛；guard 也可通过               |
| `regressed` / 2            | primary 直接拒绝；guard 不允许接受                     |
| `insufficient_samples` / 3 | 增加 rounds，写入新工件重测                            |
| `noisy` / 3                | 系统空闲后增加 rounds，写入新工件重测                  |
| `inconclusive` / 3         | primary 尚未证明收益；guard 在低噪声且样本充分时可接受 |
| `incompatible` / 4         | 修正 benchmark、环境、harness 或源码状态问题后重测     |

主指标与 guard 的规则不同：

- primary benchmark 必须为 `improved`。
- guard benchmark 不得为 `regressed`。
- guard 在样本充分且未被判定为 noisy 时允许 `inconclusive`。
- `insufficient_samples`、`noisy` 和 `incompatible` 都不是可接受的 guard 结果。

### 9.2 噪声重试上限

每个策略最多进行三轮正式测量，推荐依次使用 5、7、9 rounds。每次都创建新的 before、after 和 comparison 文件。

三轮后仍无法证明 primary improvement，则将策略标记为 `rejected`，记录结果并回退本策略；不得无限加样本追逐偶然正结果。

## 10. 非时间指标

如果 primary metric 包含 compressed size、memory 或其他指标：

- 使用确定性 fixture 和单独的 before/after 工件。
- 明确单位、方向、阈值和采集命令。
- 对相同输入比较；不得把不同输入或不同生成方式的压缩流直接比较。
- 体积优化必须同时验证解压正确性和格式兼容性。
- 内存指标必须说明是峰值、累计分配还是特定 profiler 统计。
- 不得把 `tools/bench-compare.nu` 的时间 verdict 用作体积或内存结论。

普通 `moon test` 中不得加入依赖机器负载的性能阈值断言。测试负责正确性，性能结论由独立 benchmark 工件负责。

## 11. 失败策略登记与回退

失败记录至少包含：

- 策略 ID 和最终状态。
- 假设、热点证据和源码位置。
- 改动摘要和实际修改文件。
- before、after、comparison 工件路径。
- primary 和 guard 结果。
- 失败原因或排除证据。
- 正确性测试结果。
- 已回退文件清单和回退确认。
- 允许未来重试所需的新证据。

回退时基于任务开始时的所有权清单和本策略 diff，只撤销 Agent 自己为该策略创建的修改。不得通过恢复整个文件来覆盖其中原有的用户改动。

失败策略不得提交。

## 12. 接受策略的完整门槛

只有同时满足以下条件，策略才能标记为 `accepted`：

- 所有 primary benchmark 都是 `improved`，达到静态阈值并超过动态噪声门槛。
- 所有 guard benchmark 均未 `regressed`，且不存在 noisy、样本不足或不兼容结果。
- 所有非时间指标满足任务契约。
- 输出、格式、安全检查、错误行为和兼容性保持正确。
- 针对性测试已随实现补充并通过。
- 使用 `moonbit-agent-guide` 完成 MoonBit 代码审查，没有未解决的 correctness、API 或性能证据问题。
- 公共 API 变化符合任务契约；默认应保持不变。

不要把“先优化、通过审查后再补测试”作为流程。测试必须与实现同步，审查可以要求继续补充遗漏用例。

## 13. 提交和提交后确认

每个 accepted 策略单独提交。提交前先完成第 14 节全量验证，并保留最终 pre-commit after capture。

如果 `moon fmt`、`moon info` 或审查修复改变了相关源码或配置，必须在这些命令之后重新生成最终 after capture；较早的 after 只能作为中间证据，不能代表将要提交的源码状态。

Commit 必须使用英文 Conventional Commit，正文为详细、紧凑的 bullet list，不添加 `Co-Authored-By`。正文至少记录：

- primary benchmark 的 before、after、提升百分比和 speedup，或对应非时间指标。
- target、release 模式和记录轮数。
- guard 结果。
- 测试、all-target 验证和公共 API 状态。

示例：

```text
perf(zip): reduce central-directory parsing overhead

- zip/decompress/fzip wasm-gc release: 4.12 us -> 3.78 us (-8.3%, 1.09x)
- comparator: improved across 7 recorded rounds; guards show no regression
- all-target check/build/test pass; public API unchanged
```

提交后对同一源码生成一个新的 post-commit capture：

1. 确认 post-commit capture 与 pre-commit after 的 `source_state.content_sha256` 相同。
2. 用最初 before 与 post-commit capture 再次比较，并使用 `--require-source-change`。
3. 正式报告优先引用提交后工件，使性能证据可以关联到已提交 HEAD。

pre-commit after 与 post-commit capture 源码内容相同，因此二者互比时不得使用 `--require-source-change`。若提交后测量 noisy，按相同上限生成新工件重测并记录，不得覆盖已有证据。

## 14. 最终 MoonBit 验证

每个 accepted 策略提交前，以及全部策略结束后，运行：

```bash
moon fmt
moon check --target all --deny-warn --warn-list +unnecessary_annotation
moon build --target all --deny-warn
moon test --target all --deny-warn
moon info
git diff --check
```

然后检查：

- `pkg.generated.mbti` 是否只有预期变化；不要直接编辑该文件。
- 是否存在 Warning。
- 是否误包含 `.planning/` 工件、临时 profiling harness、调试输出或失败实验代码。
- Git 暂存区是否只包含当前 accepted 策略的文件。
- commit message 中的性能数字是否与最终 JSON 工件一致。

## 15. 结束条件

满足以下条件后结束本轮性能优化：

- 初始有限候选列表中的所有策略均为 `accepted`、`rejected`、`ruled_out` 或 `blocked`。
- 没有新的 profiling 或源码证据支持预期收益可超过噪声门槛的候选。
- 所有 accepted 策略已分别提交并有提交后性能工件。
- 所有 rejected 和 ruled-out 策略已写入 `failing-cases.md`。
- 全量验证成功且没有 Warning。
- 工作区中没有遗留失败实验、临时 harness 或误纳入的性能工件。

最终向用户报告：

- accepted、rejected、ruled-out 和 blocked 策略清单。
- 每个 accepted 策略的 commit、primary/guard 指标和工件路径。
- 最终验证命令及结果。
- 公共 API 是否变化。
- 尚存风险和停止理由。
