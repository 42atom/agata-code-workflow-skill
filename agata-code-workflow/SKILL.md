---
name: agata-code-workflow
description: Use when the user wants to create, update, review, or validate Agata-style file-based workflow artifacts such as task files, plan files, research files, review threads, operator checklists, or coauthors.csv. Covers task-first naming, filename-based state transitions, issue/review separation, review round naming, and minimal workflow discipline for local Git-based collaboration.
---

# Agata Code Workflow

Use this skill when work touches the file-based workflow itself:

- create or rename `tk` / `pl` / `rs` / `rp` files
- decide where a new request should land
- review whether a workflow file is correctly named or placed
- convert loose review notes into task-first review records
- validate `rvw` readiness, review rounds, or `coauthors.csv`
- organize issue truth source and review evidence in a local Git repo
- write dense AAAK summaries for tasks, research, review, or project memory
- generate a read-only progress board when the user asks to see current project status
- start implementation in a dedicated `git worktree` for the current task
- judge whether a worktree is clean, single-task dirty, or contaminated by another task line
- run review or verification in an isolated `git worktree` when collaboration would otherwise collide
- close each finished round with a fixed next-step marker line

Do not invent a second state system. The filename state slot is the truth source.

## Core Rules

1. `issues/` is the task truth source.
2. `tk` carries state. `rp` carries review evidence.
3. `pl` is for discussion/spec. `rs` is for research. `tk` is the executable issue.
4. Review files are task-first and round-based: `review-rN` / `reply-rN`.
5. `commit` and `branch` are implementation trace, not task truth.
6. `coauthors.csv` is only dispatch context, never task state.

## Workflow

1. Read existing `issues/` and related review files before creating anything new.
2. Choose the file kind by phase:
   - discussion not settled -> `pl`
   - fact-finding or feasibility -> `rs`
   - scoped and executable -> `tk`
   - review exchange -> `rp`
3. Default to one agent pushing the mainline end-to-end. Do not split work into extra rounds unless the next step is truly blocked by review, user decision, risk confirmation, missing evidence, or a real role handoff.
4. Default to one active task line in one dedicated worktree.
5. `doi` claims task ownership, and implementation should proceed in a dedicated worktree for that task.
6. The shared root checkout is for reading, orchestration, and global checks. It is not the default implementation site.
7. The current task's `tk` and directly related `rp` records should be updated from that task's worktree instead of a separate shared checkout.
8. A dirty worktree is allowed when all changes belong to the current task line.
9. If unrelated modified or untracked files appear in the current worktree, treat it as contamination and stop stacking work there.
10. Switching tasks means switching worktrees, not continuing in the current dirty checkout.
11. Review should use a separate review worktree instead of reusing the implementation worktree.
12. Reuse the same task worktree while the same task is still active. When the task closes into `dne` / `cand` / `arvd` and all related changes are landed, remove that worktree. `bkd` may keep the worktree frozen, but do not mix another task into it.
13. Preserve id-first naming and keep the filename slots stable except for state.
14. When a task moves state, rename the existing `tk` file; do not create a parallel file.
15. When review happens, create new `rp` files; do not encode reply chains as `re.` or `re.re.`.
16. Reviewers may use an isolated `git worktree` for audit or verification to avoid colliding with active edits. A worktree is execution isolation only; task truth still lives in `tk` / `rp`.
17. If review runs in a separate worktree, dependencies and generated state must follow that worktree's own lockfiles and sources rather than a sibling checkout.
18. `rp` records are append-style evidence. Once created, treat them as frozen and prefer `dne`.
19. In `tk.links`, prefer stable `rpNNNN` / `rpNNNNN` anchors over stateful review filenames.
20. Before moving a code task to `rvw`, confirm it has non-empty `accept`, `code_version`, `verify`, and at least one linked `rp`.
21. `refs/project-memory-aaak.md` is historical memory, not task truth. Memory-gated tasks must anchor there as `锚: tkNNNN` / `锚：tkNNNN` or `锚: tkNNNNN` / `锚：tkNNNNN`.
22. Keep any helper automation thin. Scripts may validate and rename files, but must not become a second control plane.

## Bundled Script

If the user asks for workflow automation, use `scripts/task.sh` first.
Resolve bundled helper paths relative to this `SKILL.md` file's directory. Do not search for `task.sh` under the current project, and do not assume `./scripts/task.sh` exists there.

Current commands:

- `task.sh ls [state]`
- `task.sh find <id>`
- `task.sh show <task-id>`
- `task.sh move <task-id> <state>`
- `task.sh archive <task-id>`
- `task.sh check`
- `progress_view.py [--project-root <path>] [--no-open]`

Use `task.sh` for legal rename flow, basic validation, archive moves, and memory-gated close checks.
Use `progress_view.py` when the user wants a dense read-only HTML view of current workflow status and history.
Do not extend it into a scheduler, indexer, or ownership service unless the user explicitly asks.

## When To Read References

Read `references/workflow-rules.md` when you need exact naming, state, or semantic mapping details.

Read `references/aaak-zh.md` when the user wants high-density semantic compression, memory-style summaries, or protocol-like body blocks.

Read `references/aaak-profiles.md` when the user wants a workflow-specific AAAK profile for:

- `tk`
- `rs`
- `rp`
- project memory notes

Read `refs/project-memory-aaak.md` when:

- taking over an unfamiliar module
- answering "why did we do this"
- reviewing historical decisions or freeze points
- deciding whether a task must be written into long-term memory

Typical cases:

- creating a new workflow file
- deciding whether something belongs in `pl` or `tk`
- checking review round naming
- checking `rvw` entry requirements
- checking `coauthors.csv` shape
- compressing a long task body into a stable summary block
- drafting project memory in dense structured prose

## Output Discipline

- Prefer modifying the existing truth-source file over creating a new explanatory document.
- If a new review artifact is needed, make it task-first and minimal.
- If a request can be answered by renaming an existing file, do that instead of adding a layer.
- If the user asks for automation, start with a thin shell entrypoint, not a platform.
- For worktree status questions, answer with a three-state verdict first: `clean`, `single-task dirty, can continue`, or `contaminated, must split`.
- When a phase or round is finished, make the response's last line exactly one next-step marker:
  `[本轮完成，请求下一阶段：动作(文档落盘/实现/审阅/修复/通过/复审/提交/推送/需用户决策)-目标(当前任务/单号/关键字)]`
  or
  `[本轮已完成(当前任务/单号/关键字)，阶段结束]`
- Treat that marker as a mainline pointer, not a stop signal. If the next action is still owned by the current agent and has no external blocker, continue directly instead of waiting for a new round.
