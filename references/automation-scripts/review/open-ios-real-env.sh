#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
SIM_UDID="${ZZIRIT_IOS_SIMULATOR_UDID:-}"
APP_BUNDLE_ID="${ZZIRIT_IOS_APP_BUNDLE_ID:-com.flirtter.zziritApp}"
API_BASE_URL="${ZZIRIT_API_BASE_URL:-https://zzirit-proxy-147227137514.asia-northeast3.run.app}"
ALLOW_LOCAL_API="${ZZIRIT_ALLOW_LOCAL_API:-0}"
APP_SCHEME="${ZZIRIT_IOS_APP_SCHEME:-zzirit}"
EXPO_DEV_URL="${ZZIRIT_EXPO_DEV_URL:-http://127.0.0.1:8081}"
RESTART_METRO="${ZZIRIT_IOS_RESTART_METRO:-1}"
OPEN_URL="${ZZIRIT_IOS_OPEN_URL:-}"
METRO_LOG_PATH="${ZZIRIT_IOS_REAL_ENV_METRO_LOG:-/tmp/zzirit-real-env-metro.log}"

is_local_api_base_url() {
  case "$API_BASE_URL" in
    http://127.0.0.1:*|http://localhost:*|https://127.0.0.1:*|https://localhost:*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if is_local_api_base_url && [ "$ALLOW_LOCAL_API" != "1" ]; then
  echo "[open-ios-real-env] local API base URL is blocked by default: $API_BASE_URL"
  echo "[open-ios-real-env] set ZZIRIT_ALLOW_LOCAL_API=1 only for explicit local backend debugging"
  exit 1
fi

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

wait_for_port() {
  local host="$1"
  local port="$2"
  local waited=0
  while [ "$waited" -lt 30 ]; do
    if nc -z "$host" "$port" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

stop_port_processes() {
  local port="$1"
  local pids
  pids="$(lsof -ti "tcp:${port}" || true)"
  if [ -z "$pids" ]; then
    return 0
  fi
  kill $pids >/dev/null 2>&1 || true
  sleep 1
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

ensure_expo_server() {
  if [ "$RESTART_METRO" = "1" ]; then
    stop_port_processes 8081
  elif nc -z 127.0.0.1 8081 >/dev/null 2>&1; then
    return 0
  fi

  nohup bash -lc "cd \"$PROJECT_ROOT/apps/mobile\" && EXPO_NO_INTERACTIVE=1 EXPO_NO_METRO_WORKSPACE_ROOT=1 EXPO_PUBLIC_API_BASE_URL=\"$API_BASE_URL\" npx expo start --dev-client --clear -p 8081" \
    >"$METRO_LOG_PATH" 2>&1 &

  wait_for_port 127.0.0.1 8081 || {
    echo "[open-ios-real-env] expo server did not become ready"
    exit 1
  }
}

SIM_UDID="$(resolve_sim_udid)"
if [ -z "$SIM_UDID" ]; then
  echo "[open-ios-real-env] Could not resolve simulator: $SIM_NAME"
  exit 1
fi

ensure_expo_server

xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b
xcrun simctl openurl "$SIM_UDID" "$(build_dev_client_url)" >/dev/null 2>&1 || \
  xcrun simctl launch "$SIM_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
sleep 8

if [ -n "$OPEN_URL" ]; then
  xcrun simctl openurl "$SIM_UDID" "$OPEN_URL" >/dev/null 2>&1 || true
fi

cat <<EOF
[open-ios-real-env] simulator: $SIM_NAME
[open-ios-real-env] udid: $SIM_UDID
[open-ios-real-env] api_base_url: $API_BASE_URL
[open-ios-real-env] metro_log: $METRO_LOG_PATH
[open-ios-real-env] open_url: ${OPEN_URL:-none}
EOF
