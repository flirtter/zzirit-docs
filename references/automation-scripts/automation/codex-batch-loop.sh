#!/bin/zsh
set -euo pipefail

ROOT="${ZZIRIT_AUTOMATION_ROOT:-/Users/user/zzirit-v2}"
ARTIFACT_DIR="$ROOT/artifacts/automation"
LOOP_STATUS_FILE="$ARTIFACT_DIR/loop-status.md"
EVENT_LOG="$ARTIFACT_DIR/events.log"
RUNNER="${ZZIRIT_AUTOMATION_RUNNER:-$ROOT/scripts/automation/codex-next-batch.sh}"
SLEEP_SUCCESS="${ZZIRIT_AUTOMATION_LOOP_SLEEP_SUCCESS:-30}"
SLEEP_FAILURE="${ZZIRIT_AUTOMATION_LOOP_SLEEP_FAILURE:-60}"
MAX_CYCLES="${ZZIRIT_AUTOMATION_MAX_CYCLES:-0}"

mkdir -p "$ARTIFACT_DIR"
touch "$EVENT_LOG"

timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

log_event() {
  echo "[$(timestamp)] $1" >> "$EVENT_LOG"
}

write_status() {
  local state="$1"
  local cycle="$2"
  local detail="$3"
  cat > "$LOOP_STATUS_FILE" <<EOF
# Automation Loop Status

- state: $state
- checked_at: $(timestamp)
- cycle: $cycle
- runner: $RUNNER
- detail: $detail
EOF
}

cycle=0
log_event "loop-started runner=$RUNNER"
write_status "running" "$cycle" "loop started"

while true; do
  cycle=$((cycle + 1))
  write_status "running" "$cycle" "starting batch"
  log_event "loop-cycle-start cycle=$cycle"

  exit_code=0
  if ! "$RUNNER"; then
    exit_code=$?
  fi

  if [ "$exit_code" -eq 0 ]; then
    write_status "cooldown" "$cycle" "last batch succeeded; sleeping ${SLEEP_SUCCESS}s"
    log_event "loop-cycle-finished cycle=$cycle exit_code=$exit_code sleep_seconds=$SLEEP_SUCCESS"
    if [ "$MAX_CYCLES" -gt 0 ] && [ "$cycle" -ge "$MAX_CYCLES" ]; then
      write_status "stopped" "$cycle" "max cycles reached"
      log_event "loop-stopped cycle=$cycle reason=max-cycles"
      exit 0
    fi
    sleep "$SLEEP_SUCCESS"
    continue
  fi

  write_status "cooldown" "$cycle" "last batch failed; sleeping ${SLEEP_FAILURE}s"
  log_event "loop-cycle-finished cycle=$cycle exit_code=$exit_code sleep_seconds=$SLEEP_FAILURE"
  if [ "$MAX_CYCLES" -gt 0 ] && [ "$cycle" -ge "$MAX_CYCLES" ]; then
    write_status "stopped" "$cycle" "max cycles reached after failure"
    log_event "loop-stopped cycle=$cycle reason=max-cycles"
    exit "$exit_code"
  fi
  sleep "$SLEEP_FAILURE"
done
