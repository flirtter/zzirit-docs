#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
REPORT_DIR="${ZZIRIT_IOS_REPORT_DIR:-$PROJECT_ROOT/artifacts/ios-visual}"
FIGMA_REPORT_DIR="${ZZIRIT_FIGMA_REPORT_DIR:-$PROJECT_ROOT/artifacts/figma-reference}"
FIGMA_MAP_FILE="${ZZIRIT_FIGMA_MAP_FILE:-$PROJECT_ROOT/scripts/review/figma-baseline-map.json}"
FIGMA_DESIGN_CACHE_FILE="${ZZIRIT_FIGMA_DESIGN_CACHE_FILE:-$PROJECT_ROOT/artifacts/figma-api/design-file.json}"
VISUAL_SCRIPT="$PROJECT_ROOT/scripts/review/ios-visual-check.sh"
PLAYWRIGHT_SCRIPT="$PROJECT_ROOT/scripts/review/fetch-figma-playwright.sh"
STRICT_GATE_SCRIPT="$PROJECT_ROOT/scripts/review/figma-strict-gate.py"
FIGMA_API_KEY_VALUE="${FIGMA_API_KEY:-}"
FIGMA_FILE_KEY="${FIGMA_FILE_KEY:-ZhysC3KZLAmKerfHTpg3G6}"
FIGMA_NODE_ID="${FIGMA_NODE_ID:-}"
FIGMA_SCREEN_KEY="${ZZIRIT_FIGMA_SCREEN_KEY:-}"
FIGMA_IMAGE_SCALE="${ZZIRIT_FIGMA_IMAGE_SCALE:-2}"
FIGMA_IMAGE_FORMAT="${ZZIRIT_FIGMA_IMAGE_FORMAT:-png}"
FIGMA_IMAGE_PATH="${ZZIRIT_FIGMA_IMAGE_PATH:-}"
FALLBACK_SCREENSHOT_PATH="${ZZIRIT_IOS_FALLBACK_SCREENSHOT:-}"
APP_SCREENSHOT_SOURCE="${ZZIRIT_IOS_APP_SCREENSHOT_SOURCE:-}"
APP_SCREENSHOT_FRESH="${ZZIRIT_IOS_APP_SCREENSHOT_FRESH:-}"
APP_SCREENSHOT_ROUTE_ACCURATE="${ZZIRIT_IOS_APP_SCREENSHOT_ROUTE_ACCURATE:-}"
STRICT_ENFORCE="${ZZIRIT_FIGMA_STRICT_ENFORCE:-0}"
ALLOW_PLAYWRIGHT_FALLBACK="${ZZIRIT_FIGMA_ALLOW_PLAYWRIGHT_FALLBACK:-1}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SUMMARY_PATH="$REPORT_DIR/${TIMESTAMP}-figma-judge.md"

mkdir -p "$REPORT_DIR" "$FIGMA_REPORT_DIR"

if [ -n "$FALLBACK_SCREENSHOT_PATH" ]; then
  SCREEN_PATH="$FALLBACK_SCREENSHOT_PATH"
  APP_SCREENSHOT_SOURCE="${APP_SCREENSHOT_SOURCE:-fallback-screenshot}"
  APP_SCREENSHOT_FRESH="${APP_SCREENSHOT_FRESH:-no}"
  APP_SCREENSHOT_ROUTE_ACCURATE="${APP_SCREENSHOT_ROUTE_ACCURATE:-no}"
else
  bash "$VISUAL_SCRIPT"
  SCREEN_PATH="$(find "$REPORT_DIR" -type f -name '*.png' | sort | tail -n 1)"
  APP_SCREENSHOT_SOURCE="${APP_SCREENSHOT_SOURCE:-simulator-fresh}"
  APP_SCREENSHOT_FRESH="${APP_SCREENSHOT_FRESH:-yes}"
  APP_SCREENSHOT_ROUTE_ACCURATE="${APP_SCREENSHOT_ROUTE_ACCURATE:-yes}"
fi

if [ -z "$SCREEN_PATH" ]; then
  {
    echo "# iOS vs Figma"
    echo
    echo "- status: blocked"
    echo "- reason: screenshot not found"
  } >"$SUMMARY_PATH"
  echo "[ios-figma] screenshot not found"
  exit 1
fi

resolve_node_name() {
  python3 - "$FIGMA_DESIGN_CACHE_FILE" "$1" <<'PY'
import json
import sys
from pathlib import Path

cache_path = Path(sys.argv[1])
target = sys.argv[2]
if not cache_path.exists():
    raise SystemExit(0)

payload = json.loads(cache_path.read_text(encoding="utf-8"))
stack = [payload.get("document") or {}]
while stack:
    node = stack.pop()
    if node.get("id") == target:
        print(node.get("name", ""))
        break
    stack.extend(reversed(node.get("children", [])))
PY
}

