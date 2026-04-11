#!/usr/bin/env bash

set -euo pipefail

######## task workflow helper

VALID_STATES="tdo doi rvw pss dne bkd cand arvd"
VALID_MEMORY_MODES="none required done"
STALE_COAUTHOR_SECONDS=86400
ID_DIGITS_RE='[0-9]{4,5}'

die() {
  echo "error: $*" >&2
  exit 1
}

warn() {
  echo "warning: $*" >&2
}

is_valid_state() {
  local needle="$1"
  for state in $VALID_STATES; do
    if [[ "$state" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

is_valid_memory_mode() {
  local needle="$1"
  for mode in $VALID_MEMORY_MODES; do
    if [[ "$mode" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

find_project_root() {
  local dir="${PWD}"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/issues" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

normalize_task_id() {
  local raw="$1"
  if [[ "$raw" =~ ^${ID_DIGITS_RE}$ ]]; then
    echo "tk${raw}"
    return 0
  fi
  if [[ "$raw" =~ ^tk${ID_DIGITS_RE}$ ]]; then
    echo "$raw"
    return 0
  fi
  die "task id must be 4 or 5 digits, or tkNNNN / tkNNNNN"
}

strip_wrapping_quotes() {
  local value="$1"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  printf '%s\n' "$value"
}

find_task_file() {
  local root="$1"
  local task_id="$2"
  local matches=()

  while IFS= read -r path; do
    matches+=("$path")
  done < <(find "$root/issues" -maxdepth 1 -type f -name "${task_id}.*.md" | sort)

  if [[ "${#matches[@]}" -eq 0 ]]; then
    die "task file not found for ${task_id}"
  fi
  if [[ "${#matches[@]}" -gt 1 ]]; then
    printf '%s\n' "${matches[@]}" >&2
    die "multiple task files found for ${task_id}"
  fi

  echo "${matches[0]}"
}

task_state_from_file() {
  local file="$1"
  local base stem after_prefix
  base="$(basename "$file")"
  stem="${base%.*}"
  after_prefix="${stem#*.}"
  echo "${after_prefix%%.*}"
}

task_id_from_file() {
  local file="$1"
  basename "$file" | cut -d. -f1
}

extract_frontmatter_scalar() {
  local file="$1"
  local key="$2"

  awk -v wanted="$key" '
    NR == 1 && $0 == "---" { in_yaml = 1; next }
    in_yaml && $0 == "---" {
      if (in_block) {
        print block_value
      }
      exit
    }
    !in_yaml { next }

    in_block {
      if ($0 ~ /^[^[:space:]]/) {
        print block_value
        exit
      }
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (block_started) {
        block_value = block_value ORS line
      } else {
        block_value = line
        block_started = 1
      }
      next
    }

    $0 ~ ("^" wanted ":[[:space:]]*") {
      line = $0
      sub("^" wanted ":[[:space:]]*", "", line)
      if (line == "|" || line == ">") {
        in_block = 1
        block_started = 0
        block_value = ""
        next
      }
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      gsub(/^'\''|'\''$/, "", line)
      gsub(/^"|"$/, "", line)
      print line
      exit
    }
  ' "$file"
}

frontmatter_has_key() {
  local file="$1"
  local key="$2"

  awk -v wanted="$key" '
    NR == 1 && $0 == "---" { in_yaml = 1; next }
    in_yaml && $0 == "---" { exit }
    !in_yaml { next }
    $0 ~ ("^" wanted ":[[:space:]]*") { found = 1; exit }
    END { exit found ? 0 : 1 }
  ' "$file"
}

task_basename_with_state() {
  local file="$1"
  local new_state="$2"
  local base stem prefix after_prefix suffix

  base="$(basename "$file")"
  stem="${base%.*}"
  prefix="${stem%%.*}"
  after_prefix="${stem#*.}"
  suffix="${after_prefix#*.}"
  printf '%s\n' "${prefix}.${new_state}.${suffix}.md"
}

rename_task_state() {
  local file="$1"
  local new_state="$2"
  local dir new_file

  dir="$(dirname "$file")"
  new_file="${dir}/$(task_basename_with_state "$file" "$new_state")"

  mv "$file" "$new_file"
  echo "$new_file"
}

can_transition() {
  local from="$1"
  local to="$2"

  case "$from" in
    tdo) [[ "$to" == "doi" || "$to" == "cand" ]] ;;
    doi) [[ "$to" == "rvw" || "$to" == "bkd" || "$to" == "cand" ]] ;;
    rvw) [[ "$to" == "pss" || "$to" == "bkd" || "$to" == "doi" || "$to" == "cand" ]] ;;
    pss) [[ "$to" == "dne" ]] ;;
    bkd) [[ "$to" == "doi" || "$to" == "rvw" || "$to" == "cand" ]] ;;
    dne) [[ "$to" == "arvd" ]] ;;
    cand) [[ "$to" == "arvd" ]] ;;
    arvd) [[ "$to" == "arvd" ]] ;;
    *) return 1 ;;
  esac
}

