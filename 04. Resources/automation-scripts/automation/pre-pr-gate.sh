#!/usr/bin/env bash
set -euo pipefail

ROOT="${ZZIRIT_AUTOMATION_ROOT:-/Users/user/zzirit-v2}"
FOCUS_SECTION="${1:-${ZZIRIT_FOCUS_SECTION:-}}"
REPORT_ROOT="${ZZIRIT_PRE_PR_REPORT_ROOT:-$ROOT/artifacts/pre-pr}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="${REPORT_ROOT}/${TIMESTAMP}-${FOCUS_SECTION:-unknown}"
LOG_PATH="$RUN_DIR/pre-pr-gate.log"
SUMMARY_PATH="$RUN_DIR/summary.md"
FAILURES=0
UI_FOCUS=0

mkdir -p "$RUN_DIR"

if [ -z "$FOCUS_SECTION" ]; then
  echo "usage: $0 <focus-section>" >&2
  echo "example: $0 login" >&2
  exit 2
fi

case "$FOCUS_SECTION" in
  login|onboarding|lightning|meeting|chat|likes|my)
    UI_FOCUS=1
    ;;
esac

run_step() {
  local name="$1"
  shift

  echo "[pre-pr] running $name" | tee -a "$LOG_PATH"
  if "$@" >>"$LOG_PATH" 2>&1; then
    {
      echo "## $name"
      echo
      echo "- status: pass"
      echo
    } >>"$SUMMARY_PATH"
  else
    FAILURES=$((FAILURES + 1))
    {
      echo "## $name"
      echo
      echo "- status: fail"
      echo "- log: $LOG_PATH"
      echo
    } >>"$SUMMARY_PATH"
  fi
}

append_file_if_exists() {
  local label="$1"
  local path="$2"

  [ -f "$path" ] || return 0
  echo "- ${label}: $path" >>"$SUMMARY_PATH"
}

append_latest_dir_if_exists() {
  local label="$1"
  local search_root="$2"

  [ -d "$search_root" ] || return 0

  local latest_dir
  latest_dir="$(find "$search_root" -maxdepth 1 -mindepth 1 -type d | sort | tail -n 1)"
  [ -n "$latest_dir" ] || return 0
  echo "- ${label}: $latest_dir" >>"$SUMMARY_PATH"
}

{
  echo "# Pre-PR Gate"
  echo
  echo "- focus_section: $FOCUS_SECTION"
  echo "- run_dir: $RUN_DIR"
  echo "- log: $LOG_PATH"
  echo "- ui_focus: $([ "$UI_FOCUS" -eq 1 ] && echo yes || echo no)"
  echo
  echo "## Policy"
  echo
  echo "- PR 전에는 focus 기준 QA를 한 번 통과시키고 요약 아티팩트를 남긴다."
  echo "- merge 전 전체 회귀는 별도 total check로 수행한다."
  echo "- UI focus는 host QA와 디자인 evidence 없이 review-ready로 간주하지 않는다."
  echo
} >"$SUMMARY_PATH"

run_step "api:test" npm --prefix "$ROOT" run api:test
run_step "mobile:test" npm --prefix "$ROOT" run mobile:test
run_step "mobile:typecheck" npm --prefix "$ROOT" run mobile:typecheck

if [ "$UI_FOCUS" -eq 1 ] && [ "${ZZIRIT_PRE_PR_RUN_FIGMA:-1}" = "1" ]; then
  run_step "qa:ios:figma" env CI=1 EXPO_NO_INTERACTIVE=1 npm --prefix "$ROOT" run qa:ios:figma
  run_step "qa:ios:figma:strict" env CI=1 EXPO_NO_INTERACTIVE=1 npm --prefix "$ROOT" run qa:ios:figma:strict
fi

if [ "${ZZIRIT_PRE_PR_RUN_HOST_QA:-1}" = "1" ]; then
  run_step "focus-host-qa" bash "$ROOT/scripts/automation/run-focus-host-qa.sh" "$FOCUS_SECTION" "$RUN_DIR"
fi

{
  echo "## Evidence"
  echo
  append_file_if_exists "focus_host_qa_summary" "$RUN_DIR/focus-host-qa-summary.md"
  append_file_if_exists "focus_host_qa_result" "$RUN_DIR/focus-host-qa-result.json"
  append_latest_dir_if_exists "latest_figma_artifact" "$ROOT/artifacts/figma-reference"
  append_latest_dir_if_exists "latest_ios_visual_artifact" "$ROOT/artifacts/ios-visual"
  append_latest_dir_if_exists "latest_qa_artifact" "$ROOT/artifacts/qa"
  echo
  echo "## Result"
  echo
  if [ "$FAILURES" -eq 0 ]; then
    echo "- status: pass"
    echo "- recommendation: review-ready"
  else
    echo "- status: fail"
    echo "- recommendation: fix blockers before opening or updating PR"
    echo "- failures: $FAILURES"
  fi
} >>"$SUMMARY_PATH"

echo "$SUMMARY_PATH"
exit "$FAILURES"
