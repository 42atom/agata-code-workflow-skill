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
- 默认单 agent 直推主链；阶段标签用于表达进度，不是审批闸门

## 2. 真相源

真相源统一为：

- `issues/`

规则：

- 不再使用 `docs/plan/issues/` 这类历史路径
- `active-mainline.md` 只做导航，不承载状态
- 状态变更只改 `tk` 文件名，不靠正文或索引页
- 若目标项目要偏离这条真相路径，必须有项目级 `AGENTS.md` / `CLAUDE.md` 或当前控制面真相的明确证据；零散历史文件不足以推翻共享规则

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
- `dne`
- `bkd`
- `cand`
- `arvd`

规则：

- `id` 永远在最前
- `id` 支持 4 位或 5 位数字；现有 4 位文件无需迁移
- 同一项目内不允许裸数字碰撞；禁止 `tk0001` 与 `tk00001` 共存
- `board` 用模块短词或场景码
- `board` 不得使用 `tdo` / `doi` / `rvw` / `dne` / `bkd` / `cand` / `arvd` 这类状态保留词
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
- 新建 `pl` / `rs` / `tk` 时，不因为“顺手一起落盘”就提前写 memory；只有形成稳定里程碑、关键决策，或任务明确要求 `memory: required` 时才写

记忆锚点：

- 对带 `memory: required | done` 的任务，记忆文件必须显式写 `锚: tkNNNN` / `锚：tkNNNN` 或 `锚: tkNNNNN` / `锚：tkNNNNN`
- 只认稳定 id 锚点，不认正文里偶然出现一次的 task id

## 7. 状态与评审规则

任务主流状态：

`tdo -> doi -> rvw -> dne`

补充：

- 任意中间态可进 `bkd`
- 任意非终态可进 `cand`
- `dne` / `cand` 可选进 `arvd`

任务与评审分工：

- `tk` 负责状态推进
- `rp` 负责评审证据
- `rp` 不替代 `tk`
- `tk.links` 必须挂相关 `rp`
- `tk.links` 可挂具体 `rp` 文件，也可挂稳定 `rpNNNN` / `rpNNNNN` 锚点
- 默认优先挂稳定 `rp` 锚点，避免把 `rp` 的 state 槽写死进链接
- review 结论要回写到 `tk`

review 命名规则：

- 评审文档必须 task-first
- 禁止 `re.` / `re.re.` 链式命名
- 必须显式写轮次 `rN`
- `rp` 一经成文默认冻结，优先直接用 `dne`
- 新回合新增新文件，不回头改旧 `rp` 的状态槽

审核隔离规则：

- 审核时允许使用 `git worktree` 拉出独立工作目录，避免和实现中的工作区互相打架
- `worktree` 只是隔离执行环境，不是第二套任务真相源；状态、结论、往返记录仍回写 `tk` / `rp`
- 若该审核工作树对应的源码、锁文件或配置与主工作区不同，依赖安装、生成物和验证动作必须跟随该 `worktree`
- 不允许拿 A 工作树的依赖结果去替 B 工作树背书

工作树语义规则：

