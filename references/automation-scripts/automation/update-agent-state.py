#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path


DEFAULT_QUEUE = {
    "version": 1,
    "active_task_id": "qa-automation",
    "tasks": [
        {
            "id": "likes",
            "title": "Likes polish and QA",
            "section": "likes",
            "status": "done",
            "required_passes": 1,
            "blocked_threshold": 3,
        },
        {
            "id": "meeting",
            "title": "Meeting polish and QA",
            "section": "meeting",
            "status": "done",
            "required_passes": 1,
            "blocked_threshold": 3,
        },
        {
            "id": "qa-automation",
            "title": "QA automation stabilization",
            "section": "automation",
            "status": "in_progress",
            "required_passes": 2,
            "blocked_threshold": 3,
        },
        {
            "id": "chat",
            "title": "Chat polish and QA",
            "section": "chat",
            "status": "pending",
            "required_passes": 1,
            "blocked_threshold": 3,
        },
    ],
}

UI_SECTIONS = {"login", "onboarding", "lightning", "meeting", "chat", "likes", "my"}
SURFACE_SPEC_MANIFEST = Path("/Users/user/zzirit-v2/docs/spec/surfaces/manifest.json")
FOLLOWUP_PRIORITY = [
    "automation",
    "chat",
    "my",
    "onboarding",
    "login",
    "meeting",
    "likes",
]


def load_json(path: Path, default: dict) -> dict:
    if not path.exists():
        return json.loads(json.dumps(default))
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return json.loads(json.dumps(default))
    return data if isinstance(data, dict) else json.loads(json.dumps(default))


def find_task(queue: dict, task_id: str | None) -> dict | None:
    if not task_id:
        return None
    for task in queue.get("tasks", []):
        if isinstance(task, dict) and task.get("id") == task_id:
            return task
    return None


def choose_next_task(queue: dict) -> dict | None:
    for task in queue.get("tasks", []):
        if not isinstance(task, dict):
            continue
        if task.get("status") in {"pending", "queued", "in_progress"}:
            return task
    return None


def load_surface_specs(path: Path) -> dict[str, dict]:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    surfaces = data.get("surfaces") if isinstance(data, dict) else None
    if not isinstance(surfaces, list):
        return {}
    spec_map: dict[str, dict] = {}
    for item in surfaces:
        if not isinstance(item, dict):
            continue
        surface_id = str(item.get("id", "")).strip()
        if surface_id:
            spec_map[surface_id] = item
    return spec_map


def normalize_queue_tasks(queue: dict, spec_map: dict[str, dict]) -> dict:
    tasks = queue.get("tasks", [])
    if not isinstance(tasks, list):
        return queue
    valid_sections = UI_SECTIONS | {"automation", "server"}
    for task in tasks:
        if not isinstance(task, dict):
            continue
        source_surface = str(task.get("source_surface", "")).strip()
        task_id = str(task.get("id", "")).strip()
        if source_surface and source_surface in valid_sections:
            task["section"] = source_surface
            continue
        if task_id in spec_map and task_id in valid_sections:
            task["section"] = task_id
    return queue


def maybe_append_followup_tasks(queue: dict, spec_map: dict[str, dict], now: str) -> dict:
    tasks = [task for task in queue.get("tasks", []) if isinstance(task, dict)]
    if any(task.get("status") in {"in_progress", "pending", "queued"} for task in tasks):
        return queue

    existing_ids = {str(task.get("id", "")).strip() for task in tasks}
    appended = []

    for surface_id in FOLLOWUP_PRIORITY:
        spec = spec_map.get(surface_id, {})
        if not spec:
            continue
        if str(spec.get("current_state", "")).strip() == "blocked":
            continue
        next_step = str(spec.get("next_step", "")).strip()
        if not next_step:
            continue
        task_id = f"{surface_id}-followup"
        if task_id in existing_ids:
            continue
        section = surface_id
        appended.append(
            {
                "id": task_id,
                "title": f"{surface_id.replace('-', ' ').title()} follow-up",
                "section": section,
                "status": "pending",
                "required_passes": 1,
                "blocked_threshold": 3,
                "source_surface": surface_id,
                "source_next_step": next_step,
                "created_at": now,
            }
        )
        existing_ids.add(task_id)

    if appended:
        queue.setdefault("tasks", []).extend(appended)
    return queue


