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
    agents/openai.yaml
    references/workflow-rules.md
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

It is intentionally small. It does not store task state anywhere else.

Current commands:

```bash
./agata-code-workflow/scripts/task.sh ls [state]
./agata-code-workflow/scripts/task.sh show 0061
./agata-code-workflow/scripts/task.sh move 0061 doi
./agata-code-workflow/scripts/task.sh archive 0061
./agata-code-workflow/scripts/task.sh check
```

What it does:

- list task files
- show the current `tk` file
- rename a `tk` file across legal states
- move `arvd` tasks into `issues/archive/YYYY/`
- validate basic workflow invariants

What it does not do:

- no shadow database
- no auto indexing
- no ownership scheduler
- no second state system

## Recommended Project Setup

```text
your-project/
  AGENTS.md
  issues/
  docs/reviews/
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
- validate `coauthors.csv`

Do not create a second state system. The filename state slot is the truth source.
```

## Operating Model

The intended split is:

- global skill: shared workflow discipline
- project `AGENTS.md` / `CLAUDE.md`: local delta and project exceptions
- repository files: actual truth source and review evidence

This avoids copying the same rules into every repository.

## Notes

- Keep helper automation thin
- Do not turn this into a second control plane
- Prefer rename + validate over generating shadow indexes

For the exact rules, read [agata-code-workflow/references/workflow-rules.md](agata-code-workflow/references/workflow-rules.md).
