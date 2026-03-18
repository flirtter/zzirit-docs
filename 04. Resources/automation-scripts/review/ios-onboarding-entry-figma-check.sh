#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
REPORT_ROOT="${ZZIRIT_ONBOARDING_ENTRY_REPORT_DIR:-$PROJECT_ROOT/artifacts/ios-onboarding-entry}"
SIM_NAME="${ZZIRIT_IOS_SIMULATOR_NAME:-iPhone 16e}"
APP_BUNDLE_ID="${ZZIRIT_IOS_APP_BUNDLE_ID:-com.flirtter.zziritApp}"
START_EXPO="${ZZIRIT_IOS_START_EXPO:-1}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$REPORT_ROOT/$TIMESTAMP"
SUMMARY_PATH="$RUN_DIR/summary.md"
STRICT_ENFORCE="${ZZIRIT_FIGMA_STRICT_ENFORCE:-0}"
OVERALL_EXIT=0

mkdir -p "$RUN_DIR"

declare -a THEMES=("blue" "green" "pink" "yellow")

screen_key_for_theme() {
  case "$1" in
    blue) echo "onboarding_entry_blue" ;;
    green) echo "onboarding_entry_green" ;;
    pink) echo "onboarding_entry_pink" ;;
    yellow) echo "onboarding_entry_yellow" ;;
    *)
      echo ""
      ;;
  esac
}

{
  echo "# iOS Onboarding Entry Figma Check"
  echo
  echo "- simulator: $SIM_NAME"
  echo "- app_bundle_id: $APP_BUNDLE_ID"
  echo "- run_dir: $RUN_DIR"
  echo
  echo "## Theme Runs"
  echo
} > "$SUMMARY_PATH"

for theme in "${THEMES[@]}"; do
  screen_key="$(screen_key_for_theme "$theme")"
  theme_dir="$RUN_DIR/$theme"
  mkdir -p "$theme_dir"

  theme_exit=0
  if ! ZZIRIT_IOS_REPORT_DIR="$theme_dir" \
    ZZIRIT_FIGMA_REPORT_DIR="$PROJECT_ROOT/artifacts/figma-reference" \
    ZZIRIT_IOS_SIMULATOR_NAME="$SIM_NAME" \
    ZZIRIT_IOS_APP_BUNDLE_ID="$APP_BUNDLE_ID" \
    ZZIRIT_IOS_START_EXPO="$START_EXPO" \
    ZZIRIT_IOS_OPEN_URL="zzirit://login?theme=$theme" \
    ZZIRIT_FIGMA_SCREEN_KEY="$screen_key" \
    ZZIRIT_IOS_SCREENSHOT_NAME="${theme}-login.png" \
    ZZIRIT_FIGMA_STRICT_ENFORCE="$STRICT_ENFORCE" \
    bash "$PROJECT_ROOT/scripts/review/ios-figma-judgment.sh"; then
    theme_exit=$?
    OVERALL_EXIT=$theme_exit
  fi

  summary_file="$(find "$theme_dir" -maxdepth 1 -type f -name '*-figma-judge.md' | sort | tail -n 1)"
  screenshot_file="$(find "$theme_dir" -maxdepth 1 -type f -name "*-${theme}-login.png" | sort | tail -n 1)"
  strict_status="$(awk -F': ' '/^- strict parity status:/ {print $2}' "$summary_file" 2>/dev/null | tail -n 1)"
  strict_reason="$(awk -F': ' '/^- strict parity reason:/ {print $2}' "$summary_file" 2>/dev/null | tail -n 1)"

  {
    echo "- theme: $theme"
    echo "  - screen_key: $screen_key"
    echo "  - summary: ${summary_file:-missing}"
    echo "  - screenshot: ${screenshot_file:-missing}"
    echo "  - strict_status: ${strict_status:-unknown}"
    echo "  - strict_reason: ${strict_reason:-unknown}"
    echo "  - exit_code: ${theme_exit:-0}"
  } >> "$SUMMARY_PATH"
done

echo "$SUMMARY_PATH"
exit "$OVERALL_EXIT"
