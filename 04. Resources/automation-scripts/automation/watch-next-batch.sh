#!/bin/zsh
set -euo pipefail

ROOT="${ZZIRIT_AUTOMATION_ROOT:-/Users/user/zzirit-v2}"
ARTIFACT_DIR="$ROOT/artifacts/automation"
RUNS_DIR="$ARTIFACT_DIR/runs"
STATUS_FILE="$ARTIFACT_DIR/status.md"
SUMMARY_FILE="$ARTIFACT_DIR/latest-summary.md"
EVENT_LOG="$ARTIFACT_DIR/events.log"
MONITOR_LOG="$ARTIFACT_DIR/monitor.log"
ERROR_LOG="$ARTIFACT_DIR/errors.log"
HEALTH_FILE="$ARTIFACT_DIR/health.md"
ACTIVITY_FILE="$ARTIFACT_DIR/current-activity.md"
LOOP_STATUS_FILE="$ARTIFACT_DIR/loop-status.md"
PARALLEL_STATUS_FILE="$ROOT/artifacts/parallel/status.md"
FOCUS_STATE_FILE="$ARTIFACT_DIR/focus-session.json"
TASK_QUEUE_FILE="$ARTIFACT_DIR/task-queue.json"
AGENT_STATE_FILE="$ARTIFACT_DIR/agent-state.json"
NEXT_ACTION_FILE="$ARTIFACT_DIR/next-action.md"
SURFACE_SPEC_MANIFEST="$ROOT/docs/spec/surfaces/manifest.json"
LATEST_RUN_LINK="$ARTIFACT_DIR/latest-run"

current_run_id() {
  if [ -f "$STATUS_FILE" ]; then
    awk '/^- run_id:/ { print $3 }' "$STATUS_FILE" | tail -n 1
  fi
}

print_run_start_state() {
  local run_id="$1"
  local status_path="$RUNS_DIR/$run_id/pre-run-git-status.txt"

  if [ -z "$run_id" ]; then
    echo "- run_id: unknown"
    echo "- state: unknown"
    return
  fi

  echo "- run_id: $run_id"
  if [ ! -f "$status_path" ]; then
    echo "- state: pending"
    return
  fi

  if [ -s "$status_path" ]; then
    echo "- state: dirty"
    echo "- status_file: $status_path"
  else
    echo "- state: clean"
  fi
}

while true; do
  run_id="$(current_run_id)"
  clear
  echo "ZZIRIT Codex Automation Watch"
  echo "updated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo

  if [ -f "$STATUS_FILE" ]; then
    cat "$STATUS_FILE"
  else
    echo "# Automation Status"
    echo
    echo "- state: idle"
  fi

  echo
  echo "## Automation Health"
  echo
  if [ -f "$HEALTH_FILE" ]; then
    cat "$HEALTH_FILE"
  else
    echo "No health report yet."
  fi

  echo
  echo "## Loop Status"
  echo
  if [ -f "$LOOP_STATUS_FILE" ]; then
    cat "$LOOP_STATUS_FILE"
  else
    echo "No loop status yet."
  fi

  echo
  echo "## Parallel Status"
  echo
  if [ -f "$PARALLEL_STATUS_FILE" ]; then
    cat "$PARALLEL_STATUS_FILE"
  else
    echo "No parallel status yet."
  fi

  echo
  echo "## Focus Session"
  echo
  if [ -f "$FOCUS_STATE_FILE" ]; then
    cat "$FOCUS_STATE_FILE"
  else
    echo "No focus session yet."
  fi

  echo
  echo "## Surface Spec"
  echo
  if [ -f "$FOCUS_STATE_FILE" ]; then
    spec_path="$(python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); data=json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}; print(data.get("surface_spec_path",""))' "$FOCUS_STATE_FILE" 2>/dev/null || true)"
    if [ -n "$spec_path" ] && [ -f "$spec_path" ]; then
      sed -n '1,120p' "$spec_path"
    else
      echo "No surface spec path in current focus."
    fi
  else
    echo "No focus session yet."
  fi

  echo
  echo "## Task Queue"
  echo
  if [ -f "$TASK_QUEUE_FILE" ]; then
    cat "$TASK_QUEUE_FILE"
  else
    echo "No task queue yet."
  fi

  echo
  echo "## Agent State"
  echo
  if [ -f "$AGENT_STATE_FILE" ]; then
    cat "$AGENT_STATE_FILE"
  else
    echo "No agent state yet."
  fi

  echo
  echo "## Next Action"
  echo
  if [ -f "$NEXT_ACTION_FILE" ]; then
    cat "$NEXT_ACTION_FILE"
  else
    echo "No next-action note yet."
  fi

  echo
  echo "## Design Result"
  echo
  if [ -L "$LATEST_RUN_LINK" ] && [ -f "$LATEST_RUN_LINK/design-result.json" ]; then
    cat "$LATEST_RUN_LINK/design-result.json"
  else
    echo "No design-result yet."
  fi

  echo
  echo "## Current Activity"
  echo
  if [ -f "$ACTIVITY_FILE" ]; then
    cat "$ACTIVITY_FILE"
  else
    echo "No activity report yet."
  fi

  echo
  echo "## Latest Summary"
  echo
  if [ -f "$SUMMARY_FILE" ]; then
    cat "$SUMMARY_FILE"
  else
    echo "No summary yet."
  fi

  echo
  echo "## Current Run Start State"
  echo
  print_run_start_state "$run_id"

  echo
  echo "## Recent Events"
  echo
  if [ -f "$EVENT_LOG" ]; then
    if [ -n "$run_id" ]; then
      python3 - "$EVENT_LOG" "$run_id" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

log_path = Path(sys.argv[1])
run_id = sys.argv[2]

lines = log_path.read_text(encoding="utf-8").splitlines()
selected = [
    line for line in lines
    if f"run_id={run_id}" in line or "loop-" in line
]

for line in selected[-20:]:
    print(line)
PY
    else
      tail -n 20 "$EVENT_LOG"
    fi
  else
    echo "No event log yet."
  fi

  echo
  echo "## Recent Monitor Checks"
  echo
  if [ -f "$MONITOR_LOG" ]; then
    tail -n 40 "$MONITOR_LOG"
  else
    echo "No monitor log yet."
  fi

  echo
  echo "## Errors"
  echo
  if [ -f "$ERROR_LOG" ]; then
    tail -n 40 "$ERROR_LOG"
  else
    echo "No errors logged."
  fi

  sleep 5
done
