#!/bin/zsh
set -euo pipefail

ROOT="${ZZIRIT_AUTOMATION_ROOT:-/Users/user/zzirit-v2}"
FOCUS_SECTION="${1:-}"
RUN_DIR="${2:-}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
LOG_PATH="${RUN_DIR:-$ROOT/artifacts/automation}/focus-host-qa.log"
SUMMARY_PATH="${RUN_DIR:-$ROOT/artifacts/automation}/focus-host-qa-summary.md"
RESULT_PATH="${RUN_DIR:-$ROOT/artifacts/automation}/focus-host-qa-result.json"
STEP_TIMEOUT_SECONDS="${ZZIRIT_AUTOMATION_HOST_QA_STEP_TIMEOUT_SECONDS:-900}"

mkdir -p "$(dirname "$LOG_PATH")"

kill_port() {
  local port="$1"
  local pids
  pids="$(lsof -ti "tcp:${port}" 2>/dev/null || true)"
  if [ -n "$pids" ]; then
    kill $pids >/dev/null 2>&1 || true
    sleep 1
  fi
}

cleanup_mobile_sidecars() {
  kill_port 8081
  kill_port 4725
  kill_port 4726
  pkill -f "/Users/user/zzirit-v2/scripts/e2e/ios-appium-onboarding" >/dev/null 2>&1 || true
  pkill -f "/Users/user/zzirit-v2/scripts/review/ios-appium-likes-review" >/dev/null 2>&1 || true
  pkill -f "/Users/user/zzirit-v2/scripts/review/ios-appium-meeting-review" >/dev/null 2>&1 || true
  pkill -f "/Users/user/zzirit-v2/scripts/review/ios-appium-chat-smoke" >/dev/null 2>&1 || true
  pkill -f "/Users/user/zzirit-v2/scripts/review/ios-chat-raw-smoke" >/dev/null 2>&1 || true
}

append_latest_artifact_links() {
  local label="$1"
  local artifact_root="$2"

  [ -d "$artifact_root" ] || return 0

  local latest_dir
  latest_dir="$(find "$artifact_root" -maxdepth 1 -mindepth 1 -type d | sort | tail -n 1)"
  [ -n "$latest_dir" ] || return 0

  echo "- ${label}_artifact_dir: $latest_dir" >> "$SUMMARY_PATH"
  if [ -f "$latest_dir/summary.md" ]; then
    echo "- ${label}_artifact_summary: $latest_dir/summary.md" >> "$SUMMARY_PATH"
  fi
}

append_latest_summary_file() {
  local label="$1"
  local search_root="$2"

  [ -d "$search_root" ] || return 0

  local latest_summary
  latest_summary="$(find "$search_root" -type f -name summary.md | sort | tail -n 1)"
  [ -n "$latest_summary" ] || return 0

  echo "- ${label}_artifact_summary: $latest_summary" >> "$SUMMARY_PATH"
}

append_summary_file_if_exists() {
  local label="$1"
  local summary_path="$2"

  [ -f "$summary_path" ] || return 0
  echo "- ${label}_artifact_summary: $summary_path" >> "$SUMMARY_PATH"
}

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  python3 - "$timeout_seconds" "$LOG_PATH" "$@" <<'PY'
import os
import signal
import subprocess
import sys

timeout_seconds = int(sys.argv[1])
log_path = sys.argv[2]
cmd = sys.argv[3:]

with open(log_path, "a", encoding="utf-8") as log_file:
    process = subprocess.Popen(
        cmd,
        stdout=log_file,
        stderr=subprocess.STDOUT,
        preexec_fn=os.setsid,
    )
    try:
        raise SystemExit(process.wait(timeout=timeout_seconds))
    except subprocess.TimeoutExpired:
        log_file.write(
            f"[focus-host-qa] timed out after {timeout_seconds}s: {' '.join(cmd)}\n"
        )
        log_file.flush()
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        raise SystemExit(124)
PY
}

