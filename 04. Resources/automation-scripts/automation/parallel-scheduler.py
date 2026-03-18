#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return value if isinstance(value, dict) else {}


def parse_status_markdown(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("- "):
            continue
        if ":" not in line:
            continue
        key, value = line[2:].split(":", 1)
        values[key.strip()] = value.strip()
    return values


def parse_timestamp(value: str) -> int | None:
    if not value:
        return None
    try:
        return int(datetime.strptime(value, "%Y-%m-%d %H:%M:%S").timestamp())
    except ValueError:
        return None


def file_mtime_bucket(path: Path, cooldown_seconds: int) -> str:
    if not path.exists():
        return "missing"
    return str(int(path.stat().st_mtime // max(cooldown_seconds, 1)))


def now_timestamp() -> int:
    return int(datetime.now().timestamp())


def effective_main_state(
    worker: dict,
    automation_status_file: Path,
    automation_status: dict[str, str],
) -> tuple[str, str]:
    state = automation_status.get("state", "")
    if state != "running":
        return state, "state-not-running"

    stale_seconds = int(worker.get("main_run_stale_seconds", 7200))
    started_at = parse_timestamp(automation_status.get("started_at", ""))
    if started_at is not None and now_timestamp() - started_at > stale_seconds:
        return "stale-running", "started_at-stale"

    if automation_status_file.exists():
        age_seconds = now_timestamp() - int(automation_status_file.stat().st_mtime)
        if age_seconds > stale_seconds:
            return "stale-running", "status-file-stale"

    return state, "fresh-running"


def ready_gemini_review(
    worker: dict,
    artifact_root: Path,
    automation_status_file: Path,
    automation_status: dict[str, str],
) -> tuple[bool, str]:
    cooldown_seconds = int(worker.get("cooldown_seconds", 900))
    max_running_seconds = int(worker.get("max_running_seconds", max(cooldown_seconds, 900)))
    run_id = automation_status.get("run_id", "")
    state, _state_reason = effective_main_state(worker, automation_status_file, automation_status)
    control = load_json(artifact_root / worker["key"] / "control.json")
    worker_status = parse_status_markdown(artifact_root / worker["key"] / "status.md")

    if not run_id or not state:
        return False, "missing-main-run"

    if state == "running":
        return False, "wait-main-complete"

    trigger = f"{run_id}:{state}"

    worker_state = worker_status.get("state", "")
    worker_trigger = worker_status.get("trigger", "")
    worker_started_at = parse_timestamp(worker_status.get("started_at", ""))
    worker_age = (
        None if worker_started_at is None else now_timestamp() - worker_started_at
    )
    worker_running_recent = worker_age is None or worker_age < max_running_seconds
    same_active_run = worker_trigger.startswith(f"{run_id}:running:")

    # Avoid spawning duplicate review workers while the current one is still active.
    if worker_state == "running" and worker_running_recent:
        if worker_trigger == trigger:
            return False, "worker-running-same-trigger"
        if same_active_run:
            return False, "worker-running-same-run"

    if control.get("last_trigger") == trigger:
        return False, "already-reviewed"

    return True, trigger


def ready_gemini_coder(
    worker: dict,
    artifact_root: Path,
    automation_status_file: Path,
    automation_status: dict[str, str],
) -> tuple[bool, str]:
    cooldown_seconds = int(worker.get("cooldown_seconds", 1800))
    control = load_json(artifact_root / worker["key"] / "control.json")
    last_finished_at = int(control.get("last_finished_at_ts", 0) or 0)
    active_focus = automation_status.get("focus_section", "none")
    main_state, _state_reason = effective_main_state(worker, automation_status_file, automation_status)
    now_ts = now_timestamp()

    if main_state not in {"running", "success"}:
        return False, "main-not-active"

    if last_finished_at and now_ts - last_finished_at < cooldown_seconds:
        return False, "cooldown"

    trigger = f"{active_focus}:{now_ts // max(cooldown_seconds, 1)}"
    if control.get("last_trigger") == trigger:
        return False, "already-ran-bucket"

    return True, trigger


def main() -> int:
    if len(sys.argv) < 5:
        raise SystemExit(
            "usage: parallel-scheduler.py <spec-file> <artifact-root> <automation-status> <max-workers>"
        )

    spec_file = Path(sys.argv[1])
    artifact_root = Path(sys.argv[2])
    automation_status_file = Path(sys.argv[3])
    max_workers = int(sys.argv[4])

    data = json.loads(spec_file.read_text(encoding="utf-8"))
    workers = data.get("workers", []) if isinstance(data, dict) else data
    automation_status = parse_status_markdown(automation_status_file)

    ready_items: list[dict[str, str | int]] = []
    for worker in workers:
        if not worker.get("enabled", True):
            continue
        runner = worker.get("runner", "codex")
        if runner == "gemini-review":
            ready, trigger = ready_gemini_review(
                worker,
                artifact_root,
                automation_status_file,
                automation_status,
            )
        elif runner == "gemini-coder":
            ready, trigger = ready_gemini_coder(
                worker,
                artifact_root,
                automation_status_file,
                automation_status,
            )
        else:
            ready, trigger = False, "unsupported-runner"

        if ready:
            ready_items.append(
                {
                    "key": worker.get("key", ""),
                    "priority": int(worker.get("priority", 0)),
                    "trigger": trigger,
                }
            )

    ready_items.sort(key=lambda item: int(item["priority"]), reverse=True)
    payload = {"ready": ready_items[:max_workers]}
    print(json.dumps(payload, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
