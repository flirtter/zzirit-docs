#!/bin/zsh
set -euo pipefail

ROOT="${ZZIRIT_AUTOMATION_ROOT:-/Users/user/zzirit-v2}"
FOCUS_SECTION="${1:-}"
RUN_DIR="${2:-}"
ASSETS_PER_TAB="${ZZIRIT_FIGMA_BUNDLE_ASSETS_PER_TAB:-2}"
UI_FOCUS_SECTIONS="${ZZIRIT_FIGMA_BUNDLE_UI_SECTIONS:-lightning meeting chat likes my}"
BUNDLE_SCRIPT="$ROOT/scripts/review/run-figma-cdp-bundle.py"
ASSET_MANIFEST_SCRIPT="$ROOT/scripts/review/extract-figma-asset-manifest.py"
MANUAL_IMPORT_SCRIPT="$ROOT/scripts/review/import-manual-design-references.py"
SCREENS_MANIFEST="$ROOT/artifacts/figma-reference/catalog/screens-manifest.json"
ASSETS_MANIFEST="$ROOT/artifacts/figma-reference/catalog/assets-manifest.json"
STATE_FILE="${ZZIRIT_FIGMA_BUNDLE_STATE_FILE:-$ROOT/artifacts/figma-reference/catalog/bundle-state.json}"
MANUAL_REF_ROOT="$ROOT/artifacts/manual-design-references/latest"
CONTEXT_DIR="${RUN_DIR:-$ROOT/artifacts/automation}/figma-bundle-context"
SUMMARY_PATH="$CONTEXT_DIR/summary.md"
LOG_PATH="$CONTEXT_DIR/bundle.log"
MANUAL_IMPORT_STATUS="not-run"

mkdir -p "$CONTEXT_DIR"

if [ -f "$MANUAL_IMPORT_SCRIPT" ]; then
  MANUAL_IMPORT_STATUS="$(python3 "$MANUAL_IMPORT_SCRIPT" 2>>"$LOG_PATH" || echo '{"status":"failed"}')"
  {
    echo "[prepare-figma-bundle] manual design import: $MANUAL_IMPORT_STATUS"
  } >> "$LOG_PATH"
fi

write_summary() {
  local manual_section=""
  local bundle_target="${FOCUS_SECTION:-}"
  case "${FOCUS_SECTION:-}" in
    likes)
      manual_section="MY"
      bundle_target="my"
      ;;
    my) manual_section="MY" ;;
    *) manual_section="${FOCUS_SECTION:-}" ;;
  esac

  local manual_detail="none"
  if [ -n "$manual_section" ] && [ -d "$MANUAL_REF_ROOT/$manual_section" ]; then
    manual_detail="$MANUAL_REF_ROOT/$manual_section"
  fi

  cat > "$SUMMARY_PATH" <<EOF
# Figma Bundle Context

- focus_section: ${FOCUS_SECTION:-none}
- bundle_target: ${bundle_target:-none}
- status: $1
- detail: $2
- log: $LOG_PATH
- manual_design_import: $MANUAL_IMPORT_STATUS
- manual_design_catalog: $MANUAL_REF_ROOT/catalog.md
- manual_design_section: $manual_detail
EOF
}

append_manual_refs() {
  local summary_file="$1"
  local manual_section=""
  local bundle_target="${FOCUS_SECTION:-}"
  case "${FOCUS_SECTION:-}" in
    likes)
      manual_section="MY"
      bundle_target="my"
      ;;
    my) manual_section="MY" ;;
    *) manual_section="${FOCUS_SECTION:-}" ;;
  esac

  local manual_detail="none"
  if [ -n "$manual_section" ] && [ -d "$MANUAL_REF_ROOT/$manual_section" ]; then
    manual_detail="$MANUAL_REF_ROOT/$manual_section"
  fi

  {
    echo
    echo "## Manual Design References"
    echo "- import_status: \`$MANUAL_IMPORT_STATUS\`"
    echo "- catalog: \`$MANUAL_REF_ROOT/catalog.md\`"
    echo "- section_dir: \`$manual_detail\`"
    echo "- bundle_target: \`$bundle_target\`"
  } >> "$summary_file"
}

should_run="0"
bundle_target="${FOCUS_SECTION:-}"
if [ "${FOCUS_SECTION:-}" = "likes" ]; then
  bundle_target="my"
fi
for section in ${(s: :)UI_FOCUS_SECTIONS}; do
  if [ "$section" = "$FOCUS_SECTION" ]; then
    should_run="1"
    break
  fi
done

if [ -z "$FOCUS_SECTION" ] || [ "$should_run" != "1" ]; then
  write_summary "skipped" "focus section is not a supported UI bundle target"
  echo "$SUMMARY_PATH"
  exit 0
fi

if [ ! -f "$SCREENS_MANIFEST" ]; then
  write_summary "blocked" "screens manifest missing: $SCREENS_MANIFEST"
  echo "$SUMMARY_PATH"
  exit 0
fi

if [ -f "$ASSET_MANIFEST_SCRIPT" ]; then
  if ! python3 "$ASSET_MANIFEST_SCRIPT" >>"$LOG_PATH" 2>&1; then
    {
      echo
      echo "[prepare-figma-bundle] asset manifest refresh failed"
    } >> "$LOG_PATH"
  fi
fi

if [ ! -f "$ASSETS_MANIFEST" ]; then
  write_summary "blocked" "assets manifest missing: $ASSETS_MANIFEST"
  echo "$SUMMARY_PATH"
  exit 0
fi

if [ ! -f "$BUNDLE_SCRIPT" ]; then
  write_summary "blocked" "bundle script missing: $BUNDLE_SCRIPT"
  echo "$SUMMARY_PATH"
  exit 0
fi

if python3 "$BUNDLE_SCRIPT" \
  --screens-manifest "$SCREENS_MANIFEST" \
  --assets-manifest "$ASSETS_MANIFEST" \
  --state-file "$STATE_FILE" \
  --assets-per-tab "$ASSETS_PER_TAB" \
  --tabs "$bundle_target" \
  --run-root "$CONTEXT_DIR" >>"$LOG_PATH" 2>&1; then
  if [ -f "$SUMMARY_PATH" ]; then
    append_manual_refs "$SUMMARY_PATH"
    echo "$SUMMARY_PATH"
    exit 0
  fi
  write_summary "completed" "bundle script finished but summary was not produced"
  echo "$SUMMARY_PATH"
  exit 0
fi

write_summary "blocked" "bundle script execution failed"
echo "$SUMMARY_PATH"
exit 0
