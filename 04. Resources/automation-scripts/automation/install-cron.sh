#!/bin/zsh
set -euo pipefail

ROOT="${ZZIRIT_AUTOMATION_ROOT:-/Users/user/zzirit-v2}"
CRON_FILE="$ROOT/scripts/automation/zzirit-codex-auto.crontab"
MARKER_START="# >>> zzirit-codex-auto >>>"
MARKER_END="# <<< zzirit-codex-auto <<<"

if [ ! -f "$CRON_FILE" ]; then
  echo "Missing cron file: $CRON_FILE" >&2
  exit 1
fi

tmp_existing="$(mktemp)"
tmp_merged="$(mktemp)"

cleanup() {
  rm -f "$tmp_existing" "$tmp_merged"
}

trap cleanup EXIT INT TERM

crontab -l > "$tmp_existing" 2>/dev/null || true

awk -v start="$MARKER_START" -v end="$MARKER_END" '
  $0 == start { skip = 1; next }
  $0 == end { skip = 0; next }
  !skip { print }
' "$tmp_existing" > "$tmp_merged"

if [ -s "$tmp_merged" ]; then
  printf '\n' >> "$tmp_merged"
fi

cat "$CRON_FILE" >> "$tmp_merged"

crontab "$tmp_merged"
echo "Installed merged cron schedule from $CRON_FILE"