run_step() {
  local label="$1"
  local timeout_seconds="$2"
  shift
  shift

  echo "## $label" >> "$SUMMARY_PATH"
  echo >> "$SUMMARY_PATH"
  echo "\$ $*" >> "$SUMMARY_PATH"
  echo >> "$SUMMARY_PATH"

  cleanup_mobile_sidecars
  if run_with_timeout "$timeout_seconds" "$@"; then
    echo "- status: pass" >> "$SUMMARY_PATH"
  else
    local exit_code=$?
    echo "- status: blocked" >> "$SUMMARY_PATH"
    echo "- exit_code: $exit_code" >> "$SUMMARY_PATH"
    if [ "$exit_code" -eq 124 ]; then
      echo "- reason: timed out after ${timeout_seconds}s" >> "$SUMMARY_PATH"
    fi
  fi
  cleanup_mobile_sidecars
  echo >> "$SUMMARY_PATH"
}

write_result_json() {
  python3 - "$SUMMARY_PATH" "$RESULT_PATH" "$FOCUS_SECTION" "$SIM_NAME" "$LOG_PATH" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
result_path = Path(sys.argv[2])
focus_section = sys.argv[3]
simulator = sys.argv[4]
log_path = sys.argv[5]

lines = summary_path.read_text(encoding="utf-8").splitlines() if summary_path.exists() else []
steps: list[dict[str, str]] = []
artifacts: dict[str, str] = {}
current_step: dict[str, str] | None = None

for raw_line in lines:
    line = raw_line.strip()
    if raw_line.startswith("## "):
        current_step = {"label": raw_line[3:].strip(), "status": "unknown"}
        steps.append(current_step)
        continue
    if line.startswith("- status:") and current_step is not None:
        current_step["status"] = line.split(":", 1)[1].strip()
        continue
    if line.startswith("-") and "_artifact_" in line and ":" in line:
        key, value = line[1:].split(":", 1)
        artifacts[key.strip()] = value.strip()

overall_status = "skipped"
if any(step.get("status") == "blocked" for step in steps):
    overall_status = "blocked"
elif any(step.get("status") == "pass" for step in steps):
    overall_status = "pass"

payload = {
    "focus_section": focus_section,
    "simulator": simulator,
    "summary_path": str(summary_path),
    "log_path": log_path,
    "overall_status": overall_status,
    "steps": steps,
    "artifacts": artifacts,
}
result_path.write_text(json.dumps(payload, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
PY
}

{
  echo "# Focus Host QA"
  echo
  echo "- focus_section: ${FOCUS_SECTION:-none}"
  echo "- simulator: $SIM_NAME"
  echo "- log: $LOG_PATH"
  echo
} > "$SUMMARY_PATH"

case "$FOCUS_SECTION" in
  login)
    run_step \
      "Login Figma variants" \
      "$STEP_TIMEOUT_SECONDS" \
      env CI=1 EXPO_NO_INTERACTIVE=1 ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" npm --prefix "$ROOT" run qa:ios:onboarding-entry
    run_step \
      "Login/Onboarding Appium smoke" \
      "$STEP_TIMEOUT_SECONDS" \
      env CI=1 EXPO_NO_INTERACTIVE=1 ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" npm --prefix "$ROOT" run qa:appium:onboarding:ios
    ;;
  onboarding)
    run_step \
      "Onboarding Appium smoke" \
      "$STEP_TIMEOUT_SECONDS" \
      env CI=1 EXPO_NO_INTERACTIVE=1 ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" npm --prefix "$ROOT" run qa:appium:onboarding:ios
    ;;
  lightning)
    run_step \
      "Lightning visual parity" \
      "$STEP_TIMEOUT_SECONDS" \
      env CI=1 EXPO_NO_INTERACTIVE=1 ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" ZZIRIT_APPIUM_STOP_AFTER=tabs npm --prefix "$ROOT" run qa:appium:onboarding:ios
    ;;
  meeting)
    run_step \
      "Meeting visual review" \
      "$STEP_TIMEOUT_SECONDS" \
      env CI=1 EXPO_NO_INTERACTIVE=1 ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" npm --prefix "$ROOT" run qa:appium:meeting:ios
    append_latest_artifact_links "meeting_review" "$ROOT/artifacts/appium-meeting"
    echo >> "$SUMMARY_PATH"
    ;;
  chat)
    run_step \
      "Chat Appium smoke" \
      "$STEP_TIMEOUT_SECONDS" \
      env CI=1 EXPO_NO_INTERACTIVE=1 ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" npm --prefix "$ROOT" run qa:appium:chat:ios
    append_latest_artifact_links "chat_review" "$ROOT/artifacts/appium-chat"
    echo >> "$SUMMARY_PATH"
    run_step \
      "Chat raw smoke fallback" \
      "$STEP_TIMEOUT_SECONDS" \
      env CI=1 EXPO_NO_INTERACTIVE=1 ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" bash "$ROOT/scripts/review/ios-chat-raw-smoke.sh"
    append_latest_artifact_links "chat_raw_review" "$ROOT/artifacts/chat-raw"
    echo >> "$SUMMARY_PATH"
    chat_release_dir="$ROOT/artifacts/manual-review/chat-release-$(date +%Y%m%d-%H%M%S)"
    run_step \
      "Chat release capture" \
      "$STEP_TIMEOUT_SECONDS" \
      env CI=1 EXPO_NO_INTERACTIVE=1 ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" bash "$ROOT/scripts/review/capture-ios-chat-review.sh" "$chat_release_dir"
    append_summary_file_if_exists "chat_release_review" "$chat_release_dir/summary.md"
    ;;
  likes)
    run_step \
      "Likes/Appium review" \
      "$STEP_TIMEOUT_SECONDS" \
      env CI=1 EXPO_NO_INTERACTIVE=1 ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" npm --prefix "$ROOT" run qa:appium:likes:ios
    append_latest_artifact_links "likes_review" "$ROOT/artifacts/appium-likes"
    echo >> "$SUMMARY_PATH"
    likes_release_dir="$ROOT/artifacts/manual-review/likes-release-$(date +%Y%m%d-%H%M%S)"
    run_step \
      "Likes release capture" \
      "$STEP_TIMEOUT_SECONDS" \
      env CI=1 EXPO_NO_INTERACTIVE=1 ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" bash "$ROOT/scripts/review/capture-ios-likes-review.sh" "$likes_release_dir"
    append_summary_file_if_exists "likes_release_review" "$likes_release_dir/summary.md"
    echo >> "$SUMMARY_PATH"
    ;;
  my)
    run_step \
      "MY/Appium smoke" \
      "$STEP_TIMEOUT_SECONDS" \
      env CI=1 EXPO_NO_INTERACTIVE=1 ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" npm --prefix "$ROOT" run qa:appium:onboarding:ios
    append_latest_artifact_links "onboarding_review" "$ROOT/artifacts/appium-onboarding"
    echo >> "$SUMMARY_PATH"
    run_step \
      "Likes/Appium review" \
      "$STEP_TIMEOUT_SECONDS" \
      env CI=1 EXPO_NO_INTERACTIVE=1 ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" npm --prefix "$ROOT" run qa:appium:likes:ios
    append_latest_artifact_links "likes_review" "$ROOT/artifacts/appium-likes"
    echo >> "$SUMMARY_PATH"
    ;;
  *)
    echo "- status: skipped" >> "$SUMMARY_PATH"
    echo "- reason: no host QA mapping yet for focus section '$FOCUS_SECTION'" >> "$SUMMARY_PATH"
    echo >> "$SUMMARY_PATH"
    ;;
esac

write_result_json

echo "$SUMMARY_PATH"
