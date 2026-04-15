# Project Docs Boundary

Use this reference when the task is about ordinary project documentation rather than workflow truth.

## 1. Boundary

Workflow truth stays in the workflow system:

- `issues/` for `pl` / `rs` / `tk`
- `docs/reviews/` for `rp`
- `refs/project-memory-aaak.md` for long-lived project memory

Ordinary docs are things like:

- `README`
- architecture notes
- runbooks
- usage guides
- delivery / handoff notes
- module-local design docs that do not carry workflow state

Do not turn ordinary docs into fake workflow files.
Do not use ordinary docs to override task state, review state, or memory gates.

## 2. Placement

Prefer the repo's existing doc layout first.

If the repo has no clear convention:

- repo-wide docs go in root or `docs/`
- module-specific docs live near the module they describe

Do not create `docs/plan/` or `docs/research/` as a second workflow system.

## 3. Naming

For ordinary docs:

- prefer stable, lowercase, kebab-case filenames
- name by topic, not by temporary status
- avoid workflow slots like `.tdo.` / `.doi.` unless the file is truly a workflow artifact

Examples:

- `README.md`
- `docs/runtime-architecture.md`
- `docs/deployment-runbook.md`
- `src/auth/README.md`

## 4. Editing Rules

- prefer updating the canonical doc over creating a parallel explainer
- keep one doc to one responsibility
- link to workflow truth instead of copying task state into prose
- record decisions and constraints, not chat transcripts
- if front matter is needed, keep it short and use real responsible humans unless the repo already defines another convention

## 5. Relationship To Workflow Files

Use a workflow file when the document must carry execution state, review evidence, or task ownership.

Use an ordinary doc when the document explains:

- how the system works
- how to operate it
- how to use it
- what was delivered

If unsure:

- execution truth -> `pl` / `rs` / `tk` / `rp`
- explanatory material -> ordinary doc
