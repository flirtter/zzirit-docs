#!/usr/bin/env bash
set -euo pipefail

SIM_UDID="${ZZIRIT_IOS_SIMULATOR_UDID:-}"
APP_LOGIN_URL="${ZZIRIT_IOS_OPEN_URL:-zzirit://login/email}"
REVIEW_EMAIL="${ZZIRIT_REVIEW_EMAIL:-review.my@zzirit.app}"
REVIEW_PASSWORD="${ZZIRIT_REVIEW_PASSWORD:-Review123!}"

if [ -n "$SIM_UDID" ]; then
  xcrun simctl openurl "$SIM_UDID" "$APP_LOGIN_URL" >/dev/null 2>&1 || true
fi

sleep 3

read_viewport() {
  osascript \
    -e 'tell application "Simulator" to activate' \
    -e 'tell application "System Events"' \
    -e 'tell process "Simulator"' \
    -e 'tell front window' \
    -e 'repeat with e in (UI elements)' \
    -e 'try' \
    -e 'if role of e is "AXGroup" then' \
    -e 'set {xPos, yPos} to position of e' \
    -e 'set {wPos, hPos} to size of e' \
    -e 'return (xPos as text) & "," & (yPos as text) & "," & (wPos as text) & "," & (hPos as text)' \
    -e 'end if' \
    -e 'end try' \
    -e 'end repeat' \
    -e 'end tell' \
    -e 'end tell' \
    -e 'end tell'
}

click_ratio() {
  local x_ratio="$1"
  local y_ratio="$2"
  local viewport x y width height abs_x abs_y

  viewport="$(read_viewport)"
  IFS=',' read -r x y width height <<<"$viewport"
  abs_x="$(python3 - <<PY
x = float("$x")
width = float("$width")
ratio = float("$x_ratio")
print(round(x + (width * ratio), 2))
PY
)"
  abs_y="$(python3 - <<PY
y = float("$y")
height = float("$height")
ratio = float("$y_ratio")
print(round(y + (height * ratio), 2))
PY
)"

  swift -e "
import CoreGraphics
import Foundation
let point = CGPoint(x: ${abs_x}, y: ${abs_y})
let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
move?.post(tap: .cghidEventTap)
usleep(100000)
down?.post(tap: .cghidEventTap)
usleep(100000)
up?.post(tap: .cghidEventTap)
" >/dev/null 2>&1
  sleep 1
}

type_text() {
  local text="$1"
  printf '%s' "$text" | pbcopy
  osascript \
    -e 'tell application "Simulator" to activate' \
    -e 'delay 0.2' \
    -e 'tell application "System Events"' \
    -e 'keystroke "a" using command down' \
    -e 'delay 0.1' \
    -e 'key code 51' \
    -e 'delay 0.1' \
    -e 'keystroke "v" using command down' \
    -e 'end tell'
  sleep 1
}

click_ratio 0.5 0.225
type_text "$REVIEW_EMAIL"
click_ratio 0.5 0.35
type_text "$REVIEW_PASSWORD"
click_ratio 0.5 0.885

sleep 6

echo "[ios-simulator-login-seeded-account] attempted seeded login for $REVIEW_EMAIL"
