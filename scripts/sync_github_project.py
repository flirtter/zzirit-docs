#!/usr/bin/env python3

import json
import subprocess
from pathlib import Path
from typing import Dict, List, Optional


ROOT = Path(__file__).resolve().parents[1]
SEED_PATH = ROOT / "snapshots" / "project-board-seed.json"
REPO = "ahg0223/zzirit-memory-hub"
OWNER = "@me"


def gh(*args: str) -> str:
    result = subprocess.run(
        ["gh", *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def ensure_project(title: str) -> dict:
    payload = json.loads(gh("project", "list", "--owner", OWNER, "--format", "json"))
    for project in payload["projects"]:
        if project["title"] == title:
            return project
    created = json.loads(
        gh("project", "create", "--owner", OWNER, "--title", title, "--format", "json")
    )
    return created


def project_fields(number: int) -> dict:
    payload = json.loads(gh("project", "field-list", str(number), "--owner", OWNER, "--format", "json"))
    fields = {}
    for field in payload["fields"]:
        fields[field["name"]] = field
    return fields


def ensure_field(number: int, name: str, data_type: str, options: Optional[List[str]] = None) -> None:
    fields = project_fields(number)
    if name in fields:
        return
    cmd = [
        "project",
        "field-create",
        str(number),
        "--owner",
        OWNER,
        "--name",
        name,
        "--data-type",
        data_type,
    ]
    if options:
        cmd.extend(["--single-select-options", ",".join(options)])
    gh(*cmd)


def option_id(field: dict, name: str) -> Optional[str]:
    for option in field.get("options", []):
        if option["name"] == name:
            return option["id"]
    return None


def item_map(number: int) -> Dict[int, str]:
    payload = json.loads(gh("project", "item-list", str(number), "--owner", OWNER, "--format", "json"))
    mapping = {}
    for item in payload["items"]:
        content = item.get("content") or {}
        issue_number = content.get("number")
        if issue_number:
            mapping[int(issue_number)] = item["id"]
    return mapping


def add_issue_item(number: int, issue_url: str) -> str:
    payload = json.loads(
        gh("project", "item-add", str(number), "--owner", OWNER, "--url", issue_url, "--format", "json")
    )
    return payload["id"]


def edit_single_select(project_id: str, item_id: str, field_id: str, option_id_value: str) -> None:
    gh(
        "project",
        "item-edit",
        "--id",
        item_id,
        "--project-id",
        project_id,
        "--field-id",
        field_id,
        "--single-select-option-id",
        option_id_value,
    )


def edit_text(project_id: str, item_id: str, field_id: str, text: str) -> None:
    gh(
        "project",
        "item-edit",
        "--id",
        item_id,
        "--project-id",
        project_id,
        "--field-id",
        field_id,
        "--text",
        text,
    )


def main() -> None:
    project = ensure_project("ZZIRIT Delivery")
    project_number = project["number"]
    project_id = project["id"]

    ensure_field(project_number, "Work State", "SINGLE_SELECT", ["Todo", "In Progress", "QA", "Blocked", "Done"])
    ensure_field(project_number, "Surface", "SINGLE_SELECT", ["login", "onboarding", "my", "likes", "meeting", "chat", "lightning", "automation"])
    ensure_field(project_number, "Type", "SINGLE_SELECT", ["design", "qa", "automation", "refactor", "infra", "task"])
    ensure_field(project_number, "QA Level", "SINGLE_SELECT", ["manual", "appium", "host_qa", "strict"])
    ensure_field(project_number, "Design Gate", "SINGLE_SELECT", ["missing", "partial", "pass"])
    ensure_field(project_number, "Automation", "SINGLE_SELECT", ["none", "partial", "full"])
    ensure_field(project_number, "Priority", "SINGLE_SELECT", ["P0", "P1", "P2", "P3"])
    ensure_field(project_number, "Spec", "TEXT")
    ensure_field(project_number, "Artifacts", "TEXT")
    ensure_field(project_number, "Blocker", "TEXT")

    fields = project_fields(project_number)
    items = item_map(project_number)
    rows = json.loads(SEED_PATH.read_text())

    default_status_field = fields["Status"]
    work_state_field = fields["Work State"]

    for row in rows:
        issue_number = int(row["Issue"])
        item_id = items.get(issue_number)
        if not item_id:
            item_id = add_issue_item(project_number, row["URL"])
            items[issue_number] = item_id

        status_value = row["Status"]
        default_status_value = status_value if status_value in {"Todo", "In Progress", "Done"} else "In Progress"
        for field_name, value in [
            ("Status", default_status_value),
            ("Work State", status_value),
            ("Surface", row["Surface"]),
            ("Type", row["Type"]),
            ("QA Level", row["QA Level"]),
            ("Design Gate", row["Design Gate"]),
            ("Automation", row["Automation"]),
            ("Priority", row["Priority"]),
        ]:
            field = default_status_field if field_name == "Status" else work_state_field if field_name == "Work State" else fields[field_name]
            option = option_id(field, value)
            if option:
                edit_single_select(project_id, item_id, field["id"], option)

        surface = row["Surface"]
        spec_name = "automation.md" if surface == "automation" else f"{surface}.md"
        spec_path = f"references/surface-specs/{spec_name}"
        edit_text(project_id, item_id, fields["Spec"]["id"], spec_path)
        edit_text(project_id, item_id, fields["Artifacts"]["id"], "snapshots/qa-status.md")

    print(f"synced project {project_number}: {project['url']}")


if __name__ == "__main__":
    main()
