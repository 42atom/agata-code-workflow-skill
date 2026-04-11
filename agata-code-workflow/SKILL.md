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
3. Preserve id-first naming and keep the filename slots stable except for state.
4. When a task moves state, rename the existing `tk` file; do not create a parallel file.
5. When review happens, create new `rp` files; do not encode reply chains as `re.` or `re.re.`.
6. `rp` records are append-style evidence. Once created, treat them as frozen and prefer `dne`.
7. Before moving a code task to `rvw`, confirm it has `accept`, `code_version`, and `verify`.
8. `refs/project-memory-aaak.md` is historical memory, not task truth.
9. Keep any helper automation thin. Scripts may validate and rename files, but must not become a second control plane.

## Bundled Script

If the user asks for workflow automation, use `scripts/task.sh` first.

Current commands:

- `task.sh ls [state]`
- `task.sh find <id>`
- `task.sh show <task-id>`
- `task.sh move <task-id> <state>`
- `task.sh archive <task-id>`
- `task.sh check`

Use it for legal rename flow, basic validation, archive moves, and memory-gated close checks.
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