def ensure_agent_state(queue: dict, state: dict) -> dict:
    task_state = state.setdefault("tasks", {})
    for task in queue.get("tasks", []):
        if not isinstance(task, dict):
            continue
        task_state.setdefault(
            task["id"],
            {
                "success_streak": 0,
                "blocked_streak": 0,
                "last_status": "pending",
                "last_run_id": None,
            },
        )
    state.setdefault("history", [])
    return state


def derive_result_status(result: dict, task: dict | None) -> str:
    run_state = str(result.get("state", "unknown"))
    exit_code = int(result.get("exit_code", 0) or 0)
    host_qa_status = str(result.get("host_qa_status", "skipped"))
    design_result_status = str(result.get("design_result_status", "skipped"))
    section = str(task.get("section", "")) if task else ""

    if run_state == "success" and exit_code == 0:
        if section in {"automation", "server"}:
            return "pass"
        if section in UI_SECTIONS:
            if design_result_status == "pass":
                return "pass"
            if design_result_status == "blocked":
                return "blocked"
            if host_qa_status in {"pass", "completed", "success"}:
                return "partial"
            return "blocked"
        if host_qa_status in {"pass", "completed", "success", "skipped"}:
            return "pass"
        return "partial"

    if host_qa_status in {"blocked", "failure"} or design_result_status == "blocked" or run_state == "failure" or exit_code != 0:
        return "blocked"

    return "partial"


def render_next_action(queue: dict, state: dict) -> str:
    active_task = find_task(queue, queue.get("active_task_id"))
    pending = [
        task
        for task in queue.get("tasks", [])
        if isinstance(task, dict) and task.get("status") in {"pending", "queued", "in_progress"}
    ]
    next_pending = next(
        (
            task
            for task in pending
            if not active_task or task.get("id") != active_task.get("id")
        ),
        None,
    )
    lines = ["# Next Action", ""]

    if active_task:
        task_state = state.get("tasks", {}).get(active_task.get("id"), {})
        lines.extend(
            [
                f"- active_task_id: {active_task.get('id', 'none')}",
                f"- title: {active_task.get('title', 'none')}",
                f"- section: {active_task.get('section', 'none')}",
                f"- queue_status: {active_task.get('status', 'unknown')}",
                f"- success_streak: {task_state.get('success_streak', 0)} / {active_task.get('required_passes', 1)}",
                f"- blocked_streak: {task_state.get('blocked_streak', 0)} / {active_task.get('blocked_threshold', 3)}",
            ]
        )
    else:
        lines.append("- active_task_id: none")

    lines.append("")
    lines.append("## Queue")
    for task in queue.get("tasks", []):
        if not isinstance(task, dict):
            continue
        lines.append(
            f"- {task.get('id')}: {task.get('status', 'unknown')} ({task.get('section', 'none')})"
        )

    if next_pending:
        lines.append("")
        lines.append(f"- next_pending_task: {next_pending.get('id', 'none')}")

    return "\n".join(lines) + "\n"