REF_PATH="$FIGMA_IMAGE_PATH"
NODE_NAME=""
FIGMA_REFERENCE_SOURCE="provided"
FIGMA_API_STATUS="not-requested"
FIGMA_WARNING=""
PLAYWRIGHT_SUMMARY_PATH=""

if [ -z "$FIGMA_NODE_ID" ] && [ -n "$FIGMA_SCREEN_KEY" ] && [ -f "$FIGMA_MAP_FILE" ]; then
  FIGMA_NODE_ID="$(python3 - "$FIGMA_MAP_FILE" "$FIGMA_SCREEN_KEY" <<'PY'
import json
import sys
from pathlib import Path

mapping = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
screen_key = sys.argv[2]
for item in mapping:
    if item.get("screen_key") == screen_key:
        print(item.get("node_id", ""))
        break
PY
)"
fi

if [ -n "$FIGMA_NODE_ID" ]; then
  NODE_NAME="$(resolve_node_name "$FIGMA_NODE_ID")"
fi

if [ -z "$REF_PATH" ] && [ -n "$FIGMA_SCREEN_KEY" ]; then
  cached_ref="$(find "$FIGMA_REPORT_DIR/baseline/latest" -type f -name "${FIGMA_SCREEN_KEY}-*.png" 2>/dev/null | head -n 1)"
  if [ -n "$cached_ref" ]; then
    REF_PATH="$cached_ref"
    FIGMA_REFERENCE_SOURCE="cached"
  fi
fi

if [ -z "$REF_PATH" ]; then
  if [ -n "$FIGMA_API_KEY_VALUE" ] && [ -n "$FIGMA_FILE_KEY" ] && [ -n "$FIGMA_NODE_ID" ]; then
    IMAGES_JSON="$(mktemp)"
    FIGMA_API_STATUS="$(
      curl -sS -L -w '%{http_code}' -o "$IMAGES_JSON" \
        -H "X-Figma-Token: $FIGMA_API_KEY_VALUE" \
        "https://api.figma.com/v1/images/$FIGMA_FILE_KEY?ids=$FIGMA_NODE_ID&format=$FIGMA_IMAGE_FORMAT&scale=$FIGMA_IMAGE_SCALE"
    )"

    if [ "$FIGMA_API_STATUS" = "200" ]; then
      IMAGE_URL="$(
        node -e "const fs=require('fs'); const d=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const id=process.argv[2]; process.stdout.write((d.images && d.images[id]) || '');" "$IMAGES_JSON" "$FIGMA_NODE_ID"
      )"
      if [ -n "$IMAGE_URL" ]; then
        REF_PATH="$FIGMA_REPORT_DIR/${TIMESTAMP}-figma-${FIGMA_NODE_ID//:/-}.${FIGMA_IMAGE_FORMAT}"
        curl -sS -L "$IMAGE_URL" -o "$REF_PATH"
        FIGMA_REFERENCE_SOURCE="api"
      else
        FIGMA_WARNING="api-no-image-url"
      fi
    else
      FIGMA_WARNING="api-http-$FIGMA_API_STATUS"
    fi
    rm -f "$IMAGES_JSON"
  else
    FIGMA_API_STATUS="skipped"
  fi

  if [ -z "$REF_PATH" ] && [ -n "$FIGMA_NODE_ID" ] && [ "$ALLOW_PLAYWRIGHT_FALLBACK" = "1" ]; then
    REF_PATH="$FIGMA_REPORT_DIR/${TIMESTAMP}-figma-${FIGMA_NODE_ID//:/-}.png"
    PLAYWRIGHT_SUMMARY_PATH="$FIGMA_REPORT_DIR/${TIMESTAMP}-figma-${FIGMA_NODE_ID//:/-}-playwright.md"
    if FIGMA_FILE_KEY="$FIGMA_FILE_KEY" \
      FIGMA_NODE_ID="$FIGMA_NODE_ID" \
      ZZIRIT_FIGMA_SCREEN_KEY="$FIGMA_SCREEN_KEY" \
      FIGMA_OUTPUT_PATH="$REF_PATH" \
      ZZIRIT_FIGMA_PLAYWRIGHT_SUMMARY_PATH="$PLAYWRIGHT_SUMMARY_PATH" \
      bash "$PLAYWRIGHT_SCRIPT" >/dev/null 2>&1; then
      FIGMA_REFERENCE_SOURCE="playwright"
    else
      REF_PATH=""
      if [ -n "$FIGMA_WARNING" ]; then
        FIGMA_WARNING="$FIGMA_WARNING,playwright-failed"
      else
        FIGMA_WARNING="playwright-failed"
      fi
    fi
  fi
