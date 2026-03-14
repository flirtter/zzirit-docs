#!/bin/zsh
set -euo pipefail

ROOT="${ZZIRIT_AUTOMATION_ROOT:-/Users/user/zzirit-v2}"
SPEC_FILE="${ZZIRIT_PARALLEL_SPEC_FILE:-$ROOT/scripts/automation/parallel-specs.json}"
KEY="${1:-${ZZIRIT_PARALLEL_WORKER_KEY:-}}"
TRIGGER_TOKEN="${2:-${ZZIRIT_PARALLEL_TRIGGER_TOKEN:-manual}}"
CODEX_BIN="${ZZIRIT_CODEX_BIN:-/opt/homebrew/bin/codex}"
REVIEW_SCRIPT="${ZZIRIT_AUTOMATION_REVIEW_SCRIPT:-$ROOT/scripts/review/multi-model-batch-review.py}"
REVIEW_MODELS="${ZZIRIT_PARALLEL_REVIEW_MODELS:-gemini}"
REVIEW_TIMEOUT_SECONDS="${ZZIRIT_PARALLEL_REVIEW_TIMEOUT_SECONDS:-75}"
REVIEW_STRATEGY="${ZZIRIT_AUTOMATION_REVIEW_STRATEGY:-async-md-only}"
ARTIFACT_ROOT="$ROOT/artifacts/parallel"
FOCUS_SELECTOR_SCRIPT="${ZZIRIT_PARALLEL_FOCUS_SELECTOR_SCRIPT:-$ROOT/scripts/automation/select-parallel-focus.py}"
AUTOMATION_STATUS_FILE="$ROOT/artifacts/automation/status.md"
GEMINI_MODEL="${ZZIRIT_PARALLEL_GEMINI_CODER_MODEL:-gemini-2.5-flash}"

if [ -z "$KEY" ]; then
  echo "Usage: $0 <worker-key> [trigger-token]" >&2
  exit 1
fi

mkdir -p "$ARTIFACT_ROOT"

WORKER_ENV_FILE="/tmp/zzirit-worker-$KEY.env"
python3 - "$SPEC_FILE" "$KEY" "$WORKER_ENV_FILE" <<'PY'
import json
import shlex
import sys
from pathlib import Path

spec_file = Path(sys.argv[1])
key = sys.argv[2]
env_file = Path(sys.argv[3])

data = json.loads(spec_file.read_text(encoding="utf-8"))
workers = data.get("workers", []) if isinstance(data, dict) else data
worker = next((item for item in workers if item.get("key") == key), None)

env_lines = []
if worker is None:
    env_lines.append("echo 'missing worker spec' >&2")
    env_lines.append("exit 2")
else:
    screen_keys = ",".join(worker.get("screen_keys", []))
    for name in (
        "key",
        "branch",
        "worktree",
        "focus",
        "summary",
        "runner",
        "review_root",
    ):
        value = worker.get(name, "")
        env_lines.append(f"{name.upper()}={shlex.quote(str(value))}")
    env_lines.append(f"SCREEN_KEYS={shlex.quote(screen_keys)}")
    env_lines.append(f"ENABLED={shlex.quote('1' if worker.get('enabled', True) else '0')}")

env_file.write_text("\n".join(env_lines) + "\n", encoding="utf-8")
PY
source "$WORKER_ENV_FILE"

if [ "${ENABLED:-0}" != "1" ]; then
  exit 0
fi

WORKER_DIR="$ARTIFACT_ROOT/$KEY"
STATUS_FILE="$WORKER_DIR/status.md"
RUNS_DIR="$WORKER_DIR/runs"
LOCK_DIR="/tmp/zzirit-parallel-$KEY.lock"
CONTROL_FILE="$WORKER_DIR/control.json"
FOCUS_STATE_FILE="$WORKER_DIR/focus-session.json"
mkdir -p "$RUNS_DIR"
RUNNER="${RUNNER:-codex}"
REVIEW_ROOT="${REVIEW_ROOT:-$ROOT}"

timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" >/dev/null 2>&1 || true' EXIT INT TERM

run_id="$(date +%Y%m%d-%H%M%S)"
run_dir="$RUNS_DIR/$run_id"
mkdir -p "$run_dir"
summary_path="$run_dir/last-message.md"
output_path="$run_dir/worker-output.log"
review_log="$run_dir/model-review.log"
auto_commit_log="$run_dir/auto-commit.log"
prompt_file="$run_dir/prompt.txt"

active_focus="$(awk '/focus_section:/ {print $3; exit}' "$AUTOMATION_STATUS_FILE" 2>/dev/null || true)"
focus_json=""
focus_section=""
focus_label=""
focus_goal=""
focus_target="85%"

if [ "$RUNNER" = "codex" ] && [ ! -d "$WORKTREE/.git" ] && [ ! -f "$WORKTREE/.git" ]; then
  mkdir -p "$(dirname "$WORKTREE")"
  git -C "$ROOT" worktree add -B "$BRANCH" "$WORKTREE" HEAD >/dev/null 2>&1
