# agata-code-workflow 深度评审

评审人：Claude Opus 4.6 (1M)
日期：2026-04-11
评审范围：`agata-code-workflow/SKILL.md`、`references/workflow-rules.md`、`scripts/task.sh`、`scripts/progress_view.py`、`doc-sample/`、`tests/`

---

## 1. 总体评价

这是一套**克制感很强**的设计：把状态机压进文件名一个槽位、把真相源压进一个目录、把自动化压进一个 shell 脚本。它真正解决的不是"项目管理"，而是"多 Agent 协作时如何不让真相分裂"——做法是让真相**没地方分裂**。

但克制有代价。系统的健壮性几乎完全依赖三件事的同时成立：(1) 文件系统的原子重命名、(2) 单个 Agent 的串行操作、(3) 人类持续遵守命名公约。**任何一条松动，系统就从"自洽"退化成"看起来自洽"**——文件名仍然合法，但语义已经漂移。脚本里的 `check` 子命令是这套系统唯一的免疫系统，目前它能挡住一些低级错误，但拦不住"半迁移""幽灵副本""链接腐烂"这类更危险的状态。

总评：**设计哲学优秀，工程防线偏薄**。适合 1–3 人 + 几个 Agent 的小团队短周期使用；放到 5 人以上、跨周协作或频繁分支合并的场景下，会暴露出 B 类问题。

---

## 2. 设计亮点

1. **"文件名即状态"消灭了第二真相源**。索引页、看板、issue tracker 一个都不需要——这是绝大多数轻量项目管理系统做不到的克制。
2. **任务/评审的 kind 分离 (`tk` vs `rp`)** 优雅地解决了"PR 评论应该改 issue 还是另起新文档"这个老问题。`tk` 推进状态、`rp` 累积证据，职责干净。
3. **轮次显式 (`review-r1` / `reply-r1`)** 替代 `re.re.re.` 链式命名，是真正吃过亏才能想出来的设计。
4. **`pss` 与 `dne` 的机器态/人工态分层**，把"自动化通过"和"人类签收"分开，避免 CI 越权关闭任务。
5. **memory: required 的硬门禁**——`task.sh move ... dne` 在缺失锚点时直接 die，把"历史记忆"从软纪律变成硬约束，是这套系统里最像样的工程防线。
6. **`coauthors.csv` 明确不参与门禁**，只 warn 不 block，避免了"派单表过期 → 全员卡死"这类低级事故。
7. **archive 按年分桶 + `find_doc_file` 递归扫描**，让历史可达却不污染当期视图。`show` 用 `maxdepth 1`、`find` 不限深，这个深浅切分是有意识的好设计。

---

## 3. 阻断级问题（B）

### B-1：rp 文件名的 state 槽进入 `tk.links`，造成链接对状态变更脆弱

- **触发场景**：`tk0061.links` 写入 `docs/reviews/rp0061.dne.runtime.review-r1-codex.md`。某天 `rp0061` 的 state 槽被改名（例如从 `dne` 改成 `arvd` 或被纠错为 `bkd`）。
- **当前行为**：`check_tk_rp_links_exist` 用 `[[ -f "$normalized" ]]` 严格匹配整段路径，文件已经不在原路径上 → `die "missing rp link target"`。但这是 `check` 才会发现，平时移动是默默坏掉的。
- **影响**：rp 一旦"冻结"假设被打破（例如改了一个错别字 slug、或者被 archive），所有引用它的 tk 链接全部断裂。"`rp` 冻结"是文档约定不是机器约束，没人能保证。
- **修复建议**：
  1. `tk.links` 只存 **rp 的 id**（例如 `rp0061-review-r1` 或纯 `rp0061`），由脚本在校验时反查文件系统找到当前 state；
  2. 或者强制 link 字段使用 **state 通配符**（例如 `rp0061.*.runtime.review-r1-codex.md`），`check_tk_rp_links_exist` 用 glob 解析；
  3. 文档中明确"link 用稳定 id 段，不写 state 槽"。

