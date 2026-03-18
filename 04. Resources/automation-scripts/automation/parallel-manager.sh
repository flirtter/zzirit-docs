#!/bin/zsh
set -euo pipefail

ROOT="${ZZIRIT_AUTOMATION_ROOT:-/Users/user/zzirit-v2}"
SPEC_FILE="${ZZIRIT_PARALLEL_SPEC_FILE:-$ROOT/scripts/automation/parallel-specs.json}"
ARTIFACT_ROOT="$ROOT/artifacts/parallel"
STATUS_FILE="$ARTIFACT_ROOT/status.md"
EVENT_LOG="$ROOT/artifacts/automation/events.log"
SESSION_PREFIX="${ZZIRIT_PARALLEL_SESSION_PREFIX:-zzirit-par-}"
WORKER_SCRIPT="${ZZIRIT_PARALLEL_WORKER_SCRIPT:-$ROOT/scripts/automation/parallel-worker.sh}"
SCHEDULER_SCRIPT="${ZZIRIT_PARALLEL_SCHEDULER_SCRIPT:-$ROOT/scripts/automation/parallel-scheduler.py}"
CAFFEINATE_BIN="${ZZIRIT_AUTOMATION_CAFFEINATE_BIN:-$(command -v caffeinate || true)}"
LOOP_SLEEP_SECONDS="${ZZIRIT_PARALLEL_MANAGER_SLEEP_SECONDS:-20}"
MAX_WORKERS="${ZZIRIT_PARALLEL_MAX_WORKERS:-1}"
AUTOMATION_STATUS_FILE="$ROOT/artifacts/automation/status.md"

mkdir -p "$ARTIFACT_ROOT" "$(dirname "$EVENT_LOG")"
touch "$EVENT_LOG"

timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

log_event() {
  echo "[$(timestamp)] $1" >> "$EVENT_LOG"
}

render_status() {
  python3 - "$SPEC_FILE" "$ARTIFACT_ROOT" "$STATUS_FILE" <<'PY'
import json
import sys
from pathlib import Path

spec_file = Path(sys.argv[1])
artifact_root = Path(sys.argv[2])
status_file = Path(sys.argv[3])
data = json.loads(spec_file.read_text(encoding="utf-8"))
workers = data.get("workers", []) if isinstance(data, dict) else data
enabled = [item for item in workers if item.get("enabled", True)]
lines = [
    "# Parallel Automation Status",
    "",
]
for worker in enabled:
    key = worker.get("key", "unknown")
    worker_status = artifact_root / key / "status.md"
    lines.append(f"## {key}")
    lines.append("")
    if worker_status.exists():
        lines.append(worker_status.read_text(encoding="utf-8").strip())
    else:
        lines.append("- state: pending")
        lines.append(f"- branch: {worker.get('branch', '')}")
        lines.append(f"- worktree: {worker.get('worktree', '')}")
    lines.append("")
status_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

start_worker_if_needed() {
  local key="$1"
  local trigger="$2"
  local session_name="${SESSION_PREFIX}${key}"
  if tmux has-session -t "$session_name" 2>/dev/null; then
    return 0
  fi

  local session_command="$WORKER_SCRIPT $key $trigger"
  if [ -n "$CAFFEINATE_BIN" ]; then
    session_command="$CAFFEINATE_BIN -dimsu $WORKER_SCRIPT $key $trigger"
  fi

  tmux new-session -d -s "$session_name" "$session_command"
  log_event "parallel-worker-started key=$key session=$session_name trigger=$trigger"
}

while true; do
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    key="${item%% *}"
    trigger="${item#* }"
    [ -z "$key" ] && continue
    [ -z "$trigger" ] && trigger="manual"
    start_worker_if_needed "$key" "$trigger"
  done < <(
    python3 "$SCHEDULER_SCRIPT" "$SPEC_FILE" "$ARTIFACT_ROOT" "$AUTOMATION_STATUS_FILE" "$MAX_WORKERS" | python3 -c '
import json, sys
payload = json.loads(sys.stdin.read() or "{}")
for item in payload.get("ready", []):
    print(item.get("key", ""), item.get("trigger", "manual"))
'
  )

  render_status
  sleep "$LOOP_SLEEP_SECONDS"
done
