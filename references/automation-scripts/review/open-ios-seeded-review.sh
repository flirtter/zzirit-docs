#!/usr/bin/env bash
set -euo pipefail

DEVICE_NAME="${1:-iPhone 17 Pro}"
NEXT_ROUTE="${2:-/my}"
USER_ID="${ZZIRIT_REVIEW_USER_ID:-review-my-user}"
APP_BUNDLE_ID="${ZZIRIT_IOS_BUNDLE_ID:-com.flirtter.zziritApp}"

DEVICE_ID="$(
  xcrun simctl list devices available |
    grep -F "${DEVICE_NAME} (" |
    head -n 1 |
    sed -E 's/.*\(([A-F0-9-]+)\).*/\1/'
)"

if [[ -z "${DEVICE_ID}" ]]; then
  echo "Unable to resolve simulator device id for: ${DEVICE_NAME}" >&2
  exit 1
fi

xcrun simctl boot "${DEVICE_ID}" >/dev/null 2>&1 || true
open -a Simulator --args -CurrentDeviceUDID "${DEVICE_ID}" >/dev/null 2>&1 || true

ENCODED_NEXT="$(python3 - <<'PY' "${NEXT_ROUTE}"
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1], safe=''))
PY
)"

URL="zzirit:///review/seed-login?user_id=${USER_ID}&next=${ENCODED_NEXT}"
xcrun simctl openurl "${DEVICE_ID}" "${URL}"

echo "Opened seeded review route on ${DEVICE_NAME}: ${URL}"
