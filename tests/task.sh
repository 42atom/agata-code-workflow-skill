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
  project_root="$(cd "$project_root" && pwd -P)"
  printf '%s\n' "$project_root"
}

make_git_project() {
  local project_root
  project_root="$(make_project)"
  write_file "$project_root/README.md" <<'EOF'
# test repo
EOF
  write_file "$project_root/issues/.gitkeep" <<'EOF'
EOF
  write_file "$project_root/docs/reviews/.gitkeep" <<'EOF'
EOF
  write_file "$project_root/refs/.gitkeep" <<'EOF'
EOF
  (
    cd "$project_root"
    git init -q -b main
    git config user.email "test@example.com"
    git config user.name "Task Helper Test"
    git add README.md issues/.gitkeep docs/reviews/.gitkeep refs/.gitkeep
    git commit -qm "chore: init"
  )
  printf '%s\n' "$project_root"
}

make_linked_worktree() {
  local project_root="$1"
  local branch_name="$2"
  local holder worktree_root

  holder="$(mktemp -d)"
  worktree_root="$holder/linked"
  (
    cd "$project_root"
    git worktree add -q -b "$branch_name" "$worktree_root"
  )
  worktree_root="$(cd "$worktree_root" && pwd -P)"
  printf '%s\n' "$worktree_root"
}

