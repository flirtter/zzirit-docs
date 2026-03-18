#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
AUTH_ROOT="${ZZIRIT_FIGMA_AUTH_ROOT:-$PROJECT_ROOT/artifacts/figma-auth}"
PROFILE_DIR="${ZZIRIT_FIGMA_PLAYWRIGHT_USER_DATA_DIR:-$AUTH_ROOT/chrome-profile}"
DEBUG_PORT="${ZZIRIT_FIGMA_REMOTE_DEBUG_PORT:-9222}"
FIGMA_URL="${ZZIRIT_FIGMA_AUTH_URL:-${1:-https://www.figma.com/design/ZhysC3KZLAmKerfHTpg3G6/ZZIRIT---Master-Design--Copy-?node-id=31-3248&p=f&t=6rW5ccnhNgpH6wae-0}}"
LOG_PATH="${ZZIRIT_FIGMA_CDP_LOG_PATH:-$AUTH_ROOT/cdp-session.log}"

mkdir -p "$AUTH_ROOT" "$PROFILE_DIR"
pkill -f "remote-debugging-port=$DEBUG_PORT" 2>/dev/null || true
sleep 1

cat <<EOF
[figma-cdp] Opening a reusable Chrome session.
[figma-cdp] profile_dir: $PROFILE_DIR
[figma-cdp] remote_debug_port: $DEBUG_PORT
[figma-cdp] url: $FIGMA_URL
[figma-cdp] log: $LOG_PATH
EOF

nohup /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --profile-directory=Default \
  --remote-debugging-port="$DEBUG_PORT" \
  --user-data-dir="$PROFILE_DIR" \
  --window-size=1440,980 \
  "$FIGMA_URL" >"$LOG_PATH" 2>&1 &

echo $! >"$AUTH_ROOT/cdp-session.pid"
echo "http://127.0.0.1:$DEBUG_PORT"
