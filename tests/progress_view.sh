#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
progress_view="$repo_root/agata-code-workflow/scripts/progress_view.py"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  grep -q "$needle" "$path" || fail "missing [$needle] in $path"
}

write_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat >"$path"
}

######## doc-sample should generate dense static viewer

out_dir="$(mktemp -d)"
log_file="$(mktemp)"
out_dir_real="$(cd "$out_dir" && pwd -P)"

"$progress_view" --project-root "$repo_root/doc-sample" --out-dir "$out_dir" --no-open >"$log_file"

data_file="$out_dir_real/progress-data.json"
html_file="$out_dir_real/progress-view.html"

assert_file "$data_file"
assert_file "$html_file"
assert_contains "$log_file" "^data: $data_file$"
assert_contains "$log_file" "^html: $html_file$"
assert_contains "$log_file" "^opened: no$"
assert_contains "$data_file" '"name": "doc-sample"'
assert_contains "$data_file" '"doc_id": "tk0001"'
assert_contains "$html_file" 'Agata Workflow Snapshot'
assert_contains "$html_file" '现状'
assert_contains "$html_file" '历史'
assert_contains "$html_file" 'agata-progress-data'
assert_contains "$html_file" 'doc-sample'

rm -rf "$out_dir" "$log_file"

######## five-digit projects should also render correctly

project_root="$(mktemp -d)"
mkdir -p "$project_root/issues" "$project_root/docs/reviews" "$project_root/refs"

write_file "$project_root/issues/tk10001.doi.runtime.viewer-test.p1.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: validate the progress viewer
scope: render one active task
risk: low
accept: html and json carry 5-digit ids
memory: required
links:
  - docs/reviews/rp10001.dne.runtime.review-r1-codex.md
---
EOF

write_file "$project_root/issues/pl10001.tdo.runtime.viewer-plan.md" <<'EOF'
---
owner: user
assignee: codex
reviewer: user
why: same anchor should show derived relations
scope: one plan doc
risk: low
accept: same anchor visible
links: []
---
EOF

write_file "$project_root/docs/reviews/rp10001.dne.runtime.review-r1-codex.md" <<'EOF'
# tk10001 review-r1
EOF

write_file "$project_root/refs/project-memory-aaak.md" <<'EOF'
# 项目历史记忆

题: viewer-memory
时: 2026-04-11
锚: tk10001
决: keep one anchor for history panel
源: tk10001
EOF

write_file "$project_root/coauthors.csv" <<'EOF'
handle,owner,engine,role,status,updated_at,note
dense.viewer,viewer,codex,worker,online,2026-04-11T10:00:00+08:00,active
EOF

out_dir="$(mktemp -d)"
out_dir_real="$(cd "$out_dir" && pwd -P)"
"$progress_view" --project-root "$project_root" --out-dir "$out_dir" --no-open >/dev/null

data_file="$out_dir_real/progress-data.json"
html_file="$out_dir_real/progress-view.html"

assert_contains "$data_file" '"doc_id": "tk10001"'
assert_contains "$data_file" '"doc_id": "rp10001"'
assert_contains "$data_file" '"anchor_id": "10001"'
assert_contains "$html_file" 'tk10001'
assert_contains "$html_file" 'rp10001'
assert_contains "$html_file" 'project-memory-aaak'

rm -rf "$project_root" "$out_dir"

echo "ok"