- 一个活跃 task 默认对应一个专属 worktree
- 主 checkout 是共享控制面；`issues/`、`docs/reviews/`、`refs/project-memory-aaak.md`、`coauthors.csv` 的真相改动都在这里发生
- linked worktree 里的这些 truth path 只是该分支镜像，不是权威真相视图
- linked task worktree 若需要写验证记录、review 草稿或实现笔记，先写在非真相路径；不得直接改上述真相路径里的正式文件
- `tdo -> doi`、`doi -> rvw|bkd|cand|dne`、`rp` 新建/回合推进、memory 锚点、派单更新都属于控制面动作，必须先在主 checkout 落盘
- 创建 `task/tkNNNN-*` 分支或对应 task worktree 前，`issues/` 里必须已存在同号 controlling `tk`；禁止先实现后补真相
- 创建 review 分支或 review worktree 前，必须已存在同号 controlling `tk` 与目标 review 轮次真相
- `doi` 落盘后，才在该 task 的专属 worktree 中推进实现
- task worktree 只做代码、测试、生成物和临时草稿，不偷偷改 workflow 状态槽，不把自己当第二控制面
- `task.sh ls` / `find` / `show` / `new` / `move` / `archive` / `prune` 默认穿透到共享控制面，不以当前 linked worktree 里的镜像 truth path 为准
- `task.sh check` 例外：只有“当前 worktree 有没有 truth 污染”这一刀留在本地；重复 id、review 约束、memory、staleness 等全局语义仍由共享控制面裁决
- `task.sh check` 通过只说明工作流语义合法，不说明当前共享控制面上的所有脏改都属于你
- 同一 task line 的控制面写操作必须串行；不得对同一 task 预发多个 `move`，每次状态落盘后都要重读真相与 gate，再决定下一跳
- `task.sh orphan-scan` 例外：它既看当前 worktree 的 truth 漂移，也看共享 refs 的差异
- 单任务 worktree 在执行中可以是脏的，这是正常态
- 进入 `rvw`、准备合并或 `prune` 前，必须相对目标 `base-ref` 检查真相漂移与执行差异；明显过期的 worktree 先对齐，再继续推进
- 同一 worktree 出现多个 task 的实现改动，或出现当前 task 之外的无关修改 / 未跟踪文件，视为污染
- 切任务 = 切 worktree，不继续复用当前脏树
- 平行 task worktree 默认双盲；一个 task worktree 不得直接依赖另一个 task worktree 的未落地代码、生成物、本地服务端口或数据库状态
- 跨 task 交付、协作或 review 邀请，必须先落成控制面可见的共享证据，再由接收方消费；禁止通过跨目录读取另一个 task worktree 走私中间态
- `rvw` / 复审可在独立 review worktree 中做验证，但 `tk` / `rp` 结论仍回主 checkout 落盘
- 代码任务收口顺序固定：专属 worktree 完成实现与验证 -> 代码并回目标主线 -> 主单推进到 `dne` -> 清理该任务的 worktree 与本地分支
- 同一 task 续做时复用原 worktree
- 任务进入 `dne` / `cand` / `arvd` 且已收口后，应移除对应 worktree；`bkd` 可保留 worktree 但冻结，不得混入别的 task
- worktree 收尾是控制面对执行面的最后一次对账，不是顺手删目录
- 优先用 `task.sh prune <task-id> <base-ref>` 收尾；它只做校验和回收，不代替控制面自动改状态
- `prune` 只接受 `dne` / `cand` / `arvd`；`doi` 必须先释放，`bkd` 默认保留冻结现场
- `prune` 前必须满足：主 checkout 的 `task.sh check` 通过、`task.sh orphan-scan <base-ref> <task-id>` 无漂移、目标 linked worktree 干净、且相对 `base-ref` 已无执行差异
- 禁止在“旧进程 + 新代码”混合运行态上给出验证结论；必须先退出旧进程，再在新构建/新运行态上验证
- `prune` 不得从目标 worktree 自己内部执行；若当前 shell cwd 落在待删 worktree 内，必须先 `cd` 出去
- `prune` 成功时同时回收 linked worktree 和对应本地 branch；默认不碰 remote branch
- worktree 只是执行空间，不是任务真相源

共享真相可达性规则：

- `pl` 与任何 `tdo` 态文档属于共享待排期真相，不允许只存在于临时 task worktree / snapshot branch
- 共享控制面上，`issues/`、`docs/reviews/`、`refs/project-memory-aaak.md`、`coauthors.csv` 的无关脏改，以及未跟踪 `tk` / `pl` / `rs` / `rf` / `rp` 文件，默认视为外来活动线，不叫“噪声”
- 判断外来活动线时，先看 task id、state、`claimed_at`、`claimed_by`、`claimed_thread_id`、links、相邻 review / memory 锚点，以及 `coauthors.csv`；没有证据前，不得擅自当成废稿或顺手并入当前提交
- 未经明确接管，不得删除、改名、暂存或提交外来活动线；当前提交只收自己的真相改动，别线单独报告
- 若某个 task worktree 中出现了只在本地可见的 `doi` / `rvw` / `rp` / memory 改动，视为控制面漂移；必须先收回主 checkout，再继续执行
- 清理 worktree / 删除快照分支前，必须先跑 `task.sh orphan-scan <base-ref>`；只要它报出 `issues/`、`docs/reviews/`、`refs/project-memory-aaak.md` 的漂移，就不能直接清理
- 若项目记忆、review 或 git 历史提到某个 `tk` / `pl` / `rs` / `rf` / `rp`，但当前真相源找不到，先跑 `task.sh orphan-scan <base-ref> <id>`，再用 `git log --all` / `git grep` 追溯；禁止直接假定它不存在

工作树状态判断：

- `干净`
- `单任务脏，可继续`
- `污染，必须切分`

例子：

- `rp0061.dne.runtime.review-r1-codex.md`
- `rp0061.dne.runtime.reply-r1-mobile007kx.md`
- `rp0061.dne.runtime.review-r2-codex.md`

## 8. rvw 入场门槛

代码任务进入 `rvw` 前，至少要有：

- `accept`
- `code_version`
- `verify`

没有这三项，不算真正进入 review。

补充：

- `accept` / `code_version` / `verify` 不能为空值
- `verify` 是验证口径或命令，不是“已测试”这类空话
- `verify` 可写成多行块，比如 `verify: |`
- `links` 可写成 inline 数组，也可写成缩进列表
- `rvw` 任务至少要挂一个有效 `rp` 证据链接

