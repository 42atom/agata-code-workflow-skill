---
name: agata-code-workflow
description: Use when the user wants to create, update, review, or validate Agata-style file-based workflow artifacts such as task files, plan files, research files, review threads, operator checklists, or coauthors.csv. Also use it for ordinary project documentation in repos that follow this workflow, so docs stay aligned with the same truth-source boundaries. Covers task-first naming, filename-based state transitions, issue/review separation, review round naming, adjacent project docs, and minimal workflow discipline for local Git-based collaboration.
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
- write or revise ordinary project docs without creating a parallel workflow system
- generate a read-only progress board when the user asks to see current project status
- start implementation in a dedicated `git worktree` for the current task
- judge whether a worktree is clean, single-task dirty, or contaminated by another task line
- run review or verification in an isolated `git worktree` when collaboration would otherwise collide
- recover `tk` / `pl` / `rp` truth that may be stranded in another local branch or worktree
- close each finished round with a fixed next-step marker line

Do not invent a second state system. The filename state slot is the truth source.

## Core Rules

1. `issues/` is the task truth source.
2. `tk` carries state. `rp` carries review evidence.
3. `pl` is for discussion/spec. `rs` is for research. `tk` is the executable issue.
4. Review files are task-first and round-based: `review-rN` / `reply-rN`.
5. `commit` and `branch` are implementation trace, not task truth.
6. `coauthors.csv` is only dispatch context, never task state.
7. Ordinary docs may live outside `issues/`, but they must not redefine workflow state, task truth, or review truth.

## Workflow

1. Read existing `issues/` and related review files before creating anything new.
2. Choose the file kind by phase:
   - discussion not settled -> `pl`
   - fact-finding or feasibility -> `rs`
   - scoped and executable -> `tk`
   - review exchange -> `rp`
3. Default to one agent pushing the mainline end-to-end. Do not split work into extra rounds unless the next step is truly blocked by review, user decision, risk confirmation, missing evidence, or a real role handoff.
4. Default to one active task line in one dedicated worktree.
5. The shared root checkout is the workflow control plane. Workflow truth files under `issues/`, `docs/reviews/`, `refs/project-memory-aaak.md`, and `coauthors.csv` must be created and updated there.
6. `doi` claims task ownership, and the `tdo -> doi` move must happen on that shared control plane before implementation starts anywhere else.
7. Dedicated task worktrees are execution sites for code, tests, generated files, and temporary drafts. They must not become a second workflow control plane.
8. After the control-plane state is visible in the shared checkout, implementation may proceed in that task's dedicated worktree.
9. A dirty worktree is allowed when all changes belong to the current task line.
10. If unrelated modified or untracked files appear in the current worktree, treat it as contamination and stop stacking work there.
11. Switching tasks means switching worktrees, not continuing in the current dirty checkout.
12. Review may use a separate review worktree for audit or verification, but authoritative `tk` / `rp` updates still return to the shared control plane.
13. Reuse the same task worktree while the same task is still active. When the task closes into `dne` / `cand` / `arvd` and all related changes are landed, remove that worktree. `bkd` may keep the worktree frozen, but do not mix another task into it.
14. Preserve id-first naming and keep the filename slots stable except for state.
15. When a task moves state, rename the existing `tk` file; do not create a parallel file.
16. When review happens, create new `rp` files; do not encode reply chains as `re.` or `re.re.`.
17. `rp` records are append-style evidence. Once created, treat them as frozen and prefer `dne`.
18. In `tk.links`, prefer stable `rpNNNN` / `rpNNNNN` anchors over stateful review filenames.
19. Before moving a code task to `rvw`, confirm it has non-empty `accept`, `code_version`, `verify`, and at least one linked `rp`.
20. `refs/project-memory-aaak.md` is historical memory, not task truth. Memory-gated tasks must anchor there as `锚: tkNNNN` / `锚：tkNNNN` or `锚: tkNNNNN` / `锚：tkNNNNN`.
21. Keep any helper automation thin. Scripts may validate and rename files, but must not become a second control plane.
22. `pl` and any `tdo` document are shared pending truth. Do not leave them only in a disposable task worktree or snapshot branch.
23. Before deleting a worktree or dropping a local snapshot branch, run `task.sh orphan-scan <base-ref>`. If it reports truth drift under `issues/`, `docs/reviews/`, or `refs/project-memory-aaak.md`, land or hand off that truth first.
24. If memory, review, or git history mentions a `tk` / `pl` / `rs` / `rf` / `rp` id that the current truth source cannot find, first run `task.sh orphan-scan <base-ref> <id>` and then trace git history before concluding the file is gone.
25. A linked task worktree must not directly edit files under `issues/`, `docs/reviews/`, `refs/project-memory-aaak.md`, or `coauthors.csv`. Draft related notes elsewhere, then land the authoritative update from the shared control plane.
26. Create new workflow ids through `task.sh new` on the shared control plane instead of scanning `max(id)+1` by hand in parallel shells.
27. `task.sh move <id> doi` stamps `claimed_at`. `task.sh check` warns on missing or stale `doi` claims so zombie locks surface without adding a second lock system.
28. Worktree teardown is a control-plane reconciliation step. Only prune after the task is already closed into `dne` / `cand` / `arvd`, workflow truth is clean, and the linked worktree no longer carries execution-only diff versus the chosen base ref.
29. `doi` and `bkd` are not prune targets. `doi` must be released first; `bkd` keeps a frozen worktree unless the control plane explicitly changes direction.
30. In a linked worktree, local `issues/`, `docs/reviews/`, `refs/project-memory-aaak.md`, and `coauthors.csv` are only branch mirrors. They are not the authoritative truth view.
31. Workflow helpers should read and write truth through the shared control plane by default. `check` only keeps the current-worktree view for truth-pollution checks; every global workflow semantic check still reads from the control plane. `orphan-scan` still inspects the current worktree while comparing against shared refs.
32. `prune` must not remove the worktree that contains the current shell cwd. If you are standing in the target worktree, `cd` out first.

