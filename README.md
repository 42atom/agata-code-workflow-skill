# agata-code-workflow

Agata-style file workflow skill for code projects.

This skill helps agents work with a file-based task system where:

- `issues/` is the truth source
- `tk` carries state
- `rp` carries review evidence
- review files are task-first and round-based
- `coauthors.csv` is only dispatch context

It is for teams that want a lightweight local Git workflow instead of adding a separate issue system.

## What It Covers

- choosing between `pl` / `rs` / `tk` / `rp`
- filename-based state transitions
- task-first review naming
- `rvw` entry checks
- `coauthors.csv` usage
- keeping review evidence separate from task truth

## Repo Layout

```text
agata-code-workflow-skill/
  README.md
  agata-code-workflow/
    SKILL.md
    scripts/task.sh
    scripts/progress_view.py
    agents/openai.yaml
    templates/progress-view.html
    references/workflow-rules.md
    references/aaak-zh.md
    references/aaak-profiles.md
  doc-sample/
    AGENTS.md
    CLAUDE.md
    coauthors.csv
    issues/
    docs/reviews/
    refs/project-memory-aaak.md
```

## How To Use

Install the `agata-code-workflow/` folder as a local skill in your coding agent environment.

Then, in each project that uses this workflow, keep the project-specific entrypoint short:

- put project-specific rules in `AGENTS.md` or `CLAUDE.md`
- point the agent to this skill by name
- only write project delta locally; do not duplicate the whole workflow spec into every repo

## Thin Helper Script

This repo also ships a thin workflow helper:

- `agata-code-workflow/scripts/task.sh`
- `agata-code-workflow/scripts/progress_view.py`

It is intentionally small. It does not store task state anywhere else.

Document ids support 4 or 5 digits. Existing 4-digit ids remain valid.

Current commands:

```bash
./agata-code-workflow/scripts/task.sh ls [state]
./agata-code-workflow/scripts/task.sh find rp10061
./agata-code-workflow/scripts/task.sh show 10061
./agata-code-workflow/scripts/task.sh move 10061 doi
./agata-code-workflow/scripts/task.sh archive 10061
./agata-code-workflow/scripts/task.sh check
./agata-code-workflow/scripts/progress_view.py --project-root . --no-open
```

What it does:

- list task files
- resolve the current or archived path set for a stable document id
- show the current `tk` file
- rename a `tk` file across legal states
- move `arvd` tasks into `issues/archive/YYYY/`
- validate basic workflow invariants
- validate that declared `rp` links in `tk.links` actually exist
- accept stable `rp0001` / `rp10001` review anchors in `tk.links` and prefer them over stateful review paths
- require non-empty `accept` / `code_version` / `verify` on `rvw` tasks
- require at least one linked `rp` evidence record on `rvw` tasks
- reject root-level `tk*.arvd.*.md` archive residue in `issues/`
- reject colliding bare numeric ids such as `tk0001` vs `tk00001`
- gate `memory: required|done` tasks against `refs/project-memory-aaak.md` via `锚: tkNNNN` / `锚：tkNNNN` or `锚: tkNNNNN` / `锚：tkNNNNN`
- warn on stale online `coauthors.csv` rows
- generate `AIDOCS/agata-workflow-status/progress-data.json`
- render a self-contained `AIDOCS/agata-workflow-status/progress-view.html`
- open the rendered HTML in the default browser without file-fetch CORS issues

Progress view note:

- the reusable template lives in `agata-code-workflow/templates/progress-view.html`
- the generated viewer embeds the JSON snapshot, so `file://` opening still works
- current view focuses on open workflow truth + derived relations
- history view focuses on closed/archive flow + recent document activity
- the UI is dense and read-only, so an agent can quickly show project status without inventing a second control plane

Example:

![Dense read-only workflow progress view](assets/progress-view-doc-sample.png)

Review note:

- `rp` files are append-style evidence
- once written, prefer treating them as frozen records in `dne`
- new rounds should create new `rp` files instead of renaming old ones
- `task.sh find rp0001` may return multiple files because `rp` acts like a thread anchor, not a single-file id
- for `tk.links`, prefer stable `rp0001` / `rp10001` anchors over stateful filenames

What it does not do:

- no shadow database
- no auto indexing
- no ownership scheduler
- no second state system

## AAAK Semantic Compression

This skill also includes optional AAAK references for dense agent-readable body writing:

- `agata-code-workflow/references/aaak-zh.md`
- `agata-code-workflow/references/aaak-profiles.md`

Use AAAK when you want:

- compressed task summaries
- dense review conclusions
- compact research notes
- long-lived project memory

Recommended memory file:

- `refs/project-memory-aaak.md`

Use it as a derived history layer:

- not task truth
- not a review replacement
- only for stable project memory

Do not use AAAK to replace:

- filename state truth
- front matter control fields
- operator checklists
- long command procedures

If a task declares:

```yaml
memory: required
```

then it must be recorded in `refs/project-memory-aaak.md` before it closes into `dne` / `arvd`.

Recommended anchor shape:

```text
锚: tk10061
```

## Recommended Project Setup

```text
your-project/
  AGENTS.md
  issues/
  docs/reviews/
  refs/project-memory-aaak.md
  coauthors.csv        # optional
```

## AGENTS.md Example

Use this when the project runs with an `AGENTS.md` entrypoint:

```md
## Workflow

This project uses the `agata-code-workflow` skill.

When work touches any of the following, use that skill:

- `issues/`
- `docs/reviews/`
- `refs/project-memory-aaak.md`
- `operator-checklist-*`
- `coauthors.csv`
- filename-based task state transitions

Project-specific rules belong here. General workflow rules stay in the skill.
```

## CLAUDE.md Example

Use this when the project runs with a `CLAUDE.md` entrypoint:

```md
# Workflow

Use the `agata-code-workflow` skill for file-based task management in this repo.

Apply it whenever you:

- create or rename `tk` / `pl` / `rs` / `rp` files
- move a task between `tdo` / `doi` / `rvw` / `dne`
- create review records under `docs/reviews/`
- maintain `refs/project-memory-aaak.md`
- validate `coauthors.csv`

Do not create a second state system. The filename state slot is the truth source.
```

## Operating Model

The intended split is:

- global skill: shared workflow discipline
- project `AGENTS.md` / `CLAUDE.md`: local delta and project exceptions
- repository files: actual truth source and review evidence

This avoids copying the same rules into every repository.

## doc-sample

The repo also includes a minimal sample project skeleton under `doc-sample/`.

Use it as:

- a starting point for a new repo
- a naming reference
- a concrete example of `pl` / `rs` / `tk` / `rp`

Do not treat it as a second truth source. It is only a scaffold.

## Notes

- Keep helper automation thin
- Do not turn this into a second control plane
- Prefer rename + validate over generating shadow indexes

For the exact rules, read [agata-code-workflow/references/workflow-rules.md](agata-code-workflow/references/workflow-rules.md).
