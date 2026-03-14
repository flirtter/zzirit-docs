#!/bin/zsh
set -euo pipefail

ROOT="${ZZIRIT_AUTOMATION_ROOT:-/Users/user/zzirit-v2}"
ARTIFACT_DIR="$ROOT/artifacts/automation"
STATUS_FILE="$ARTIFACT_DIR/status.md"
MONITOR_LOG="$ARTIFACT_DIR/monitor.log"
ERROR_LOG="$ARTIFACT_DIR/errors.log"
LATEST_ERROR="$ARTIFACT_DIR/latest-error.md"
HEALTH_FILE="$ARTIFACT_DIR/health.md"
ACTIVITY_FILE="$ARTIFACT_DIR/current-activity.md"
STATE_FILE="$ARTIFACT_DIR/monitor-state.json"
MAX_RUNNING_MINUTES="${ZZIRIT_AUTOMATION_MAX_RUNNING_MINUTES:-150}"
MAX_IDLE_MINUTES="${ZZIRIT_AUTOMATION_MAX_IDLE_MINUTES:-45}"

mkdir -p "$ARTIFACT_DIR"
touch "$MONITOR_LOG" "$ERROR_LOG"

python3 - "$STATUS_FILE" "$MONITOR_LOG" "$ERROR_LOG" "$LATEST_ERROR" "$HEALTH_FILE" "$ACTIVITY_FILE" "$STATE_FILE" "$MAX_RUNNING_MINUTES" "$MAX_IDLE_MINUTES" <<'PY'
from __future__ import annotations

import json
import re
import sys
from datetime import datetime
from pathlib import Path

status_path = Path(sys.argv[1])
monitor_log = Path(sys.argv[2])
error_log = Path(sys.argv[3])
latest_error = Path(sys.argv[4])
health_file = Path(sys.argv[5])
activity_file = Path(sys.argv[6])
state_file = Path(sys.argv[7])
max_running_minutes = int(sys.argv[8])
max_idle_minutes = int(sys.argv[9])
secret_pattern = re.compile(r"FIGMA_API_KEY=|===== \.automation\.env =====")


def now() -> datetime:
    return datetime.now()


def append(path: Path, text: str) -> None:
    with path.open("a", encoding="utf-8") as handle:
        handle.write(text)


def parse_status(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}

    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"- ([^:]+):\s*(.*)$", line.strip())
        if match:
            values[match.group(1).strip()] = match.group(2).strip()
    return values