project_memory_file() {
  local root="$1"
  echo "$root/refs/project-memory-aaak.md"
}

task_needs_memory_gate() {
  local file="$1"
  local memory_mode state

  memory_mode="$(extract_frontmatter_scalar "$file" "memory")"
  if [[ -z "$memory_mode" || "$memory_mode" == "none" ]]; then
    return 1
  fi

  is_valid_memory_mode "$memory_mode" || die "invalid memory mode: $file -> $memory_mode"

  if [[ "$memory_mode" == "done" ]]; then
    return 0
  fi

  state="$(task_state_from_file "$file")"
  [[ "$state" == "dne" || "$state" == "arvd" ]]
}

memory_entry_exists() {
  local root="$1"
  local task_id="$2"
  local memory_file

  memory_file="$(project_memory_file "$root")"
  [[ -f "$memory_file" ]] || return 1
  awk -v wanted="$task_id" '
    /^锚[:：][[:space:]]*/ {
      line = $0
      sub(/^锚[:：][[:space:]]*/, "", line)
      gsub(/[|,]/, " ", line)
      count = split(line, items, /[[:space:]]+/)
      for (i = 1; i <= count; i++) {
        if (items[i] == wanted) {
          found = 1
          exit
        }
      }
    }
    END { exit found ? 0 : 1 }
  ' "$memory_file"
}

assert_memory_gate_for_close() {
  local root="$1"
  local file="$2"
  local new_state="$3"
  local task_id memory_mode

  if [[ "$new_state" != "dne" && "$new_state" != "arvd" ]]; then
    return 0
  fi

  memory_mode="$(extract_frontmatter_scalar "$file" "memory")"
  if [[ -z "$memory_mode" || "$memory_mode" == "none" ]]; then
    return 0
  fi

  is_valid_memory_mode "$memory_mode" || die "invalid memory mode: $file -> $memory_mode"

  task_id="$(task_id_from_file "$file")"
  memory_entry_exists "$root" "$task_id" || die "missing project memory anchor for ${task_id}: $(project_memory_file "$root")"
}

print_usage() {
  cat <<'EOF'
usage:
  task.sh ls [state]
  task.sh find <id>
  task.sh show <task-id>
  task.sh move <task-id> <state>
  task.sh archive <task-id>
  task.sh check
EOF
}

normalize_doc_id() {
  local raw="$1"
  if [[ "$raw" =~ ^${ID_DIGITS_RE}$ ]]; then
    echo "tk${raw}"
    return 0
  fi
  if [[ "$raw" =~ ^(tk|pl|rs|rf|rp)${ID_DIGITS_RE}$ ]]; then
    echo "$raw"
    return 0
  fi
  die "id must be 4 or 5 digits, or {tk|pl|rs|rf|rp}NNNN / {tk|pl|rs|rf|rp}NNNNN"
}

find_doc_file() {
  local root="$1"
  local doc_id="$2"
  local matches=()

  while IFS= read -r path; do
    matches+=("$path")
  done < <(
    {
      find "$root/issues" -type f -name "${doc_id}.*.md" 2>/dev/null
      find "$root/docs/reviews" -type f -name "${doc_id}.*.md" 2>/dev/null
    } | sort
  )

  if [[ "${#matches[@]}" -eq 0 ]]; then
    die "document not found for ${doc_id}"
  fi

  printf '%s\n' "${matches[@]}"
}

cmd_ls() {
  local root="$1"
  local wanted_state="${2:-}"

  if [[ -n "$wanted_state" ]]; then
    is_valid_state "$wanted_state" || die "invalid state: ${wanted_state}"
    find "$root/issues" -maxdepth 1 -type f -name "tk*.${wanted_state}.*.md" | sort
    return 0
  fi

  find "$root/issues" -maxdepth 1 -type f -name "tk*.md" | sort
}

