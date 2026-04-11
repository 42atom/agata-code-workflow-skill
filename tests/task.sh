#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_sh="$repo_root/agata-code-workflow/scripts/task.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local got="$1"
  local want="$2"
  local message="$3"

  [[ "$got" == "$want" ]] || fail "${message}: expected [${want}] got [${got}]"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  [[ "$haystack" == *"$needle"* ]] || fail "${message}: missing [${needle}] in [${haystack}]"
}

run_task() {
  local project_root="$1"
  shift

  local stdout_file stderr_file
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  set +e
  (
    cd "$project_root"
    "$task_sh" "$@"
  ) >"$stdout_file" 2>"$stderr_file"
  task_status=$?
  set -e

  task_stdout="$(cat "$stdout_file")"
  task_stderr="$(cat "$stderr_file")"

  rm -f "$stdout_file" "$stderr_file"
}

make_project() {
  local project_root
  project_root="$(mktemp -d)"
  mkdir -p "$project_root/issues" "$project_root/docs/reviews" "$project_root/refs"
  printf '%s\n' "$project_root"
}

write_file() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  cat >"$path"
}

task_status=0
task_stdout=""
task_stderr=""

######## archive find should resolve archived tk ids

project_root="$(make_project)"
write_file "$project_root/issues/tk10001.dne.runtime.archive-me.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: archive lookup should keep history reachable
scope: archive one task
risk: low
accept: archived task remains discoverable
memory: none
links: []
---
EOF

run_task "$project_root" archive 10001
assert_eq "$task_status" "0" "archive command should succeed"
archive_year="$(date +%Y)"
archived_path="$project_root/issues/archive/${archive_year}/tk10001.arvd.runtime.archive-me.p1.md"
assert_eq "$task_stdout" "$archived_path" "archive command should move into yearly archive"

run_task "$project_root" find tk10001
assert_eq "$task_status" "0" "find should locate archived task id"
assert_eq "$task_stdout" "$archived_path" "find should resolve archived task path"

rm -rf "$project_root"

######## root-level arvd residue should fail check

project_root="$(make_project)"
write_file "$project_root/issues/tk10011.arvd.runtime.archive-residue.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: root-level arvd files should not survive after archive
scope: detect half-migrated archive residue
risk: low
accept: check fails on residue
memory: none
links: []
---
EOF

run_task "$project_root" check
assert_eq "$task_status" "1" "check should fail on root-level arvd residue"
assert_contains "$task_stderr" "archived task residue detected" "check should explain archive residue failure"

rm -rf "$project_root"

######## rvw tasks should reject empty verify

project_root="$(make_project)"
write_file "$project_root/issues/tk10002.rvw.runtime.empty-verify.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: rvw guard should reject empty verify
scope: guard verify
risk: low
accept: reject empty verify
code_version: abc123
verify:
links:
  - docs/reviews/rp10002.dne.runtime.review-r1-codex.md
---
EOF
write_file "$project_root/docs/reviews/rp10002.dne.runtime.review-r1-codex.md" <<'EOF'
# tk10002 review-r1
EOF

run_task "$project_root" check
assert_eq "$task_status" "1" "check should fail on empty verify"
assert_contains "$task_stderr" "empty verify" "check should explain empty verify failure"

rm -rf "$project_root"

######## rvw tasks should require linked rp evidence

project_root="$(make_project)"
write_file "$project_root/issues/tk0003.rvw.runtime.missing-rp-link.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: rvw guard should require rp evidence
scope: guard evidence link
risk: low
accept: reject rvw without rp link
code_version: abc123
verify: bash verify.sh
links: []
---
EOF

run_task "$project_root" check
assert_eq "$task_status" "1" "check should fail when rvw task has no rp link"
assert_contains "$task_stderr" "rvw task missing rp link" "check should explain missing rp evidence"

rm -rf "$project_root"

######## rvw tasks should accept bare rp anchors, 4-space links, and block verify

project_root="$(make_project)"
write_file "$project_root/issues/tk10006.rvw.runtime.stable-rp-anchor.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: rvw should accept stable rp anchors and multiline verify commands
scope: parse valid yaml-like frontmatter more robustly
risk: low
accept: helper accepts stable rp anchor links
code_version: abc123
verify: |
  bash verify.sh
  pytest tests/task.sh
links:
    - rp10006
---
EOF
write_file "$project_root/docs/reviews/rp10006.dne.runtime.review-r1-codex.md" <<'EOF'
# tk10006 review-r1
EOF
write_file "$project_root/docs/reviews/rp10006.dne.runtime.reply-r1-mobile007kx.md" <<'EOF'
# tk10006 reply-r1
EOF

