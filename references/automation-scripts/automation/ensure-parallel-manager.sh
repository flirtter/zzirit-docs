#!/bin/zsh
set -euo pipefail

ROOT="${ZZIRIT_AUTOMATION_ROOT:-/Users/user/zzirit-v2}"
SESSION_NAME="${ZZIRIT_PARALLEL_MANAGER_SESSION:-zzirit-parallel-manager}"
MANAGER_SCRIPT="${ZZIRIT_PARALLEL_MANAGER_SCRIPT:-$ROOT/scripts/automation/parallel-manager.sh}"
ARTIFACT_ROOT="$ROOT/artifacts/parallel"
EVENT_LOG="$ROOT/artifacts/automation/events.log"
CAFFEINATE_BIN="${ZZIRIT_AUTOMATION_CAFFEINATE_BIN:-$(command -v caffeinate || true)}"

mkdir -p "$ARTIFACT_ROOT" "$(dirname "$EVENT_LOG")"
touch "$EVENT_LOG"

timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  exit 0
fi

session_command="$MANAGER_SCRIPT"
if [ -n "$CAFFEINATE_BIN" ]; then
  session_command="$CAFFEINATE_BIN -dimsu $MANAGER_SCRIPT"
fi

tmux new-session -d -s "$SESSION_NAME" "$session_command"
echo "[$(timestamp)] parallel-manager-started session=$SESSION_NAME script=$MANAGER_SCRIPT" >> "$EVENT_LOG"
