#!/bin/zsh
set -euo pipefail

ROOT="${ZZIRIT_AUTOMATION_ROOT:-/Users/user/zzirit-v2}"
SESSION_NAME="${ZZIRIT_AUTOMATION_LOOP_SESSION:-zzirit-auto-runner}"
LOOP_SCRIPT="${ZZIRIT_AUTOMATION_LOOP_SCRIPT:-$ROOT/scripts/automation/codex-batch-loop.sh}"
ARTIFACT_DIR="$ROOT/artifacts/automation"
EVENT_LOG="$ARTIFACT_DIR/events.log"
LOOP_STATUS_FILE="$ARTIFACT_DIR/loop-status.md"
CAFFEINATE_BIN="${ZZIRIT_AUTOMATION_CAFFEINATE_BIN:-$(command -v caffeinate || true)}"

mkdir -p "$ARTIFACT_DIR"
touch "$EVENT_LOG"

timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

log_event() {
  echo "[$(timestamp)] $1" >> "$EVENT_LOG"
}

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  exit 0
fi

session_command="$LOOP_SCRIPT"
if [ -n "$CAFFEINATE_BIN" ]; then
  session_command="$CAFFEINATE_BIN -dimsu $LOOP_SCRIPT"
fi

tmux new-session -d -s "$SESSION_NAME" "$session_command"
log_event "loop-session-started session=$SESSION_NAME script=$LOOP_SCRIPT"

cat > "$LOOP_STATUS_FILE" <<EOF
# Automation Loop Status

- state: running
- checked_at: $(timestamp)
- session: $SESSION_NAME
- runner: $LOOP_SCRIPT
- detail: tmux loop ensured${CAFFEINATE_BIN:+ with caffeinate}
EOF
