#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
SIM_UDID="${ZZIRIT_IOS_SIMULATOR_UDID:-}"
APP_BUNDLE_ID="${ZZIRIT_IOS_APP_BUNDLE_ID:-com.flirtter.zziritApp}"
API_BASE_URL="${ZZIRIT_API_BASE_URL:-https://zzirit-proxy-147227137514.asia-northeast3.run.app}"
APPIUM_SERVER_PORT="${ZZIRIT_APPIUM_SERVER_PORT:-4726}"
APPIUM_SERVER_URL="${ZZIRIT_APPIUM_SERVER_URL:-http://127.0.0.1:${APPIUM_SERVER_PORT}/wd/hub}"
APPIUM_LOG_PATH="${ZZIRIT_APPIUM_LIKES_LOG:-$PROJECT_ROOT/artifacts/appium-likes/appium-server.log}"

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

wait_for_http() {
  local url="$1"
  local waited=0
  while [ "$waited" -lt 30 ]; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

ensure_appium_server() {
  if curl -fsS "${APPIUM_SERVER_URL}/status" >/dev/null 2>&1; then
    return 0
  fi

  nohup appium \
    --address 127.0.0.1 \
    --port "$APPIUM_SERVER_PORT" \
    --base-path /wd/hub \
    --use-drivers=xcuitest \
    --log "$APPIUM_LOG_PATH" \
    >/dev/null 2>&1 &

  wait_for_http "${APPIUM_SERVER_URL}/status" || {
    echo "[ios-appium-likes-review] appium server did not become ready" >&2
    exit 1
  }
}

SIM_UDID="$(resolve_sim_udid)"
if [ -z "$SIM_UDID" ]; then
  echo "[ios-appium-likes-review] Could not resolve simulator: $SIM_NAME" >&2
  exit 1
fi

xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null 2>&1 || true

if ! xcrun simctl get_app_container "$SIM_UDID" "$APP_BUNDLE_ID" data >/dev/null 2>&1; then
  echo "[ios-appium-likes-review] Release app is not installed for $APP_BUNDLE_ID on $SIM_NAME" >&2
  exit 1
fi

ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" \
ZZIRIT_IOS_SIMULATOR_UDID="$SIM_UDID" \
ZZIRIT_API_BASE_URL="$API_BASE_URL" \
bash "$PROJECT_ROOT/scripts/review/open-ios-real-env.sh" >/tmp/zzirit-likes-open-real-env.log

ensure_appium_server

cd "$PROJECT_ROOT"
ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" \
ZZIRIT_IOS_SIMULATOR_UDID="$SIM_UDID" \
ZZIRIT_IOS_APP_BUNDLE_ID="$APP_BUNDLE_ID" \
ZZIRIT_API_BASE_URL="$API_BASE_URL" \
ZZIRIT_APPIUM_SERVER_URL="$APPIUM_SERVER_URL" \
node "$PROJECT_ROOT/scripts/review/ios-appium-likes-review.mjs"