fi

if [ -z "$REF_PATH" ]; then
  {
    echo "# iOS vs Figma"
    echo
    echo "- status: blocked"
    echo "- App screenshot: $SCREEN_PATH"
    echo "- App screenshot source: $APP_SCREENSHOT_SOURCE"
    echo "- App screenshot fresh: $APP_SCREENSHOT_FRESH"
    echo "- App screenshot route accurate: $APP_SCREENSHOT_ROUTE_ACCURATE"
    echo "- Figma file: $FIGMA_FILE_KEY"
    if [ -n "$FIGMA_SCREEN_KEY" ]; then
      echo "- Figma screen key: $FIGMA_SCREEN_KEY"
    fi
    echo "- Figma node: ${FIGMA_NODE_ID:-missing}"
    echo "- Figma reference source: unresolved"
    echo "- strict parity status: blocked"
    echo "- strict parity reference kind: unresolved"
    echo "- strict parity reason: figma-reference-unresolved"
    echo "- Figma API status: $FIGMA_API_STATUS"
    if [ -n "$FIGMA_WARNING" ]; then
      echo "- Figma warning: $FIGMA_WARNING"
    fi
    if [ -n "$PLAYWRIGHT_SUMMARY_PATH" ]; then
      echo "- Playwright summary: $PLAYWRIGHT_SUMMARY_PATH"
    fi
    echo "- reason: Figma reference could not be resolved from cache, API, or Playwright fallback"
  } >"$SUMMARY_PATH"
  echo "[ios-figma] Figma reference not resolved for node ${FIGMA_NODE_ID:-missing}"
  exit 1
fi

STRICT_PAYLOAD="$(
  python3 "$STRICT_GATE_SCRIPT" \
    --app-source "$APP_SCREENSHOT_SOURCE" \
    --app-fresh "$APP_SCREENSHOT_FRESH" \
    --app-route-accurate "$APP_SCREENSHOT_ROUTE_ACCURATE" \
    --figma-source "$FIGMA_REFERENCE_SOURCE" \
    --figma-path "$REF_PATH"
)"
STRICT_STATUS="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["status"])' <<<"$STRICT_PAYLOAD")"
STRICT_REFERENCE_KIND="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["reference_kind"])' <<<"$STRICT_PAYLOAD")"
STRICT_REASON="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["reason"])' <<<"$STRICT_PAYLOAD")"

{
  echo "# iOS vs Figma"
  echo
  echo "- status: compared"
  echo "- App screenshot: $SCREEN_PATH"
  echo "- App screenshot source: $APP_SCREENSHOT_SOURCE"
  echo "- App screenshot fresh: $APP_SCREENSHOT_FRESH"
  echo "- App screenshot route accurate: $APP_SCREENSHOT_ROUTE_ACCURATE"
  echo "- Figma reference: $REF_PATH"
  echo "- Figma reference source: $FIGMA_REFERENCE_SOURCE"
  echo "- strict parity status: $STRICT_STATUS"
  echo "- strict parity reference kind: $STRICT_REFERENCE_KIND"
  echo "- strict parity reason: $STRICT_REASON"
  echo "- Figma API status: $FIGMA_API_STATUS"
  if [ -n "$FIGMA_SCREEN_KEY" ]; then
    echo "- Figma screen key: $FIGMA_SCREEN_KEY"
  fi
  if [ -n "$FIGMA_NODE_ID" ]; then
    echo "- Figma node: $FIGMA_NODE_ID"
  fi
  if [ -n "$NODE_NAME" ]; then
    echo "- Figma node name: $NODE_NAME"
  fi
  if [ -n "$FIGMA_WARNING" ]; then
    echo "- Figma warning: $FIGMA_WARNING"
  fi
  if [ -n "$PLAYWRIGHT_SUMMARY_PATH" ] && [ -f "$PLAYWRIGHT_SUMMARY_PATH" ]; then
    echo "- Playwright summary: $PLAYWRIGHT_SUMMARY_PATH"
  fi
  echo
  echo "## Manual decision checklist"
  echo
  echo "- typography scale and line height"
  echo "- CTA placement and spacing"
  echo "- safe area / bottom inset usage"
  echo "- input spacing / keyboard overlap"
  echo "- text truncation / empty state handling"
} >"$SUMMARY_PATH"

echo "[ios-figma] Summary: $SUMMARY_PATH"
echo "[ios-figma] App screenshot: $SCREEN_PATH"
echo "[ios-figma] Figma reference: $REF_PATH"

if [ "$STRICT_ENFORCE" = "1" ] && [ "$STRICT_STATUS" != "verified" ]; then
  echo "[ios-figma] strict parity blocked: $STRICT_REASON"
  exit 2
fi
