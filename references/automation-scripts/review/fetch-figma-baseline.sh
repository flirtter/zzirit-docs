#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
AUTOMATION_ENV_FILE="${ZZIRIT_AUTOMATION_ENV_FILE:-$HOME/.zzirit-automation.env}"
FIGMA_FILE_KEY="${FIGMA_FILE_KEY:-ZhysC3KZLAmKerfHTpg3G6}"
OUTPUT_ROOT="${ZZIRIT_FIGMA_BASELINE_DIR:-$PROJECT_ROOT/artifacts/figma-reference/baseline}"
DEFAULT_SIMPLE_MAP="$PROJECT_ROOT/scripts/review/figma-baseline-map.json"
DEFAULT_NODE_MAP="$PROJECT_ROOT/docs/spec/figma-node-map.json"
if [ -n "${ZZIRIT_FIGMA_BASELINE_MAP_FILE:-}" ]; then
  FIGMA_MAP_FILE="$ZZIRIT_FIGMA_BASELINE_MAP_FILE"
elif [ -f "$DEFAULT_SIMPLE_MAP" ]; then
  FIGMA_MAP_FILE="$DEFAULT_SIMPLE_MAP"
else
  FIGMA_MAP_FILE="$DEFAULT_NODE_MAP"
fi
NODE_IDS="${ZZIRIT_FIGMA_BASELINE_NODE_IDS:-}"
USE_PLAYWRIGHT_FALLBACK="${ZZIRIT_FIGMA_USE_PLAYWRIGHT:-1}"
PLAYWRIGHT_SCRIPT="$PROJECT_ROOT/scripts/review/fetch-figma-playwright.sh"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$OUTPUT_ROOT/$TIMESTAMP"
SUMMARY_PATH="$RUN_DIR/summary.md"

mkdir -p "$RUN_DIR"

if [ -f "$AUTOMATION_ENV_FILE" ]; then
  set -a
  . "$AUTOMATION_ENV_FILE"
  set +a
fi

ITEMS_FILE="$(mktemp)"
python3 - "$FIGMA_MAP_FILE" "$NODE_IDS" <<'PY' >"$ITEMS_FILE"
import json
import sys
from pathlib import Path

map_file = Path(sys.argv[1])
node_id_arg = sys.argv[2].strip()
mapping = json.loads(map_file.read_text(encoding="utf-8")) if map_file.exists() else []
if isinstance(mapping, dict):
    mapping = mapping.get("screens", [])

if node_id_arg:
    wanted = {item.strip() for item in node_id_arg.split(",") if item.strip()}
    items = []
    for node_id in wanted:
        found = next(
            (
                entry
                for entry in mapping
                if entry.get("node_id") == node_id or entry.get("figma_node_id") == node_id
            ),
            None,
        )
        if found is None:
            items.append(
                {
                    "screen_key": node_id.replace(":", "-"),
                    "node_id": node_id,
                    "label": node_id,
                }
            )
        else:
            items.append(found)
else:
    items = [entry for entry in mapping if entry.get("node_id") or entry.get("figma_node_id")]

for item in items:
    print(
        "\t".join(
            [
                item.get("screen_key", item.get("key", "")),
                item.get("node_id", item.get("figma_node_id", "")),
                item.get("label", item.get("route", item.get("key", ""))),
            ]
        )
    )
PY

{
  echo "# Figma Baseline Capture"
  echo
  echo "- file_key: $FIGMA_FILE_KEY"
  echo "- run_dir: $RUN_DIR"
  echo "- api_key_present: $( [ -n "${FIGMA_API_KEY:-}" ] && echo yes || echo no )"
  echo "- playwright_fallback: $( [ "$USE_PLAYWRIGHT_FALLBACK" = "1" ] && echo enabled || echo disabled )"
  echo
  echo "## Captured Nodes"
  echo
} >"$SUMMARY_PATH"

while IFS= read -r item; do
  screen_key="$(printf '%s' "$item" | cut -f1)"
  node_id="$(printf '%s' "$item" | cut -f2)"
  label="$(printf '%s' "$item" | cut -f3)"

  if [ -z "$node_id" ]; then
    continue
  fi

  safe_node_id="${node_id//:/-}"
  output_path="$RUN_DIR/${screen_key}-${safe_node_id}.png"
  source="missing"
  warning=""

  if [ -n "${FIGMA_API_KEY:-}" ]; then
    api_json="$(mktemp)"
    api_status="$(
      curl -sS -L -w '%{http_code}' -o "$api_json" \
        -H "X-Figma-Token: $FIGMA_API_KEY" \
        "https://api.figma.com/v1/images/$FIGMA_FILE_KEY?ids=$node_id&format=png&scale=2"
    )"

    if [ "$api_status" = "200" ]; then
      image_url="$(
        node -e "const fs=require('fs'); const d=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const id=process.argv[2]; process.stdout.write((d.images && d.images[id]) || '');" "$api_json" "$node_id"
      )"
      if [ -n "$image_url" ]; then
        curl -sS -L "$image_url" -o "$output_path"
        source="api"
      else
        warning="api-no-image-url"
      fi
    else
      warning="api-http-$api_status"
    fi
    rm -f "$api_json"
  else
    warning="api-key-missing"
  fi

  if [ "$source" = "missing" ] && [ "$USE_PLAYWRIGHT_FALLBACK" = "1" ]; then
    if FIGMA_FILE_KEY="$FIGMA_FILE_KEY" \
      FIGMA_NODE_ID="$node_id" \
      ZZIRIT_FIGMA_SCREEN_KEY="$screen_key" \
      FIGMA_OUTPUT_PATH="$output_path" \
      ZZIRIT_FIGMA_PLAYWRIGHT_RUN_DIR="$RUN_DIR/playwright-$screen_key" \
      bash "$PLAYWRIGHT_SCRIPT" >/dev/null 2>&1; then
      source="playwright"
    else
      if [ -n "$warning" ]; then
        warning="$warning,playwright-failed"
      else
        warning="playwright-failed"
      fi
    fi
  fi

  if [ -f "$output_path" ]; then
    echo "- $screen_key: $label ($node_id) -> $output_path [source=$source${warning:+ warning=$warning}]" >>"$SUMMARY_PATH"
  else
    echo "- $screen_key: $label ($node_id) -> missing image [source=$source${warning:+ warning=$warning}]" >>"$SUMMARY_PATH"
  fi
done <"$ITEMS_FILE"

rm -f "$ITEMS_FILE"

ln -sfn "$RUN_DIR" "$OUTPUT_ROOT/latest"
echo "$SUMMARY_PATH"
