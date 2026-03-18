#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
SIM_UDID="${ZZIRIT_IOS_SIMULATOR_UDID:-}"
APP_BUNDLE_ID="${ZZIRIT_IOS_APP_BUNDLE_ID:-com.flirtter.zziritApp}"
USE_INSTALLED_APP="${ZZIRIT_IOS_USE_INSTALLED_APP:-0}"

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

SIM_UDID="$(resolve_sim_udid)"
if [ -z "$SIM_UDID" ]; then
  echo "[ios-chat-raw] Could not resolve simulator: $SIM_NAME"
  exit 1
fi

xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b

if [ "$USE_INSTALLED_APP" = "1" ]; then
  xcrun simctl launch "$SIM_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  sleep 4
else
  ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" \
  ZZIRIT_IOS_SIMULATOR_UDID="$SIM_UDID" \
  ZZIRIT_IOS_APP_BUNDLE_ID="$APP_BUNDLE_ID" \
  ZZIRIT_IOS_RESTART_METRO="${ZZIRIT_IOS_RESTART_METRO:-1}" \
  bash "$PROJECT_ROOT/scripts/review/open-ios-real-env.sh" >/dev/null
fi

ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" \
ZZIRIT_IOS_SIMULATOR_UDID="$SIM_UDID" \
ZZIRIT_IOS_APP_BUNDLE_ID="$APP_BUNDLE_ID" \
ZZIRIT_IOS_USE_INSTALLED_APP="$USE_INSTALLED_APP" \
ZZIRIT_IOS_PROJECT_ROOT="$PROJECT_ROOT" \
node "$PROJECT_ROOT/scripts/review/ios-chat-raw-smoke.mjs"
