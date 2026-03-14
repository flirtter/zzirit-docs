#!/bin/zsh
set -euo pipefail

ROOT="${ZZIRIT_AUTOMATION_ROOT:-/Users/user/zzirit-v2}"
AUTOMATION_ENV_FILE="${ZZIRIT_AUTOMATION_ENV_FILE:-$HOME/.zzirit-automation.env}"
LEGACY_ENV_FILE="$ROOT/.automation.env"
ARTIFACT_DIR="$ROOT/artifacts/automation"
RUNS_DIR="$ARTIFACT_DIR/runs"
PROMPT_FILE="$ROOT/scripts/automation/next-batch-prompt.txt"
FOCUS_SCRIPT="$ROOT/scripts/automation/select-focus-session.py"
FOCUS_STATE_FILE="$ARTIFACT_DIR/focus-session.json"
TASK_QUEUE_FILE="$ARTIFACT_DIR/task-queue.json"
AGENT_STATE_FILE="$ARTIFACT_DIR/agent-state.json"
NEXT_ACTION_FILE="$ARTIFACT_DIR/next-action.md"
AGENT_STATE_SCRIPT="$ROOT/scripts/automation/update-agent-state.py"
DESIGN_RESULT_SCRIPT="$ROOT/scripts/automation/write-design-result.py"
MEMORY_HUB_NOTE_SCRIPT="$ROOT/scripts/automation/write-memory-hub-note.py"
HOST_QA_SCRIPT="${ZZIRIT_AUTOMATION_HOST_QA_SCRIPT:-$ROOT/scripts/automation/run-focus-host-qa.sh}"
BUNDLE_CONTEXT_SCRIPT="${ZZIRIT_AUTOMATION_FIGMA_BUNDLE_SCRIPT:-$ROOT/scripts/automation/prepare-figma-bundle-context.sh}"
STATUS_FILE="$ARTIFACT_DIR/status.md"
LATEST_SUMMARY="$ARTIFACT_DIR/latest-summary.md"
LATEST_OUTPUT="$ARTIFACT_DIR/latest-output.log"
EVENT_LOG="$ARTIFACT_DIR/events.log"
ERROR_LOG="$ARTIFACT_DIR/errors.log"
LATEST_ERROR="$ARTIFACT_DIR/latest-error.md"
LOCK_DIR="/tmp/zzirit-codex-next-batch.lock"
CODEX_BIN="${ZZIRIT_CODEX_BIN:-/opt/homebrew/bin/codex}"
AUTO_COMMIT_ENABLED="${ZZIRIT_AUTOMATION_AUTO_COMMIT:-1}"
REVIEW_ENABLED="${ZZIRIT_AUTOMATION_REVIEW_ENABLED:-1}"
REVIEW_REQUIRED="${ZZIRIT_AUTOMATION_REVIEW_REQUIRED:-0}"
REVIEW_STRATEGY="${ZZIRIT_AUTOMATION_REVIEW_STRATEGY:-async-md-only}"
REVIEW_SCRIPT="${ZZIRIT_AUTOMATION_REVIEW_SCRIPT:-$ROOT/scripts/review/multi-model-batch-review.py}"
REVIEW_MODELS="${ZZIRIT_AUTOMATION_REVIEW_MODELS:-gemini}"
REVIEW_TIMEOUT_SECONDS="${ZZIRIT_AUTOMATION_REVIEW_TIMEOUT_SECONDS:-90}"
FOCUS_DURATION_MINUTES="${ZZIRIT_AUTOMATION_FOCUS_DURATION_MINUTES:-75}"
FIGMA_BUNDLE_UI_SECTIONS="${ZZIRIT_FIGMA_BUNDLE_UI_SECTIONS:-lightning meeting chat my}"

mkdir -p "$RUNS_DIR"
touch "$EVENT_LOG" "$ERROR_LOG"

timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

log_event() {
  echo "[$(timestamp)] $1" >> "$EVENT_LOG"
}