fi

if [ "$RUNNER" = "gemini-coder" ]; then
  if [ ! -d "$WORKTREE/.git" ] && [ ! -f "$WORKTREE/.git" ]; then
    mkdir -p "$(dirname "$WORKTREE")"
    git -C "$ROOT" worktree add -B "$BRANCH" "$WORKTREE" HEAD >/dev/null 2>&1
  fi
  if [ -x "$FOCUS_SELECTOR_SCRIPT" ]; then
    focus_json="$(python3 "$FOCUS_SELECTOR_SCRIPT" "$FOCUS_STATE_FILE" "${active_focus:-}" "${ZZIRIT_PARALLEL_GEMINI_CODER_FOCUS_DURATION_MINUTES:-45}" 2>/dev/null || true)"
    focus_section="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("section",""))' <<<"$focus_json" 2>/dev/null || true)"
    focus_label="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("label",""))' <<<"$focus_json" 2>/dev/null || true)"
    focus_goal="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("goal",""))' <<<"$focus_json" 2>/dev/null || true)"
    focus_target="$(python3 -c 'import json,sys; data=json.loads(sys.stdin.read() or "{}"); print(data.get("target","85%"))' <<<"$focus_json" 2>/dev/null || true)"
  fi
  if [ -n "$focus_label" ]; then
    FOCUS="$focus_label"
  fi
fi

cat > "$STATUS_FILE" <<EOF
# Parallel Worker Status

- key: $KEY
- state: running
- started_at: $(timestamp)
- branch: ${BRANCH:-n/a}
- worktree: $WORKTREE
- run_id: $run_id
- focus: $FOCUS
- runner: $RUNNER
- trigger: $TRIGGER_TOKEN
EOF

cat > "$prompt_file" <<EOF
Continue a focused autonomous batch in $WORKTREE.

Worker key: $KEY
Trigger: $TRIGGER_TOKEN
Focus: $FOCUS
Summary: $SUMMARY
Screen keys: ${SCREEN_KEYS:-none}

