#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TIMESTAMP="${ZZIRIT_FIGMA_ASSET_SAMPLE_TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}"
RUN_ROOT="${ZZIRIT_FIGMA_ASSET_SAMPLE_RUN_ROOT:-$PROJECT_ROOT/artifacts/figma-reference/asset-samples/$TIMESTAMP}"

mkdir -p "$RUN_ROOT"

targets=(
  "lightning-card-image|I20295:24901;20234:7973"
  "my-bolt-photo|20451:10145"
  "my-like-card-image|I20220:27642;20220:27626"
)

summary="$RUN_ROOT/summary.md"
{
  echo "# Figma Asset Sample Capture"
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
        --padding 6 \
        --min-width 30 \
        --min-height 30 \
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
