#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
FIGMA_FILE_KEY="${FIGMA_FILE_KEY:-ZhysC3KZLAmKerfHTpg3G6}"
FIGMA_NODE_ID="${FIGMA_NODE_ID:-}"
FIGMA_SCREEN_KEY="${ZZIRIT_FIGMA_SCREEN_KEY:-}"
PLAYWRIGHT_CHANNEL="${ZZIRIT_FIGMA_PLAYWRIGHT_CHANNEL:-chrome}"
PLAYWRIGHT_DEVICE="${ZZIRIT_FIGMA_PLAYWRIGHT_DEVICE:-Desktop Chrome HiDPI}"
PLAYWRIGHT_TIMEOUT_MS="${ZZIRIT_FIGMA_PLAYWRIGHT_TIMEOUT_MS:-90000}"
PLAYWRIGHT_WAIT_MS="${ZZIRIT_FIGMA_PLAYWRIGHT_WAIT_MS:-10000}"
PLAYWRIGHT_STORAGE_STATE="${ZZIRIT_FIGMA_PLAYWRIGHT_STORAGE_STATE:-}"
PLAYWRIGHT_USE_PROFILE_COPY="${ZZIRIT_FIGMA_USE_PROFILE_COPY:-1}"
PLAYWRIGHT_HEADLESS="${ZZIRIT_FIGMA_PLAYWRIGHT_HEADLESS:-0}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="${ZZIRIT_FIGMA_PLAYWRIGHT_RUN_DIR:-$PROJECT_ROOT/artifacts/figma-reference/playwright-copy/$TIMESTAMP}"
SUMMARY_PATH="${ZZIRIT_FIGMA_PLAYWRIGHT_SUMMARY_PATH:-$RUN_DIR/summary.md}"
LOG_PATH="${ZZIRIT_FIGMA_PLAYWRIGHT_LOG_PATH:-$RUN_DIR/playwright.log}"
DEBUG_SHOT="${ZZIRIT_FIGMA_PLAYWRIGHT_DEBUG_SHOT:-$RUN_DIR/debug.png}"
COPY_SCRIPT="$PROJECT_ROOT/scripts/review/playwright-figma-copy-png.cjs"

mkdir -p "$RUN_DIR"

if [ -z "$FIGMA_FILE_KEY" ] || [ -z "$FIGMA_NODE_ID" ]; then
  {
    echo "# Figma Playwright Copy PNG"
    echo
    echo "- status: blocked"
    echo "- reason: FIGMA_FILE_KEY or FIGMA_NODE_ID missing"
  } >"$SUMMARY_PATH"
  echo "[figma-playwright-copy] missing FIGMA_FILE_KEY or FIGMA_NODE_ID" >&2
  exit 1
fi

PLAYWRIGHT_USER_DATA_DIR=""
if [ "$PLAYWRIGHT_USE_PROFILE_COPY" = "1" ]; then
  PLAYWRIGHT_USER_DATA_DIR="$(bash "$PROJECT_ROOT/scripts/review/prepare-figma-playwright-profile.sh")"
fi

SAFE_NODE_ID="${FIGMA_NODE_ID//:/-}"
SCREEN_SLUG="${FIGMA_SCREEN_KEY:-figma-node}"
OUTPUT_PATH="${FIGMA_OUTPUT_PATH:-$RUN_DIR/${SCREEN_SLUG}-${SAFE_NODE_ID}.png}"
INNER_URL="https://www.figma.com/design/$FIGMA_FILE_KEY/ZZIRIT---Master-Design--Copy-?node-id=$SAFE_NODE_ID"

set +e
ZZIRIT_PLAYWRIGHT_URL="$INNER_URL" \
ZZIRIT_PLAYWRIGHT_OUTPUT_PATH="$OUTPUT_PATH" \
ZZIRIT_PLAYWRIGHT_CHANNEL="$PLAYWRIGHT_CHANNEL" \
ZZIRIT_PLAYWRIGHT_DEVICE="$PLAYWRIGHT_DEVICE" \
ZZIRIT_PLAYWRIGHT_TIMEOUT_MS="$PLAYWRIGHT_TIMEOUT_MS" \
ZZIRIT_PLAYWRIGHT_WAIT_MS="$PLAYWRIGHT_WAIT_MS" \
ZZIRIT_PLAYWRIGHT_USER_DATA_DIR="$PLAYWRIGHT_USER_DATA_DIR" \
ZZIRIT_PLAYWRIGHT_STORAGE_STATE="$PLAYWRIGHT_STORAGE_STATE" \
ZZIRIT_PLAYWRIGHT_HEADLESS="$PLAYWRIGHT_HEADLESS" \
ZZIRIT_PLAYWRIGHT_DEBUG_SHOT="$DEBUG_SHOT" \
node "$COPY_SCRIPT" \
  >"$LOG_PATH" 2>&1
PLAYWRIGHT_EXIT_CODE=$?
set -e

if [ "$PLAYWRIGHT_EXIT_CODE" -eq 0 ] && [ -f "$OUTPUT_PATH" ]; then
  {
    echo "# Figma Playwright Copy PNG"
    echo
    echo "- status: copied"
    echo "- source: playwright-copy-as-png"
    echo "- figma_file_key: $FIGMA_FILE_KEY"
    echo "- figma_node_id: $FIGMA_NODE_ID"
    if [ -n "$FIGMA_SCREEN_KEY" ]; then
      echo "- figma_screen_key: $FIGMA_SCREEN_KEY"
    fi
    echo "- figma_design_url: $INNER_URL"
    if [ -n "$PLAYWRIGHT_USER_DATA_DIR" ]; then
      echo "- playwright_user_data_dir: $PLAYWRIGHT_USER_DATA_DIR"
    fi
    if [ -n "$PLAYWRIGHT_STORAGE_STATE" ]; then
      echo "- playwright_storage_state: $PLAYWRIGHT_STORAGE_STATE"
    fi
    echo "- output_path: $OUTPUT_PATH"
    echo "- debug_shot: $DEBUG_SHOT"
    echo "- log_path: $LOG_PATH"
  } >"$SUMMARY_PATH"
  echo "$OUTPUT_PATH"
  exit 0
fi

{
  echo "# Figma Playwright Copy PNG"
  echo
  echo "- status: blocked"
  echo "- source: playwright-copy-as-png"
  echo "- figma_file_key: $FIGMA_FILE_KEY"
  echo "- figma_node_id: $FIGMA_NODE_ID"
  if [ -n "$FIGMA_SCREEN_KEY" ]; then
    echo "- figma_screen_key: $FIGMA_SCREEN_KEY"
  fi
  echo "- figma_design_url: $INNER_URL"
  if [ -n "$PLAYWRIGHT_USER_DATA_DIR" ]; then
    echo "- playwright_user_data_dir: $PLAYWRIGHT_USER_DATA_DIR"
  fi
  if [ -n "$PLAYWRIGHT_STORAGE_STATE" ]; then
    echo "- playwright_storage_state: $PLAYWRIGHT_STORAGE_STATE"
  fi
  echo "- reason: playwright copy-as-png failed"
  echo "- exit_code: $PLAYWRIGHT_EXIT_CODE"
  echo "- output_path: $OUTPUT_PATH"
  echo "- debug_shot: $DEBUG_SHOT"
  echo "- log_path: $LOG_PATH"
} >"$SUMMARY_PATH"

echo "[figma-playwright-copy] copy-as-png failed for node $FIGMA_NODE_ID" >&2
exit 1