### B-2：并发重命名无锁，Git rename/rename 冲突无人处理

- **触发场景**：Agent A 和 Agent B 同时在各自分支上执行 `task.sh move tk0061 rvw` 和 `task.sh move tk0061 bkd`。两个分支各自把文件改成不同名字，merge 时 Git 报 rename/rename 冲突。
- **当前行为**：脚本层面没有任何 lock、advisory file、或冲突预演。两次 `mv` 在不同 worktree 都会成功，因为它们对各自的工作树是合法的。冲突在 merge 时才爆出来，且 Git 默认无法自动解决——需要人手动判定哪个 state 才是真相。
- **影响**：在多 Agent 并发场景下，这是系统最容易翻车的地方。一旦发生，"文件名即真相"瞬间退化成"分支名 + 文件名"双真相，需要外部协议来收敛。更糟的情况：合并者随手 `git checkout --ours`，丢失另一边的语义。
- **修复建议**：
  1. 文档层加一条硬规矩——**任何 `tk` 状态变更必须发生在 main 分支上**，不在 feature 分支上改 state（feature 分支只改正文）；
  2. `task.sh move` 在执行前检查当前是否在 main/默认分支，不是就 die 或 warn；
  3. 长期方案：把 state 从文件名挪到一个**单文件状态台账**（例如 `issues/_state.tsv`，每行 `tkNNNN<TAB>state<TAB>updated_at`），文件名只保留 id+slug。这违背"文件名即状态"的初心，但能让 Git 三方合并起作用——属于哲学折中，留给作者自己权衡。

### B-3：`cmd_archive` 是两步操作，中间崩溃留下半迁移状态

- **触发场景**：`cmd_archive` 先 `rename_task_state ... arvd`（在 `issues/` 内重命名），再 `mv` 到 `issues/archive/$year/`。如果两步之间 shell 被 Ctrl-C、磁盘满、或 `mkdir -p` 失败，文件会停留在 `issues/tk0061.arvd.runtime.xxx.md`。
- **当前行为**：再次运行 `task.sh archive tk0061` **可以恢复**——`find_task_file` 仍能找到，state 已经是 `arvd` 所以跳过第一步，直接 `mv` 到 archive 目录。这条路径是工作的。但是：
  1. 如果用户没有意识到中断、不再运行 archive，那么 `tk*.arvd.*` 会出现在当期 `ls` 输出里，污染看板；
  2. `progress_view.py` 的 `ACTIVE_STATES` 不含 `arvd`，所以面板上不显示，但是 `cmd_ls` 会列出来；
  3. `check_rvw_fields` 等校验只针对 `tk*.rvw.*`，半迁移的 arvd 文件不会被任何校验抓到。
- **影响**：静默残留。系统没有一个"为什么这个 arvd 还在 issues 根目录"的探针。
- **修复建议**：
  1. `cmd_archive` 改成"先 mv 到 archive 目录，再在目标位置 rename 状态"（先把文件搬出当期目录，把"残留在 issues/ 的 arvd"变成不可能态）；
  2. 或者在 `cmd_check` 加一项 `check_arvd_residue`——`find issues/ -maxdepth 1 -name 'tk*.arvd.*.md'` 非空即 die；
  3. 把 archive 改成**不依赖中间状态**的单步操作（mv 时直接重命名为最终文件名）。

### B-4：YAML frontmatter 解析器是严格匹配，正文里偶然命中会误报

- **触发场景**：`check_rvw_fields` 用 `grep -q '^accept:'`，但 awk 的 `extract_frontmatter_scalar` 又只读 YAML 块。两者不一致：
  1. 任务正文里写一行 `accept: foo`（例如 markdown 引用一段 yaml 示例），`grep` 通过；
  2. 但 `extract_frontmatter_scalar` 读不到 frontmatter 里的真值，返回空；
  3. 紧接着 `[[ ! "$accept" =~ ^[[:space:]]*$ ]]` 失败 → die "empty accept"。