def main() -> int:
    if len(sys.argv) != 5:
        raise SystemExit(
            "usage: update-agent-state.py <task-queue.json> <agent-state.json> <next-action.md> <result.json>"
        )

    queue_path = Path(sys.argv[1])
    state_path = Path(sys.argv[2])
    next_action_path = Path(sys.argv[3])
    result_path = Path(sys.argv[4])

    queue = load_json(queue_path, DEFAULT_QUEUE)
    state = ensure_agent_state(queue, load_json(state_path, {}))
    result = load_json(result_path, {})
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    spec_map = load_surface_specs(SURFACE_SPEC_MANIFEST)
    queue = normalize_queue_tasks(queue, spec_map)

    has_result = result_path.exists() and bool(result)

    task = find_task(queue, result.get("task_id")) if has_result else None
    if has_result and not task and queue.get("active_task_id"):
        task = find_task(queue, queue.get("active_task_id"))

    if has_result and task:
        task_state = state["tasks"].setdefault(task["id"], {})
        derived_status = derive_result_status(result, task)
        task_state["last_status"] = derived_status
        task_state["last_run_id"] = result.get("run_id")
        task_state["last_updated_at"] = now

        if derived_status == "pass":
            task_state["success_streak"] = int(task_state.get("success_streak", 0) or 0) + 1
            task_state["blocked_streak"] = 0
            if task.get("status") != "done" and task_state["success_streak"] >= int(task.get("required_passes", 1) or 1):
                task["status"] = "done"
                task["completed_at"] = now
                if queue.get("active_task_id") == task.get("id"):
                    next_task = choose_next_task(queue)
                    if next_task and next_task.get("id") == task.get("id"):
                        remaining = [
                            item
                            for item in queue.get("tasks", [])
                            if isinstance(item, dict) and item.get("status") in {"pending", "queued", "in_progress"}
                        ]
                        next_task = remaining[0] if remaining else None
                    if next_task:
                        next_task["status"] = "in_progress"
                        next_task.setdefault("started_at", now)
                        queue["active_task_id"] = next_task.get("id")
                    else:
                        queue["active_task_id"] = None
        elif derived_status == "blocked":
            task_state["success_streak"] = 0
            task_state["blocked_streak"] = int(task_state.get("blocked_streak", 0) or 0) + 1
            if task_state["blocked_streak"] >= int(task.get("blocked_threshold", 3) or 3):
                task["status"] = "blocked"
                task["blocked_at"] = now
                if queue.get("active_task_id") == task.get("id"):
                    next_task = choose_next_task(queue)
                    if next_task and next_task.get("id") == task.get("id"):
                        remaining = [
                            item
                            for item in queue.get("tasks", [])
                            if isinstance(item, dict) and item.get("status") in {"pending", "queued", "in_progress"}
                        ]
                        next_task = remaining[0] if remaining else None
                    if next_task:
                        next_task["status"] = "in_progress"
                        next_task.setdefault("started_at", now)
                        queue["active_task_id"] = next_task.get("id")
                    else:
                        queue["active_task_id"] = None
        else:
            task_state.setdefault("success_streak", 0)
            task_state.setdefault("blocked_streak", 0)

        state.setdefault("history", []).append(
            {
                "run_id": result.get("run_id"),
                "task_id": task.get("id"),
                "derived_status": derived_status,
                "state": result.get("state"),
                "host_qa_status": result.get("host_qa_status"),
                "design_result_status": result.get("design_result_status"),
                "recorded_at": now,
            }
        )
        state["history"] = state["history"][-20:]

    queue = maybe_append_followup_tasks(queue, spec_map, now)
    state = ensure_agent_state(queue, state)

    if not queue.get("active_task_id"):
        next_task = choose_next_task(queue)
        if next_task:
            next_task["status"] = "in_progress"
            next_task.setdefault("started_at", now)
            queue["active_task_id"] = next_task.get("id")

    state["current_task_id"] = queue.get("active_task_id")
    if has_result:
        state["last_run_id"] = result.get("run_id")
        state["last_result_path"] = str(result_path)
    state["updated_at"] = now

    queue_path.write_text(json.dumps(queue, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    state_path.write_text(json.dumps(state, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    next_action_path.write_text(render_next_action(queue, state), encoding="utf-8")

    print(json.dumps({
        "active_task_id": queue.get("active_task_id"),
        "next_action_path": str(next_action_path),
        "agent_state_path": str(state_path),
        "task_queue_path": str(queue_path),
    }, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