## Bundled Script

If the user asks for workflow automation, use `scripts/task.sh` first.
Resolve bundled helper paths relative to this `SKILL.md` file's directory. Do not search for `task.sh` under the current project, and do not assume `./scripts/task.sh` exists there.

Current commands:

- `task.sh new <kind> <board> <slug> [prio]`
- `task.sh ls [state]`
- `task.sh find <id>`
- `task.sh show <task-id>`
- `task.sh move <task-id> <state>`
- `task.sh archive <task-id>`
- `task.sh prune <task-id> <base-ref>`
- `task.sh check`
- `task.sh orphan-scan <base-ref> [filter]`
- `progress_view.py [--project-root <path>] [--no-open]`

Use `task.sh` for legal rename flow, basic validation, archive moves, prune cleanup, and memory-gated close checks.
`task.sh ls`, `find`, `show`, `new`, `move`, `archive`, and `prune` may be called from a linked worktree, but they must resolve truth against the shared control plane instead of the local mirror paths.
Use `task.sh check` on the current worktree when you need to catch linked-worktree truth pollution or contamination. Its local view is only for that pollution guard; the rest of the workflow semantics still resolve against the control plane.
Use `task.sh orphan-scan` when you need current-worktree truth drift plus shared-ref comparison before cleanup or recovery.
Use `task.sh prune <task-id> <base-ref>` when a dedicated task worktree is ready to die. It re-checks workflow truth, blocks `doi` / `bkd`, and only removes a single linked worktree whose execution diff is already drained against the chosen base ref. It also refuses to delete the worktree that contains the current shell cwd.
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

Read `references/project-docs.md` when the user is writing or revising ordinary project docs such as:

- `README`
- architecture notes
- runbooks
- usage docs
- handoff / delivery notes
- module-local design notes that are not workflow truth

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
- creating a new workflow doc id without racing another shell
- checking whether workflow truth is stranded in another local branch or worktree
- writing or revising a non-workflow project doc in an Agata repo
- compressing a long task body into a stable summary block
- drafting project memory in dense structured prose

## Output Discipline

- Prefer modifying the existing truth-source file over creating a new explanatory document.
- Workflow truth edits belong on the shared root checkout control plane, even if implementation is happening in another worktree.
- If a linked worktree needs to write task notes or review drafts, keep them outside the truth-source paths until they are ready to land on the control plane.
- For ordinary docs, prefer updating the canonical doc instead of creating a parallel note with overlapping scope.
- If a new review artifact is needed, make it task-first and minimal.
- If a request can be answered by renaming an existing file, do that instead of adding a layer.
- If the user asks for automation, start with a thin shell entrypoint, not a platform.
- Do not place ordinary project docs under workflow-only slots such as `pl` / `rs` just to make them look tracked.
- For worktree status questions, answer with a three-state verdict first: `clean`, `single-task dirty, can continue`, or `contaminated, must split`.
- When a phase or round is finished, make the response's last line exactly one next-step marker:
  `[本轮完成，请求下一阶段：动作(文档落盘/实现/审阅/修复/通过/复审/提交/推送/合并与清理/需用户决策...)-目标(当前任务/单号/关键字)]`
  or
  `[本轮已完成(当前任务/单号/关键字)，阶段结束]`
- Treat that marker as a mainline pointer, not a stop signal. If the next action is still owned by the current agent and has no external blocker, continue directly instead of waiting for a new round.