remove_linked_worktree() {
  local project_root="$1"
  local worktree_root="$2"

  (
    cd "$project_root"
    git worktree remove --force "$worktree_root"
  ) >/dev/null 2>&1 || true
  rm -rf "$(dirname "$worktree_root")"
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

######## new should allocate ids from the shared control plane

project_root="$(make_git_project)"

run_task "$project_root" new tk runtime sample-created p1
assert_eq "$task_status" "0" "new tk should succeed in shared root checkout"
assert_eq "$task_stdout" "$project_root/issues/tk0001.tdo.runtime.sample-created.p1.md" "new tk should allocate first 4-digit id"
[[ -f "$task_stdout" ]] || fail "new tk should create the file"
grep -q "memory: none" "$task_stdout" || fail "new tk should include default memory mode"

run_task "$project_root" new pl product sample-plan
assert_eq "$task_status" "0" "new pl should succeed in shared root checkout"
assert_eq "$task_stdout" "$project_root/issues/pl0002.tdo.product.sample-plan.md" "new pl should advance the shared sequence"

linked_root="$(make_linked_worktree "$project_root" "task/new-control-plane")"
run_task "$linked_root" new rs runtime linked-attempt
assert_eq "$task_status" "0" "new should route to the shared control plane from a linked worktree"
assert_eq "$task_stdout" "$project_root/issues/rs0003.tdo.runtime.linked-attempt.md" "linked worktree new should still create truth on the control plane"
[[ -f "$task_stdout" ]] || fail "linked worktree new should create the control-plane file"
[[ ! -f "$linked_root/issues/rs0003.tdo.runtime.linked-attempt.md" ]] || fail "linked worktree new should not write the mirror truth path locally"

remove_linked_worktree "$project_root" "$linked_root"
rm -rf "$project_root"

######## check should reject direct truth edits inside linked worktrees

project_root="$(make_git_project)"
write_file "$project_root/issues/tk10008.doi.runtime.truth-edit-drift.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: linked worktrees must not edit truth files directly
scope: fail check on local truth drift
risk: low
accept: check rejects truth edits in linked worktree
memory: none
claimed_at: 2026-04-16T00:00:00Z
links: []
---
EOF
(
  cd "$project_root"
  git add issues/tk10008.doi.runtime.truth-edit-drift.p1.md
  git commit -qm "plan(runtime): add truth edit drift test [tk10008]"
)
linked_root="$(make_linked_worktree "$project_root" "task/tk10008-truth-drift")"
cat >>"$linked_root/issues/tk10008.doi.runtime.truth-edit-drift.p1.md" <<'EOF'

# 本地草稿

1. this should not live in a linked worktree truth file
EOF

run_task "$linked_root" check
assert_eq "$task_status" "1" "check should fail when linked worktree edits truth files"
assert_contains "$task_stderr" "truth-source edits in a linked worktree" "check should explain linked worktree truth drift"

run_task "$linked_root" orphan-scan main 10008
assert_eq "$task_status" "1" "orphan-scan should still inspect the current linked worktree for truth drift"
assert_contains "$task_stdout" "worktree M issues/tk10008.doi.runtime.truth-edit-drift.p1.md" "orphan-scan should report linked worktree truth edits"

remove_linked_worktree "$project_root" "$linked_root"
rm -rf "$project_root"

######## doi tasks should warn on missing or stale claimed_at without failing

project_root="$(make_project)"
write_file "$project_root/issues/tk10013.doi.runtime.stale-claim.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: stale doi claims should surface during check
scope: warn on zombie lock candidates
risk: low
accept: stale doi shows a warning
memory: none
claimed_at: 2000-01-01T00:00:00Z
links: []
---
EOF
write_file "$project_root/issues/tk10014.doi.runtime.missing-claim.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: missing claim timestamps should also surface
scope: warn on malformed doi metadata
risk: low
accept: missing claimed_at shows a warning
memory: none
links: []
---
EOF

run_task "$project_root" check
assert_eq "$task_status" "0" "stale doi warnings should not fail check"
assert_eq "$task_stdout" "ok" "stale doi warnings should still finish with ok"
assert_contains "$task_stderr" "warning: stale doi task: tk10013" "check should warn on stale doi"
assert_contains "$task_stderr" "warning: doi task missing claimed_at: tk10014" "check should warn on missing claim timestamp"

rm -rf "$project_root"

######## move and show should route control-plane truth through a linked worktree

project_root="$(make_git_project)"
write_file "$project_root/issues/tk10007.tdo.runtime.control-plane-move.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: workflow state changes should route through the shared control plane
scope: linked worktrees should not mutate their local truth mirror
risk: low
accept: linked worktree move updates the control-plane task only
memory: none
links: []
---
EOF
(
  cd "$project_root"
  git add issues/tk10007.tdo.runtime.control-plane-move.p1.md
  git commit -qm "plan(runtime): add control-plane move test [tk10007]"
)
linked_root="$(make_linked_worktree "$project_root" "task/tk10007")"

run_task "$linked_root" move 10007 doi
assert_eq "$task_status" "0" "move should route to the shared control plane from a linked worktree"
assert_eq "$task_stdout" "$project_root/issues/tk10007.doi.runtime.control-plane-move.p1.md" "linked worktree move should rename the control-plane task"
grep -q "^claimed_at: " "$task_stdout" || fail "move to doi should stamp claimed_at"
[[ -f "$linked_root/issues/tk10007.tdo.runtime.control-plane-move.p1.md" ]] || fail "linked worktree mirror should stay on its own branch copy"

run_task "$linked_root" show 10007
assert_eq "$task_status" "0" "show should read the control-plane truth from a linked worktree"
assert_eq "$task_stdout" "$project_root/issues/tk10007.doi.runtime.control-plane-move.p1.md" "show should ignore the stale linked worktree mirror"

remove_linked_worktree "$project_root" "$linked_root"
rm -rf "$project_root"

######## archive should route control-plane truth through a linked worktree

project_root="$(make_git_project)"
write_file "$project_root/issues/tk10012.dne.runtime.control-plane-archive.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: archive should land on the shared control plane even when called from a linked worktree
scope: route archive through the authoritative checkout
risk: low
accept: linked worktree archive updates the control-plane task only
memory: none
links: []
---
EOF
(
  cd "$project_root"
  git add issues/tk10012.dne.runtime.control-plane-archive.p1.md
  git commit -qm "plan(runtime): add control-plane archive test [tk10012]"
)
linked_root="$(make_linked_worktree "$project_root" "task/tk10012")"

run_task "$linked_root" archive 10012
assert_eq "$task_status" "0" "archive should route to the shared control plane from a linked worktree"
archive_year="$(date +%Y)"
assert_eq "$task_stdout" "$project_root/issues/archive/${archive_year}/tk10012.arvd.runtime.control-plane-archive.p1.md" "linked worktree archive should move the control-plane task into yearly archive"
[[ -f "$linked_root/issues/tk10012.dne.runtime.control-plane-archive.p1.md" ]] || fail "linked worktree mirror should stay on its own branch copy after archive routing"

remove_linked_worktree "$project_root" "$linked_root"
rm -rf "$project_root"

######## prune should reject active doi worktrees

project_root="$(make_git_project)"
write_file "$project_root/issues/tk10020.doi.runtime.prune-live-claim.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: prune must not silently delete an active claim
scope: block cleanup while doi lock is still held
risk: low
accept: prune rejects doi tasks
memory: none
claimed_at: 2026-04-16T00:00:00Z
links: []
---
EOF
(
  cd "$project_root"
  git add issues/tk10020.doi.runtime.prune-live-claim.p1.md
  git commit -qm "plan(runtime): add prune doi guard [tk10020]"
)
linked_root="$(make_linked_worktree "$project_root" "task/tk10020")"

run_task "$linked_root" prune 10020 main
assert_eq "$task_status" "1" "prune should fail while task is still doi"
assert_contains "$task_stderr" "task in state doi cannot be pruned" "prune should explain live claim guard"

remove_linked_worktree "$project_root" "$linked_root"
rm -rf "$project_root"

######## prune should reject blocked frozen worktrees

project_root="$(make_git_project)"
write_file "$project_root/issues/tk10021.bkd.runtime.prune-frozen-worktree.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: blocked tasks may intentionally keep a frozen worktree
scope: block prune on bkd state
risk: low
accept: prune rejects frozen blocked worktrees
memory: none
links: []
---
EOF
(
  cd "$project_root"
  git add issues/tk10021.bkd.runtime.prune-frozen-worktree.p1.md
  git commit -qm "plan(runtime): add prune bkd guard [tk10021]"
)
linked_root="$(make_linked_worktree "$project_root" "task/tk10021")"

run_task "$project_root" prune 10021 main
assert_eq "$task_status" "1" "prune should fail while task is frozen in bkd"
assert_contains "$task_stderr" "task in state bkd cannot be pruned" "prune should explain blocked-state guard"

remove_linked_worktree "$project_root" "$linked_root"
rm -rf "$project_root"

######## prune should remove a settled worktree whose execution diff is already landed

project_root="$(make_git_project)"
write_file "$project_root/issues/tk10022.dne.runtime.prune-landed-worktree.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: landed task worktrees should be removable from the control plane
scope: delete linked worktree and its local branch after reconciliation
risk: low
accept: prune removes the clean linked worktree
memory: none
links: []
---
EOF
(
  cd "$project_root"
  git add issues/tk10022.dne.runtime.prune-landed-worktree.p1.md
  git commit -qm "plan(runtime): add prune success case [tk10022]"
)
linked_root="$(make_linked_worktree "$project_root" "task/tk10022")"
write_file "$linked_root/src/prune-landed.js" <<'EOF'
export const pruneLanded = true;
EOF
(
  cd "$linked_root"
  git add src/prune-landed.js
  git commit -qm "feat(runtime): add landed prune sample [tk10022]"
)
(
  cd "$project_root"
  git merge --no-ff -qm "merge task/tk10022" task/tk10022
)

run_task "$linked_root" prune 10022 main
assert_eq "$task_status" "0" "prune should succeed once code is landed and task is closed"
assert_contains "$task_stdout" "branch: task/tk10022" "prune should report the cleaned local branch"
[[ ! -d "$linked_root" ]] || fail "prune should remove the linked worktree directory"
(
  cd "$project_root"
  if git rev-parse --verify --quiet refs/heads/task/tk10022 >/dev/null; then
    fail "prune should delete the local branch"
  fi
)

rm -rf "$project_root"

######## prune should reject closed tasks whose execution diff is not yet landed

project_root="$(make_git_project)"
write_file "$project_root/issues/tk10023.dne.runtime.prune-unlanded-worktree.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: cleanup must stop if code still lives only in the task branch
scope: block prune on outstanding execution diff
risk: low
accept: prune fails until branch content is landed
memory: none
links: []
---
EOF
(
  cd "$project_root"
  git add issues/tk10023.dne.runtime.prune-unlanded-worktree.p1.md
  git commit -qm "plan(runtime): add prune diff guard [tk10023]"
)
linked_root="$(make_linked_worktree "$project_root" "task/tk10023")"
write_file "$linked_root/src/prune-unlanded.js" <<'EOF'
export const pruneUnlanded = true;
EOF
(
  cd "$linked_root"
  git add src/prune-unlanded.js
  git commit -qm "feat(runtime): add unlanded prune sample [tk10023]"
)

run_task "$linked_root" prune 10023 main
assert_eq "$task_status" "1" "prune should fail when execution diff is still unique to the task branch"
assert_contains "$task_stderr" "linked worktree still carries execution diff vs main for tk10023" "prune should explain outstanding execution drift"
[[ -d "$linked_root" ]] || fail "failed prune should keep the linked worktree in place"
(
  cd "$project_root"
  if ! git rev-parse --verify --quiet refs/heads/task/tk10023 >/dev/null; then
    fail "failed prune should keep the local branch"
  fi
)

remove_linked_worktree "$project_root" "$linked_root"
rm -rf "$project_root"

######## orphan-scan should fail on untracked truth files in current worktree

project_root="$(make_git_project)"
write_file "$project_root/issues/tk10058.tdo.runtime.stranded-worktree.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: orphan-scan should catch untracked truth in current worktree
scope: detect stranded truth before cleanup
risk: low
accept: orphan-scan fails on untracked truth
memory: none
links: []
---
EOF

run_task "$project_root" orphan-scan main
assert_eq "$task_status" "1" "orphan-scan should fail on current worktree truth drift"
assert_contains "$task_stdout" "worktree ?? issues/tk10058.tdo.runtime.stranded-worktree.p1.md" "orphan-scan should report untracked truth path"

rm -rf "$project_root"

######## orphan-scan should fail when another branch holds truth not on base

project_root="$(make_git_project)"
(
  cd "$project_root"
  git checkout -qb task/pl10042
)
write_file "$project_root/issues/pl10042.tdo.runtime.stranded-plan.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: orphan-scan should catch branch-only plan truth
scope: detect truth stranded in another branch
risk: low
accept: orphan-scan reports branch-only truth files
memory: none
links: []
---
EOF
(
  cd "$project_root"
  git add issues/pl10042.tdo.runtime.stranded-plan.md
  git commit -qm "plan(runtime): stranded proposal [pl10042]"
  git checkout -q main
)

run_task "$project_root" orphan-scan main
assert_eq "$task_status" "1" "orphan-scan should fail when another branch carries truth drift"
assert_contains "$task_stdout" "branch:task/pl10042" "orphan-scan should report branch owner for stranded truth"
assert_contains "$task_stdout" "issues/pl10042.tdo.runtime.stranded-plan.md" "orphan-scan should report branch-only truth path"

rm -rf "$project_root"

######## orphan-scan should ignore non-truth files

project_root="$(make_git_project)"
write_file "$project_root/src/app.js" <<'EOF'
console.log("code-only drift");
EOF

run_task "$project_root" orphan-scan main
assert_eq "$task_status" "0" "orphan-scan should ignore code-only changes"
assert_eq "$task_stdout" "ok" "code-only drift should not trip orphan-scan"

rm -rf "$project_root"

echo "ok"
