#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
SIM_UDID="${ZZIRIT_IOS_SIMULATOR_UDID:-}"
APP_BUNDLE_ID="${ZZIRIT_IOS_APP_BUNDLE_ID:-com.flirtter.zziritApp}"
APP_PATH="${ZZIRIT_IOS_APP_PATH:-}"
API_BASE_URL="${ZZIRIT_API_BASE_URL:-https://zzirit-proxy-147227137514.asia-northeast3.run.app}"
ALLOW_LOCAL_API="${ZZIRIT_ALLOW_LOCAL_API:-0}"
APP_SCHEME="${ZZIRIT_IOS_APP_SCHEME:-zzirit}"
EXPO_DEV_URL="${ZZIRIT_EXPO_DEV_URL:-http://127.0.0.1:8081}"
APPIUM_SERVER_PORT="${ZZIRIT_APPIUM_SERVER_PORT:-4725}"
APPIUM_SERVER_URL="${ZZIRIT_APPIUM_SERVER_URL:-http://127.0.0.1:${APPIUM_SERVER_PORT}/wd/hub}"
REPORT_ROOT="${ZZIRIT_APPIUM_ONBOARDING_REPORT_DIR:-$PROJECT_ROOT/artifacts/appium-onboarding}"
ONBOARDING_START_URL="${ZZIRIT_IOS_ONBOARDING_START_URL:-${APP_SCHEME}:///signup}"
RUN_DIR="$REPORT_ROOT/$(date +%Y%m%d-%H%M%S)"
API_LOG_PATH="$RUN_DIR/api-server.log"
EXPO_LOG_PATH="$RUN_DIR/expo.log"
APPIUM_LOG_PATH="$REPORT_ROOT/appium-server.log"
RESTART_SERVERS="${ZZIRIT_QA_RESTART_SERVERS:-1}"
REINSTALL_APP="${ZZIRIT_QA_REINSTALL_APP:-1}"
SIMULATOR_API_BASE_URL="$API_BASE_URL"

mkdir -p "$RUN_DIR"

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
  echo "[ios-appium-onboarding] local API base URL is blocked by default: $API_BASE_URL"
  echo "[ios-appium-onboarding] set ZZIRIT_ALLOW_LOCAL_API=1 only for explicit local backend debugging"
  exit 1
fi

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

resolve_host_ip() {
  ipconfig getifaddr en0 2>/dev/null || \
    ipconfig getifaddr en1 2>/dev/null || \
    ifconfig | awk '/inet / && $2 != "127.0.0.1" && $2 !~ /^169\\.254\\./ { print $2; exit }'
}

resolve_url_port() {
  URL_TO_PARSE="$1" python3 - <<'PY'
import os
from urllib.parse import urlparse

url = urlparse(os.environ["URL_TO_PARSE"])
print(url.port or (443 if url.scheme == "https" else 80))
PY
}

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

stop_expo_processes() {
  pkill -f "/Users/user/zzirit-v2/apps/mobile.*expo start --dev-client" >/dev/null 2>&1 || true
  pkill -f "expo start --dev-client --clear -p 8081" >/dev/null 2>&1 || true
  sleep 1
}

is_app_installed() {
  xcrun simctl get_app_container "$SIM_UDID" "$APP_BUNDLE_ID" data >/dev/null 2>&1
}

grant_app_permissions() {
  for service in photos photos-add camera; do
    xcrun simctl privacy "$SIM_UDID" grant "$service" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  done
}

