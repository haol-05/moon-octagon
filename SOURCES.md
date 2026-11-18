# 来源、GitHub 与 Mooncakes 有限查重

检索日期：**2026-11-18，Asia/Shanghai**。结论：在以下有限范围内，**未发现相同的 MoonBit 整数八边形抽象域核心**。现有生态已经覆盖静态分析、整数关系推理、线性求解、STN 和区间 widening 等相邻能力，因此不能说“约束分析是空白”，也不能承诺全网零重叠或官方一定过审。

## 实际检索范围

### Mooncakes

请求 `https://mooncakes.io/api/v0/modules?limit=10000&offset=0`，首次超时、重试 HTTP 200，返回 **3844 个模块**。按 name、description、keywords 筛选：octagon / octagonal / abstract interpretation / relational abstract domain / strong closure / tight closure / difference bound matrix / numerical invariant / static analysis / constraint / 八边形 / 抽象解释 / 不变量。不是逐行阅读所有包，也不认为元数据没有关键词就代表源码一定没有功能。

### GitHub 仓库和 README

使用 GitHub REST 仓库搜索，保存每个响应、状态码、URL 与命中：

- `"octagon" moonbit`、`"abstract interpretation" moonbit`、`"difference bound" moonbit`、`"polyhedra" moonbit`：各 0 个仓库命中。
- `octagon language:MoonBit in:readme`、`"strong closure" moonbit in:readme`、`"tight closure" moonbit in:readme`、`"difference bound matrix" moonbit in:readme`、`"relational abstract domain" moonbit in:readme`、`"八边形" moonbit in:readme`：各 0 个命中。
- 搜索其他候选方向时真实发现 MoonFault、MoonPetri、MoonBelief、MoonSTN、MoonOT、MoonConformal 等项目，相关方向已排除。GitHub 一次未认证查询发生 403 限流，记录为失败，不当作无结果。

### GitHub 代码

通过本机 GitHub CLI 的 `gh search code` 实际搜索公开 MoonBit 文件，保存返回的 repo/path/blob URL（含当时内容 ref）：

| 查询（均带 language:moonbit） | 返回 | 后续处理 |
| --- | --- | --- |
| octagon、Octagon | 各 64 个文件，同一批结果 | 按 URL 去重，**逐个读取全部 64 个文件**；均 HTTP 200。命中为图形/文档形状、模型顶点、Unicode 字符名、测试字样，未发现抽象域核心 |
| tight_closure、strong_closure、difference_bound | 各 0 | 不把空结果解释为全网证明 |
| octagonal | 8 | 几何及字符相关文件，补充源码读取 |
| tightClosure、OctagonDomain | 各 0 | 另查 CamelCase 命名 |
| dbm | 达到设置的 100 条返回上限 | 宽泛结果包含 dBm、数据库、编码数据等；没有声称完整检查此关键词所有命中 |
| dbm closure | 1 | `bobzhang/asciidoctor.mbt/pdf/rouge/matlab_keywords.mbt` 的语言关键字数据 |
| octagon widen | 2 | Office / OOXML 几何形状和文档元素 |
| octagonal constraint、difference_bound_matrix、strongly_closed | 各 0 | 更具体的补充查询 |

代码搜索依赖 GitHub 索引、语言识别、分词和默认分支，不覆盖私有项目、未索引内容、其他分支和未发布代码。仅列举关键词不足以保证没有其他命名方式实现同一能力。提交前应重新检索，并由赛事审核判断独立选题是否成立。

## 相邻项目源码核查与关系

下载以下公开仓库默认分支 ZIP，在 `.mbt` / `.mbti` / `.md` 中检查 octagon、tight closure、strong closure、difference bound matrix 等术语，同时阅读 README 与相关实现/API。默认分支和 pushed_at 在 `adjacent-audit.json` 保存；ZIP 是检索快照，不是上游源码依赖，不进入项目发布源码。

