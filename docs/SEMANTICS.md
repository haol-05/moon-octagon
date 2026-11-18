# 语义、资源和错误契约

## 整数八边形域

每个变量映射为 `p(2i)=xi`、`p(2i+1)=-xi`。矩阵 `m[i][j]` 表示 `p(i)-p(j)≤m[i][j]`，并维护 `m[i][j]=m[j^1][i^1]`。一元规则写为两倍边界；同变量的二元规则允许表达 `2x≤c` 和常量真假。

构造按以下次序进行：Floyd–Warshall 最短路闭包；检测负对角；对每对互补一元边检查 `floor(a/2)+floor(b/2)<0` 的整数不可行；将每条边收紧为与两个一元半边和的最小值。负奇数取向负无穷的 floor，不能使用向零截断。该过程基于整数 tight-closure 定理。时间 O(n³)，矩阵空间 O(n²)，这里 n 为带符号维数。

空域作为单独状态表示，不能导出为可满足 conjunction。`constraints` 返回完整规范关系集，输入输出数组不与内部矩阵共享；所有公开运算返回新状态。查询闭包副本，不会修改 widening 中间表示。

`assign(target, source, offset)` 精确计算 `x_target:=sign*x_source+offset` 的八边形像，RHS 从同一旧状态读取，支持自赋值和负号。多条 Transfer **顺序执行**；若要同时交换两个变量，调用者应使用临时维度，不要把顺序赋值当成并行赋值。`forget` 是存在量化投影，保留其他变量之间已推出的关系。

## 库限制

| 项 | 限制 |
| --- | --- |
| 维度 | 1..24 |
| 普通构造/refine 的约束数 | 每次 ≤4096；完整 24 维导出最多 2256 条，能够回读 |
| 库中二元约束绝对值 | ≤10^15；一元 ≤5×10^14，防止倍增越界 |
| 赋值偏移/常量 | ±10^9 |
| 每个有限派生边界/中间算术和 | ±10^15；超出抛 `Arithmetic`，绝不静默饱和 |
| 具体样本坐标 | ±10^15；差值与二项和仍在 Int64 安全范围 |
| Transfer | 每次 ≤128 条 |
| 冲突提取/验证 | 原始约束 ≤512；提取检查预算 1..1024，预算不足直接抛 Limit |
| 循环 | 迭代 1..256、widen 延迟 0..32、narrowing 0..8 |

`INF=4×10^15` 只作无穷哨兵；矩阵有限项与它分离。合法输入不保证所有后续运算均在预算内；调用者必须处理 `Arithmetic`。维度/预算不是性能承诺，特别是最大规模的冲突最小化与多轮循环有更高成本。

## JSON

请求都是一个 object，必须有 `op`、`dimensions`、`constraints`。维度为 JSON 整数字面量；所有输入数值在 ±10^9 内。拒绝小数、指数形式、重复键、未知字段、缺少字段、越界变量和非 ±1 符号。保留数字原始文本，避免浮点解析把 `1.00000000000000000000001` 错当成整数 1。

Term 为 `{"variable":0,"sign":1}`。Constraint 为 `{"left":Term,"right":Term或null,"bound":整数}`；省略 right 表示一元。`bound` 也可为负数。

| op | 额外字段 | 结果 |
| --- | --- | --- |
| analyze | 可选 queries，≤512 条候选约束 | domain、每项 proven/refuted/vacuous、最紧上界、反例 |
| transfer | transfers | 最终 domain |
| join / meet | other，另一组同维约束 | 合并/交集 domain |
| conflict | 可选 max_checks | 极小冲突索引、所选约束的文本、verified；可满足时 conflict=null 且 constraints 为空数组 |
| loop | guard、body；可选 max_iterations / widen_after / narrowing_steps | inductive / budget_exhausted、head、iterations、verified |

Transfer 使用 `op=guard` + constraints，`op=assign` + target/source/offset，`op=set` + target/value，`op=forget` + target。

所有外层结果明确包含 `ok`。数值结果中的 Int64 **输出十进制字符串**，如 `"100"`；无界为 `null`，不是 0。非空 domain 输出 intervals 和 witness；空域只有 `state=empty`。单请求文本 ≤200000 UTF-16 单位，批请求 ≤1000000，深度 ≤32，批次 ≤64 项；单请求 constraints/queries ≤512。

`process_json` 与直接 CLI 使用结构化错误信封；直接 `moon run cmd/main` 总是打印一条结果，由调用者检查 ok。文件包装器 `scripts/cli.mjs` 则把单请求错误转为退出码 2；批处理仍退出 0，调用者逐项读取 ok。文件读取和输出失败抛出/退出失败，不把部分输出当成功。

## 证据含义

`Proven` 只证明当前数学域蕴含候选关系；`Vacuous` 表示前提无解；`Refuted` 附模型中的反例，不蕴含源程序真实可达。`witness` 按变量依次选取接近零的整数并重新闭包，最后再做直接矩阵成员检查。

`Inductive` 表示 entry⊆head 且 body(head∩guard)⊆head；不证明循环终止、调度可行或源代码正确映射。narrowing 只在找到 post-fixpoint 后进行，最终再次验证。预算耗尽结果没有该保证。
