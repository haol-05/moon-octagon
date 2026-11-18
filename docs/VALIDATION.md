# 本地验证记录

日期：2026-11-18，Asia/Shanghai。状态：核心开发完成，JS/WasmGC/Wasm 本地运行通过；公开交付和官方审核未执行。

## 工具链

- moon `0.1.20261117 (eb64713 2026-11-17)`。
- moonc `v0.10.21+06da1ed44 (2026-11-16)`。
- Node.js `v25.2.1`；验证脚本只使用 Node 内置模块，声明最低 Node 22，未在本机另装 Node 22 做第二遍测试。
- 工具链位置 `D:\moonbit\_tools\moon-audit-20261118`，与其他项目源码分离。

## 已实际完成

| 检查 | 结果 |
| --- | --- |
| `moon fmt --check` | 退出 0 |
| `moon check --target all --deny-warn -j 1` | 退出 0 |
| `moon info` | 退出 0；生成公开接口 |
| JS / WasmGC / Wasm 的 build | 每目标退出 0 |
| JS / WasmGC / Wasm 的 test | 每目标 **21/21** |
| `moon run examples/relations` | 每个上述目标成功，输出一致 |
| JSON CLI 后端对照 | JS / WasmGC / Wasm 对同一关系查询的完整 JSON 对象一致 |
| `scripts/cli.mjs` 文件入口 | 配置、传感器、循环、奇偶冲突四份输入成功，exit 0 |
| Native 运行测试 | 未通过，失败发生在官方 Windows runtime 编译，详见下节 |
| Git / GitHub / Mooncakes / 报名 | 未创建或执行 |

`_build/reports/final-checks.json`、`file-cli.json` 与 `independent-oracle.json` 保留可复查原始结果。构建缓存可重建，不把这些结果当作线上 CI。

## 独立对照方法

`node scripts/verify.mjs` 不重写被测 DBM 算法：直接枚举有限整数向量，按原始不等式逐项求值，计算最大值，再调用编译后的 MoonBit 导出函数比较。

- 随机种子固定 `7331`，640 组二/三变量系统；每个变量有 `[-3,3]` 的显式输入界，因此枚举覆盖该系统的全部整数状态。
- 额外穷举四组符号、七个边界组成的 28 条二元规则的全部 **406 种无序二规则组合**。
- 合计 **1046 个系统、21216 次边界/蕴含查询**：比对空域、每变量最紧上下界、全部指定符号形式的最紧上界；每个见证和反例重新按原始规则直接核验。
- **320 个 signed-copy 赋值案例**：先枚举旧状态、直接计算赋值像，核对新状态的界和具体见证。
- **320 个 join/meet 案例**：合并界与具体并集的 extrema 一致；meet 对照具体交集。
- **64 组冲突子集**：复核索引唯一、闭包验证器结果，并在原始有界空间直接检查所选约束不含解。该部分枚举不声称独立证明无界删除子集的全局不可满足性；极小性验证另由库从原始约束重建。

MoonBit 测试还直接枚举全部 36 个二元符号/边界系统：校验每个有界点的成员关系、288 个 signed-copy 变换后 `[-4,4]²` 上的全部成员关系、存在投影，以及导出约束回读。其余测试覆盖负奇数 floor、实数可行/整数不可行、同变量抵消、join 引入新状态、widening 保持关系、循环归纳性、预算耗尽、输入所有权、错误符号/维度、精度敏感 JSON、重复键、嵌套限制、批次逐项错误和公开消费者调用。

这些是有限行为证据，不能替代数学定理的形式化证明或其他分析器的端到端集成。

## 干净副本复现

从本项目只复制源码、接口、示例、许可证、文档和工具脚本到新的目录，排除 `_build`、`.mooncakes`、`node_modules`、`.git` 与私有申报模板。路径：

`D:\moonbit\contest-submission\cleanroom-octagon-20261118-LC8IKJ`

在该目录从空构建缓存运行 `node scripts/verify.mjs`，**退出 0**，再次得到同样 1046/21216/320/320/64 与三个目标各 21/21 的结果。回执在原项目 `_build/reports/clean-room.json`。未借用原项目生成 JS 作为干净副本的输入。

## 尚未通过或未执行

- **Native**：显式指定现有 `C:\msys64\ucrt64\bin\gcc.exe`（16.2.0）后，官方 runtime 的 `event_bus.c` / `fs.c` / `thread_pool.c` 报 `Currently only MSVC is supported on Windows`，另有 socket 常量缺失。没有修改官方 runtime 绕过失败；未发现可用的标准 Visual Studio 安装入口。该结果区分于 MoonBit 静态检查已通过，不能写成 native build/test 成功。
- **线上 CI**：只配置了 `.github/workflows/ci.yml`，没有上传，故没有任何线上运行成功证据。配置使用官方 stable installer，编译器升级后若接口文件变化应复核，不能静默忽略。
- **GitHub、Mooncakes、有效提交历史、报名初审、最终验收**：全部待后续明确授权或参赛者操作。本次不创建 Git 历史凑次数。
- **生态唯一性**：只做了 SOURCES.md 中明确范围的实时检索；私有/未索引/未来项目及官方立项意见未知。
