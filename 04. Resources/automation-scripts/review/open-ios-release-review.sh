#!/usr/bin/env bash
set -euo pipefail

SIM_NAME="${1:-iPhone 17 Pro}"
NEXT_ROUTE="${2:-/my}"
USER_ID="${ZZIRIT_REVIEW_USER_ID:-review-my-user}"
APP_BUNDLE_ID="${ZZIRIT_IOS_APP_BUNDLE_ID:-com.flirtter.zziritApp}"

DEVICE_ID="$(
  xcrun simctl list devices available |
    awk -v name="$SIM_NAME" '
      $0 ~ name {
        match($0, /\([0-9A-Fa-f-]+\)/)
        if (RSTART) {
          print substr($0, RSTART + 1, RLENGTH - 2)
          exit
        }
      }
    '
)"

if [[ -z "${DEVICE_ID}" ]]; then
  echo "Unable to resolve simulator device id for: ${SIM_NAME}" >&2
  exit 1
fi

if ! xcrun simctl get_app_container "${DEVICE_ID}" "${APP_BUNDLE_ID}" data >/dev/null 2>&1; then
  echo "App is not installed on ${SIM_NAME}: ${APP_BUNDLE_ID}" >&2
  exit 1
fi

xcrun simctl boot "${DEVICE_ID}" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "${DEVICE_ID}" >/dev/null 2>&1 || true
xcrun simctl bootstatus "${DEVICE_ID}" -b >/dev/null 2>&1 || true
xcrun simctl terminate "${DEVICE_ID}" "${APP_BUNDLE_ID}" >/dev/null 2>&1 || true
xcrun simctl launch "${DEVICE_ID}" "${APP_BUNDLE_ID}" >/dev/null 2>&1 || true
sleep 8

ENCODED_NEXT="$(python3 - <<'PY' "${NEXT_ROUTE}"
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1], safe=''))
PY
)"

URL="zzirit:///review/seed-login?user_id=${USER_ID}&next=${ENCODED_NEXT}"
xcrun simctl openurl "${DEVICE_ID}" "${URL}"

cat <<EOF
[open-ios-release-review] simulator: ${SIM_NAME}
[open-ios-release-review] device_id: ${DEVICE_ID}
[open-ios-release-review] bundle_id: ${APP_BUNDLE_ID}
[open-ios-release-review] url: ${URL}
EOF
