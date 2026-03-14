#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_PLAN_REVIEW_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SLICE="${1:-product}"
MODEL="${ZZIRIT_PLAN_REVIEW_MODEL:-qwen2.5-coder:7b}"
ARTIFACT_ROOT="${ZZIRIT_PLAN_REVIEW_ARTIFACT_ROOT:-$PROJECT_ROOT/artifacts/plan-review}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$ARTIFACT_ROOT/$TIMESTAMP-$SLICE"
PROMPT_PATH="$RUN_DIR/prompt.md"
OUTPUT_PATH="$RUN_DIR/review.md"
META_PATH="$RUN_DIR/meta.json"

mkdir -p "$RUN_DIR"

declare -a FILES
SLICE_LABEL=""

case "$SLICE" in
  product)
    SLICE_LABEL="Product Scope And Phase Plan"
    FILES=(
      "/Users/user/zzirit-plan.md"
      "$PROJECT_ROOT/README.md"
      "$PROJECT_ROOT/docs/master-plan.md"
      "$PROJECT_ROOT/docs/spec/product-baseline.md"
      "$PROJECT_ROOT/docs/spec/gap-audit-20260308.md"
    )
    ;;
  architecture)
    SLICE_LABEL="Architecture And Data Boundaries"
    FILES=(
      "/Users/user/zzirit-plan.md"
      "$PROJECT_ROOT/docs/architecture.md"
      "$PROJECT_ROOT/docs/spec/api-contract-baseline.md"
      "$PROJECT_ROOT/docs/spec/data-model-baseline.md"
      "$PROJECT_ROOT/docs/spec/gap-audit-20260308.md"
    )
    ;;
  qa)
    SLICE_LABEL="QA, Delivery, And Automation"
    FILES=(
      "$PROJECT_ROOT/README.md"
      "$PROJECT_ROOT/docs/master-plan.md"
      "$PROJECT_ROOT/docs/qa-strategy.md"
      "$PROJECT_ROOT/docs/spec/design-baseline.md"
      "$PROJECT_ROOT/docs/spec/gap-audit-20260308.md"
    )
    ;;
  design)
    SLICE_LABEL="Design Parity And Figma Coverage"
    FILES=(
      "$PROJECT_ROOT/README.md"
      "$PROJECT_ROOT/docs/spec/design-baseline.md"
      "$PROJECT_ROOT/docs/spec/product-baseline.md"
      "$PROJECT_ROOT/docs/spec/gap-audit-20260308.md"
      "$PROJECT_ROOT/apps/mobile/app/login/index.tsx"
    )
    ;;
  *)
    echo "Unsupported slice: $SLICE" >&2
    exit 1
    ;;
esac

{
  echo "# Review Request"
  echo
  echo "You are reviewing a software delivery plan in PLAN MODE."
  echo
  echo "Slice: $SLICE_LABEL"
  echo "Goal: implement every product requirement from the ZZIRIT Figma planning and design files."
  echo
  echo "Review rules:"
  echo "- review only this slice, not the whole project"
  echo "- be strict about omissions, sequencing mistakes, contradictions, and risky assumptions"
  echo "- prefer concrete plan edits over vague advice"
  echo "- when a plan item is already good enough, say so briefly and move on"
  echo "- do not rewrite the whole plan"
  echo
  echo "Output format:"
  echo "1. Findings"
  echo "2. Recommended plan edits"
  echo "3. Open risks after those edits"
  echo
  echo "Target files:"
  for file in "${FILES[@]}"; do
    echo "- $file"
  done
  echo
  for file in "${FILES[@]}"; do
    echo "----- BEGIN FILE: $file -----"
    sed -n '1,260p' "$file"
    echo
    echo "----- END FILE: $file -----"
    echo
  done
} > "$PROMPT_PATH"

python3 - "$MODEL" "$PROMPT_PATH" "$OUTPUT_PATH" "$META_PATH" "$SLICE" "$SLICE_LABEL" <<'PY'
from __future__ import annotations

import json
import sys
import urllib.request
from pathlib import Path

model = sys.argv[1]
prompt_path = Path(sys.argv[2])
output_path = Path(sys.argv[3])
meta_path = Path(sys.argv[4])
slice_name = sys.argv[5]
slice_label = sys.argv[6]
prompt = prompt_path.read_text(encoding="utf-8")

request = urllib.request.Request(
    "http://127.0.0.1:11434/api/generate",
    data=json.dumps(
        {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.2,
            },
        }
    ).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)

with urllib.request.urlopen(request, timeout=180) as response:
    payload = json.loads(response.read().decode("utf-8"))

output_path.write_text(payload.get("response", "").strip() + "\n", encoding="utf-8")
meta_path.write_text(
    json.dumps(
        {
            "model": model,
            "slice": slice_name,
            "slice_label": slice_label,
            "prompt_path": str(prompt_path),
            "output_path": str(output_path),
        },
        ensure_ascii=True,
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)
PY

echo "$OUTPUT_PATH"
