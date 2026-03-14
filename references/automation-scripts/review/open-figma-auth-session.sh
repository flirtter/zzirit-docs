#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
AUTH_ROOT="${ZZIRIT_FIGMA_AUTH_ROOT:-$PROJECT_ROOT/artifacts/figma-auth}"
PLAYWRIGHT_CHANNEL="${ZZIRIT_FIGMA_PLAYWRIGHT_CHANNEL:-chrome}"
PROFILE_DIR="${ZZIRIT_FIGMA_PLAYWRIGHT_USER_DATA_DIR:-$AUTH_ROOT/chrome-profile}"
STORAGE_STATE="${ZZIRIT_FIGMA_PLAYWRIGHT_STORAGE_STATE:-$AUTH_ROOT/storage-state.json}"
STATUS_PATH="${ZZIRIT_FIGMA_AUTH_STATUS_PATH:-$AUTH_ROOT/auth-status.json}"
FIGMA_URL="${ZZIRIT_FIGMA_AUTH_URL:-${1:-https://www.figma.com/design/ZhysC3KZLAmKerfHTpg3G6/ZZIRIT---Master-Design--Copy-?node-id=31-3248&p=f&t=6rW5ccnhNgpH6wae-0}}"
AUTH_MONITOR_SCRIPT="$PROJECT_ROOT/scripts/review/figma-auth-monitor.cjs"

mkdir -p "$AUTH_ROOT" "$PROFILE_DIR"

cat <<EOF
[figma-auth] Opening a persistent Playwright Chrome session.
[figma-auth] profile_dir: $PROFILE_DIR
[figma-auth] storage_state: $STORAGE_STATE
[figma-auth] url: $FIGMA_URL

Instructions:
1. Log in to Figma in the opened Chrome window.
2. Confirm the target file opens successfully.
3. Close the browser window when finished.

When the browser closes, Playwright will save storage state to:
$STORAGE_STATE
EOF

ZZIRIT_FIGMA_AUTH_URL="$FIGMA_URL" \
ZZIRIT_FIGMA_PLAYWRIGHT_CHANNEL="$PLAYWRIGHT_CHANNEL" \
ZZIRIT_FIGMA_PLAYWRIGHT_USER_DATA_DIR="$PROFILE_DIR" \
ZZIRIT_FIGMA_PLAYWRIGHT_STORAGE_STATE="$STORAGE_STATE" \
ZZIRIT_FIGMA_AUTH_STATUS_PATH="$STATUS_PATH" \
node "$AUTH_MONITOR_SCRIPT"
