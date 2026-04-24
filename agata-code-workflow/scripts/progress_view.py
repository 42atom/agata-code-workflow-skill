#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
import subprocess
import webbrowser
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

######## workflow constants

DOC_RE = re.compile(
    r"^(?P<kind>tk|pl|rs|rf|rp)"
    r"(?P<digits>\d{4,5})\."
    r"(?P<state>tdo|doi|rvw|dne|bkd|cand|arvd)\."
    r"(?P<board>[a-z0-9-]+)\."
    r"(?P<slug>[a-z0-9-]+?)"
    r"(?:\.(?P<priority>p[0-2]))?\.md$"
)

STATE_ORDER = ["doi", "rvw", "bkd", "tdo", "dne", "cand", "arvd"]
STATE_LABEL = {
    "tdo": "待做",
    "doi": "进行中",
    "rvw": "评审中",
    "dne": "已完成",
    "bkd": "阻塞",
    "cand": "已取消",
    "arvd": "已归档",
}
STATE_TONE = {
    "tdo": "todo",
    "doi": "active",
    "rvw": "review",
    "dne": "done",
    "bkd": "blocked",
    "cand": "cancelled",
    "arvd": "archive",
}
KIND_LABEL = {
    "tk": "任务",
    "pl": "计划",
    "rs": "研究",
    "rf": "参考",
    "rp": "评审",
}
PRIORITY_RANK = {"p0": 0, "p1": 1, "p2": 2, "": 9}
ACTIVE_STATES = {"tdo", "doi", "rvw", "bkd"}
DONE_STATES = {"dne"}
HISTORY_STATES = {"dne", "cand", "arvd"}
STALE_COAUTHOR_SECONDS = 24 * 60 * 60


######## filesystem and parsing helpers


def find_project_root(start: Path) -> Path:
    cursor = start.resolve()
    if cursor.is_file():
        cursor = cursor.parent

    for candidate in [cursor, *cursor.parents]:
        if (candidate / "issues").is_dir():
            return candidate

    raise SystemExit("error: run from a project directory that contains issues/ or pass --project-root")


def load_template(script_path: Path, template_override: str | None) -> str:
    if template_override:
        template_path = Path(template_override).expanduser().resolve()
    else:
        template_path = script_path.resolve().parent.parent / "templates" / "progress-view.html"

    try:
        return template_path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise SystemExit(f"error: template not found: {template_path}") from exc


def strip_quotes(value: str) -> str:
    trimmed = value.strip()
    if len(trimmed) >= 2 and trimmed[0] == trimmed[-1] and trimmed[0] in {"'", '"'}:
        return trimmed[1:-1]
    return trimmed


def parse_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}, text

    frontmatter: dict[str, Any] = {}
    index = 1

    while index < len(lines):
        raw = lines[index]
        stripped = raw.strip()

        if stripped == "---":
            body = "\n".join(lines[index + 1 :]).strip()
            return frontmatter, body

        if not stripped:
            index += 1
            continue

        match = re.match(r"^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$", raw)
        if match:
            key, value = match.groups()
            base_indent = len(raw) - len(raw.lstrip())

            if value in {"|", ">"}:
                block: list[str] = []
                index += 1
                while index < len(lines):
                    nested = lines[index]
                    nested_stripped = nested.strip()
                    nested_indent = len(nested) - len(nested.lstrip())
                    if nested_stripped and nested_indent <= base_indent:
                        break
                    block.append(nested.lstrip() if nested_stripped else "")
                    index += 1
                frontmatter[key] = "\n".join(block).strip("\n")
                continue

            if value == "":
                items: list[str] = []
                probe = index + 1
                while probe < len(lines):
                    nested = lines[probe]
                    nested_stripped = nested.strip()
                    nested_indent = len(nested) - len(nested.lstrip())
                    if not nested_stripped:
                        probe += 1
                        continue
                    if nested_indent <= base_indent:
                        break
                    dash_match = re.match(r"^\s*-\s+(.*)$", nested)
                    if not dash_match:
                        break
                    items.append(strip_quotes(dash_match.group(1)))
                    probe += 1
                if items:
                    frontmatter[key] = items
                    index = probe
                    continue

            cleaned = strip_quotes(value)
            if cleaned.startswith("[") and cleaned.endswith("]"):
                content = cleaned[1:-1].strip()
                if content:
                    frontmatter[key] = [strip_quotes(part) for part in content.split(",")]
                else:
                    frontmatter[key] = []
            else:
                frontmatter[key] = cleaned

        index += 1

    return frontmatter, ""