run_task "$project_root" check
assert_eq "$task_status" "0" "check should accept bare rp anchors and block verify"
assert_eq "$task_stdout" "ok" "successful stable rp anchor check should print ok"

rm -rf "$project_root"

######## memory gate should only trust explicit anchors

project_root="$(make_project)"
write_file "$project_root/issues/tk10004.dne.runtime.memory-anchor.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: memory gate should require an explicit anchor
scope: close task with memory gate
risk: low
accept: reject weak memory mention
memory: required
links: []
---
EOF
write_file "$project_root/refs/project-memory-aaak.md" <<'EOF'
# 项目历史记忆

题: tk10004-memory
时: 2026-04-11
决: only mentioning the task id should not pass
源: tk10004
EOF

run_task "$project_root" check
assert_eq "$task_status" "1" "check should fail when memory anchor is missing"
assert_contains "$task_stderr" "missing project memory anchor" "check should ask for explicit memory anchor"

write_file "$project_root/refs/project-memory-aaak.md" <<'EOF'
# 项目历史记忆

题: tk10004-memory
时: 2026-04-11
锚：tk10004
决: explicit anchor should satisfy memory gate
源: tk10004
EOF

run_task "$project_root" check
assert_eq "$task_status" "0" "check should pass once memory anchor exists"
assert_eq "$task_stdout" "ok" "successful check should print ok"

rm -rf "$project_root"

######## 4-digit and 5-digit ids should not collide by bare numeric value

project_root="$(make_project)"
write_file "$project_root/issues/tk0001.tdo.runtime.numeric-collision-four.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: bare numeric ids must stay unique
scope: detect 4-digit and 5-digit collisions
risk: low
accept: colliding ids fail check
memory: none
links: []
---
EOF
write_file "$project_root/issues/tk00001.tdo.runtime.numeric-collision-five.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: bare numeric ids must stay unique
scope: detect 4-digit and 5-digit collisions
risk: low
accept: colliding ids fail check
memory: none
links: []
---
EOF

run_task "$project_root" check
assert_eq "$task_status" "1" "check should fail on colliding bare numeric task ids"
assert_contains "$task_stderr" "duplicate or colliding task ids detected" "check should explain numeric id collision"

rm -rf "$project_root"

######## five-digit tk and rp ids should pass end-to-end

project_root="$(make_project)"
write_file "$project_root/issues/tk10005.rvw.runtime.five-digit-pass.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: 5-digit ids should work across rvw validation and review lookup
scope: prove 5-digit task and review ids
risk: low
accept: 5-digit ids pass helper validation
code_version: abc123
verify: bash verify.sh
links:
  - docs/reviews/rp10005.dne.runtime.review-r1-codex.md
---
EOF
write_file "$project_root/docs/reviews/rp10005.dne.runtime.review-r1-codex.md" <<'EOF'
# tk10005 review-r1
EOF

run_task "$project_root" check
assert_eq "$task_status" "0" "check should accept valid 5-digit rvw tasks"
assert_eq "$task_stdout" "ok" "successful 5-digit check should print ok"

run_task "$project_root" show 10005
assert_eq "$task_status" "0" "show should accept raw 5-digit task ids"
assert_eq "$task_stdout" "$project_root/issues/tk10005.rvw.runtime.five-digit-pass.p1.md" "show should resolve 5-digit task ids"

run_task "$project_root" find rp10005
assert_eq "$task_status" "0" "find should locate 5-digit review ids"
assert_eq "$task_stdout" "$project_root/docs/reviews/rp10005.dne.runtime.review-r1-codex.md" "find should resolve 5-digit review ids"

rm -rf "$project_root"

######## stale online coauthors should warn without failing

project_root="$(make_project)"
write_file "$project_root/coauthors.csv" <<'EOF'
handle,owner,engine,role,status,updated_at,note
ghost.agent,ghost,codex,worker,online,2000-01-01T00:00:00+00:00,stale online agent
sleeping.agent,sleeping,claude,worker,offline,2000-01-01T00:00:00+00:00,offline should not warn
EOF

run_task "$project_root" check
assert_eq "$task_status" "0" "stale coauthors should not fail check"
assert_eq "$task_stdout" "ok" "stale coauthors should still finish with ok"
assert_contains "$task_stderr" "warning: stale online coauthor: ghost.agent" "check should warn about stale online coauthor"

rm -rf "$project_root"

echo "ok"
