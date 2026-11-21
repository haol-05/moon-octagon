# Changelog

## 0.1.2 — 2026-11-21

边界与错误路径测试补丁，无 API 或语义变化。

- 新增空域格运算、资源上限、协议 transfer/join/meet/loop 与错误信封测试，每目标 37 项。
- `moon coverage analyze` 未覆盖行由 101 降至 33，核心库仅余防御性分支。

## 0.1.1 — 2026-11-21

文档与发布元数据补丁，无 API 或语义变化。

- README 同步 29 项测试、`check_all`、Mooncakes 安装与发布状态。
- 0.1.0 发布包内的 README 早于最终文档，本版修正包页面信息。

## 0.1.0 — 2026-11-21

首个公开版本：纯 MoonBit 的整数八边形抽象域与可检查证据。已在 Mooncakes 发布为 `haol-05/moon-octagon@0.1.0`（服务端构建成功）。

### 域与变换

- 整数紧闭包（Floyd–Warshall、奇偶不可行检测、tight closure 收紧），空域单独表示。
- 不可变状态与格运算：`top`/`bottom`/`from_constraints`/`refine`/`meet`/`join`/`subset_of`/`equivalent`。
- 关系变换：`assign`（signed-copy、自赋值）、`set_constant`、`forget`、`forget_many`（一次闭包投影多个变量）、`widen`、`execute`。
- 查询与输出：`interval`、`intervals`（一次规范化批量查询）、`bound`、`entails`、`contains`、`constraints`、`render`（稳定单行文本）。

### 证据与循环

- `witness` 给出经过成员复核的整数模型；`check` 返回 `Proven`/`Refuted(反例)`/`Vacuous`。
- `explain_conflict` 返回包含意义极小的冲突子集，`verify_conflict` 从原始下标重建验证；JSON 输出附带所选约束文本与 `render_constraint`。
- `analyze_loop` 延迟 widening、有界 narrowing，并以 `verify_invariant` 复核初始化与保持性；预算耗尽状态不当作不变量。

### 集成与工具

- JSON 桥：`analyze`/`transfer`/`join`/`meet`/`conflict`/`loop` 与批量入口；严格 schema、数值字符串输出、结构化错误。
- `scripts/cli.mjs`：文件或 stdin 输入、`--out`、`--batch`，退出码 0/2/64/1；`node:test` 合同测试。
- `scripts/verify.mjs`：不依赖 DBM 实现的有限状态独立枚举（1046 个系统、21216 次查询）。
- 示例：`examples/relations`、`examples/interval-gap` 与四份 JSON 输入。

### 工程

- MIT 许可证、来源与查重记录（`SOURCES.md`）、语义与限制（`docs/SEMANTICS.md`）、验证记录（`docs/VALIDATION.md`）。
- GitHub Actions：格式、js/wasm/wasm-gc 的检查/构建/测试、Linux Native、示例与独立 oracle。