Rules:
- Work only within this focus lane.
- Target breadth-first progress: stop at about 85% when the remainder is polish, environment friction, or parity cleanup.
- Prefer visible product progress for this lane over unrelated durability work.
- Read cached baseline docs first.
- If a target screen needs a Figma reference and the API rate limits, use Playwright capture or cached references.
- If UI files change, produce a Figma comparison for the touched target screens.
- Only treat a touched screen as design-verified when \`npm run qa:ios:figma:strict\` or an equivalent strict run reports \`strict parity status: verified\`.
- \`verified\` requires a canonical Figma reference and a fresh route-accurate app screenshot.
- If the lane only has fallback screenshots, proxy references, or manual references, record the exact blocker and keep moving, but do not claim parity is complete.
- Do not use the local MacBook simulator. Assume Mac Studio as the iOS QA host.
- Keep server and app communication correct for this lane.
- Run the smallest sufficient tests and QA for this lane.
- Update docs/autonomous-work-log.md with the worker batch result.
- End with a concise summary.
EOF

if [ "$RUNNER" = "gemini-coder" ]; then
  cat >> "$prompt_file" <<EOF

Parallel Gemini coding lane:
- The main Codex lane is currently focused on: ${active_focus:-unknown}
- Work on a different section in this batch.
- Selected backlog section: ${focus_section:-unknown}
- Selected label: ${focus_label:-unknown}
- Selected goal: ${focus_goal:-unknown}
- Selected target: ${focus_target:-85%}
- Follow the same criteria as the main Codex lane, but keep this batch narrower and leave a clean handoff for Codex to revisit later.
EOF
fi

exit_code=0
review_summary_path=""

if [ "$RUNNER" = "gemini-review" ]; then
  if [ ! -f "$REVIEW_SCRIPT" ]; then
    echo "Missing review script: $REVIEW_SCRIPT" > "$output_path"
    exit_code=127
  else
    if ! ZZIRIT_REVIEW_ROOT="$REVIEW_ROOT" \
      ZZIRIT_REVIEW_RUN_ID="${run_id}-${KEY}" \
      ZZIRIT_REVIEW_BATCH_SUMMARY="$ROOT/artifacts/automation/latest-summary.md" \
      ZZIRIT_REVIEW_MODELS="$REVIEW_MODELS" \
      ZZIRIT_REVIEW_TIMEOUT_SECONDS="$REVIEW_TIMEOUT_SECONDS" \
      python3 "$REVIEW_SCRIPT" >"$review_log" 2>&1; then
      exit_code=$?
    fi
    review_summary_path="$(tail -n 1 "$review_log" 2>/dev/null | tr -d '\r')"
    {
      echo "# Parallel Worker Summary"
      echo
      echo "- key: $KEY"
      echo "- runner: $RUNNER"
      echo "- mode: advisory-md-only"
      echo "- focus: $FOCUS"
      echo "- trigger: $TRIGGER_TOKEN"
      echo "- review_models: $REVIEW_MODELS"
      echo "- review_root: $REVIEW_ROOT"
      echo "- advisory_log: $review_log"
      echo "- advisory_summary: ${review_summary_path:-missing}"
      echo "- exit_code: $exit_code"
    } > "$summary_path"
    cp "$review_log" "$output_path" 2>/dev/null || true
  fi
elif [ "$RUNNER" = "gemini-coder" ]; then
  if ! command -v gemini >/dev/null 2>&1; then
    echo "Missing gemini binary" > "$output_path"
    exit_code=127
  else
    if ! gemini \
      -m "$GEMINI_MODEL" \
      --approval-mode auto_edit \
      --output-format text \
      --prompt "$(cat "$prompt_file")" >"$output_path" 2>&1; then
      exit_code=$?
    fi
    if [ ! -f "$summary_path" ]; then
      {
        echo "# Parallel Worker Summary"
        echo
        echo "- key: $KEY"
        echo "- runner: $RUNNER"
        echo "- trigger: $TRIGGER_TOKEN"
        echo "- focus: ${focus_label:-$FOCUS}"
        echo "- backlog_section: ${focus_section:-unknown}"
        echo "- selected_goal: ${focus_goal:-unknown}"
        echo "- output: $output_path"
        echo "- exit_code: $exit_code"
      } > "$summary_path"
    fi
  fi
elif [ ! -x "$CODEX_BIN" ]; then
  echo "Missing codex binary: $CODEX_BIN" > "$output_path"
  exit_code=127
else
  if ! "$CODEX_BIN" exec \
    -C "$WORKTREE" \
    -c approval_policy='"never"' \
    -c sandbox_mode='"workspace-write"' \
    --skip-git-repo-check \
    --color never \
    -o "$summary_path" \
    "$(cat "$prompt_file")" >"$output_path" 2>&1; then
    exit_code=$?
  fi
fi

if [ "$RUNNER" = "codex" ] && [ "$exit_code" -eq 0 ] && [ "$REVIEW_STRATEGY" = "inline" ] && [ -f "$REVIEW_SCRIPT" ] && [ -n "$(git -C "$WORKTREE" status --short 2>/dev/null)" ]; then
  ZZIRIT_REVIEW_ROOT="$WORKTREE" \
  ZZIRIT_REVIEW_RUN_ID="${run_id}-${KEY}" \
  ZZIRIT_REVIEW_BATCH_SUMMARY="$summary_path" \
  ZZIRIT_REVIEW_MODELS="$REVIEW_MODELS" \
  ZZIRIT_REVIEW_TIMEOUT_SECONDS="$REVIEW_TIMEOUT_SECONDS" \
  python3 "$REVIEW_SCRIPT" >"$review_log" 2>&1 || true
elif [ "$RUNNER" = "codex" ] && [ "$exit_code" -eq 0 ] && [ "$REVIEW_STRATEGY" != "inline" ]; then
  {
    echo
    echo "Advisory review:"
    echo "- mode: $REVIEW_STRATEGY"
    echo "- status: deferred"
    echo "- owner: gemini-review worker"
  } >> "$summary_path"
fi

auto_commit_sha="none"
if [ "$RUNNER" != "gemini-review" ] && [ "$exit_code" -eq 0 ] && [ -n "$(git -C "$WORKTREE" status --short 2>/dev/null)" ]; then
  git -C "$WORKTREE" add -A
  if ! git -C "$WORKTREE" diff --cached --quiet; then
    if git -C "$WORKTREE" commit -m "chore: parallel batch $KEY $run_id" >"$auto_commit_log" 2>&1; then
      auto_commit_sha="$(git -C "$WORKTREE" rev-parse --short HEAD 2>/dev/null || echo none)"
    fi
  fi
fi

state="success"
if [ "$exit_code" -ne 0 ]; then
  state="failure"
fi

cat > "$STATUS_FILE" <<EOF
# Parallel Worker Status

- key: $KEY
- state: $state
- finished_at: $(timestamp)
- branch: ${BRANCH:-n/a}
- worktree: $WORKTREE
- run_id: $run_id
- focus: ${focus_label:-$FOCUS}
- runner: $RUNNER
- trigger: $TRIGGER_TOKEN
- auto_commit_sha: $auto_commit_sha
- summary: $summary_path
- output: $output_path
- review_log: $review_log
EOF

python3 - "$CONTROL_FILE" "$TRIGGER_TOKEN" "$KEY" "$RUNNER" <<'PY'
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path

path = Path(sys.argv[1])
trigger = sys.argv[2]
key = sys.argv[3]
runner = sys.argv[4]
payload = {
    "key": key,
    "runner": runner,
    "last_trigger": trigger,
    "last_finished_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "last_finished_at_ts": int(datetime.now().timestamp()),
}
path.write_text(json.dumps(payload, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
PY

exit 0
