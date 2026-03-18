#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
MAP_FILE="${ZZIRIT_FIGMA_BASELINE_MAP_FILE:-$PROJECT_ROOT/scripts/review/figma-baseline-map.json}"
SCREEN_KEY="${ZZIRIT_FIGMA_SCREEN_KEY:-${1:-}}"

if [ -z "$SCREEN_KEY" ]; then
  echo "Usage: ZZIRIT_FIGMA_SCREEN_KEY=<screen-key> $0" >&2
  exit 1
fi

FIGMA_NODE_ID="$(
  python3 - "$MAP_FILE" "$SCREEN_KEY" <<'PY'
import json
import sys
from pathlib import Path

map_file = Path(sys.argv[1])
screen_key = sys.argv[2]
mapping = json.loads(map_file.read_text(encoding="utf-8")) if map_file.exists() else []
if isinstance(mapping, dict):
    mapping = mapping.get("screens", [])
for item in mapping:
    if item.get("screen_key") == screen_key or item.get("key") == screen_key:
        print(item.get("node_id", item.get("figma_node_id", "")))
        raise SystemExit
raise SystemExit(1)
PY
)"

export FIGMA_NODE_ID
export ZZIRIT_FIGMA_SCREEN_KEY="$SCREEN_KEY"
bash "$PROJECT_ROOT/scripts/review/fetch-figma-playwright.sh"