cmd_show() {
  local root="$1"
  local task_id
  task_id="$(normalize_task_id "$2")"
  find_task_file "$root" "$task_id"
}

cmd_find() {
  local root="$1"
  local doc_id
  doc_id="$(normalize_doc_id "$2")"
  find_doc_file "$root" "$doc_id"
}

cmd_move() {
  local root="$1"
  local task_id new_state file old_state new_file

  task_id="$(normalize_task_id "$2")"
  new_state="$3"
  is_valid_state "$new_state" || die "invalid state: ${new_state}"

  file="$(find_task_file "$root" "$task_id")"
  old_state="$(task_state_from_file "$file")"

  if [[ "$old_state" == "$new_state" ]]; then
    die "task already in state ${new_state}"
  fi
  can_transition "$old_state" "$new_state" || die "illegal transition: ${old_state} -> ${new_state}"
  assert_memory_gate_for_close "$root" "$file" "$new_state"

  new_file="$(rename_task_state "$file" "$new_state")"
  echo "$new_file"
}

cmd_archive() {
  local root="$1"
  local task_id file state year archive_dir archived_file

  task_id="$(normalize_task_id "$2")"
  file="$(find_task_file "$root" "$task_id")"
  state="$(task_state_from_file "$file")"
  year="$(date +%Y)"
  archive_dir="$root/issues/archive/${year}"
  mkdir -p "$archive_dir"

  if [[ "$state" != "arvd" ]]; then
    can_transition "$state" "arvd" || die "task in state ${state} cannot be archived"
    assert_memory_gate_for_close "$root" "$file" "arvd"
    archived_file="${archive_dir}/$(task_basename_with_state "$file" "arvd")"
  else
    archived_file="${archive_dir}/$(basename "$file")"
  fi

  mv "$file" "$archived_file"
  echo "$archived_file"
}

check_duplicate_task_ids() {
  local root="$1"
  local duplicates

  if ! duplicates="$(
    python3 - "$root/issues" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
pattern = re.compile(r"^(tk\d{4,5})\.")

exact_ids = {}
bare_ids = {}

for path in sorted(root.rglob("tk*.md")):
    match = pattern.match(path.name)
    if not match:
        continue
    task_id = match.group(1)
    exact_ids.setdefault(task_id, []).append(str(path))
    bare_ids.setdefault(f"tk{int(task_id[2:])}", set()).add(task_id)

problems = []
for task_id, paths in sorted(exact_ids.items()):
    if len(paths) > 1:
        problems.append(f"exact:{task_id} -> " + ", ".join(paths))

for bare_id, task_ids in sorted(bare_ids.items()):
    if len(task_ids) > 1:
        problems.append(f"bare:{bare_id} -> " + ", ".join(sorted(task_ids)))

if problems:
    print("\n".join(problems))
    raise SystemExit(1)
PY
  )"; then
    echo "$duplicates" >&2
    die "duplicate or colliding task ids detected"
  fi
}

check_rvw_fields() {
  local root="$1"
  local file accept code_version verify

  while IFS= read -r file; do
    frontmatter_has_key "$file" "accept" || die "missing accept: $file"
    frontmatter_has_key "$file" "code_version" || die "missing code_version: $file"
    frontmatter_has_key "$file" "verify" || die "missing verify: $file"

    accept="$(extract_frontmatter_scalar "$file" "accept")"
    code_version="$(extract_frontmatter_scalar "$file" "code_version")"
    verify="$(extract_frontmatter_scalar "$file" "verify")"

    [[ ! "$accept" =~ ^[[:space:]]*$ ]] || die "empty accept: $file"
    [[ ! "$code_version" =~ ^[[:space:]]*$ ]] || die "empty code_version: $file"
    [[ ! "$verify" =~ ^[[:space:]]*$ ]] || die "empty verify: $file"
    task_has_rp_link "$root" "$file" || die "rvw task missing rp link: $file"
  done < <(find "$root/issues" -maxdepth 1 -type f -name 'tk*.rvw.*.md' | sort)
}

check_rp_names() {
  local root="$1"
  local file base

  [[ -d "$root/docs/reviews" ]] || return 0

  while IFS= read -r file; do
    base="$(basename "$file")"
    [[ "$base" =~ ^rp${ID_DIGITS_RE}\.(tdo|doi|rvw|pss|dne|bkd|cand|arvd)\.[a-z0-9-]+\.(review-r[0-9]+-[a-z0-9-]+|reply-r[0-9]+-[a-z0-9-]+)\.md$ ]] \
      || die "invalid review filename: $file"
  done < <(find "$root/docs/reviews" -maxdepth 1 -type f -name '*.md' | sort)
}

