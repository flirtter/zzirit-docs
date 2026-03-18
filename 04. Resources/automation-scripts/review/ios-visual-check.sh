#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
REPORT_DIR="${ZZIRIT_IOS_REPORT_DIR:-$PROJECT_ROOT/artifacts/ios-visual}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-}"
SIM_UDID="${ZZIRIT_IOS_SIMULATOR_UDID:-}"
APP_BUNDLE_ID="${ZZIRIT_IOS_APP_BUNDLE_ID:-}"
SCREENSHOT_NAME="${ZZIRIT_IOS_SCREENSHOT_NAME:-zzirit-screen.png}"
SCREENSHOT_PREWAIT="${ZZIRIT_IOS_SCREENSHOT_PREWAIT:-3}"
SCREENSHOT_POSTWAIT="${ZZIRIT_IOS_SCREENSHOT_POSTWAIT:-2}"
MANUAL_WAIT="${ZZIRIT_IOS_MANUAL_WAIT:-0}"
OPEN_URL="${ZZIRIT_IOS_OPEN_URL:-}"
OPEN_URL_WAIT="${ZZIRIT_IOS_OPEN_URL_WAIT:-3}"
START_EXPO="${ZZIRIT_IOS_START_EXPO:-0}"
START_EXPO_CMD="${ZZIRIT_IOS_START_EXPO_CMD:-CI=1 EXPO_NO_INTERACTIVE=1 EXPO_NO_METRO_WORKSPACE_ROOT=1 npx expo start --dev-client --clear -p 8081}"
START_EXPO_LOG="${ZZIRIT_IOS_START_EXPO_LOG:-$REPORT_DIR/expo-start.log}"
START_EXPO_TIMEOUT="${ZZIRIT_IOS_START_EXPO_TIMEOUT:-180}"
KEEP_EXPO_SERVER="${ZZIRIT_IOS_KEEP_EXPO_SERVER:-false}"
APP_SCHEME="${ZZIRIT_IOS_APP_SCHEME:-zzirit}"
EXPO_DEV_URL="${ZZIRIT_EXPO_DEV_URL:-http://127.0.0.1:8081}"
USE_DEV_CLIENT="${ZZIRIT_IOS_USE_DEV_CLIENT:-}"
DEV_CLIENT_WAIT="${ZZIRIT_IOS_DEV_CLIENT_WAIT:-6}"
MAESTRO_FLOW="${ZZIRIT_MAESTRO_FLOW:-}"
MAESTRO_CLI="${ZZIRIT_MAESTRO_CLI_CMD:-maestro}"
EXPO_PID=""

if [ -z "$USE_DEV_CLIENT" ]; then
  if [ "$START_EXPO" = "1" ]; then
    USE_DEV_CLIENT="1"
  else
    USE_DEV_CLIENT="0"
  fi
fi

mkdir -p "$REPORT_DIR"

cleanup() {
  if [ -n "$EXPO_PID" ] && [ "$KEEP_EXPO_SERVER" != "true" ]; then
    kill "$EXPO_PID" >/dev/null 2>&1 || true
  fi
}

wait_for_expo_ready() {
  local waited=0
  local patterns=(
    "Starting Metro Bundler"
    "Metro waiting on"
    "Metro is running"
    "Expo DevTools is running"
    "Open the app in Expo Go"
    "› Opening exp://"
    "Bundled"
  )
  local failure_patterns=(
    "Input is required"
    "Skipping dev server"
    "CommandError"
  )

  while [ "$waited" -lt "$START_EXPO_TIMEOUT" ]; do
    if [ -f "$START_EXPO_LOG" ]; then
      for pattern in "${failure_patterns[@]}"; do
        if rg -q "$pattern" "$START_EXPO_LOG"; then
          echo "[ios-visual] Expo failed to start cleanly: $pattern"
          return 1
        fi
      done
      for pattern in "${patterns[@]}"; do
        if rg -q "$pattern" "$START_EXPO_LOG"; then
          echo "[ios-visual] Expo ready: $pattern"
          return 0
        fi
      done
    fi
    sleep 2
    waited=$((waited + 2))
  done

  echo "[ios-visual] Expo did not become ready within ${START_EXPO_TIMEOUT}s"
  return 1
}

