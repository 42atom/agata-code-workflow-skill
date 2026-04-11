#!/usr/bin/env bash

set -euo pipefail

######## task workflow helper

VALID_STATES="tdo doi rvw pss dne bkd cand arvd"
VALID_MEMORY_MODES="none required done"

die() {
  echo "error: $*" >&2
  exit 1
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
  if [[ "$raw" =~ ^[0-9]{4}$ ]]; then
    echo "tk${raw}"
    return 0
  fi
  if [[ "$raw" =~ ^tk[0-9]{4}$ ]]; then
    echo "$raw"
    return 0
  fi
  die "task id must be 4 digits or tkNNNN"
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
    in_yaml && $0 == "---" { exit }
    !in_yaml { next }
    $0 ~ ("^" wanted ":[[:space:]]*") {
      line = $0
      sub("^" wanted ":[[:space:]]*", "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      gsub(/^'\''|'\''$/, "", line)
      gsub(/^"|"$/, "", line)
      print line
      exit
    }
  ' "$file"
}

rename_task_state() {
  local file="$1"
  local new_state="$2"
  local dir base stem prefix after_prefix suffix new_file

  dir="$(dirname "$file")"
  base="$(basename "$file")"
  stem="${base%.*}"
  prefix="${stem%%.*}"
  after_prefix="${stem#*.}"
  suffix="${after_prefix#*.}"
  new_file="${dir}/${prefix}.${new_state}.${suffix}.md"

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
  grep -Eq "(^|[^[:alnum:]_-])${task_id}([^[:alnum:]_-]|$)" "$memory_file"
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
  memory_entry_exists "$root" "$task_id" || die "missing project memory entry for ${task_id}: $(project_memory_file "$root")"
}

print_usage() {
  cat <<'EOF'
usage:
  task.sh ls [state]
  task.sh show <task-id>
  task.sh move <task-id> <state>
  task.sh archive <task-id>
  task.sh check
EOF
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

  if [[ "$state" != "arvd" ]]; then
    can_transition "$state" "arvd" || die "task in state ${state} cannot be archived"
    assert_memory_gate_for_close "$root" "$file" "arvd"
    file="$(rename_task_state "$file" "arvd")"
  fi

  year="$(date +%Y)"
  archive_dir="$root/issues/archive/${year}"
  mkdir -p "$archive_dir"
  archived_file="${archive_dir}/$(basename "$file")"

  mv "$file" "$archived_file"
  echo "$archived_file"
}

check_duplicate_task_ids() {
  local root="$1"
  local duplicates

  duplicates="$(find "$root/issues" -maxdepth 1 -type f -name 'tk*.md' -print \
    | sed 's#.*/##' \
    | cut -d. -f1 \
    | sort \
    | uniq -d)"

  if [[ -n "$duplicates" ]]; then
    echo "$duplicates" >&2
    die "duplicate task ids detected"
  fi
}

check_rvw_fields() {
  local root="$1"
  local file

  while IFS= read -r file; do
    grep -q '^accept:' "$file" || die "missing accept: $file"
    grep -q '^code_version:' "$file" || die "missing code_version: $file"
    grep -q '^verify:' "$file" || die "missing verify: $file"
  done < <(find "$root/issues" -maxdepth 1 -type f -name 'tk*.rvw.*.md' | sort)
}

check_rp_names() {
  local root="$1"
  local file base

  [[ -d "$root/docs/reviews" ]] || return 0

  while IFS= read -r file; do
    base="$(basename "$file")"
    [[ "$base" =~ ^rp[0-9]{4}\.(tdo|doi|rvw|pss|dne|bkd|cand|arvd)\.[a-z0-9-]+\.(review-r[0-9]+-[a-z0-9-]+|reply-r[0-9]+-[a-z0-9-]+)\.md$ ]] \
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
      if ($0 ~ /^  - /) {
        sub(/^  - /, "", $0)
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

  target="${target%\"}"
  target="${target#\"}"
  target="${target%\'}"
  target="${target#\'}"

  if [[ "$target" = /* ]]; then
    echo "$target"
    return 0
  fi

  if [[ "$target" =~ ^rp[0-9]{4}\..*\.md$ ]]; then
    echo "$root/docs/reviews/$target"
    return 0
  fi

  echo "$root/$target"
}

check_tk_rp_links_exist() {
  local root="$1"
  local file raw_link normalized base

  while IFS= read -r file; do
    while IFS= read -r raw_link; do
      normalized="$(normalize_link_target "$root" "$raw_link")"
      base="$(basename "$normalized")"

      if [[ ! "$base" =~ ^rp[0-9]{4}\..*\.md$ ]]; then
        continue
      fi

      [[ -f "$normalized" ]] || die "missing rp link target: $file -> $raw_link"
    done < <(extract_frontmatter_links "$file")
  done < <(find "$root/issues" -maxdepth 1 -type f -name 'tk*.md' | sort)
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
    memory_entry_exists "$root" "$task_id" || die "missing project memory entry for ${task_id}: $(project_memory_file "$root")"
  done < <(find "$root/issues" -maxdepth 1 -type f -name 'tk*.md' | sort)
}

cmd_check() {
  local root="$1"

  check_duplicate_task_ids "$root"
  check_rvw_fields "$root"
  check_rp_names "$root"
  check_tk_rp_links_exist "$root"
  check_legacy_reply_chains "$root"
  check_project_memory_links "$root"
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
