#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
SIM_UDID="${ZZIRIT_IOS_SIMULATOR_UDID:-}"
APP_BUNDLE_ID="${ZZIRIT_IOS_BUNDLE_ID:-com.flirtter.zziritApp}"
API_BASE_URL="${ZZIRIT_API_BASE_URL:-https://zzirit-proxy-147227137514.asia-northeast3.run.app}"
APPIUM_PORT="${APPIUM_PORT:-4726}"
APPIUM_LOG="${ZZIRIT_APPIUM_LOG:-$PROJECT_ROOT/artifacts/appium-meeting/appium-server.log}"

mkdir -p "$(dirname "$APPIUM_LOG")"

resolve_sim_udid() {
  if [[ -n "$SIM_UDID" ]]; then
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

wait_for_port() {
  local port="$1"
  local waited=0
  while [[ "$waited" -lt 30 ]]; do
    if nc -z 127.0.0.1 "$port" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

DEVICE_ID="$(resolve_sim_udid)"
if [[ -z "$DEVICE_ID" ]]; then
  echo "[ios-appium-meeting-review] Could not resolve simulator: $SIM_NAME" >&2
  exit 1
fi

xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl privacy "$DEVICE_ID" grant location "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl privacy "$DEVICE_ID" grant photos "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl privacy "$DEVICE_ID" grant photos-add "$APP_BUNDLE_ID" >/dev/null 2>&1 || true

bash "$PROJECT_ROOT/scripts/review/open-ios-real-env.sh" >/tmp/zzirit-meeting-open-real-env.log 2>&1

if ! nc -z 127.0.0.1 "$APPIUM_PORT" >/dev/null 2>&1; then
  nohup appium --address 127.0.0.1 --port "$APPIUM_PORT" >"$APPIUM_LOG" 2>&1 &
  wait_for_port "$APPIUM_PORT" || {
    echo "[ios-appium-meeting-review] Appium did not become ready on port $APPIUM_PORT" >&2
    exit 1
  }
fi

APPIUM_BASE_URL="http://127.0.0.1:${APPIUM_PORT}/wd/hub" \
ZZIRIT_IOS_PROJECT_ROOT="$PROJECT_ROOT" \
ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" \
ZZIRIT_IOS_SIMULATOR_UDID="$DEVICE_ID" \
ZZIRIT_IOS_BUNDLE_ID="$APP_BUNDLE_ID" \
ZZIRIT_REVIEW_SEED_API_BASE_URL="${ZZIRIT_REVIEW_SEED_API_BASE_URL:-https://zzirit-api-147227137514.asia-northeast3.run.app}" \
ZZIRIT_REVIEW_SEED_KEY="${ZZIRIT_REVIEW_SEED_KEY:-review-seed-20260313-my}" \
node "$PROJECT_ROOT/scripts/review/ios-appium-meeting-review.mjs"
