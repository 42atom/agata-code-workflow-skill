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
5. When a compiled-app test, live repro, or runtime trace changes the understood root cause, task boundary, or ownership split, stop further implementation and update the controlling `tk` and any linked `rp` first. Do not continue coding on stale workflow truth.
6. During closure, keep exactly one controlling task line. Related tasks may be cited as dependencies, consumers, or historical anchors, but do not advance multiple overlapping `tk` lines in parallel.
7. The shared root checkout is the workflow control plane. Workflow truth files under `issues/`, `docs/reviews/`, `refs/project-memory-aaak.md`, and `coauthors.csv` must be created and updated there.
8. `doi` claims task ownership, and the `tdo -> doi` move must happen on that shared control plane before implementation starts anywhere else.
9. Dedicated task worktrees are execution sites for code, tests, generated files, and temporary drafts. They must not become a second workflow control plane.
10. After the control-plane state is visible in the shared checkout, implementation may proceed in that task's dedicated worktree.
11. A dirty worktree is allowed when all changes belong to the current task line.
12. If unrelated modified or untracked files appear in the current worktree, treat it as contamination and stop stacking work there.
13. Switching tasks means switching worktrees, not continuing in the current dirty checkout.
14. Review may use a separate review worktree for audit or verification, but authoritative `tk` / `rp` updates still return to the shared control plane.
15. Reuse the same task worktree while the same task is still active. When the task closes into `dne` / `cand` / `arvd` and all related changes are landed, remove that worktree. `bkd` may keep the worktree frozen, but do not mix another task into it.
16. Preserve id-first naming and keep the filename slots stable except for state.
17. When a task moves state, rename the existing `tk` file; do not create a parallel file.
18. When review happens, create new `rp` files; do not encode reply chains as `re.` or `re.re.`.
19. `rp` records are append-style evidence. Once created, treat them as frozen and prefer `dne`.
20. In `tk.links`, prefer stable `rpNNNN` / `rpNNNNN` anchors over stateful review filenames.
21. Before moving a code task to `rvw`, confirm it has non-empty `accept`, `code_version`, `verify`, and at least one linked `rp`.
22. `refs/project-memory-aaak.md` is historical memory, not task truth. Memory-gated tasks must anchor there as `锚: tkNNNN` / `锚：tkNNNN` or `锚: tkNNNNN` / `锚：tkNNNNN`.
23. Keep any helper automation thin. Scripts may validate and rename files, but must not become a second control plane.
24. `pl` and any `tdo` document are shared pending truth. Do not leave them only in a disposable task worktree or snapshot branch.
25. Before deleting a worktree or dropping a local snapshot branch, run `task.sh orphan-scan <base-ref>`. If it reports truth drift under `issues/`, `docs/reviews/`, or `refs/project-memory-aaak.md`, land or hand off that truth first.
26. If memory, review, or git history mentions a `tk` / `pl` / `rs` / `rf` / `rp` id that the current truth source cannot find, first run `task.sh orphan-scan <base-ref> <id>` and then trace git history before concluding the file is gone.
27. A linked task worktree must not directly edit files under `issues/`, `docs/reviews/`, `refs/project-memory-aaak.md`, or `coauthors.csv`. Draft related notes elsewhere, then land the authoritative update from the shared control plane.
28. Create new workflow ids through `task.sh new` on the shared control plane instead of scanning `max(id)+1` by hand in parallel shells.
29. `task.sh new` takes `<kind> <board> <slug> [prio]`. `board` is a module or scenario code, not a workflow state. New `pl` / `rs` / `rf` / `tk` docs start at `tdo`; new `rp` docs start at `dne`.
30. Do not infer a legacy truth path such as `docs/plan/` from stray old files. Only deviate from `issues/` when the target project has explicit local workflow rules or current control-plane truth that says so.
31. Do not write project memory just because you are creating a fresh `pl` / `rs` / `tk`. Memory is for stable milestones, key decisions, freeze points, or tasks that explicitly require `memory: required`.
32. `task.sh move <id> doi` stamps `claimed_at`, `claimed_by`, and, when the runtime exposes it, `claimed_thread_id`. In same-engine concurrency, thread id is the primary disambiguator.
33. Control-plane mutation on the same task line must be serial. Do not pre-issue multiple `move` commands for the same task; after each successful move, re-read the task truth and gates before deciding the next transition.
34. Worktree teardown is a control-plane reconciliation step. Only prune after the task is already closed into `dne` / `cand` / `arvd`, workflow truth is clean, and the linked worktree no longer carries execution-only diff versus the chosen base ref.
35. `doi` and `bkd` are not prune targets. `doi` must be released first; `bkd` keeps a frozen worktree unless the control plane explicitly changes direction.
36. In a linked worktree, local `issues/`, `docs/reviews/`, `refs/project-memory-aaak.md`, and `coauthors.csv` are only branch mirrors. They are not the authoritative truth view.
37. Workflow helpers should read and write truth through the shared control plane by default. `check` only keeps the current-worktree view for truth-pollution checks; every global workflow semantic check still reads from the control plane. `orphan-scan` still inspects the current worktree while comparing against shared refs.
38. `prune` must not remove the worktree that contains the current shell cwd. If you are standing in the target worktree, `cd` out first.
39. Dependency and runtime verification are worktree-local. If source, lockfile, or config differs from another checkout, install dependencies inside the current worktree before build/test.
40. For JS/TS worktrees, detect the package manager from lockfiles (`pnpm-lock.yaml` / `package-lock.json` / `yarn.lock`) and run deterministic install (`pnpm install --frozen-lockfile` / `npm ci` / `yarn install --frozen-lockfile`) before verification commands.
41. If verification fails because dependencies are missing or stale, stop and report it explicitly as dependency drift in the current worktree; do not borrow another worktree's install result or hide the failure.
42. Do not create a task branch or task worktree before the controlling `tk` exists in `issues/`. Do not implement first and backfill task truth later.
43. Do not create a review branch or review worktree before both the controlling `tk` and the intended review-round truth exist.
44. Close code tasks in this order: finish implementation and verification in the dedicated worktree, land code on the target mainline branch, move the controlling task to `dne`, then clean up that task's worktree and local branch.
45. Never conclude verification from a mixed runtime (old process + new code). Exit old processes first, then run verification on the new build/runtime only.

