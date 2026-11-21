# 本地验证记录

日期：2026-11-21，Asia/Shanghai。状态：核心实现、公开仓库与 Mooncakes 0.2.0 交付完成；报名、初审与最终验收未提交。

## 工具链

- 本机 moon `0.1.20261117 (eb64713 2026-11-17)`，moonc `v0.10.21+06da1ed44`，Node.js `v24.19.0`。
- GitHub Actions 使用官方 install/unix.sh 安装的最新稳定工具链与 Node 22；每次运行由 `moon version --all` 记录实际版本。
- 本机工具链放在仓库外的 `_tools/moon-latest`，不随源码提交；core 已完成 js / wasm / wasm-gc 预构建。

## 已实际完成

| 检查 | 结果 |
| --- | --- |
| `moon fmt --check` | 退出 0 |
| `moon check --target js/wasm/wasm-gc --deny-warn -j 1` | 各目标退出 0 |
| `moon build --target js/wasm/wasm-gc -j 1` | 各目标退出 0 |
| `moon test --target js/wasm/wasm-gc --deny-warn -j 1` | 每目标 **68/68** |
| `moon run examples/relations`、`examples/interval-gap` | js / wasm / wasm-gc 均成功，三个目标输出一致 |
| `node --test scripts/cli.test.mjs` | 4/4（stdin、batch、--out、退出码 2/64） |
| `node scripts/verify.mjs` | 退出 0；1046 个系统、21216 次查询、320 次赋值、320 次 join/meet、64 组冲突 |
| `moon coverage analyze` | 0.2.0 新增模块后未覆盖行 75（文本/Box/并行/CFG 的错误与空域分支为主）；示例、CLI 与 bridge 进程入口不计入单元覆盖 |
| 干净副本复现 | 源码复制到仓库外目录、排除 `_build`/`.git`，重跑 verify.mjs 退出 0，三个目标仍为 68/68 |
| GitHub Actions | run [44320812207](https://github.com/haol-05/moon-octagon/actions/runs/44320812207)：check、test(js)、test(wasm)、test(wasm-gc)、native、oracle 六个作业全部 success；后续提交运行同样通过 |
| Mooncakes | `moon publish` 发布 `haol-05/moon-octagon@0.2.0`；[manifest API](https://mooncakes.io/api/v0/manifest/haol-05/moon-octagon) 回读 `build_status=success`，包页面 <https://mooncakes.io/docs/haol-05/moon-octagon> |
| Mooncakes 安装复测 | 全新模块执行 `moon add haol-05/moon-octagon` 下载 0.2.0，消费者程序运行输出 `sum<=100` 与规范形式 |

`_build/reports/independent-oracle.json` 保留可复查收据；构建缓存可重建，不作为源码提交的一部分。

## 独立对照方法

`node scripts/verify.mjs` 不重写被测 DBM 算法：直接枚举有限整数向量，按原始不等式逐项求值，计算最大值，再调用编译后的 MoonBit 导出函数比较。

- 随机种子固定 `7331`，640 组二/三变量系统；每个变量有 `[-3,3]` 的显式输入界，因此枚举覆盖该系统的全部整数状态。
- 额外穷举四组符号、七个边界组成的 28 条二元规则的全部 **406 种无序二规则组合**。
- 合计 **1046 个系统、21216 次边界/蕴含查询**：比对空域、每变量最紧上下界、全部指定符号形式的最紧上界；每个见证和反例重新按原始规则直接核验。
- **320 个 signed-copy 赋值案例**：先枚举旧状态、直接计算赋值像，核对新状态的界和具体见证。
- **320 个 join/meet 案例**：合并界与具体并集的 extrema 一致；meet 对照具体交集。
- **64 组冲突子集**：复核索引唯一、闭包验证器结果，并在原始有界空间直接检查所选约束不含解。

MoonBit 测试（每目标 68 项）覆盖：文本前端（区间/关系/等号/负字面量/边界错误与回读）、Box 格运算/赋值/witness/文本、并行赋值（交换/像映射/限额）与 rename、CFG 菱形/自环/链/预算、120 组固定种子的随机三约束系统（成员关系、区间、check、投影均与具体枚举对照）、`check_all` 批量判定、空域格运算、资源上限、协议 transfer/join/meet/loop 与错误信封、负奇数 floor、实数可行/整数不可行、同变量抵消、关系投影（`forget`、`forget_many` 与穷举投影一致、顺序无关）、signed-copy 赋值、join 引入新状态、widening 关系保持、循环归纳性、预算耗尽、输入所有权、带下标与预算值的错误信息、错误符号/维度、批量 `intervals`、`render` 稳定文本、`render_constraint`、冲突 JSON 原文、精度敏感 JSON、重复键、嵌套限制、批次逐项错误、公开消费者调用和 CLI 合同。

这些是有限行为证据，不能替代数学定理的形式化证明或其他分析器的端到端集成。

## 尚未通过或未执行

- **报名、初审、最终验收**：未提交问卷或申报书，未取得官方结论。
- **本机 Windows Native**：官方 runtime 当前只支持 MSVC，使用已有 GCC 编译失败，故不报告本机 Native 通过；CI 的 Linux native 作业已实际成功，不能混写为本机结果。
- **生态唯一性**：只做了 SOURCES.md 中明确范围的实时检索；私有/未索引/未来项目及官方立项意见未知。
