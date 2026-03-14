#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
SEED_API_BASE_URL="${ZZIRIT_REVIEW_SEED_API_BASE_URL:-https://zzirit-api-147227137514.asia-northeast3.run.app}"
SEED_KEY="${ZZIRIT_REVIEW_SEED_KEY:-review-seed-20260313-my}"
OUT_DIR="${1:-$PROJECT_ROOT/artifacts/manual-review/meeting-seeded-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$OUT_DIR"

read_viewport() {
  osascript \
    -e 'tell application "Simulator" to activate' \
    -e 'tell application "System Events"' \
    -e 'tell process "Simulator"' \
    -e 'repeat 20 times' \
    -e 'try' \
    -e 'set frontmost to true' \
    -e 'set win to first window whose subrole is "AXStandardWindow"' \
    -e 'set {xPos, yPos} to position of win' \
    -e 'set {wVal, hVal} to size of win' \
    -e 'return (xPos as string) & "," & (yPos as string) & "," & (wVal as string) & "," & (hVal as string)' \
    -e 'end try' \
    -e 'delay 0.2' \
    -e 'end repeat' \
    -e 'error "Unable to locate Simulator viewport"' \
    -e 'end tell' \
    -e 'end tell'
}

click_viewport_ratio() {
  local x_ratio="$1"
  local y_ratio="$2"
  local viewport x y width height abs_x abs_y
  viewport="$(read_viewport)"
  IFS=',' read -r x y width height <<<"$viewport"
  abs_x="$(python3 - <<'PY' "$x" "$width" "$x_ratio"
import sys
x, width, ratio = map(float, sys.argv[1:])
print(x + width * ratio)
PY
)"
  abs_y="$(python3 - <<'PY' "$y" "$height" "$y_ratio"
import sys
y, height, ratio = map(float, sys.argv[1:])
print(y + height * ratio)
PY
)"
  swift -e "import CoreGraphics; import Foundation; let p = CGPoint(x: $abs_x, y: $abs_y); let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left); let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left); let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left); move?.post(tap: .cghidEventTap); usleep(80000); down?.post(tap: .cghidEventTap); usleep(80000); up?.post(tap: .cghidEventTap)"
  sleep 1
}

DEVICE_ID="$(
  xcrun simctl list devices available | awk -v name="$SIM_NAME" '
    $0 ~ name {
      match($0, /\([0-9A-Fa-f-]+\)/)
      if (RSTART) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
      }
    }
  '
)"

if [[ -z "$DEVICE_ID" ]]; then
  echo "[capture-ios-meeting-review] Could not resolve simulator: $SIM_NAME" >&2
  exit 1
fi

curl -fsS -X POST "$SEED_API_BASE_URL/v1/review-seed/my" -H "X-Review-Seed-Key: $SEED_KEY" \
  >"$OUT_DIR/seed.json"

bash "$PROJECT_ROOT/scripts/review/open-ios-seeded-review.sh" "$SIM_NAME" '/meeting'
sleep 8
xcrun simctl io "$DEVICE_ID" screenshot "$OUT_DIR/01-meeting-list.png" >/dev/null

xcrun simctl openurl "$DEVICE_ID" 'zzirit:///create-meeting'
sleep 6
xcrun simctl io "$DEVICE_ID" screenshot "$OUT_DIR/02-create-meeting.png" >/dev/null
click_viewport_ratio 0.50 0.36
sleep 2
xcrun simctl io "$DEVICE_ID" screenshot "$OUT_DIR/02a-location-picker.png" >/dev/null

xcrun simctl openurl "$DEVICE_ID" 'zzirit:///meeting-detail?id=review-meeting-1'
sleep 6
xcrun simctl io "$DEVICE_ID" screenshot "$OUT_DIR/03-meeting-detail.png" >/dev/null

cat <<EOF
[capture-ios-meeting-review] simulator: $SIM_NAME
[capture-ios-meeting-review] device_id: $DEVICE_ID
[capture-ios-meeting-review] out_dir: $OUT_DIR
EOF