resolve_sim_udid() {
  if [ -n "$SIM_UDID" ]; then
    echo "$SIM_UDID"
    return 0
  fi

  if [ -n "$SIM_NAME" ]; then
    xcrun simctl list devices available | awk -v name="$SIM_NAME" '
      $0 ~ name {
        match($0, /\([0-9A-Fa-f-]+\)/)
        if (RSTART) {
          print substr($0, RSTART + 1, RLENGTH - 2)
          exit
        }
      }
    '
    return 0
  fi

  xcrun simctl list devices booted | awk '
    /Booted/ {
      match($0, /\([0-9A-Fa-f-]+\)/)
      if (RSTART) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
      }
    }
  '
}

build_dev_client_url() {
  APP_SCHEME="$APP_SCHEME" EXPO_DEV_URL="$EXPO_DEV_URL" python3 - <<'PY'
import os
import urllib.parse

scheme = os.environ["APP_SCHEME"]
expo_url = os.environ["EXPO_DEV_URL"]
print(f"{scheme}://expo-development-client/?url={urllib.parse.quote(expo_url, safe='')}")
PY
}

if ! command -v xcrun >/dev/null 2>&1; then
  echo "[ios-visual] xcrun not found"
  exit 1
fi

trap cleanup EXIT INT TERM

SIM_UDID="$(resolve_sim_udid)"
if [ -z "$SIM_UDID" ]; then
  echo "[ios-visual] Could not resolve a simulator"
  exit 1
fi

xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b

if [ "$START_EXPO" = "1" ]; then
  mkdir -p "$(dirname "$START_EXPO_LOG")"
  (
    cd "$PROJECT_ROOT/apps/mobile"
    bash -lc "$START_EXPO_CMD"
  ) >"$START_EXPO_LOG" 2>&1 &
  EXPO_PID=$!
  wait_for_expo_ready
fi

if [ "$USE_DEV_CLIENT" = "1" ]; then
  xcrun simctl openurl "$SIM_UDID" "$(build_dev_client_url)" >/dev/null 2>&1 || \
    xcrun simctl launch "$SIM_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  sleep "$DEV_CLIENT_WAIT"
elif [ -n "$APP_BUNDLE_ID" ]; then
  xcrun simctl launch "$SIM_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
fi

if [ -n "$OPEN_URL" ]; then
  xcrun simctl openurl "$SIM_UDID" "$OPEN_URL" >/dev/null 2>&1 || true
  sleep "$OPEN_URL_WAIT"
fi

sleep "$SCREENSHOT_PREWAIT"

if [ -n "$MAESTRO_FLOW" ]; then
  if command -v "$MAESTRO_CLI" >/dev/null 2>&1; then
    "$MAESTRO_CLI" test "$MAESTRO_FLOW" || true
  else
    echo "[ios-visual] Maestro not installed, skipping flow"
  fi
fi

sleep "$SCREENSHOT_POSTWAIT"

if [ "$MANUAL_WAIT" -gt 0 ]; then
  echo "[ios-visual] Waiting ${MANUAL_WAIT}s for manual navigation"
  sleep "$MANUAL_WAIT"
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SCREEN_PATH="$REPORT_DIR/${TIMESTAMP}-${SCREENSHOT_NAME}"
xcrun simctl io "$SIM_UDID" screenshot "$SCREEN_PATH"

echo "[ios-visual] Simulator UDID: $SIM_UDID"
echo "[ios-visual] Screenshot: $SCREEN_PATH"
echo "[ios-visual] Checkpoints:"
echo "- safe area / notch / home indicator overlap"
echo "- keyboard + scroll interaction"
echo "- button sticky position and label overflow"
echo "- long text wrapping and empty states"