extract_frontmatter_links() {
  local file="$1"

  awk '
    NR == 1 && $0 == "---" { in_yaml = 1; next }
    in_yaml && $0 == "---" { exit }
    !in_yaml { next }

    in_links {
      if ($0 ~ /^[[:space:]]*-[[:space:]]+/) {
        sub(/^[[:space:]]*-[[:space:]]+/, "", $0)
        print $0
        next
      }
      if ($0 ~ /^[^[:space:]]/) {
        in_links = 0
      }
      if (!in_links) {
        next
      }
    }

    /^links:[[:space:]]*\[/ {
      line = $0
      sub(/^links:[[:space:]]*\[/, "", line)
      sub(/\][[:space:]]*$/, "", line)
      count = split(line, items, /,[[:space:]]*/)
      for (i = 1; i <= count; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", items[i])
        gsub(/^'\''|'\''$/, "", items[i])
        gsub(/^"|"$/, "", items[i])
        if (items[i] != "") {
          print items[i]
        }
      }
      next
    }

    /^links:[[:space:]]*$/ {
      in_links = 1
      next
    }
  ' "$file"
}

normalize_link_target() {
  local root="$1"
  local target="$2"

  target="$(strip_wrapping_quotes "$target")"

  if [[ "$target" = /* ]]; then
    echo "$target"
    return 0
  fi

  if [[ "$target" =~ ^rp${ID_DIGITS_RE}\..*\.md$ ]]; then
    echo "$root/docs/reviews/$target"
    return 0
  fi

  echo "$root/$target"
}

find_review_anchor_matches() {
  local root="$1"
  local review_id="$2"

  find "$root/docs/reviews" -maxdepth 1 -type f -name "${review_id}.*.md" 2>/dev/null | sort
}

task_has_rp_link() {
  local root="$1"
  local file="$2"
  local raw_link raw_target normalized base

  while IFS= read -r raw_link; do
    raw_target="$(strip_wrapping_quotes "$raw_link")"

    if [[ "$raw_target" =~ ^rp${ID_DIGITS_RE}$ ]]; then
      if find_review_anchor_matches "$root" "$raw_target" | grep -q .; then
        return 0
      fi
      continue
    fi

    normalized="$(normalize_link_target "$root" "$raw_link")"
    base="$(basename "$normalized")"

    if [[ "$base" =~ ^rp${ID_DIGITS_RE}\..*\.md$ ]]; then
      return 0
    fi
  done < <(extract_frontmatter_links "$file")

  return 1
}

check_tk_rp_links_exist() {
  local root="$1"
  local file raw_link raw_target normalized base

  while IFS= read -r file; do
    while IFS= read -r raw_link; do
      raw_target="$(strip_wrapping_quotes "$raw_link")"

      if [[ "$raw_target" =~ ^rp${ID_DIGITS_RE}$ ]]; then
        if ! find_review_anchor_matches "$root" "$raw_target" | grep -q .; then
          die "missing rp link target: $file -> $raw_link"
        fi
        continue
      fi

      normalized="$(normalize_link_target "$root" "$raw_link")"
      base="$(basename "$normalized")"

      if [[ ! "$base" =~ ^rp${ID_DIGITS_RE}\..*\.md$ ]]; then
        continue
      fi

      [[ -f "$normalized" ]] || die "missing rp link target: $file -> $raw_link"
    done < <(extract_frontmatter_links "$file")
  done < <(find "$root/issues" -maxdepth 1 -type f -name 'tk*.md' | sort)
}

check_arvd_residue() {
  local root="$1"
  local residue

  residue="$(find "$root/issues" -maxdepth 1 -type f -name 'tk*.arvd.*.md' | sort)"
  if [[ -n "$residue" ]]; then
    echo "$residue" >&2
    die "archived task residue detected in issues/"
  fi
}

check_legacy_reply_chains() {
  local root="$1"
  local legacy

  legacy="$(find "$root/docs" -type f \( -name 're.*.md' -o -name 're.re.*.md' \) 2>/dev/null | sort || true)"
  if [[ -n "$legacy" ]]; then
    echo "$legacy" >&2
    die "legacy reply-chain filenames detected"
  fi
}

check_project_memory_links() {
  local root="$1"
  local file task_id

  while IFS= read -r file; do
    if ! task_needs_memory_gate "$file"; then
      continue
    fi

    task_id="$(task_id_from_file "$file")"
    memory_entry_exists "$root" "$task_id" || die "missing project memory anchor for ${task_id}: $(project_memory_file "$root")"
  done < <(find "$root/issues" -maxdepth 1 -type f -name 'tk*.md' | sort)
}

timestamp_to_epoch() {
  local raw="$1"
  local bsd_raw="$raw"

  if [[ "$bsd_raw" =~ ^(.+)([+-][0-9]{2}):([0-9]{2})$ ]]; then
    bsd_raw="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
  elif [[ "$bsd_raw" =~ Z$ ]]; then
    bsd_raw="${bsd_raw%Z}+0000"
  fi

  if date -j -f "%Y-%m-%dT%H:%M:%S%z" "$bsd_raw" "+%s" >/dev/null 2>&1; then
    date -j -f "%Y-%m-%dT%H:%M:%S%z" "$bsd_raw" "+%s"
    return 0
  fi

  if date -d "$raw" "+%s" >/dev/null 2>&1; then
    date -d "$raw" "+%s"
    return 0
  fi

  return 1
}

check_coauthors_staleness() {
  local root="$1"
  local coauthors_file now line_no handle owner engine role status updated_at note updated_epoch age

  coauthors_file="$root/coauthors.csv"
  [[ -f "$coauthors_file" ]] || return 0

  now="$(date +%s)"
  line_no=0

  while IFS=, read -r handle owner engine role status updated_at note; do
    line_no=$((line_no + 1))

    if [[ "$line_no" -eq 1 ]]; then
      continue
    fi

    if [[ -z "$handle$status$updated_at" || "$status" != "online" ]]; then
      continue
    fi

    if [[ -z "$updated_at" ]]; then
      warn "stale online coauthor without updated_at: ${handle} (${coauthors_file}:${line_no})"
      continue
    fi

    if ! updated_epoch="$(timestamp_to_epoch "$updated_at")"; then
      warn "invalid coauthor timestamp: ${handle} -> ${updated_at} (${coauthors_file}:${line_no})"
      continue
    fi

    age=$((now - updated_epoch))
    if (( age > STALE_COAUTHOR_SECONDS )); then
      warn "stale online coauthor: ${handle} last updated ${updated_at}"
    fi
  done < "$coauthors_file"
}

cmd_check() {
  local root="$1"

  check_duplicate_task_ids "$root"
  check_arvd_residue "$root"
  check_rvw_fields "$root"
  check_rp_names "$root"
  check_tk_rp_links_exist "$root"
  check_legacy_reply_chains "$root"
  check_project_memory_links "$root"
  check_coauthors_staleness "$root"
  echo "ok"
}

main() {
  local root cmd

  cmd="${1:-}"

  case "$cmd" in
    ""|-h|--help|help)
      print_usage
      ;;
    ls)
      root="$(find_project_root)" || die "run from a project directory that contains issues/"
      shift
      cmd_ls "$root" "${1:-}"
      ;;
    find)
      root="$(find_project_root)" || die "run from a project directory that contains issues/"
      [[ $# -eq 2 ]] || die "usage: task.sh find <id>"
      cmd_find "$root" "$2"
      ;;
    show)
      root="$(find_project_root)" || die "run from a project directory that contains issues/"
      [[ $# -eq 2 ]] || die "usage: task.sh show <task-id>"
      cmd_show "$root" "$2"
      ;;
    move)
      root="$(find_project_root)" || die "run from a project directory that contains issues/"
      [[ $# -eq 3 ]] || die "usage: task.sh move <task-id> <state>"
      cmd_move "$root" "$2" "$3"
      ;;
    archive)
      root="$(find_project_root)" || die "run from a project directory that contains issues/"
      [[ $# -eq 2 ]] || die "usage: task.sh archive <task-id>"
      cmd_archive "$root" "$2"
      ;;
    check)
      root="$(find_project_root)" || die "run from a project directory that contains issues/"
      [[ $# -eq 1 ]] || die "usage: task.sh check"
      cmd_check "$root"
      ;;
    *)
      die "unknown command: ${cmd}"
      ;;
  esac
}

main "$@"