focus_payload() {
  if [ ! -f "$FOCUS_SCRIPT" ]; then
    return 0
  fi
  python3 "$FOCUS_SCRIPT" "$FOCUS_STATE_FILE" "$FOCUS_DURATION_MINUTES"
}

record_error() {
  local kind="$1"
  local message="$2"

  {
    echo "[$(timestamp)] kind=$kind run_id=$run_id"
    echo "$message"
    echo
  } >> "$ERROR_LOG"

  cat > "$LATEST_ERROR" <<EOF
# Latest Automation Error

- time: $(timestamp)
- kind: $kind
- run_id: $run_id
- run_dir: $run_dir

$message
EOF
}

run_id="$(date +%Y%m%d-%H%M%S)"
run_dir="$RUNS_DIR/$run_id"
run_output="$run_dir/codex-output.log"
run_summary="$run_dir/last-message.md"
run_result="$run_dir/result.json"
mkdir -p "$run_dir"
ln -sfn "$run_dir" "$ARTIFACT_DIR/latest-run"

if [ -s "$LEGACY_ENV_FILE" ]; then
  cat > "$STATUS_FILE" <<EOF
# Automation Status

- state: failure
- run_id: $run_id
- finished_at: $(timestamp)
- exit_code: 88
- run_dir: $run_dir
- latest_output: $LATEST_OUTPUT
- latest_summary: $LATEST_SUMMARY
EOF

  log_event "blocked run_id=$run_id reason=legacy-env-file"
  record_error \
    "legacy-env-file" \
    "Move secrets out of the repo before running automation.
legacy_env_file: $LEGACY_ENV_FILE"
  cat > "$run_output" <<EOF
Automation blocked because a legacy repo-scoped secret file exists:
$LEGACY_ENV_FILE
EOF
  cat > "$run_summary" <<EOF
# Automation Summary

- state: failure
- run_id: $run_id
- exit_code: 88
- reason: legacy repo-scoped secret file exists
EOF
  cp "$run_summary" "$LATEST_SUMMARY"
  cp "$run_output" "$LATEST_OUTPUT"
  exit 0
fi

if [ -f "$AUTOMATION_ENV_FILE" ] && [ ! -s "$AUTOMATION_ENV_FILE" ]; then
  cat > "$STATUS_FILE" <<EOF
# Automation Status

- state: failure
- run_id: $run_id
- finished_at: $(timestamp)
- exit_code: 89
- run_dir: $run_dir
- latest_output: $LATEST_OUTPUT
- latest_summary: $LATEST_SUMMARY
EOF

  log_event "blocked run_id=$run_id reason=empty-automation-env"
  record_error \
    "empty-automation-env" \
    "Automation env file exists but is empty.
automation_env_file: $AUTOMATION_ENV_FILE"
  cat > "$run_output" <<EOF
Automation blocked because the external automation env file is empty:
$AUTOMATION_ENV_FILE
EOF
  cat > "$run_summary" <<EOF
# Automation Summary

- state: failure
- run_id: $run_id
- exit_code: 89
- reason: external automation env file is empty
EOF
  cp "$run_summary" "$LATEST_SUMMARY"
  cp "$run_output" "$LATEST_OUTPUT"
  exit 0
fi

if [ -f "$AUTOMATION_ENV_FILE" ]; then
  set -a
  . "$AUTOMATION_ENV_FILE"
  set +a
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log_event "skipped run_id=$run_id reason=lock-held"
  exit 0
fi

