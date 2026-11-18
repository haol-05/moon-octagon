# moon-octagon

**纯 MoonBit 整数关系约束与不变量分析库。** 保留 `x+y≤c`、`x−y≤c`、`x≤c` 等关系，提供整数紧闭包、不可变抽象状态、赋值与投影、分支合并、循环不变量及可检查的反例。不是一个只有命令行的演示：核心公开 API 可被其他 MoonBit 项目直接调用。

## 为什么需要它

独立区间知道 `x∈[0,100]`、`y∈[0,100]`，却无法保留两者的总量限制 `x+y≤100`。八边形域使用带符号变量的差分约束矩阵，在可控的三次方闭包成本内保留这类关系。

本地实现覆盖三个不同工作流，全部有可运行输入：

| 使用者与输入 | 已实现输出 | 例子 |
| --- | --- | --- |
| 程序分析工具：初始变量范围、循环条件、顺序赋值 | 关系不变量、归纳性复核、预算耗尽状态；`x++、y--` 保留 `x+y=10`，退出时推出 `y=0` | `examples/loop.json` |
| 配置检查工具：主副本资源的上下界与总量约束 | 总量边界、规则蕴含判定、违反候选规则的整数反例、原始规则冲突子集 | `examples/configuration.json` |
| 设备数据处理工具：整数刻度测量区间、通道差值容差 | 联合可行域、收紧后的各通道范围及一致的整数样本；首通道 `[20,23]` 且差值在 ±2 内，第二通道为 `[18,25]` | `examples/sensors.json` |

## 本地运行

需要 MoonBit **moonc 0.10.21**（本地实测 `v0.10.21+06da1ed44`，moon `0.1.20261117`）和 Node.js ≥22；无第三方包依赖，仅官方 core。当前工具链的 `#derive`、JSON 自由函数等接口不承诺兼容旧编译器。

```powershell
cd D:\moonbit\moon-octagon
# 当前工作区已经安装的工具链；其他机器改用自己的安装路径。
$env:MOON_HOME = 'D:\moonbit\_tools\moon-audit-20261118'
$env:Path = "$env:MOON_HOME\bin;$env:Path"
moon run examples/relations --target js -j 1
node scripts/cli.mjs examples/configuration.json
node scripts/cli.mjs examples/sensors.json
node scripts/cli.mjs examples/loop.json
node scripts/cli.mjs examples/parity-conflict.json
```

`scripts/cli.mjs` 负责文件读取、调用构建产物及进程退出码；所有模型校验与分析都在 MoonBit 中执行。它直接导入 MoonBit 导出的 JS 函数，不把大文件塞进进程参数。单请求错误退出 2，成功退出 0；`--batch file.json` 对每项保留独立 `ok` 状态。

## 调用库

当前项目仅本地开发，**尚未发布 Mooncakes**；不要把模块名当成可安装性证明。先在本目录运行示例和公开消费者测试。将来公开后再按实际发布版本添加依赖。在 `moon.pkg` 中导入 `"haol-05/moon-octagon" @oct`：

```moonbit
let s = @oct.from_constraints(2, [
  @oct.lower(0, 0L),
  @oct.lower(1, 0L),
  @oct.relation(@oct.positive(0), @oct.positive(1), 100L),
])
let joint_limit = s.entails(
  @oct.relation(@oct.positive(0), @oct.positive(1), 100L),
)
let after_copy = s.assign(1, @oct.negative(0), 100L)
// after_copy 保留 x+y=100；原 s 不变。
```

完整公开接口在 `pkg.generated.mbti`，独立调用示例在 `examples/relations/main.mbt`。会失败的调用抛出 `OctagonError`，调用者显式捕获或传播。

| 接口组 | 已实现行为 |
| --- | --- |
| 构造与查询 | `top`、`bottom`、`from_constraints`、`refine`、`interval`、`bound`、`entails`、`contains`、`constraints` |
| 集合与状态变换 | `meet`、`join`、`subset_of`、`equivalent`、`forget`、`assign`、`set_constant`、`widen`、`execute` |
| 证据 | `witness`、`check`、`satisfies`、`explain_conflict`、`verify_conflict` |
| 循环与集成 | `analyze_loop`、`verify_invariant`、`process_json`、`process_batch_json`、`report` |

## 数学语义与边界

- 变量属于数学整数 **Z**，不是实数，也不是 MoonBit Int 的溢出回绕模型。将本库用于机器整数程序前，宿主必须保证不溢出或自行建模。
- 支持 `±x≤c` 与 `±x±y≤c`；不支持任意线性系数、非线性、概率、资源排程、源代码解析或完整编译器验证。传感器示例使用整数刻度，不虚构实数误差覆盖。
- 闭包是整数紧闭包，能识别 `x+y=1 且 x=y` 这种实数可行而整数不可行的系统。`join` 是最小八边形上近似，可能引入原分支没有的状态。
- `check` 的 `Refuted` 给出抽象域中的具体整数反例，不自动证明真实程序可达。空域返回 `Vacuous`，与 `Proven` 分开。
- 循环只分析单个显式建模的 while 迭代：延迟 widening、有限 narrowing，最后复核初始化与保持性。`BudgetExhausted` 只给部分迭代状态，不算不变量；没有终止性证明。
- widening 保留未经闭包的左操作数；查询在副本上闭包。自行连续调用时请不要将 `canonical()` 的结果替换回 widening 序列，否则不再保证有限链稳定。
- 冲突子集是 **包含意义极小**，不是约束数最少；验证器从原始下标重建每次删约束的系统。验证复用闭包内核，不宣称来自另一个证明器。
- 规模、算术预算、JSON 契约见 [docs/SEMANTICS.md](docs/SEMANTICS.md)。上限是故障边界，非所有最坏组合的响应时间承诺。

## 验证与工程交付

```powershell
moon fmt --check
moon check --target all --deny-warn -j 1
moon info
node scripts/verify.mjs
```

本地已验证 JS / Wasm / WasmGC 每目标 21 项测试，额外独立枚举 **1,046 个系统、21,216 次查询、320 次赋值、320 次 join/meet、64 组冲突证据**；其中穷举了 28 条二元有符号规则的所有 406 种无序二规则组合。测试目标是有限模型中的语义，不把有限测试当成形式化证明。详见 [docs/VALIDATION.md](docs/VALIDATION.md)，可复跑收据写在 `_build/reports/independent-oracle.json`。

本机 Native 受当前 Windows runtime 仅支持 MSVC 的限制，使用已有 GCC 时编译官方 runtime 失败；**不报告 Native 测试通过**。未来 CI 在 Linux 上包含 Native 检查，但当前只提供配置、尚未在线执行。

本项目与已有区间分析、SMT/符号执行、Cassowary、STN 存在数学和用途相邻关系。**GitHub 仓库/README/代码与 Mooncakes 都已检索，有限范围未发现相同整数八边形域核心；不能保证全网零重叠或官方过审。** 具体查询与源码证据见 [SOURCES.md](SOURCES.md)。

MIT 许可证。算法来自公开文献的独立实现，不是新数学算法，也不是 APRON 完整移植。仅本地交付，没有初始化 Git、创建提交、上传 GitHub、发布 Mooncakes 或提交报名。