- **影响**：作者完全无法理解为什么校验失败——文件里明明有 `accept:`。
- **修复建议**：
  1. 把 `grep` 改成调用 `extract_frontmatter_scalar` 后判断非空一步到位，删掉 `grep` 这层；
  2. 或者把 `grep` 限定在 `awk '/^---$/{c++; next} c==1'` 提取的 frontmatter 段内；
  3. 顺便修一个隐患：`extract_frontmatter_scalar` 不支持 `key: |` 多行块、不支持 `key:\n  value`（嵌套缩进），有 `verify` 这种可能写多行命令的字段会失效。

### B-5：`links` 解析器对 YAML 缩进格式假设过窄

- **触发场景**：`extract_frontmatter_links` 只识别两种格式：(1) 内联 `links: [a, b]`、(2) 块格式且每项必须是 `^  - `（恰好两个空格）。如果作者写：
  ```yaml
  links:
    - rp0001....md   # 4 个空格
  ```
  或写在 `links:` 后没空行直接跟非空格内容，**整段 links 被静默丢弃**。
- **当前行为**：`task_has_rp_link` 返回 false → `check_rvw_fields` die "rvw task missing rp link"，但作者明明写了。或者更糟：`check_tk_rp_links_exist` 不去检查这些"看不见"的链接，链接断了也不报。
- **影响**：解析器的"宽容缺失"和校验的"严格存在"叠加，给出误导性错误。
- **修复建议**：把 frontmatter 解析换成真正的 YAML 解析（python 重写 task.sh 的 frontmatter 部分，或者调用 `python -c "import yaml; ..."`），并在文档中明确支持的缩进格式。

### B-6：4 位 / 5 位 id 共存导致 id 空间碰撞与重复检测失效

- **触发场景**：`tk0001` 和 `tk00001` 在 `check_duplicate_task_ids` 看来不是重复——它们 `cut -d. -f1` 的结果分别是 `tk0001` 和 `tk00001`，字符串不同。但人类会把它们当成"同一个任务的两次创建"。
- **当前行为**：`normalize_task_id` 接受 4 或 5 位但**不做规范化**——传入 `1` 会拼出 `tk1`，正则不通过 die。但传入 `00001` 和 `0001` 是两个完全不同的 id，脚本不警告。
- **影响**：随着 id 数量增长跨过 9999 → 10000 边界，团队会出现"双轨"id 习惯，未来检索/链接极易写错位数。
- **修复建议**：
  1. 在 `cmd_check` 加一项：扫描所有 id，把每个数字部分去掉前导零得到"裸数字"，按裸数字 group，发现两个 id 裸数字相同就 die；
  2. 或者一刀切——文档里规定"每个项目要么全 4 位要么全 5 位"，`task.sh check` 检测混用即 warn；
  3. 同时在 `find_task_file` 里加一个 fuzzy 警告：用户输入 `0001`，发现 `tk00001` 也存在，提醒确认。

---

## 4. 建议级问题（S）

### S-1：rp 是"冻结"但没有任何机器约束

文档说"`rp` 一经成文默认冻结"，但 `task.sh` 没有任何机制阻止 rp 被改名/改 state/改 slug。如果约定要靠纸面，B-1 这种链接腐烂就是必然。建议加一项 `check_rp_frozen`——通过 git log 或文件 mtime 检测 rp 文件是否被修改过（进入 `dne` 后），warn 即可。

### S-2：`pss → dne` 之外没有回退路径，pss 是死胡同

`can_transition` 里 `pss) [[ "$to" == "dne" ]]`——一旦机器判过 pss，发现问题想退回 doi 都不行。现实中"自动化通过但人工 review 又发现问题"很常见。建议加 `pss → doi` 和 `pss → bkd`。

### S-3：`memory: required` 在 `pss` 时不校验，到 `dne` 才校验