## Control-Plane Concurrency

- A passing `task.sh check` is a semantic verdict, not an ownership verdict. It does not mean every dirty truth file on the shared control plane belongs to your current task line.
- On the shared control plane, unrelated edits under `issues/`, `docs/reviews/`, `refs/project-memory-aaak.md`, or `coauthors.csv`, plus untracked `tk` / `pl` / `rs` / `rf` / `rp` files, are foreign active lines by default, not "noise".
- Before touching a foreign active line, inspect the task id, state, `claimed_at`, `claimed_by`, `claimed_thread_id`, links, nearby review or memory anchors, and `coauthors.csv` when present. Use those signals to decide whether someone else is actively landing truth.
- On the same task line, control-plane writes are serial by default. Do not pipeline `move` calls such as `doi -> rvw -> dne`; each step must land, then re-read truth and gates before the next step.
- Unless you are explicitly taking over, do not delete, rename, stage, or fold a foreign active line into your own commit. Commit only your own truth edits and report the other active line separately.

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
For `task.sh new`, remember: `board` is the third filename slot, not the state slot. The helper assigns the initial state itself: new `pl` / `rs` / `rf` / `tk` docs start as `tdo`, and new `rp` docs start as `dne`.
For `task.sh move <id> doi`, the helper stamps `claimed_at`, `claimed_by`, and, when available, `claimed_thread_id`. You can override the coarse claimant with `AGATA_CLAIMANT` and the thread marker with `AGATA_CLAIM_THREAD_ID`.
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
- diagnosing linked-worktree dependency drift before running build/test
- checking `coauthors.csv` shape
- creating a new workflow doc id without racing another shell
- checking whether workflow truth is stranded in another local branch or worktree
- writing or revising a non-workflow project doc in an Agata repo
- compressing a long task body into a stable summary block
- drafting project memory in dense structured prose

## Output Discipline

- Prefer modifying the existing truth-source file over creating a new explanatory document.
- Workflow truth edits belong on the shared root checkout control plane, even if implementation is happening in another worktree.
- After any live repro, compiled-app verification, or runtime trace that changes the current diagnosis, first write back a minimal truth resync note to the controlling workflow artifact before continuing. That note must say: scene, observed truth, root-cause or boundary judgment, and the next cut.
- Do not start the next fix while the controlling `tk` / `rp` still reflects an older diagnosis than the latest live evidence.
- If a linked worktree needs to write task notes or review drafts, keep them outside the truth-source paths until they are ready to land on the control plane.
- For ordinary docs, prefer updating the canonical doc instead of creating a parallel note with overlapping scope.
- If a new review artifact is needed, make it task-first and minimal.
- If a request can be answered by renaming an existing file, do that instead of adding a layer.
- If the user asks for automation, start with a thin shell entrypoint, not a platform.
- Do not place ordinary project docs under workflow-only slots such as `pl` / `rs` just to make them look tracked.
- For worktree status questions, answer with a three-state verdict first: `clean`, `single-task dirty, can continue`, or `contaminated, must split`.
- Close tasks with task-scoped evidence only. Do not generalize to the whole repo or all worktrees.
- For cleanup, say only that the current task's bound worktree and local branch were reclaimed. Do not say things like "only the root repo remains" or "everything was cleaned".
- Call unrelated shared-control-plane changes `foreign active lines`, not "noise" or generic dirty state.
- If new scope appears after a task is already `dne`, say it needs a new `tk` instead of writing back into the closed task.
- Before a close-out reply, you may add one thin `全场快速扫视`: control plane first, worktrees second, compressed conclusion only.
- A `全场快速扫视` reports only foreign active lines plus the remaining foreign worktree count or coarse ownership, and says they were not taken over.
- When a phase or round is finished, make the response's last line exactly one next-step marker:
  `[本轮完成，下一阶段：动作(文档落盘/实现/审阅/修复/复审/通过/提交/合并与清理/推送/任务完成/需用户决策...)-目标(当前任务/单号/关键字)]`
  or
  `[本轮已完成(当前任务/单号/关键字)，阶段结束]`
- Treat that marker as a mainline pointer, not a stop signal. If the next action is still owned by the current agent and has no external blocker, continue directly instead of waiting for a new round.