clear_app_storage() {
  local container
  local async_storage_dir

  container="$(xcrun simctl get_app_container "$SIM_UDID" "$APP_BUNDLE_ID" data 2>/dev/null || true)"
  if [ -z "$container" ]; then
    return 0
  fi

  async_storage_dir="$container/Library/Application Support/$APP_BUNDLE_ID/RCTAsyncLocalStorage_V1"
  if [ -d "$async_storage_dir" ]; then
    find "$async_storage_dir" -mindepth 1 -delete
  fi
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

ensure_api_server() {
  if ! is_local_api_base_url; then
    return 0
  fi

  if [ "$RESTART_SERVERS" = "1" ]; then
    stop_port_processes 8000
  elif curl -fsS "${API_BASE_URL}/health" >/dev/null 2>&1; then
    return 0
  fi

  nohup bash -lc "cd \"$PROJECT_ROOT/apps/api\" && uv run uvicorn app.main:app --host 0.0.0.0 --port 8000" \
    >"$API_LOG_PATH" 2>&1 &

  wait_for_http "${API_BASE_URL}/health" || {
    echo "[ios-appium-onboarding] api server did not become ready"
    exit 1
  }
}

ensure_expo_server() {
  if [ "$RESTART_SERVERS" = "1" ]; then
    stop_expo_processes
    stop_port_processes 8081
  elif nc -z 127.0.0.1 8081 >/dev/null 2>&1; then
    return 0
  fi

  nohup bash -lc "cd \"$PROJECT_ROOT/apps/mobile\" && CI=1 EXPO_NO_INTERACTIVE=1 EXPO_NO_METRO_WORKSPACE_ROOT=1 EXPO_PUBLIC_API_BASE_URL=\"$SIMULATOR_API_BASE_URL\" npx expo start --dev-client --clear --port 8081" \
    >"$EXPO_LOG_PATH" 2>&1 &

  wait_for_port 127.0.0.1 8081 || {
    echo "[ios-appium-onboarding] expo server did not become ready"
    exit 1
  }

  if grep -q "Skipping dev server" "$EXPO_LOG_PATH" 2>/dev/null; then
    echo "[ios-appium-onboarding] expo server skipped startup because port 8081 was still occupied"
    exit 1
  fi
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
    echo "[ios-appium-onboarding] appium server did not become ready"
    exit 1
  }
}

ensure_app_path() {
  if [ -n "$APP_PATH" ]; then
    echo "$APP_PATH"
    return 0
  fi

  find ~/Library/Developer/Xcode/DerivedData -path '*Build/Products/Debug-iphonesimulator/ZZIRIT.app' | tail -n 1
}

launch_app_foreground() {
  xcrun simctl launch "$SIM_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
}

SIM_UDID="$(resolve_sim_udid)"
if [ -z "$SIM_UDID" ]; then
  echo "[ios-appium-onboarding] Could not resolve simulator: $SIM_NAME"
  exit 1
fi

if is_local_api_base_url; then
  HOST_IP="$(resolve_host_ip)"
  API_PORT="$(resolve_url_port "$API_BASE_URL")"
  if [ -n "$HOST_IP" ] && [ -n "$API_PORT" ]; then
    SIMULATOR_API_BASE_URL="http://${HOST_IP}:${API_PORT}"
  fi
fi

ensure_api_server
ensure_expo_server
ensure_appium_server

APP_PATH="$(ensure_app_path)"
if [ -z "$APP_PATH" ]; then
  echo "[ios-appium-onboarding] Could not find simulator app bundle"
  exit 1
fi

xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "$SIM_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM_UDID" -b
xcrun simctl addmedia "$SIM_UDID" "$PROJECT_ROOT/apps/mobile/assets/images/profile-example1.png" >/dev/null 2>&1 || true
xcrun simctl keychain "$SIM_UDID" reset >/dev/null 2>&1 || true
clear_app_storage
xcrun simctl terminate "$SIM_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
if [ "$REINSTALL_APP" = "1" ]; then
  xcrun simctl uninstall "$SIM_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
fi
if [ "$REINSTALL_APP" = "1" ] || ! is_app_installed; then
  xcrun simctl install "$SIM_UDID" "$APP_PATH"
fi
grant_app_permissions
xcrun simctl openurl "$SIM_UDID" "$(build_dev_client_url)" >/dev/null 2>&1 || \
  xcrun simctl launch "$SIM_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
sleep 10
launch_app_foreground
sleep 2
xcrun simctl openurl "$SIM_UDID" "$ONBOARDING_START_URL" >/dev/null 2>&1 || true
sleep 2
launch_app_foreground
sleep 1
xcrun simctl openurl "$SIM_UDID" "$ONBOARDING_START_URL" >/dev/null 2>&1 || true
sleep 4

ZZIRIT_APPIUM_SERVER_URL="$APPIUM_SERVER_URL" \
ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" \
ZZIRIT_IOS_SIMULATOR_UDID="$SIM_UDID" \
ZZIRIT_IOS_APP_BUNDLE_ID="$APP_BUNDLE_ID" \
ZZIRIT_APPIUM_REPORT_DIR="$REPORT_ROOT" \
ZZIRIT_APPIUM_RUN_DIR="$RUN_DIR" \
node "$PROJECT_ROOT/scripts/e2e/ios-appium-onboarding.mjs"
