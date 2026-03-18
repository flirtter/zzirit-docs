#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TIMESTAMP="${ZZIRIT_FIGMA_SMOKE_TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}"
RUN_ROOT="${ZZIRIT_FIGMA_SMOKE_RUN_ROOT:-$PROJECT_ROOT/artifacts/figma-reference/cdp-smoke/$TIMESTAMP}"

mkdir -p "$RUN_ROOT"

targets=(
  "lightning-tab|20220:17365"
  "meeting-tab|20220:17704"
  "chat-list|20220:19790"
  "my-home|20220:18367"
)

summary="$RUN_ROOT/summary.md"
{
  echo "# Figma CDP Smoke"
  echo
  echo "- timestamp: $TIMESTAMP"
  echo "- run_root: $RUN_ROOT"
  echo "- capture_method: cdp_selection_crop"
  echo
  echo "## Results"
} >"$summary"

for target in "${targets[@]}"; do
  name="${target%%|*}"
  node_id="${target##*|}"
  raw_path="$RUN_ROOT/${name}-raw.png"
  cropped_path="$RUN_ROOT/${name}-cropped.png"
  json_path="$RUN_ROOT/${name}.json"
  err_path="$RUN_ROOT/${name}.err"

  if FIGMA_NODE_ID="$node_id" FIGMA_OUTPUT_PATH="$raw_path" \
      node "$PROJECT_ROOT/scripts/review/figma-cdp-screenshot-node.cjs" >"$json_path" 2>"$err_path"; then
    if python3 "$PROJECT_ROOT/scripts/review/detect-figma-selection-crop.py" "$raw_path" "$cropped_path" \
        >>"$json_path" 2>>"$err_path"; then
      {
        echo "- [ok] \`$name\` \`$node_id\`"
        echo "  - raw: \`$raw_path\`"
        echo "  - cropped: \`$cropped_path\`"
        echo "  - meta: \`$json_path\`"
      } >>"$summary"
      continue
    fi
  fi

  {
    echo "- [error] \`$name\` \`$node_id\`"
    echo "  - raw: \`$raw_path\`"
    echo "  - meta: \`$json_path\`"
    echo "  - err: \`$err_path\`"
  } >>"$summary"
done

echo "$RUN_ROOT"
