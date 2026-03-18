#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
AUTH_PROFILE_DIR="${ZZIRIT_FIGMA_AUTH_PROFILE_DIR:-$PROJECT_ROOT/artifacts/figma-auth/chrome-profile}"
WORK_PROFILE_DIR="${ZZIRIT_FIGMA_WORK_PROFILE_DIR:-$PROJECT_ROOT/artifacts/figma-auth/chrome-profile-copy}"

if [ ! -d "$AUTH_PROFILE_DIR" ]; then
  echo "[figma-profile] auth profile missing: $AUTH_PROFILE_DIR" >&2
  exit 1
fi

mkdir -p "$(dirname "$WORK_PROFILE_DIR")"
rm -rf "$WORK_PROFILE_DIR"
rsync -a "$AUTH_PROFILE_DIR/" "$WORK_PROFILE_DIR/"
find "$WORK_PROFILE_DIR" -maxdepth 1 \( -name 'Singleton*' -o -name 'DevToolsActivePort' \) -exec rm -f {} +

echo "$WORK_PROFILE_DIR"