def first_heading(body: str) -> str:
    for raw in body.splitlines():
        line = raw.strip()
        if line.startswith("#"):
            return line.lstrip("#").strip()
    return ""


def first_paragraph(body: str) -> str:
    paragraph: list[str] = []
    for raw in body.splitlines():
        line = raw.strip()
        if not line:
            if paragraph:
                break
            continue
        if line.startswith("#"):
            continue
        paragraph.append(line)
    return " ".join(paragraph)


def humanize_slug(slug: str) -> str:
    return slug.replace("-", " ")


def format_iso(ts: float) -> str:
    return datetime.fromtimestamp(ts, tz=timezone.utc).astimezone().isoformat(timespec="seconds")


def format_display(ts: float) -> str:
    return datetime.fromtimestamp(ts, tz=timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M")


def normalize_link(project_root: Path, raw_link: str) -> Path:
    target = strip_quotes(raw_link)
    if not target:
        return project_root
    if target.startswith("/"):
        return Path(target)
    if re.match(r"^rp\d{4,5}\..*\.md$", target):
        return project_root / "docs" / "reviews" / target
    return project_root / target


def find_review_anchor_matches(project_root: Path, review_id: str) -> list[Path]:
    review_root = project_root / "docs" / "reviews"
    if not review_root.is_dir():
        return []
    return sorted(review_root.glob(f"{review_id}.*.md"))


def resolve_link_entry(project_root: Path, raw_link: str) -> dict[str, Any]:
    target = strip_quotes(raw_link)

    if re.fullmatch(r"rp\d{4,5}", target):
        matches = find_review_anchor_matches(project_root, target)
        first = matches[0].resolve() if matches else (project_root / "docs" / "reviews" / target).resolve()
        return {
            "raw": raw_link,
            "path": str(first),
            "relative_path": str(first).replace(str(project_root.resolve()) + "/", ""),
            "label": target,
            "exists": bool(matches),
            "file_url": matches[0].resolve().as_uri() if matches else "",
        }

    normalized = normalize_link(project_root, raw_link)
    exists = normalized.exists()
    return {
        "raw": raw_link,
        "path": str(normalized.resolve()),
        "relative_path": str(normalized.resolve()).replace(str(project_root.resolve()) + "/", ""),
        "label": normalized.name or raw_link,
        "exists": exists,
        "file_url": normalized.resolve().as_uri() if exists else "",
    }


def derive_relation_summary(doc: dict[str, Any], siblings: list[dict[str, Any]], linked_entries: list[dict[str, Any]]) -> dict[str, Any]:
    kind_counts = Counter(item["kind"] for item in siblings)
    derived_bits = [
        f"{kind}" if count == 1 else f"{kind}×{count}"
        for kind, count in ((kind, kind_counts.get(kind, 0)) for kind in ["pl", "rs", "rf", "rp", "tk"])
        if count
    ]
    linked_bits = [item["label"] for item in linked_entries[:4]]
    if len(linked_entries) > 4:
        linked_bits.append(f"+{len(linked_entries) - 4}")
    return {
        "count": len(siblings),
        "derived_bits": derived_bits,
        "linked_bits": linked_bits,
        "linked_count": len(linked_entries),
    }


def parse_doc_file(path: Path, project_root: Path) -> dict[str, Any] | None:
    match = DOC_RE.match(path.name)
    if not match:
        return None

    stat = path.stat()
    text = path.read_text(encoding="utf-8")
    frontmatter, body = parse_frontmatter(text)
    links = frontmatter.get("links", [])
    if not isinstance(links, list):
        links = []

    rel_path = path.resolve().relative_to(project_root.resolve())
    title = first_heading(body) or humanize_slug(match.group("slug"))
    summary = frontmatter.get("why") or first_paragraph(body) or frontmatter.get("scope") or title

    normalized_links = []
    for raw in links:
        normalized_links.append(resolve_link_entry(project_root, raw))

    record = {
        "doc_id": f"{match.group('kind')}{match.group('digits')}",
        "anchor_id": match.group("digits"),
        "kind": match.group("kind"),
        "kind_label": KIND_LABEL[match.group("kind")],
        "state": match.group("state"),
        "state_label": STATE_LABEL[match.group("state")],
        "tone": STATE_TONE[match.group("state")],
        "board": match.group("board"),
        "slug": match.group("slug"),
        "title": title,
        "summary": summary,
        "priority": match.group("priority") or "",
        "priority_rank": PRIORITY_RANK.get(match.group("priority") or "", 9),
        "path": str(rel_path),
        "file_url": path.resolve().as_uri(),
        "modified_at": format_iso(stat.st_mtime),
        "modified_display": format_display(stat.st_mtime),
        "modified_epoch": stat.st_mtime,
        "archived": "issues/archive/" in str(rel_path).replace("\\", "/"),
        "owner": frontmatter.get("owner", ""),
        "assignee": frontmatter.get("assignee", ""),
        "reviewer": frontmatter.get("reviewer", ""),
        "risk": frontmatter.get("risk", ""),
        "accept": frontmatter.get("accept", ""),
        "verify": frontmatter.get("verify", ""),
        "code_version": frontmatter.get("code_version", ""),
        "memory": frontmatter.get("memory", "none"),
        "why": frontmatter.get("why", ""),
        "scope": frontmatter.get("scope", ""),
        "links": normalized_links,
    }

    return record


def parse_memory_anchors(memory_file: Path) -> list[str]:
    if not memory_file.is_file():
        return []

    anchors: list[str] = []
    for raw in memory_file.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        match = re.match(r"^锚[:：]\s*(.*)$", line)
        if match:
            value = match.group(1).strip()
            for item in re.split(r"[|,\s]+", value):
                if item:
                    anchors.append(item)
    return anchors


def parse_coauthors(project_root: Path) -> list[dict[str, Any]]:
    coauthors_file = project_root / "coauthors.csv"
    if not coauthors_file.is_file():
        return []

    rows: list[dict[str, Any]] = []
    with coauthors_file.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        now = datetime.now(timezone.utc)
        for row in reader:
            status = (row.get("status") or "").strip()
            updated_at = (row.get("updated_at") or "").strip()
            stale = False
            invalid_time = False

            if status == "online":
                try:
                    updated = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
                    stale = (now - updated.astimezone(timezone.utc)).total_seconds() > STALE_COAUTHOR_SECONDS
                except ValueError:
                    invalid_time = bool(updated_at)
                    stale = True

            rows.append(
                {
                    "handle": (row.get("handle") or "").strip(),
                    "owner": (row.get("owner") or "").strip(),
                    "engine": (row.get("engine") or "").strip(),
                    "role": (row.get("role") or "").strip(),
                    "status": status,
                    "updated_at": updated_at,
                    "note": (row.get("note") or "").strip(),
                    "stale": stale,
                    "invalid_time": invalid_time,
                }
            )
    return rows


######## data model shaping


def collect_docs(project_root: Path) -> list[dict[str, Any]]:
    docs: list[dict[str, Any]] = []
    for base in [project_root / "issues", project_root / "docs" / "reviews"]:
        if not base.exists():
            continue
        for path in sorted(base.rglob("*.md")):
            parsed = parse_doc_file(path, project_root)
            if parsed:
                docs.append(parsed)
    return docs


def sort_docs(docs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        docs,
        key=lambda item: (
            STATE_ORDER.index(item["state"]) if item["state"] in STATE_ORDER else len(STATE_ORDER),
            item["priority_rank"],
            item["doc_id"],
        ),
    )


def build_dashboard(project_root: Path) -> dict[str, Any]:
    docs = collect_docs(project_root)
    anchors = defaultdict(list)
    for doc in docs:
        anchors[doc["anchor_id"]].append(doc)

    memory_file = project_root / "refs" / "project-memory-aaak.md"
    memory_anchors = set(parse_memory_anchors(memory_file))
    coauthors = parse_coauthors(project_root)

    for doc in docs:
        linked_docs = [item for item in doc["links"] if item["exists"]]
        siblings = [
            sibling
            for sibling in anchors[doc["anchor_id"]]
            if sibling["path"] != doc["path"]
        ]
        doc["relation"] = derive_relation_summary(doc, siblings, linked_docs)
        doc["siblings"] = [
            {
                "doc_id": sibling["doc_id"],
                "kind": sibling["kind"],
                "state": sibling["state"],
                "path": sibling["path"],
                "file_url": sibling["file_url"],
            }
            for sibling in sort_docs(siblings)
        ]
        doc["has_memory_anchor"] = doc["doc_id"] in memory_anchors

    current_docs = [doc for doc in docs if not doc["archived"]]
    current_tasks = sort_docs([doc for doc in current_docs if doc["kind"] == "tk"])
    current_non_tasks = sort_docs([doc for doc in current_docs if doc["kind"] in {"pl", "rs", "rf"}])
    review_docs = sort_docs([doc for doc in docs if doc["kind"] == "rp"])
    history_tasks = sorted(
        [doc for doc in docs if doc["kind"] == "tk" and (doc["archived"] or doc["state"] in HISTORY_STATES)],
        key=lambda item: (-item["modified_epoch"], item["doc_id"]),
    )

    current_counts = Counter(doc["state"] for doc in current_tasks)
    active_total = sum(current_counts[state] for state in ACTIVE_STATES)
    done_total = sum(current_counts[state] for state in DONE_STATES)
    cancelled_total = current_counts.get("cand", 0)
    track_total = max(len(current_tasks) - cancelled_total, 1)
    completion_ratio = round(done_total / track_total, 3)

    board_counts = Counter(doc["board"] for doc in current_tasks)
    archive_counts = Counter()
    for doc in docs:
        if doc["archived"]:
            parts = Path(doc["path"]).parts
            if "archive" in parts:
                idx = parts.index("archive")
                if idx + 1 < len(parts):
                    archive_counts[parts[idx + 1]] += 1

    recent_events = sorted(
        [
            {
                "doc_id": doc["doc_id"],
                "kind": doc["kind"],
                "kind_label": doc["kind_label"],
                "state": doc["state"],
                "state_label": doc["state_label"],
                "title": doc["title"],
                "summary": doc["summary"],
                "path": doc["path"],
                "file_url": doc["file_url"],
                "modified_display": doc["modified_display"],
                "modified_epoch": doc["modified_epoch"],
            }
            for doc in docs
        ],
        key=lambda item: (-item["modified_epoch"], item["doc_id"]),
    )
    if memory_file.exists():
        stat = memory_file.stat()
        recent_events.append(
            {
                "doc_id": "mem",
                "kind": "mem",
                "kind_label": "记忆",
                "state": "dne",
                "state_label": "历史记忆",
                "title": "project-memory-aaak",
                "summary": f"{len(memory_anchors)} anchors",
                "path": str(memory_file.relative_to(project_root)),
                "file_url": memory_file.resolve().as_uri(),
                "modified_display": format_display(stat.st_mtime),
                "modified_epoch": stat.st_mtime,
            }
        )
    recent_events = sorted(recent_events, key=lambda item: (-item["modified_epoch"], item["doc_id"]))[:60]

    memory_watch = [
        doc
        for doc in current_tasks
        if doc["memory"] in {"required", "done"}
    ]
    stale_coauthors = [row for row in coauthors if row["status"] == "online" and row["stale"]]

    return {
        "project": {
            "name": project_root.name,
            "root": str(project_root.resolve()),
            "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
            "generated_display": datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S"),
            "template_version": "2026.04.11",
        },
        "current": {
            "metrics": {
                "task_total": len(current_tasks),
                "active_total": active_total,
                "review_total": current_counts.get("rvw", 0),
                "blocked_total": current_counts.get("bkd", 0),
                "done_total": done_total,
                "cancelled_total": cancelled_total,
                "completion_ratio": completion_ratio,
                "review_doc_total": len(review_docs),
                "non_task_total": len(current_non_tasks),
                "stale_coauthor_total": len(stale_coauthors),
            },
            "state_counts": [
                {
                    "state": state,
                    "label": STATE_LABEL[state],
                    "count": current_counts.get(state, 0),
                    "tone": STATE_TONE[state],
                }
                for state in STATE_ORDER
            ],
            "board_counts": [
                {"board": board, "count": count}
                for board, count in sorted(board_counts.items(), key=lambda item: (-item[1], item[0]))
            ],
            "tasks": current_tasks,
            "non_tasks": current_non_tasks,
            "memory_watch": memory_watch,
            "stale_coauthors": stale_coauthors,
            "coauthors": coauthors,
        },
        "history": {
            "closed_tasks": history_tasks,
            "archive_years": [
                {"year": year, "count": count}
                for year, count in sorted(archive_counts.items(), key=lambda item: item[0], reverse=True)
            ],
            "recent_events": recent_events,
            "memory_file": {
                "path": str(memory_file.relative_to(project_root)) if memory_file.exists() else "refs/project-memory-aaak.md",
                "file_url": memory_file.resolve().as_uri() if memory_file.exists() else "",
                "exists": memory_file.exists(),
                "anchors": sorted(memory_anchors),
            },
        },
    }


######## rendering


def inject_template(template: str, payload: dict[str, Any]) -> str:
    data_text = json.dumps(payload, ensure_ascii=False).replace("</", "<\\/")
    return (
        template
        .replace("__AGATA_PROGRESS_DATA__", data_text)
        .replace("__AGATA_PROJECT_NAME__", payload["project"]["name"])
        .replace("__AGATA_GENERATED_AT__", payload["project"]["generated_display"])
    )


def write_outputs(out_dir: Path, payload: dict[str, Any], template: str) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    data_path = out_dir / "progress-data.json"
    html_path = out_dir / "progress-view.html"

    data_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    html_path.write_text(inject_template(template, payload), encoding="utf-8")
    return data_path, html_path


def maybe_open(html_path: Path, should_open: bool) -> bool:
    if not should_open:
        return False

    if shutil.which("open"):
        subprocess.run(["open", str(html_path)], check=False)
        return True

    return webbrowser.open(html_path.resolve().as_uri())


######## cli


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate a dense static HTML snapshot for an Agata workflow project."
    )
    parser.add_argument("--project-root", help="Project root that contains issues/")
    parser.add_argument(
        "--out-dir",
        help="Output directory. Defaults to <project>/AIDOCS/agata-workflow-status",
    )
    parser.add_argument("--template", help="Override the bundled HTML template")
    parser.add_argument("--no-open", action="store_true", help="Generate files without opening the browser")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    script_path = Path(__file__)
    project_root = find_project_root(Path(args.project_root) if args.project_root else Path.cwd())
    out_dir = Path(args.out_dir).expanduser().resolve() if args.out_dir else project_root / "AIDOCS" / "agata-workflow-status"

    payload = build_dashboard(project_root)
    template = load_template(script_path, args.template)
    data_path, html_path = write_outputs(out_dir, payload, template)
    opened = maybe_open(html_path, not args.no_open)

    print(f"data: {data_path}")
    print(f"html: {html_path}")
    print(f"opened: {'yes' if opened else 'no'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