人工签收 dne 时才发现"忘了写记忆锚点"，此时 reviewer 已经准备关闭任务，被脚本拦回去要回头补 memory，体验割裂。建议在 `rvw → pss` 和 `doi → rvw` 节点也做一次 warn 级提醒（不阻断），让作者更早意识到。

### S-4：board 字段在 tk 与 rp 之间无一致性校验

review 规则提到"`board` 必须和任务文件第三槽一致"（针对 commit），但 rp 文件之间、tk 与 rp 之间不强制。`tk0061.runtime.*` 链了 `rp0061.frontend.*` 不会报错。建议 `check_rp_names` 顺便比对该 rp 是否被任何同 board 的 tk 引用。

### S-5：`coauthors.csv` 用朴素 `IFS=,` 解析，逗号字段会断裂

如果 `note` 字段含逗号（"on call, escalate to ops"），整行被切错，`status` 取到错误列。建议改成 `python -c` 或 `awk -F','` 但配合 quoted-field 处理，或者干脆禁止 note 字段含逗号并在 check 时报警。

### S-6：`task.sh check` 在 doc-sample 之外没有 CI 钩子

这套校验只在用户主动跑 `task.sh check` 时执行。建议在 README 给出一个 5 行的 git pre-commit hook 模板（拦 commit 时跑 `task.sh check`），让校验从"自觉"变成"默认"。

### S-7：archive 跨年后，`task.sh ls` 看不到任何归档信息

`cmd_ls` 只看 `issues/` 顶层，跨年归档完全在视野外。建议加 `task.sh ls --archived [year]` 一行命令。

### S-8：`find_project_root` 用 `issues/` 存在性识别根目录，嵌套场景可能误判

如果用户在 monorepo 里某个子项目 cd 进去，向上找到的第一个 `issues/` 不一定是当前模块的——可能是父项目的。建议同时检查 `issues/` 是否包含至少一个 `tk*.md`，或者要求一个显式 marker（`.agata-root` 之类的空文件）。

### S-9：`assert_memory_gate_for_close` 只在 `move` 走脚本时生效

如果用户绕过脚本直接 `git mv tk0001.pss.x.md tk0001.dne.x.md`，没有任何拦截。`cmd_check` 也只是事后 warn。这是"脚本不是真理执行者，只是助手"的设计代价，无法根治，但建议在 README 显著位置写明"绕过脚本会破坏 memory gate"。

### S-10：memory 锚点解析器不容忍全角符号

`awk '/^锚:[[:space:]]*/'` 只识别半角冒号。中文用户极易输入"锚："（全角冒号）→ 解析失败 → "missing memory anchor"。修复是一行：`/^锚[:：][[:space:]]*/`。

---

## 5. 观察项（O）

- **O-1**：`STATE_ORDER` 在 `progress_view.py` 把 `tdo` 排在 `bkd` 之后、又把 `pss` 排在 `dne` 之前——和 `workflow-rules.md` 里 `tdo → doi → rvw → pss → dne` 的语义流不一致。展示侧的"重要度排序"和文档的"流程顺序"是两个语义，建议在代码注释里明确"这是面板权重不是状态机顺序"，避免后人改坏。
- **O-2**：`STATE_TONE = {"cand": "cancelled"}` 但 `STATE_LABEL` 是 "已取消"——`cand` 在文档里是 "candidate"（候选），是把任务挂起备查的态，而 progress view 把它显示为"已取消"。语义漂移，需要团队对齐。
- **O-3**：`tests/task.sh` 里有些测试断言依赖 `mktemp -d` 的目录格式和 BSD/GNU date 行为，跨平台跑可能脆。
- **O-4**：`task.sh` 没有 `--dry-run`，所有 mv 立即生效。复杂操作（archive）建议加预演模式。
- **O-5**：所有校验都是 fail-fast (`die`)，第一个错误就退出。`cmd_check` 应该收集所有错误一次性输出，不然修一个跑一次很折磨。
- **O-6**：`SKILL.md` 描述里"Use this skill when work touches the file-based workflow itself" 没有显式触发示例，Agent 可能不知道何时调用。建议补 1-2 个"用户说了什么 → 调用此 skill"的样例。
- **O-7**：没有 `tk` 之间互相依赖（blocked-by / depends-on）的表达——多 Agent 并行时没法说"等 tk0001 done 才能起 tk0002"。可能是有意保持简单。
- **O-8**：`progress_view.py` 是只读 HTML，但模板里若引用了外部资源可能被浏览器拦。值得在 README 写明"完全离线"。