| 项目与证据 | 已覆盖能力 | 本项目新增对象及限制 |
| --- | --- | --- |
| [riantr/moonbit_static_analysis](https://github.com/riantr/moonbit_static_analysis)，master，检索时 pushed_at 2026-11-17T16:38:31Z；`src/flow/interval.mbt`、`interval_0529_test.mbt`、README | 真实的程序分析器；已有区间格、算术、widen/narrow、数据流和状态机检查。区间求值/不变量不是新概念 | 新交付是可复用的**多变量整数关系域**及完整紧闭包、signed-copy transfer、投影、八边形 join。场景相邻；没有复制其前端或声称它永久不支持关系分析。当前没有实现其宿主适配器或提交上游 PR |
| [NaIWaniubi/moonprove](https://github.com/NaIWaniubi/moonprove)，master，pushed_at 2026-11-10T13:05:33Z；README、`src/solver` 与公开源码 | 源程序/契约的符号执行，Fourier–Motzkin、区间反驳、边界搜索；证明、反例、unknown 与循环归纳 | 一般整数关系可表达相同数学输入，这是部分功能重叠。本库的核心输出是**可组合的规范抽象集合**，支持最佳八边形 join、forget 和 widening，不是换算法重写其语言与验证器；不宣称比它完整或替代它 |
| [sgy1023-crt/MoonCassowary](https://github.com/sgy1023-crt/MoonCassowary)，main，pushed_at 2026-09-30T10:54:12Z；README、源码/API | 连续线性约束、增量 tableau、软偏好与编辑变量，面向交互布局 | 相同不等式在实数上可输入，但输出目标不同。本库按整数语义处理奇偶不可行，提供抽象域格和状态变换；不复制 Kiwi/Cassowary、不提供布局优先级或最优解 |
| [JingLan0v0/MoonSTN](https://github.com/JingLan0v0/MoonSTN)，main，pushed_at 2026-11-18T05:54:00Z；README、公开源码 | 数值时间差约束闭包、负环、时窗、任务/资源顺序搜索与独立计划验证 | `x−y≤c` 与 DBM 基础有重叠。本库提供带符号双变量和整数 tight closure 的数值抽象域，不另写时序规划/排程；不会仅以多了正负号宣称整个时序能力原创 |
| [LMK-ai-nb/rootcover](https://github.com/LMK-ai-nb/RootCover)、本工作区 moon-verified-solve | 非线性区间/根包围、承包与有界搜索 | 同有“区间”，但实数非线性集合搜索不同于整数八边形状态变换；不复制求根或全局优化 |

另查当前工作区的图流、财务、物流、网络演算、日程审计等项目名称/核心交付，不从其中机械拆分项目。当前核心仅依赖官方 core，独立源码实现，不伪造基于上游扩展或维护者认可；有待评审确认的新生态价值是一个可被已有分析器接入的关系域组件，而不是“搜索不到所以独创”。

## 公开算法和许可证

- Antoine Miné, [The Octagon Abstract Domain](https://arxiv.org/abs/cs/0703084)，Higher-Order and Symbolic Computation 19 (2006)，定义八边形域、关系 transfer、投影与 widening。参考其公开定义，不复制论文正文、图或实现代码。
- Roberto Bagnara, Patricia M. Hill, Enea Zaffanella, [An Improved Tight Closure Algorithm for Integer Octagonal Constraints](https://arxiv.org/abs/0705.4618)，整数一致性与紧闭包定理的数学来源。独立实现，未把公开数学当作本项目发明。
- [APRON](https://github.com/antoinemine/apron) 的 Octagon manager 是其他语言生态中的成熟实现。这里不是 APRON 全量移植，也没有复制/翻译其源码；不把它的 LGPL 代码包含到 MIT 项目中。没有声称全球首次实现八边形域。
- [MoonBit core](https://github.com/moonbitlang/core)，官方工具链依赖，Apache-2.0；不内嵌 core 源码。模型、合成样例、测试与 Node 验证器由本项目独立编写；数据不含真实个人或业务资料。

## 证据位置

本机原始响应/源码快照：`D:\moonbit\contest-submission\research-faulttree-20261118`（最初从故障树候选开始，因此保留原目录名）。项目内 [docs/research-evidence.json](docs/research-evidence.json) 记录原始文件大小与 SHA-256；目录中有 GitHub 代码返回、逐文件命中行、全部模块元数据和相邻源码快照。该绝对路径只描述本地研究资料，不是用户需要安装的依赖。

没有覆盖的范围：所有未公开源码、全部仓库分支/维护计划、所有可能同义词和全部 3844 模块源码。后续生态变化与官方审查均可改变当前选题结论。
