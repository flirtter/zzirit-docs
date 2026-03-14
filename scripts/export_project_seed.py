#!/usr/bin/env python3

import csv
import json
import re
import subprocess
from pathlib import Path


REPO = "ahg0223/zzirit-memory-hub"
ROOT = Path(__file__).resolve().parents[1]
OUT_JSON = ROOT / "snapshots" / "project-board-seed.json"
OUT_CSV = ROOT / "snapshots" / "project-board-seed.csv"
CURRENT_STATE = ROOT / "snapshots" / "current-state.json"


def run_gh(*args: str) -> str:
    result = subprocess.run(
        ["gh", *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def infer_surface(labels: list[str], title: str) -> str:
    for label in labels:
        if label.startswith("surface:"):
            return label.split(":", 1)[1]
    match = re.match(r"^\[([a-z0-9-]+)\]", title)
    if not match:
        return "unknown"
    slug = match.group(1)
    if slug.endswith("-followup"):
        return slug[: -len("-followup")]
    if slug.startswith("meeting-"):
        return "meeting"
    if slug.startswith("likes-"):
        return "likes"
    if slug.startswith("onboarding-"):
        return "onboarding"
    if slug.startswith("login-"):
        return "login"
    if slug.startswith("my-"):
        return "my"
    if slug.startswith("chat-"):
        return "chat"
    return "unknown"


def infer_type(labels: list[str]) -> str:
    if "automation" in labels:
        return "automation"
    if "refactor" in labels:
        return "refactor"
    if "qa" in labels:
        return "qa"
    if "design-gap" in labels:
        return "design"
    return "task"


def infer_status(body: str) -> str:
    if "current queue status: `in_progress`" in body:
        return "In Progress"
    if "current queue status: `pending`" in body:
        return "Todo"
    return "Todo"


def infer_design_gate(labels: list[str]) -> str:
    if "design-gap" in labels:
        return "partial"
    return "missing"


def infer_automation(labels: list[str]) -> str:
    if "automation" in labels:
        return "partial"
    return "none"


def load_current_state() -> dict:
    if not CURRENT_STATE.exists():
        return {}
    return json.loads(CURRENT_STATE.read_text())


def main() -> None:
    issues = json.loads(
        run_gh(
            "issue",
            "list",
            "-R",
            REPO,
            "--state",
            "open",
            "--limit",
            "200",
            "--json",
            "number,title,body,labels,url",
        )
    )
    current_state = load_current_state()
    active_task = (
        current_state.get("automation", {})
        .get("current_task", {})
        .get("task_id")
    )

    rows = []
    for issue in issues:
        labels = [label["name"] for label in issue["labels"]]
        surface = infer_surface(labels, issue["title"])
        status = infer_status(issue["body"])
        if active_task and issue["title"].startswith(f"[{active_task}]"):
            status = "In Progress"
        row = {
            "Issue": issue["number"],
            "Title": issue["title"],
            "URL": issue["url"],
            "Surface": surface,
            "Type": infer_type(labels),
            "Status": status,
            "QA Level": "host_qa" if "qa" in labels else "manual",
            "Design Gate": infer_design_gate(labels),
            "Automation": infer_automation(labels),
            "Priority": "P1" if status == "In Progress" else "P2",
            "Labels": ", ".join(labels),
        }
        rows.append(row)

    rows.sort(key=lambda row: row["Issue"])

    OUT_JSON.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n")
    with OUT_CSV.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()) if rows else [])
        if rows:
            writer.writeheader()
            writer.writerows(rows)

    print(f"wrote {OUT_JSON}")
    print(f"wrote {OUT_CSV}")


if __name__ == "__main__":
    main()