---

## 6. 推演场景清单

| # | 假设 | 推演结果 | 严重度 |
|---|------|---------|--------|
| 1 | 两个 Agent 在不同分支同时 `task.sh move tk0061 ...` | merge 时 Git rename/rename 冲突，无机器级仲裁 | **B (B-2)** |
| 2 | `cmd_archive` 在 `mv` 之间被 Ctrl-C | 残留 `tk*.arvd.*` 在 `issues/` 顶层，不会被任何校验抓到 | **B (B-3)** |
| 3 | `rp0061` 因纠错改 slug，从 `review-r1-codex.md` 改成 `review-r1-claude.md` | tk.links 全部断链，`check` 报 missing | B (B-1) |
| 4 | 链接写错路径：`docs/review/rp0061...`（漏 s） | `normalize_link_target` 拼成 `$root/docs/review/...`，`-f` 测试失败，`check` die ✓ | 校验有效 |
| 5 | id 写成 `tk00001`，已存在 `tk0001` | `check_duplicate_task_ids` 不报错；视为两个任务 | B (B-6) |
| 6 | `memory: required` 但 `refs/project-memory-aaak.md` 没写锚 | `task.sh move tk0001 dne` die ✓ | 防线有效 |
| 7 | 用户用全角冒号 `锚：tk0001` | 校验认不出 → "missing memory anchor"，但文件里明明有 | S-10 |
| 8 | 用户跳过脚本，`git mv` 直接改 state 槽 | 任何门禁都失效，状态机空转 | S-9 |
| 9 | rp 文件被人误删 | `check_tk_rp_links_exist` 死的链接会被抓 ✓ | 防线有效 |
| 10 | YAML links 用 4 空格缩进 | 解析器静默丢失整段 links → "missing rp link"，但作者明明写了 | B-5 |
| 11 | 正文里写了一行 `accept: example`（markdown 示例） | `grep` 通过，`extract_frontmatter_scalar` 取空 → die "empty accept" 但用户看不懂 | B-4 |
| 12 | `pss` 后又被 reviewer 发现致命问题想回 doi | 不允许，pss 是单向死胡同 | S-2 |
| 13 | 跨年 archive 后，老任务消失在 `task.sh ls` | 老任务不可见，`find` 还能找，但用户体验断裂 | S-7 |
| 14 | `verify` 字段写成多行 `verify: \|\n  pytest tests/...` | `extract_frontmatter_scalar` 不支持 block 标量，取空 → die | B-4 (扩展) |
| 15 | `coauthors.csv` 的 note 含逗号 | `IFS=,` 切错列，status 误判 | S-5 |
| 16 | 半迁移后 `cmd_check` 跑过 | 不会报半迁移 arvd 残留 | B-3 |
| 17 | `tk` 和 `rp` 用了不同 board | 静默通过 | S-4 |
| 18 | 用户在 monorepo 子目录 cd 后跑 `task.sh ls` | 可能命中错误的父级 `issues/` | S-8 |
| 19 | 大批量 check 失败 | 第一个错就 die，调试体验差 | O-5 |
| 20 | rp 在标记 dne 后被人手动改正文 | 没有任何"冻结"约束 | S-1 |

---

## 7. 与最佳实践对比

### 与 Anthropic *Building Effective Agents*

