#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
SEED_API_BASE_URL="${ZZIRIT_REVIEW_SEED_API_BASE_URL:-https://zzirit-api-147227137514.asia-northeast3.run.app}"
SEED_KEY="${ZZIRIT_REVIEW_SEED_KEY:-review-seed-20260313-my}"
OUT_DIR="${1:-$PROJECT_ROOT/artifacts/manual-review/likes-release-$(date +%Y%m%d-%H%M%S)}"

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
  echo "[capture-ios-likes-review] Could not resolve simulator: $SIM_NAME" >&2
  exit 1
fi

curl -fsS -X POST "$SEED_API_BASE_URL/v1/review-seed/my" -H "X-Review-Seed-Key: $SEED_KEY" \
  >"$OUT_DIR/seed.json"

bash "$PROJECT_ROOT/scripts/review/open-ios-seeded-review.sh" "$SIM_NAME" '/likes?tab=received'
sleep 8
xcrun simctl io "$DEVICE_ID" screenshot "$OUT_DIR/01-likes-received.png" >/dev/null

xcrun simctl openurl "$DEVICE_ID" 'zzirit:///likes?tab=sent'
sleep 6
xcrun simctl io "$DEVICE_ID" screenshot "$OUT_DIR/02-likes-sent.png" >/dev/null

xcrun simctl openurl "$DEVICE_ID" 'zzirit:///likes?tab=zzirit'
sleep 6
xcrun simctl io "$DEVICE_ID" screenshot "$OUT_DIR/03-likes-zzirit.png" >/dev/null

cat > "$OUT_DIR/summary.md" <<EOF
# Likes Release Capture

- simulator: $SIM_NAME
- device_id: $DEVICE_ID
- out_dir: $OUT_DIR
- seed_api_base_url: $SEED_API_BASE_URL
- artifacts:
  - $OUT_DIR/01-likes-received.png
  - $OUT_DIR/02-likes-sent.png
  - $OUT_DIR/03-likes-zzirit.png
EOF

cat <<EOF
[capture-ios-likes-review] simulator: $SIM_NAME
[capture-ios-likes-review] device_id: $DEVICE_ID
[capture-ios-likes-review] out_dir: $OUT_DIR
EOF
