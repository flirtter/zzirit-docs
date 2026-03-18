#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
SIM_UDID="${ZZIRIT_IOS_SIMULATOR_UDID:-}"
APP_BUNDLE_ID="${ZZIRIT_IOS_APP_BUNDLE_ID:-com.flirtter.zziritApp}"
APP_PATH="${ZZIRIT_IOS_APP_PATH:-}"
APPIUM_SERVER_PORT="${ZZIRIT_APPIUM_SERVER_PORT:-4725}"
APPIUM_SERVER_URL="${ZZIRIT_APPIUM_SERVER_URL:-http://127.0.0.1:${APPIUM_SERVER_PORT}/wd/hub}"
REPORT_ROOT="${ZZIRIT_APPIUM_REPORT_DIR:-$PROJECT_ROOT/artifacts/appium}"
APPIUM_LOG_PATH="$REPORT_ROOT/appium-server.log"

mkdir -p "$REPORT_ROOT"

resolve_sim_udid() {
  if [ -n "$SIM_UDID" ]; then
    echo "$SIM_UDID"
    return 0
  fi

  xcrun simctl list devices available | awk -v name="$SIM_NAME" '
    $0 ~ name {
      match($0, /\([0-9A-Fa-f-]+\)/)
      if (RSTART) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
      }
    }
  '
}

wait_for_appium() {
  local waited=0
  while [ "$waited" -lt 20 ]; do
    if curl -fsS "${APPIUM_SERVER_URL}/status" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

SIM_UDID="$(resolve_sim_udid)"
if [ -z "$SIM_UDID" ]; then
  echo "[ios-appium] Could not resolve simulator: $SIM_NAME"
  exit 1
fi

xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b

if [ -n "$APP_PATH" ]; then
  xcrun simctl install "$SIM_UDID" "$APP_PATH"
fi

xcrun simctl launch "$SIM_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

if ! curl -fsS "${APPIUM_SERVER_URL}/status" >/dev/null 2>&1; then
  if ! command -v appium >/dev/null 2>&1; then
    echo "[ios-appium] appium not installed"
    exit 1
  fi

  nohup appium \
    --address 127.0.0.1 \
    --port "$APPIUM_SERVER_PORT" \
    --base-path /wd/hub \
    --use-drivers=xcuitest \
    --log "$APPIUM_LOG_PATH" \
    >/dev/null 2>&1 &

  wait_for_appium || {
    echo "[ios-appium] appium server did not become ready"
    exit 1
  }
fi

ZZIRIT_APPIUM_SERVER_URL="$APPIUM_SERVER_URL" \
ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" \
ZZIRIT_IOS_SIMULATOR_UDID="$SIM_UDID" \
ZZIRIT_IOS_APP_BUNDLE_ID="$APP_BUNDLE_ID" \
ZZIRIT_APPIUM_REPORT_DIR="$REPORT_ROOT" \
node "$PROJECT_ROOT/scripts/e2e/ios-appium-smoke.mjs"