## 8.1 归档残留

规则：

- `arvd` 是终态，不应残留在 `issues/` 根目录
- 归档后的任务应位于 `issues/archive/YYYY/`
- `check` 发现根目录 `tk*.arvd.*.md` 时必须失败

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

## 9.1 发号与认领保活

规则：

- 新建 `tk` / `pl` / `rs` / `rf` / `rp` 时，优先走 `task.sh new`，由共享控制面统一分配下一个可用 id
- 不手工在并发 shell 里做 `max(id)+1` 发号
- `task.sh move <id> doi` 会写入 `claimed_at`、`claimed_by`，以及当前 runtime 能提供时的 `claimed_thread_id`
- `move` 是单步控制面动作，不是流水线；尤其 `rvw` / `dne` / `arvd` 这类带 gate 的状态，必须等上一步成功落盘并重读真相后再推进
- `task.sh check` 对缺失 `claimed_at` 或长时间未推进的 `doi` 发警告，不自动回滚、不新增旁路锁文件
- 当多个 agent 共享同一个引擎名（例如都叫 `codex`）时，`claimed_thread_id` 是主识别信号；`claimed_by` 只保留粗粒度身份
- `doi` 超时只触发接管检查，不触发自动回滚；接手前必须检查现场、跑 `task.sh orphan-scan <base-ref> <task-id>`，并在控制面显式改状态或交接

## 9.2 收尾回收

规则：

- `task.sh prune <task-id> <base-ref>` 是薄终结器，不是状态机；它不替你自动推进 `tk`
- 若任务仍在 `doi`，`prune` 必须失败，防止删除活跃认领
- 若任务在 `bkd`，`prune` 默认失败，防止误删冻结现场
- 若任务在 `dne` / `cand` / `arvd`，`prune` 仍要确认目标 linked worktree 已无未提交修改，且相对 `base-ref` 不再携带执行面独有差异
- `prune` 只处理单一明确绑定的 linked worktree；找不到或找到多个都应失败，不替操作者猜

## 10. 回合收口输出

当本轮形成可报告结果时，回答结尾最后一句给出下一步指向；这不自动意味着当前 agent 停止执行。只允许以下两种格式：

- `[本轮完成，下一阶段：动作(文档落盘/实现/审阅/修复/复审/通过/提交/合并与清理/推送/任务完成/需用户决策...)-目标(当前任务/单号/关键字)]`
- `[本轮已完成(当前任务/单号/关键字)，阶段结束]`

规则：

- 这句必须放在整段回复最后一行
- 这是主链指针，不是停止命令；若下一动作仍由当前 agent 可直接完成，当前 agent 继续推进，不因这句人为停下
- `动作` 只写一个当前主动作，保持短、硬、可执行
- `目标` 只写当前任务、单号或稳定关键字，不写长解释
- 收尾说明只写当前 task 的终态、证据和回收；不替整个 repo、全部 worktree 或别的任务下结论
- 清理结果只写“仅回收当前 task 绑定的 worktree / 本地分支”；不写“只剩根仓”“都清掉了”这类 repo 级表述
- 共享控制面上的别线统一叫“外来活动线”，不叫“噪声”或“无关脏改”
- 若任务已 `dne`，后续新增范围一律表述为“另开新 tk”，不回写已关闭任务
- 收尾前可选做一次“全场快速扫视”：先看控制面外来活动线，再看执行面 worktree，只报压缩结论，不展开全场明细
- “全场快速扫视”只报外来活动线的 `id/state`，以及外来 worktree 的数量或粗归属；默认明确写“均未接管”
- 只有遇到 `需用户决策`、权限阻塞、高风险确认、证据不足或真实责任切换时，才把它当作真正的停点或交接点
- 若仍需外部拍板，优先使用 `需用户决策`
- 若该阶段已真正收口且无需再推进，使用“阶段结束”格式

例子：

- `[本轮完成，下一阶段：实现-tk0061]`
- `[本轮完成，下一阶段：审阅-tk0061]`
- `[本轮完成，下一阶段：修复-rp0061]`
- `[本轮完成，下一阶段：提交-tk0061]`
- `[本轮完成，下一阶段：推送-tk0061]`
- `[本轮完成，下一阶段：需用户决策-支付降级方案]`
- `[本轮已完成(tk0061)，阶段结束]`
- `tk0061 已收口到 dne。task.sh find tk0061：只指向 dne；task.sh check：ok；task.sh prune tk0061 <base-ref>：ok，仅回收 tk0061 绑定的 worktree 与本地分支。根仓仍有外来活动线，未纳入本次提交。`
- `全场快速扫视：控制面另有 tk0138.doi、pl0046.rvw；执行面仍有 2 个外来 worktree，均未接管。`

## 11. 单任务示例

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
7. 人工关闭：任务文件改名 `tk0061.dne...`
