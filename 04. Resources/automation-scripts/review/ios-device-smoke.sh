#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
REPORT_DIR="${ZZIRIT_IOS_DEVICE_REPORT_DIR:-$PROJECT_ROOT/artifacts/ios-device}"
DEVICE_ID="${ZZIRIT_IOS_DEVICE_ID:-HG}"
APP_BUNDLE_ID="${ZZIRIT_IOS_APP_BUNDLE_ID:-}"
APP_PATH="${ZZIRIT_IOS_DEVICE_APP_PATH:-}"

mkdir -p "$REPORT_DIR"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "[ios-device] xcrun not found"
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LIST_JSON="$REPORT_DIR/${TIMESTAMP}-devices.json"
DETAILS_LOG="$REPORT_DIR/${TIMESTAMP}-device-details.log"
DISPLAYS_LOG="$REPORT_DIR/${TIMESTAMP}-device-displays.log"
INSTALL_LOG="$REPORT_DIR/${TIMESTAMP}-install.log"
LAUNCH_LOG="$REPORT_DIR/${TIMESTAMP}-launch.log"
LOCK_STATE_LOG="$REPORT_DIR/${TIMESTAMP}-lock-state.log"
SUMMARY_PATH="$REPORT_DIR/${TIMESTAMP}-summary.md"

run_with_timeout() {
  local timeout_seconds="$1"
  local output_path="$2"
  shift 2

  python3 - "$timeout_seconds" "$output_path" "$@" <<'PY'
import subprocess
import sys

timeout_seconds = int(sys.argv[1])
output_path = sys.argv[2]
command = sys.argv[3:]

with open(output_path, "w", encoding="utf-8") as stream:
    try:
        completed = subprocess.run(
            command,
            stdout=stream,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=timeout_seconds,
            check=False,
        )
        sys.exit(completed.returncode)
    except subprocess.TimeoutExpired:
        stream.write(f"[ios-device] timed out after {timeout_seconds}s\n")
        sys.exit(124)
PY
}

xcrun devicectl list devices --json-output "$LIST_JSON" >/dev/null
xcrun devicectl device info details --device "$DEVICE_ID" >"$DETAILS_LOG"
xcrun devicectl device info displays --device "$DEVICE_ID" >"$DISPLAYS_LOG"
xcrun devicectl device info lockState --device "$DEVICE_ID" >"$LOCK_STATE_LOG" 2>&1 || true

if [ -n "$APP_PATH" ]; then
  run_with_timeout 120 "$INSTALL_LOG" xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" || true
fi

if [ -n "$APP_BUNDLE_ID" ]; then
  run_with_timeout 30 "$LAUNCH_LOG" xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$APP_BUNDLE_ID" || true
fi

{
  echo "# iOS Device Smoke"
  echo
  echo "- Device selector: $DEVICE_ID"
  echo "- Device list json: $LIST_JSON"
  echo "- Device details: $DETAILS_LOG"
  echo "- Display info: $DISPLAYS_LOG"
  echo "- Lock state: $LOCK_STATE_LOG"
  if [ -n "$APP_PATH" ]; then
    echo "- Install log: $INSTALL_LOG"
  fi
  if [ -n "$APP_BUNDLE_ID" ]; then
    echo "- Launch log: $LAUNCH_LOG"
  fi
  echo
  echo "Manual follow-up required:"
  echo "- open the launched app on device"
  echo "- take a device screenshot manually"
  echo "- store the screenshot beside this summary"
} >"$SUMMARY_PATH"

echo "[ios-device] Summary: $SUMMARY_PATH"