def parse_time(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None


def minutes_since(value: datetime | None) -> int | None:
    if value is None:
        return None
    return int((now() - value).total_seconds() // 60)


def load_state(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            return {str(key): str(value) for key, value in data.items()}
    except json.JSONDecodeError:
        return {}
    return {}


def contains_secret(path: Path | None) -> bool:
    if path is None or not path.exists():
        return False
    try:
        return bool(secret_pattern.search(path.read_text(encoding="utf-8", errors="ignore")))
    except OSError:
        return False


def safe_read(path: Path | None) -> str:
    if path is None or not path.exists():
        return ""
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def last_nonempty_lines(text: str, count: int) -> list[str]:
    lines = [line for line in text.splitlines() if line.strip()]
    return lines[-count:]


def find_model_review_summary(run_dir: Path | None) -> Path | None:
    if run_dir is None:
        return None
    review_log = run_dir / "model-review.log"
    if not review_log.exists():
        return None
    lines = [line.strip() for line in safe_read(review_log).splitlines() if line.strip()]
    if not lines:
        return None
    candidate = Path(lines[-1])
    if candidate.exists():
        return candidate
    return None


def summarize_activity(
    automation_state: str,
    run_id: str,
    run_dir: Path | None,
    latest_output: Path | None,
) -> str:
    current_output = run_dir / "codex-output.log" if run_dir else None
    current_summary = run_dir / "last-message.md" if run_dir else None
    current_model_review = find_model_review_summary(run_dir)
    current_output_text = safe_read(current_output)
    current_summary_text = safe_read(current_summary)
    current_model_review_text = safe_read(current_model_review)

    lines = [
        "# Current Automation Activity",
        "",
        f"- checked_at: {current_time}",
        f"- state: {automation_state}",
        f"- run_id: {run_id}",
    ]
    if run_dir:
        lines.append(f"- run_dir: {run_dir}")
    focus_section = status.get("focus_section", "")
    if focus_section and focus_section != "none":
        lines.append(f"- focus_section: {focus_section}")
    focus_label = status.get("focus_label", "")
    if focus_label and focus_label != "none":
        lines.append(f"- focus_label: {focus_label}")
    focus_target = status.get("focus_target", "")
    if focus_target and focus_target != "none":
        lines.append(f"- focus_target: {focus_target}")
    focus_goal = status.get("focus_goal", "")
    if focus_goal and focus_goal != "none":
        lines.append(f"- focus_goal: {focus_goal}")
    focus_started_at = status.get("focus_started_at", "")
    if focus_started_at and focus_started_at != "none":
        lines.append(f"- focus_started_at: {focus_started_at}")
    focus_expires_at = status.get("focus_expires_at", "")
    if focus_expires_at and focus_expires_at != "none":
        lines.append(f"- focus_expires_at: {focus_expires_at}")
    lines.append("")

    if automation_state == "running":
        lines.append("## Current Run")
        lines.append("")
        if current_output_text:
            lines.extend(last_nonempty_lines(current_output_text, 40))
        else:
            lines.append("No current output yet.")
    else:
        lines.append("## Latest Completed Summary")
        lines.append("")
        if current_summary_text:
            lines.append(current_summary_text.strip())
        elif latest_output is not None and latest_output.exists():
            lines.extend(last_nonempty_lines(safe_read(latest_output), 40))
        else:
            lines.append("No completed summary available.")

    lines.append("")
    lines.append("## Advisory Gemini Review")
    lines.append("")
    if current_model_review and current_model_review_text:
        lines.append(f"- summary: {current_model_review}")
        lines.append("")
        lines.append(current_model_review_text.strip())
    elif run_dir and (run_dir / "model-review.log").exists():
        lines.append("- status: pending or unavailable")
        lines.append("- note: advisory only; main QA is not blocked")
        lines.extend(last_nonempty_lines(safe_read(run_dir / "model-review.log"), 20))
    else:
        lines.append("No advisory review artifact yet. Main QA is not blocked.")

    lines.append("")
    return "\n".join(lines) + "\n"


def save_state(path: Path, values: dict[str, str]) -> None:
    path.write_text(json.dumps(values, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")


status = parse_status(status_path)
state = load_state(state_file)
current_time = now().strftime("%Y-%m-%d %H:%M:%S")
run_id = status.get("run_id", "unknown")
automation_state = status.get("state", "missing")
started_at = parse_time(status.get("started_at"))
finished_at = parse_time(status.get("finished_at"))
run_dir = Path(status.get("run_dir", "")) if status.get("run_dir") else None
latest_output = Path(status.get("latest_output", "")) if status.get("latest_output") else None
current_output = run_dir / "codex-output.log" if run_dir else None

issue_kind = ""
issue_message = ""

if not status:
    issue_kind = "missing-status"
    issue_message = "status file is missing"
elif contains_secret(current_output) or contains_secret(latest_output):
    issue_kind = "secret-leak"
    issue_message = f"secret material detected in automation logs (run_id={run_id})"
elif automation_state == "failure":
    issue_kind = "batch-failure"
    issue_message = f"latest run failed (run_id={run_id})"
elif automation_state == "running":
    age = minutes_since(started_at)
    if age is None:
        issue_kind = "running-without-start-time"
        issue_message = f"running state is missing started_at (run_id={run_id})"
    elif age > max_running_minutes:
        issue_kind = "stale-running"
        issue_message = f"run_id={run_id} has been running for {age} minutes"
elif automation_state == "success":
    age = minutes_since(finished_at)
    if age is None:
        issue_kind = "success-without-finish-time"
        issue_message = f"success state is missing finished_at (run_id={run_id})"
    elif age > max_idle_minutes:
        issue_kind = "stale-idle"
        issue_message = f"no fresh automation run for {age} minutes (last run_id={run_id})"
else:
    issue_kind = "unknown-state"
    issue_message = f"unknown automation state: {automation_state}"

fingerprint = f"{issue_kind}:{run_id}" if issue_kind else ""
last_issue = state.get("last_issue", "")

if issue_kind:
    append(
        monitor_log,
        f"[{current_time}] issue kind={issue_kind} run_id={run_id} message={issue_message}\n",
    )
    if fingerprint != last_issue:
        append(
            error_log,
            f"[{current_time}] kind={issue_kind} run_id={run_id}\n{issue_message}\n\n",
        )
        latest_error.write_text(
            "\n".join(
                [
                    "# Latest Automation Error",
                    "",
                    f"- time: {current_time}",
                    f"- kind: {issue_kind}",
                    f"- run_id: {run_id}",
                    "",
                    issue_message,
                    "",
                ]
            ),
            encoding="utf-8",
        )
        state["last_issue"] = fingerprint
else:
    age = minutes_since(finished_at if automation_state == "success" else started_at)
    append(
        monitor_log,
        f"[{current_time}] healthy state={automation_state} run_id={run_id} age_minutes={age if age is not None else 'n/a'}\n",
    )
    state["last_issue"] = ""
    latest_error.write_text(
        "\n".join(
            [
                "# Latest Automation Error",
                "",
                f"- checked_at: {current_time}",
                "- state: none",
                "",
                "No active automation issue detected.",
                "",
            ]
        ),
        encoding="utf-8",
    )

health_file.write_text(
    "\n".join(
        [
            "# Automation Health",
            "",
            f"- checked_at: {current_time}",
            f"- state: {automation_state}",
            f"- run_id: {run_id}",
            f"- issue: {issue_kind or 'none'}",
            f"- message: {issue_message or 'healthy'}",
            "",
        ]
    ),
    encoding="utf-8",
)

activity_file.write_text(
    summarize_activity(automation_state, run_id, run_dir, latest_output),
    encoding="utf-8",
)

save_state(state_file, state)
PY