cleanup() {
  rmdir "$LOCK_DIR" >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

capture_git_snapshot() {
  local prefix="$1"
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT" status --short > "$run_dir/${prefix}-git-status.txt" || true
    git -C "$ROOT" log -5 --oneline > "$run_dir/${prefix}-git-log.txt" || true
    if [ "$prefix" = "pre-run" ] && [ -s "$run_dir/${prefix}-git-status.txt" ]; then
      log_event "dirty-start run_id=$run_id status_file=$run_dir/${prefix}-git-status.txt"
    fi
  else
    echo "git metadata unavailable" > "$run_dir/${prefix}-git-status.txt"
    echo "git metadata unavailable" > "$run_dir/${prefix}-git-log.txt"
  fi
}

has_worktree_changes() {
  if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi
  if [ -n "$(git -C "$ROOT" status --short 2>/dev/null)" ]; then
    return 0
  fi
  return 1
}

auto_commit_if_needed() {
  if [ "$AUTO_COMMIT_ENABLED" != "1" ]; then
    return 0
  fi

  if ! has_worktree_changes; then
    return 0
  fi

  local commit_message="chore: apply automation batch $run_id"
  local commit_body_file="$run_dir/auto-commit-message.txt"
  local commit_log="$run_dir/auto-commit.log"

  {
    echo "$commit_message"
    echo
    echo "Automation run: $run_id"
    echo "Summary:"
    sed -n '1,80p' "$run_summary" 2>/dev/null || true
  } > "$commit_body_file"

  git -C "$ROOT" add -A
  if git -C "$ROOT" diff --cached --quiet; then
    return 0
  fi

  if git -C "$ROOT" commit -F "$commit_body_file" >"$commit_log" 2>&1; then
    auto_commit_sha="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || true)"
    log_event "committed run_id=$run_id commit=$auto_commit_sha log=$commit_log"
    {
      echo
      echo "Auto-commit:"
      echo "- sha: ${auto_commit_sha:-unknown}"
      echo "- log: $commit_log"
    } >> "$run_summary"
    return 0
  fi

  auto_commit_failure_log="$commit_log"
  return 1
}

run_model_review_if_needed() {
  if [ "$REVIEW_ENABLED" != "1" ]; then
    return 0
  fi

  if [ "$REVIEW_STRATEGY" != "inline" ]; then
    {
      echo
      echo "Advisory review:"
      echo "- mode: $REVIEW_STRATEGY"
      echo "- status: deferred"
      echo "- owner: parallel gemini-review worker"
      echo "- note: main automation completed implementation and host QA without waiting for Gemini; use the markdown artifact later as advisory QA notes"
    } >> "$run_summary"
    return 0
  fi

  if [ ! -f "$REVIEW_SCRIPT" ]; then
    {
      echo
      echo "Model review:"
      echo "- status: skipped"
      echo "- reason: review script missing"
      echo "- path: $REVIEW_SCRIPT"
    } >> "$run_summary"
    return 0
  fi

  if ! has_worktree_changes; then
    {
      echo
      echo "Model review:"
      echo "- status: skipped"
      echo "- reason: no worktree changes to review"
    } >> "$run_summary"
    return 0
  fi

  local review_log="$run_dir/model-review.log"
  local review_summary_path=""

  if ZZIRIT_REVIEW_ROOT="$ROOT" \
    ZZIRIT_REVIEW_RUN_ID="$run_id" \
    ZZIRIT_REVIEW_BATCH_SUMMARY="$run_summary" \
    ZZIRIT_REVIEW_MODELS="$REVIEW_MODELS" \
    ZZIRIT_REVIEW_TIMEOUT_SECONDS="$REVIEW_TIMEOUT_SECONDS" \
    python3 "$REVIEW_SCRIPT" >"$review_log" 2>&1; then
    review_summary_path="$(tail -n 1 "$review_log" | tr -d '\r')"
    log_event "reviewed run_id=$run_id summary=$review_summary_path log=$review_log"
    {
      echo
      echo "Model review:"
      echo "- status: completed"
      echo "- models: $REVIEW_MODELS"
      echo "- timeout_seconds: $REVIEW_TIMEOUT_SECONDS"
      echo "- summary: ${review_summary_path:-unknown}"
      echo "- log: $review_log"
    } >> "$run_summary"
    return 0
  fi

  {
    echo
    echo "Model review:"
    echo "- status: failed"
    echo "- models: $REVIEW_MODELS"
    echo "- timeout_seconds: $REVIEW_TIMEOUT_SECONDS"
    echo "- log: $review_log"
  } >> "$run_summary"

  if [ "$REVIEW_REQUIRED" = "1" ]; then
    return 1
  fi

  return 0
}

normalize_success_summary() {
  if [ -z "${auto_commit_sha:-}" ] || [ ! -f "$run_summary" ]; then
    return 0
  fi

  python3 - "$run_summary" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
lines = summary_path.read_text(encoding="utf-8").splitlines()
patterns = (
    "Commit is still blocked by git write permissions",
    "Commit is still blocked by environment permissions",
    "Commit is still blocked by environment permission",
    "index.lock",
    "changes remain uncommitted in the working tree.",
)

cleaned: list[str] = []
removed_stale_blocker = False

for index, line in enumerate(lines):
    stripped = line.strip()
    if any(pattern in line for pattern in patterns):
        removed_stale_blocker = True
        continue
    if stripped == "Blocker:":
        nearby = "\n".join(lines[index + 1 : index + 5])
        if any(pattern in nearby for pattern in patterns):
          removed_stale_blocker = True
          continue
    cleaned.append(line)

if removed_stale_blocker:
    while cleaned and cleaned[-1] == "":
        cleaned.pop()
    cleaned.extend(
        [
            "",
            "Post-run correction:",
            "- stale commit-blocker text was removed after auto-commit succeeded",
        ]
    )

summary_path.write_text("\n".join(cleaned) + "\n", encoding="utf-8")
PY
}

sync_latest_artifacts() {
  cp "$run_summary" "$LATEST_SUMMARY"
  cp "$run_output" "$LATEST_OUTPUT"
}

host_qa_status="skipped"
host_qa_result_path=""
host_qa_summary_path=""
design_result_status="skipped"
design_result_path=""
memory_hub_note_path=""
memory_hub_note_json_path=""

write_run_result_json() {
  python3 - "$run_result" "$run_id" "$state" "$exit_code" "$run_dir" "$run_output" "$run_summary" "${focus_section:-}" "${focus_label:-}" "${task_id:-}" "${task_title:-}" "${host_qa_status:-skipped}" "${host_qa_result_path:-}" "${host_qa_summary_path:-}" "${figma_bundle_summary_path:-}" "${design_result_status:-skipped}" "${design_result_path:-}" "${auto_commit_sha:-}" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

(
    result_path,
    run_id,
    state,
    exit_code,
    run_dir,
    run_output,
    run_summary,
    focus_section,
    focus_label,
    task_id,
    task_title,
    host_qa_status,
    host_qa_result_path,
    host_qa_summary_path,
    figma_bundle_summary_path,
    design_result_status,
    design_result_path,
    auto_commit_sha,
) = sys.argv[1:]

payload = {
    "run_id": run_id,
    "state": state,
    "exit_code": int(exit_code),
    "run_dir": run_dir,
    "run_output": run_output,
    "run_summary": run_summary,
    "focus_section": focus_section or None,
    "focus_label": focus_label or None,
    "task_id": task_id or None,
    "task_title": task_title or None,
    "host_qa_status": host_qa_status or "skipped",
    "host_qa_result_path": host_qa_result_path or None,
    "host_qa_summary_path": host_qa_summary_path or None,
    "figma_bundle_summary_path": figma_bundle_summary_path or None,
    "design_result_status": design_result_status or "skipped",
    "design_result_path": design_result_path or None,
    "auto_commit_sha": auto_commit_sha or None,
}

Path(result_path).write_text(json.dumps(payload, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
PY
}

update_agent_state_if_needed() {
  if [ ! -f "$AGENT_STATE_SCRIPT" ]; then
    return 0
  fi

  python3 "$AGENT_STATE_SCRIPT" "$TASK_QUEUE_FILE" "$AGENT_STATE_FILE" "$NEXT_ACTION_FILE" "$run_result" >/dev/null 2>&1 || true
}

run_focus_host_qa_if_needed() {
  if [ -z "${focus_section:-}" ] || [ "$focus_section" = "none" ]; then
    return 0
  fi

  if [ ! -x "$HOST_QA_SCRIPT" ]; then
    {
      echo
      echo "Host QA:"
      echo "- status: skipped"
      echo "- reason: host QA script missing or not executable"
      echo "- path: $HOST_QA_SCRIPT"
    } >> "$run_summary"
    return 0
  fi

  local host_qa_log="$run_dir/focus-host-qa.log"
  local host_qa_summary=""

  host_qa_status="skipped"
  host_qa_result_path="$run_dir/focus-host-qa-result.json"
  host_qa_summary_path="$run_dir/focus-host-qa-summary.md"

  if host_qa_summary="$("$HOST_QA_SCRIPT" "$focus_section" "$run_dir" 2>>"$host_qa_log")"; then
    if [ -f "$host_qa_result_path" ]; then
      host_qa_status="$(python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); data=json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}; print(data.get("overall_status","pass"))' "$host_qa_result_path" 2>/dev/null || echo pass)"
    else
      host_qa_status="pass"
    fi
    {
      echo
      echo "Host QA:"
      echo "- status: completed"
      echo "- summary: ${host_qa_summary:-unknown}"
      echo "- result: ${host_qa_result_path:-unknown}"
      echo "- log: $host_qa_log"
    } >> "$run_summary"
    return 0
  fi

  host_qa_status="blocked"

  {
    echo
    echo "Host QA:"
    echo "- status: blocked"
    echo "- summary: ${host_qa_summary:-missing}"
    echo "- result: ${host_qa_result_path:-missing}"
    echo "- log: $host_qa_log"
  } >> "$run_summary"
  return 0
}

write_design_result_if_needed() {
  design_result_status="skipped"
  design_result_path="$run_dir/design-result.json"

  if [ ! -f "$DESIGN_RESULT_SCRIPT" ]; then
    return 0
  fi

  if python3 "$DESIGN_RESULT_SCRIPT" \
    "${focus_section:-}" \
    "$run_dir" \
    "${host_qa_result_path:-}" \
    "${host_qa_summary_path:-}" \
    "${figma_bundle_summary_path:-}" \
    "$ROOT/artifacts/manual-design-references/latest" \
    "$design_result_path" >/dev/null 2>&1; then
    if [ -f "$design_result_path" ]; then
      design_result_status="$(python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); data=json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}; print(data.get("overall_status","skipped"))' "$design_result_path" 2>/dev/null || echo skipped)"
    fi
  fi
}

prepare_figma_bundle_context_if_needed() {
  figma_bundle_summary_path=""

  if [ -z "${focus_section:-}" ]; then
    return 0
  fi

  local should_run="0"
  for candidate in ${(s: :)FIGMA_BUNDLE_UI_SECTIONS}; do
    if [ "$candidate" = "$focus_section" ]; then
      should_run="1"
      break
    fi
  done

  if [ "$should_run" != "1" ]; then
    return 0
  fi

  if [ ! -x "$BUNDLE_CONTEXT_SCRIPT" ]; then
    return 0
  fi

  local bundle_summary=""
  local bundle_log="$run_dir/figma-bundle-context.log"

  if bundle_summary="$("$BUNDLE_CONTEXT_SCRIPT" "$focus_section" "$run_dir" 2>>"$bundle_log")"; then
    figma_bundle_summary_path="${bundle_summary:-}"
    if [ -n "$figma_bundle_summary_path" ]; then
      log_event "figma-bundle-context run_id=$run_id section=$focus_section summary=$figma_bundle_summary_path"
    fi
    return 0
  fi

  log_event "figma-bundle-context-failed run_id=$run_id section=$focus_section log=$bundle_log"
  return 0
}

refresh_figma_bundle_context_signals() {
  figma_bundle_cached_count="0"
  figma_bundle_high_drift_count="0"

  if [ -z "${figma_bundle_summary_path:-}" ] || [ ! -f "$figma_bundle_summary_path" ]; then
    return 0
  fi

  figma_bundle_cached_count="$(grep -c 'skipped_existing' "$figma_bundle_summary_path" 2>/dev/null || echo 0)"
  figma_bundle_high_drift_count="$(grep -c 'drift_signal: high' "$figma_bundle_summary_path" 2>/dev/null || echo 0)"
}

append_figma_bundle_context_note() {
  if [ -z "${figma_bundle_summary_path:-}" ] || [ ! -f "$run_summary" ]; then
    return 0
  fi

  {
    echo
    echo "Figma bundle context:"
    echo "- status: prepared"
    echo "- focus_section: ${focus_section:-none}"
    echo "- summary: $figma_bundle_summary_path"
    echo "- cached_reuse_count: ${figma_bundle_cached_count:-0}"
    echo "- high_drift_count: ${figma_bundle_high_drift_count:-0}"
    echo "- note: cached node captures are reused when the same node/design signature already exists"
  } >> "$run_summary"
}

append_design_result_note() {
  if [ -z "${design_result_path:-}" ] || [ ! -f "$design_result_path" ]; then
    return 0
  fi

  {
    echo
    echo "Design result:"
    echo "- status: ${design_result_status:-skipped}"
    echo "- result: $design_result_path"
  } >> "$run_summary"
}

write_memory_hub_note_if_needed() {
  memory_hub_note_path="$run_dir/memory-hub-note.md"
  memory_hub_note_json_path="$run_dir/memory-hub-note.json"

  if [ ! -f "$MEMORY_HUB_NOTE_SCRIPT" ]; then
    return 0
  fi

  if python3 "$MEMORY_HUB_NOTE_SCRIPT" \
    "$run_result" \
    "$run_summary" \
    "$run_dir" \
    "$memory_hub_note_path" \
    "$memory_hub_note_json_path" >/dev/null 2>&1; then
    return 0
  fi

  memory_hub_note_path=""
  memory_hub_note_json_path=""
  return 0
}

append_memory_hub_note() {
  if [ -z "${memory_hub_note_path:-}" ] || [ ! -f "$memory_hub_note_path" ]; then
    return 0
  fi

  {
    echo
    echo "Memory hub note:"
    echo "- markdown: $memory_hub_note_path"
    echo "- json: ${memory_hub_note_json_path:-missing}"
  } >> "$run_summary"
}

cat > "$STATUS_FILE" <<EOF
# Automation Status

- state: running
- run_id: $run_id
- started_at: $(timestamp)
- run_dir: $run_dir
- focus_session_file: $FOCUS_STATE_FILE
EOF

log_event "started run_id=$run_id run_dir=$run_dir"
capture_git_snapshot "pre-run"

focus_json="$(focus_payload 2>/dev/null || true)"
focus_section="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("section",""))' <<<"$focus_json" 2>/dev/null || true)"
focus_label="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("label",""))' <<<"$focus_json" 2>/dev/null || true)"
focus_goal="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("goal",""))' <<<"$focus_json" 2>/dev/null || true)"
focus_expires_at="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("expires_at",""))' <<<"$focus_json" 2>/dev/null || true)"
focus_target="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("target",""))' <<<"$focus_json" 2>/dev/null || true)"
task_id="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("task_id",""))' <<<"$focus_json" 2>/dev/null || true)"
task_title="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("task_title",""))' <<<"$focus_json" 2>/dev/null || true)"
surface_spec_path="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("surface_spec_path",""))' <<<"$focus_json" 2>/dev/null || true)"
surface_spec_status="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("surface_spec_status",""))' <<<"$focus_json" 2>/dev/null || true)"
surface_qa_level="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("surface_qa_level",""))' <<<"$focus_json" 2>/dev/null || true)"
surface_automation_status="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("surface_automation_status",""))' <<<"$focus_json" 2>/dev/null || true)"
surface_next_step="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("surface_next_step",""))' <<<"$focus_json" 2>/dev/null || true)"

if [ -n "$focus_section" ]; then
  cat > "$STATUS_FILE" <<EOF
# Automation Status

- state: running
- run_id: $run_id
- started_at: $(timestamp)
- run_dir: $run_dir
- focus_session_file: $FOCUS_STATE_FILE
- focus_section: $focus_section
- focus_label: $focus_label
- task_id: ${task_id:-none}
- task_title: ${task_title:-none}
- focus_target: ${focus_target:-85%}
- focus_goal: $focus_goal
- focus_started_at: $(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("started_at",""))' <<<"$focus_json" 2>/dev/null || true)
- focus_expires_at: $focus_expires_at
- surface_spec_path: ${surface_spec_path:-none}
- surface_spec_status: ${surface_spec_status:-none}
- surface_qa_level: ${surface_qa_level:-none}
- surface_automation_status: ${surface_automation_status:-none}
EOF
  log_event "focus run_id=$run_id section=$focus_section expires_at=$focus_expires_at"
fi

figma_bundle_summary_path=""
figma_bundle_cached_count="0"
figma_bundle_high_drift_count="0"
prepare_figma_bundle_context_if_needed
refresh_figma_bundle_context_signals

host_name="$(hostname)"
host_user="$(whoami)"
prompt_context="Execution context:
- host: $host_name
- user: $host_user
- If the current host is the Mac Studio, do not run ssh studio. Use the current machine directly for Mac Studio validation and iOS QA.
- FIGMA_FILE_KEY default should target the active design file ZhysC3KZLAmKerfHTpg3G6 unless a batch needs a different file.
- Never read, print, diff, or summarize secret material such as .automation.env, .env, tokens, keys, provisioning profiles, or shell environment values. Use already-loaded environment variables without echoing them.
- Do not use the local MacBook simulator as a target. All iOS simulator work should assume Mac Studio as the active execution environment.
- Do not try to fix or diagnose CoreSimulator access from inside the Codex sandbox. Outer automation will run host-side simulator and Appium commands after the coding pass.
- If the Mac Studio simulator is visibly sitting on an unrelated stale screen, relaunch/reset the app and drive the intended route before making UI decisions.
- This run is one slice of a longer focused session. Favor shipping visible progress in the chosen section over tiny review-tool churn.

"
if [ -n "$focus_section" ]; then
  prompt_context="${prompt_context}Focused session:
- section: $focus_section
- label: $focus_label
- task_id: ${task_id:-none}
- task_title: ${task_title:-none}
- target completion: ${focus_target:-85%}
- session expires at: $focus_expires_at
- session goal: $focus_goal
- surface spec path: ${surface_spec_path:-none}
- surface spec status: ${surface_spec_status:-none}
- surface qa level: ${surface_qa_level:-none}
- surface automation status: ${surface_automation_status:-none}
- surface next step: ${surface_next_step:-none}
- Stay on this section for the whole batch unless a hard external blocker prevents all meaningful progress.
- A meaningful batch should include multiple concrete steps in this section, such as implement -> validate -> capture/compare -> refine -> revalidate.
- Do not end the batch after a single tooling-only tweak if visible product work is still available in this section.
- For UI sections, aim to leave behind fresh screen artifacts for the exact target route, not just improved tooling diagnostics.
- If Gemini/model-review findings point to unrelated tooling outside this section, note them as deferred instead of abandoning the current focused session.

"
fi
if [ -n "${figma_bundle_summary_path:-}" ]; then
  prompt_context="${prompt_context}Figma bundle context:
- summary: $figma_bundle_summary_path
- cached_reuse_count: ${figma_bundle_cached_count:-0}
- high_drift_count: ${figma_bundle_high_drift_count:-0}
- use the bundle summary before UI decisions for this focus section
- if current implementation drifts materially from the listed screen/assets or the legacy app, prioritize structure/parity corrections first
- if high_drift_count is non-zero, treat current UI parity as untrusted until the route structure and key child assets have been compared against Figma and legacy references
- the bundle capture layer reuses cached node references when the design signature and node id are unchanged, so repeated items may be intentionally skipped

"
fi
prompt="${prompt_context}$(cat "$PROMPT_FILE")"
exit_code=0
auto_commit_sha=""
auto_commit_failure_log=""

if [ ! -x "$CODEX_BIN" ]; then
  exit_code=127
  echo "Missing codex binary: $CODEX_BIN" > "$run_output"
else
  if ! "$CODEX_BIN" exec \
    -C "$ROOT" \
    -c approval_policy='"never"' \
    -c sandbox_mode='"workspace-write"' \
    --skip-git-repo-check \
    --color never \
    -o "$run_summary" \
    "$prompt" >"$run_output" 2>&1; then
    exit_code=$?
  fi
fi

if grep -q "Not inside a trusted directory" "$run_output" 2>/dev/null; then
  exit_code=86
fi

if [ ! -f "$run_summary" ] && [ "$exit_code" -eq 0 ]; then
  exit_code=87
fi

if [ ! -f "$run_summary" ]; then
  {
    echo "# Automation Summary"
    echo
    echo "- state: failure"
    echo "- run_id: $run_id"
    echo "- exit_code: $exit_code"
    echo
    echo '```text'
    tail -n 80 "$run_output" || true
    echo '```'
  } > "$run_summary"
fi

if rg -n 'FIGMA_API_KEY=|===== \.automation\.env =====|legacy repo-scoped secret file exists' "$run_output" "$run_summary" >/dev/null 2>&1; then
  exit_code=88
  cat > "$run_output" <<EOF
Automation output was redacted because secret material was detected in the run logs.
run_id: $run_id
EOF
  cat > "$run_summary" <<EOF
# Automation Summary

- state: failure
- run_id: $run_id
- exit_code: 88
- reason: secret material was detected in the run logs and the output was redacted
EOF
fi

capture_git_snapshot "post-run"

state="success"
if [ "$exit_code" -ne 0 ]; then
  state="failure"
fi

if [ "$exit_code" -eq 0 ]; then
  run_focus_host_qa_if_needed
fi

if [ "$exit_code" -eq 0 ] && ! auto_commit_if_needed; then
  exit_code=90
  state="failure"
fi

if [ "$exit_code" -eq 0 ] && ! run_model_review_if_needed; then
  exit_code=91
  state="failure"
fi

if [ "$exit_code" -eq 0 ]; then
  normalize_success_summary
fi

append_figma_bundle_context_note
write_design_result_if_needed
append_design_result_note
write_run_result_json
write_memory_hub_note_if_needed
append_memory_hub_note
update_agent_state_if_needed

sync_latest_artifacts

log_event "$state run_id=$run_id exit_code=$exit_code output=$run_output summary=$run_summary"

if [ "$exit_code" -ne 0 ]; then
  if [ "$exit_code" -eq 90 ]; then
    record_error \
      "auto-commit-failure" \
      "exit_code: $exit_code
output: $run_output
summary: $run_summary
commit_log: $auto_commit_failure_log"
  else
    record_error \
      "batch-failure" \
      "exit_code: $exit_code
output: $run_output
summary: $run_summary"
  fi
fi

cat > "$STATUS_FILE" <<EOF
# Automation Status

- state: $state
- run_id: $run_id
- finished_at: $(timestamp)
- exit_code: $exit_code
- run_dir: $run_dir
- latest_output: $LATEST_OUTPUT
- latest_summary: $LATEST_SUMMARY
- auto_commit_sha: ${auto_commit_sha:-none}
- focus_section: ${focus_section:-none}
- focus_label: ${focus_label:-none}
- task_id: ${task_id:-none}
- task_title: ${task_title:-none}
- focus_target: ${focus_target:-85%}
- focus_goal: ${focus_goal:-none}
- focus_started_at: $(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("started_at","none"))' <<<"$focus_json" 2>/dev/null || true)
- focus_expires_at: ${focus_expires_at:-none}
- surface_spec_path: ${surface_spec_path:-none}
- surface_spec_status: ${surface_spec_status:-none}
- surface_qa_level: ${surface_qa_level:-none}
- surface_automation_status: ${surface_automation_status:-none}
- focus_session_file: $FOCUS_STATE_FILE
- task_queue_file: $TASK_QUEUE_FILE
- agent_state_file: $AGENT_STATE_FILE
- next_action_file: $NEXT_ACTION_FILE
- design_result_status: ${design_result_status:-skipped}
- design_result_path: ${design_result_path:-none}
- run_result: $run_result
EOF

exit 0
