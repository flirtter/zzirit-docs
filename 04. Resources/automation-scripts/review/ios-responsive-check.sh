#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
REPORT_DIR="${ZZIRIT_IOS_RESPONSIVE_REPORT_DIR:-$PROJECT_ROOT/artifacts/ios-responsive}"
VISUAL_SCRIPT="$PROJECT_ROOT/scripts/review/ios-visual-check.sh"
SIMULATORS="${ZZIRIT_IOS_RESPONSIVE_SIMULATORS:-iPhone 16e,iPhone 17 Pro,iPhone 17 Pro Max}"
START_EXPO="${ZZIRIT_IOS_START_EXPO:-0}"

mkdir -p "$REPORT_DIR"

IFS=',' read -r -a SIM_ARRAY <<< "$SIMULATORS"

INDEX=0
for raw_name in "${SIM_ARRAY[@]}"; do
  SIM_NAME="$(echo "$raw_name" | sed 's/^ *//; s/ *$//')"
  SAFE_NAME="$(echo "$SIM_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')"

  VISUAL_START_EXPO=0
  VISUAL_KEEP_EXPO_SERVER=true
  if [ "$INDEX" -eq 0 ] && [ "$START_EXPO" = "1" ]; then
    VISUAL_START_EXPO=1
  fi

  ZZIRIT_IOS_REPORT_DIR="$REPORT_DIR" \
  ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" \
  ZZIRIT_IOS_SCREENSHOT_NAME="${SAFE_NAME}.png" \
  ZZIRIT_IOS_START_EXPO="$VISUAL_START_EXPO" \
  ZZIRIT_IOS_KEEP_EXPO_SERVER="$VISUAL_KEEP_EXPO_SERVER" \
  bash "$VISUAL_SCRIPT"

  INDEX=$((INDEX + 1))
done

SUMMARY_PATH="$REPORT_DIR/$(date +%Y%m%d-%H%M%S)-responsive-summary.md"
{
  echo "# iOS Responsive Matrix"
  echo
  for raw_name in "${SIM_ARRAY[@]}"; do
    SIM_NAME="$(echo "$raw_name" | sed 's/^ *//; s/ *$//')"
    SAFE_NAME="$(echo "$SIM_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')"
    SCREEN_PATH="$(find "$REPORT_DIR" -type f -name "*-${SAFE_NAME}.png" | sort | tail -n 1)"
    echo "- $SIM_NAME: ${SCREEN_PATH:-not-found}"
  done
  if [ "$START_EXPO" = "1" ]; then
    echo
    echo "Expo server was left running intentionally for the capture loop."
  fi
} >"$SUMMARY_PATH"

echo "[ios-responsive] Summary: $SUMMARY_PATH"
