### coder workflow rule

## 1. 主链

工作流只认三条主链：

- 研究 -> Plan -> 实现 -> 验证 -> 关闭
- Bug -> 理解 -> 分析 -> 计划 -> 修复 -> 验证
- 派单 -> Plan -> 拆分 -> 派发 -> 跟踪 -> 验收

原则：

- 不新增无职责文件
- 不让索引页承载状态真相
- 文件名状态槽是唯一状态真相源

## 2. 真相源

真相源统一为：

- `issues/`

规则：

- 不再使用 `docs/plan/issues/` 这类历史路径
- `active-mainline.md` 只做导航，不承载状态
- 状态变更只改 `tk` 文件名，不靠正文或索引页

## 3. 文档命名

统一格式：

`<kind><id-NNNN|NNNNN>.<state>.<board>.<slug>[.<prio>].md`

kind：

- `tk` = task
- `rs` = research
- `rf` = ref
- `rp` = report / review record
- `pl` = plan

state：

- `tdo`
- `doi`
- `rvw`
- `pss`
- `dne`
- `bkd`
- `cand`
- `arvd`

规则：

- `id` 永远在最前
- `id` 支持 4 位或 5 位数字；现有 4 位文件无需迁移
- `board` 用模块短词或场景码
- `slug` 只允许 `[a-z0-9-]`
- owner / 时间 / 原因进 front matter，不进文件名

## 4. 语义映射

- `pl` = 需求讨论 / spec / proposal
- `rs` = 调研 / 事实收集 / 可行性分析
- `tk` = 正式执行任务，等价于 issue
- `rp` = 评审记录，等价于 PR review thread
- `commit / branch` = 实现轨迹，不承载任务状态真相

规则：

- 需求未收敛，先落 `pl`
- 需要摸底验证，落 `rs`
- 范围和验收清楚后，才创建 `tk`
- review 讨论、阻断点、回合往返，都落 `rp`

## 5. 协作者名录

允许在仓库根目录放：

- `coauthors.csv`

它的职责只有一个：

- 提供派单参考，不承载任务状态

最小表头：

```csv
handle,owner,engine,role,status,updated_at,note
```

规则：

- `status` 只用 `online` / `offline`
- `status` 只作参考，不作自动化门禁
- 长时间未更新的状态视为不可靠
- helper `check` 可对 stale online 行报警，但不阻断流程

## 6. 历史记忆层

允许在仓库内放：

- `refs/project-memory-aaak.md`

它的职责只有一个：

- 承载低噪声、高密度的项目历史记忆

规则：

- 它是历史入口，不是任务状态真相
- 与当前状态冲突时，以 `issues/` 与证据链为准
- 只记里程碑、关键决策、流程迁移、冻结节点、关键阻断
- 不记逐条流水账，不替代 `tk` / `rp`

最小 front matter 扩展：

- `memory: none | required | done`

语义：

- `none` = 不要求进入项目历史记忆
- `required` = 关闭前必须写入 `refs/project-memory-aaak.md`
- `done` = 已写入项目历史记忆，且记忆文件必须能回指该任务

记忆锚点：

- 对带 `memory: required | done` 的任务，记忆文件必须显式写 `锚: tkNNNN` 或 `锚: tkNNNNN`
- 只认稳定 id 锚点，不认正文里偶然出现一次的 task id

## 7. 状态与评审规则

任务主流状态：

`tdo -> doi -> rvw -> pss -> dne`

补充：

- 任意中间态可进 `bkd`
- 任意非终态可进 `cand`
- `dne` / `cand` 可选进 `arvd`

任务与评审分工：

- `tk` 负责状态推进
- `rp` 负责评审证据
- `rp` 不替代 `tk`
- `tk.links` 必须挂相关 `rp`
- review 结论要回写到 `tk`

review 命名规则：

- 评审文档必须 task-first
- 禁止 `re.` / `re.re.` 链式命名
- 必须显式写轮次 `rN`
- `rp` 一经成文默认冻结，优先直接用 `dne`
- 新回合新增新文件，不回头改旧 `rp` 的状态槽

例子：

- `rp0061.dne.runtime.review-r1-codex.md`
- `rp0061.dne.runtime.reply-r1-mobile007kx.md`
- `rp0061.dne.runtime.review-r2-codex.md`

`pss` 定位：

- `pss` 是机器态，不是人工终态
- 人工关闭结论仍以 `dne` 为准

## 8. rvw 入场门槛

代码任务进入 `rvw` 前，至少要有：

- `accept`
- `code_version`
- `verify`

没有这三项，不算真正进入 review。

补充：

- `accept` / `code_version` / `verify` 不能为空值
- `verify` 是验证口径或命令，不是“已测试”这类空话
- `rvw` 任务至少要挂一个有效 `rp` 证据链接

## 9. 提交规范

commit：

`{action}({board}): {slug}  [tkNNNN]` 或 `{action}({board}): {slug}  [tkNNNNN]`

branch：

`{state}/{tkNNNN}-{slug}` 或 `{state}/{tkNNNNN}-{slug}`

action：

- `feat`
- `fix`
- `refactor`
- `test`
- `plan`
- `pass`
- `report`
- `proto`
- `docs`
- `chore`

规则：

- 有 task 就必须带 `[tkNNNN]` 或 `[tkNNNNN]`
- `board` 必须和任务文件第三槽一致
- 需要验收时在 commit body 追加 `Reviewed-by`

## 10. 单任务示例

目录：

```text
coauthors.csv

issues/
  tk0061.doi.runtime.daily-production-stats-log.p1.md

docs/reviews/
  rp0061.dne.runtime.review-r1-codex.md
  rp0061.dne.runtime.reply-r1-mobile007kx.md
  rp0061.dne.runtime.review-r2-codex.md

refs/
  project-memory-aaak.md

docs/
  operator-checklist-tk0061.md
```

流转：

1. 建任务：`tk0061.tdo...`
2. 开做：`tk0061.doi...`
3. 首轮评审：新增 `rp0061.dne.runtime.review-r1-codex.md`
4. 回复评审：新增 `rp0061.dne.runtime.reply-r1-mobile007kx.md`
5. 二轮评审：新增 `rp0061.dne.runtime.review-r2-codex.md`
6. 进入 review：任务文件改名 `tk0061.rvw...`
7. 验证通过：任务文件改名 `tk0061.pss...`
8. 人工关闭：任务文件改名 `tk0061.dne...`
