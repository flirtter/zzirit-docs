#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
REPORT_DIR="${ZZIRIT_IOS_E2E_REPORT_DIR:-$PROJECT_ROOT/artifacts/e2e}"
FLOW_PATH="${ZZIRIT_IOS_E2E_FLOW:-$PROJECT_ROOT/maestro/flows/onboarding-signup-smoke.yaml}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
APP_BUNDLE_ID="${ZZIRIT_IOS_APP_BUNDLE_ID:-com.flirtter.zziritApp}"

mkdir -p "$REPORT_DIR"

if ! command -v maestro >/dev/null 2>&1; then
  echo "[ios-e2e] Maestro not installed"
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "[ios-e2e] xcrun not found"
  exit 1
fi

SIM_UDID="$(xcrun simctl list devices available | awk -v name="$SIM_NAME" '
  $0 ~ name {
    match($0, /\([0-9A-Fa-f-]+\)/)
    if (RSTART) {
      print substr($0, RSTART + 1, RLENGTH - 2)
      exit
    }
  }
')"

if [ -z "$SIM_UDID" ]; then
  echo "[ios-e2e] Could not resolve simulator: $SIM_NAME"
  exit 1
fi

xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b

LOG_PATH="$REPORT_DIR/$(date +%Y%m%d-%H%M%S)-maestro.log"
APP_BUNDLE_ID="$APP_BUNDLE_ID" maestro test "$FLOW_PATH" | tee "$LOG_PATH"

echo "[ios-e2e] Log: $LOG_PATH"