Anthropic 的核心建议是：
1. **Workflow ≠ Agent**：用预定义的工作流而不是让 LLM 自由决策；
2. **每一步都可观察、可回滚**；
3. **尽可能少的状态、尽可能扁平的结构**；
4. **强调真相单一源**。

对比：
- ✅ **真相单一源**：agata 把这一条做到了极致，比绝大多数实践都激进；
- ✅ **预定义工作流**：状态机白纸黑字写在 `can_transition`；
- ⚠️ **可观察**：`progress_view.py` 提供只读视图，及格；缺少"事件流"——状态变更没有 audit log，谁在何时把 `tk0061` 从 `doi` 改到 `rvw`，靠 git log 反查（间接）；
- ❌ **可回滚**：`pss → ?` 死胡同（S-2），rename 操作没有 dry-run（O-4），半迁移无探针（B-3）——回滚能力较弱。

**建议**：增加一个 `task.sh log <id>`，从 git 历史重建该任务的状态变更时间线，作为最低成本的 audit 层。

### 与 ChatDev

ChatDev 的关键洞察是 **"Communicative Dehallucination"**：让 Agent 之间通过结构化消息互相纠错。它的通信结构是有 schema 的（指令/反馈/确认）。

对比：
- agata 的 `rp` 文件其实就是结构化通信，`review-rN` / `reply-rN` 已经把"轮次"显式化了，比 ChatDev 的会话历史更可追溯；
- 但 agata 没有"指令类型"——每个 rp 是一篇自由文档，无法机器解析"这次 review 是 ASK / NACK / ACK / BLOCK"；
- **建议**：在 rp frontmatter 加一个 `verdict: ask|nack|ack|block` 字段，`task.sh check` 用它做 rvw 入场判定（"至少一个 ack 才能 rvw → pss"）。

### 与 OpenHands / SWE-agent

这类系统强调 **action-observation 循环 + 工具受限**。它们用 sandbox 限制 Agent 能改什么文件。

对比：
- agata 没有沙箱概念——任何 Agent 都能改任何文件，依赖文件名公约自律；
- 这是设计选择（轻量、本地、无服务），不是缺陷；
- **建议**：在 README 加一段"信任模型"声明——"本系统假设所有 Agent 都遵守命名公约，不防御恶意 Agent"。让用户知道边界。

### 与 Linear / GitHub Issues 这类传统系统

agata 的反传统在于：**它没有 unique id 服务**。Linear 用数据库保证 id 单调，agata 靠人手分配。这是 B-6 的根因。

- **建议**：`task.sh new <kind> <board> <slug>` 子命令，自动扫描已用 id 取下一个（4 位空间满了就转 5 位），消灭 id 碰撞和位数混用。这是这套系统目前**最大的缺失工具**。

---

## 总结

agata 的设计在哲学层面非常清晰：**"让真相没有藏身之处"**。它用最少的机制取得了相当多的纪律——这是高品味的设计。

但任何把约定当机制的系统，都需要一个强壮的"免疫系统"来兜住人和并发的不确定性。当前的 `task.sh check` 是这套免疫系统的雏形，覆盖了基础病灶，但对 **链接腐烂 (B-1)**、**并发冲突 (B-2)**、**半迁移 (B-3)**、**解析器与校验器不一致 (B-4/B-5)**、**id 空间漂移 (B-6)** 这五类深层问题没有防线。

如果只能修一个，建议优先 **B-2（并发约束）**：哪怕只是在文档里加一条"state 变更必须在 main 分支上发生"，也能挡住 80% 的多 Agent 翻车。

如果只能加一个工具，建议加 **`task.sh new`**，从源头解决 id 碰撞和位数混用。

设计是好的，再加一道工程防线，这套系统就能从"概念验证"升级到"可托付的生产工作流"。

---
*评审完毕*
*阶段：vibe / 评审*
*任务：审阅 agata-code-workflow-skill 项目*
*模型：claude-opus-4-6[1m]*
