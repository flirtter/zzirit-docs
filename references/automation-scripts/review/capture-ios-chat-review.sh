#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
SEED_API_BASE_URL="${ZZIRIT_REVIEW_SEED_API_BASE_URL:-https://zzirit-api-147227137514.asia-northeast3.run.app}"
SEED_KEY="${ZZIRIT_REVIEW_SEED_KEY:-review-seed-20260313-my}"
OUT_DIR="${1:-$PROJECT_ROOT/artifacts/manual-review/chat-release-$(date +%Y%m%d-%H%M%S)}"

mkdir -p "$OUT_DIR"

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
  echo "[capture-ios-chat-review] Could not resolve simulator: $SIM_NAME" >&2
  exit 1
fi

curl -fsS -X POST "$SEED_API_BASE_URL/v1/review-seed/my" -H "X-Review-Seed-Key: $SEED_KEY" \
  >"$OUT_DIR/seed.json"

bash "$PROJECT_ROOT/scripts/review/open-ios-seeded-review.sh" "$SIM_NAME" '/chatting'
sleep 8
xcrun simctl io "$DEVICE_ID" screenshot "$OUT_DIR/01-chat-list.png" >/dev/null

xcrun simctl openurl "$DEVICE_ID" 'zzirit:///chattingroom?id=review-room-4&name=강유림&partnerId=review-match-4'
sleep 6
xcrun simctl io "$DEVICE_ID" screenshot "$OUT_DIR/02-chat-empty-room.png" >/dev/null

xcrun simctl openurl "$DEVICE_ID" 'zzirit:///chattingroom?id=review-room-1&name=문서아&partnerId=review-match-1'
sleep 6
xcrun simctl io "$DEVICE_ID" screenshot "$OUT_DIR/03-chat-text-room.png" >/dev/null

xcrun simctl openurl "$DEVICE_ID" 'zzirit:///chattingroom?id=review-room-3&name=유서린&partnerId=review-match-3'
sleep 6
xcrun simctl io "$DEVICE_ID" screenshot "$OUT_DIR/04-chat-location-room.png" >/dev/null

xcrun simctl openurl "$DEVICE_ID" 'zzirit:///chattingroom?id=review-room-2&name=임하린&partnerId=review-match-2'
sleep 6
xcrun simctl io "$DEVICE_ID" screenshot "$OUT_DIR/05-chat-image-room.png" >/dev/null

cat > "$OUT_DIR/summary.md" <<EOF
# Chat Release Capture

- simulator: $SIM_NAME
- device_id: $DEVICE_ID
- out_dir: $OUT_DIR
- seed_api_base_url: $SEED_API_BASE_URL
- artifacts:
  - $OUT_DIR/01-chat-list.png
  - $OUT_DIR/02-chat-empty-room.png
  - $OUT_DIR/03-chat-text-room.png
  - $OUT_DIR/04-chat-location-room.png
  - $OUT_DIR/05-chat-image-room.png
EOF

cat <<EOF
[capture-ios-chat-review] simulator: $SIM_NAME
[capture-ios-chat-review] device_id: $DEVICE_ID
[capture-ios-chat-review] out_dir: $OUT_DIR
EOF
