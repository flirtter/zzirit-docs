#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${ZZIRIT_IOS_PROJECT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
REPORT_DIR="${ZZIRIT_IOS_PARITY_REPORT_DIR:-$PROJECT_ROOT/artifacts/ios-parity}"
DEVICE_ID="${ZZIRIT_IOS_DEVICE_ID:-HG}"
SIMULATORS="${ZZIRIT_IOS_PARITY_SIMULATORS:-iPhone 16e,iPhone 17 Pro,iPhone 17 Pro Max}"
RUN_RESPONSIVE="${ZZIRIT_IOS_RUN_RESPONSIVE:-1}"
RUN_DEVICE_SMOKE="${ZZIRIT_IOS_RUN_DEVICE_SMOKE:-1}"
START_EXPO="${ZZIRIT_IOS_START_EXPO:-0}"
APP_BUNDLE_ID="${ZZIRIT_IOS_APP_BUNDLE_ID:-com.flirtter.zziritApp}"

mkdir -p "$REPORT_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DEVICE_DETAILS="$REPORT_DIR/${TIMESTAMP}-device-details.log"
DEVICE_DISPLAYS="$REPORT_DIR/${TIMESTAMP}-device-displays.log"
SIM_METRICS="$REPORT_DIR/${TIMESTAMP}-simulators.tsv"
SUMMARY_PATH="$REPORT_DIR/${TIMESTAMP}-summary.md"
RESPONSIVE_LOG="$REPORT_DIR/${TIMESTAMP}-responsive.log"
DEVICE_LOG="$REPORT_DIR/${TIMESTAMP}-device.log"

xcrun devicectl device info details --device "$DEVICE_ID" >"$DEVICE_DETAILS"
xcrun devicectl device info displays --device "$DEVICE_ID" >"$DEVICE_DISPLAYS"

IFS=',' read -r -a SIM_ARRAY <<< "$SIMULATORS"
: >"$SIM_METRICS"

for raw_name in "${SIM_ARRAY[@]}"; do
  SIM_NAME="$(echo "$raw_name" | sed 's/^ *//; s/ *$//')"
  SIM_UDID="$(xcrun simctl list devices available | awk -v name="$SIM_NAME" '
    $0 ~ name {
      match($0, /\([0-9A-Fa-f-]+\)/)
      if (RSTART) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
      }
    }
  ')"

  if [ -z "$SIM_UDID" ]; then
    echo "${SIM_NAME}\tmissing\tmissing\tmissing\tmissing" >>"$SIM_METRICS"
    continue
  fi

  xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SIM_UDID" -b >/dev/null 2>&1 || true

  WIDTH="$(xcrun simctl getenv "$SIM_UDID" SIMULATOR_MAINSCREEN_WIDTH)"
  HEIGHT="$(xcrun simctl getenv "$SIM_UDID" SIMULATOR_MAINSCREEN_HEIGHT)"
  SCALE="$(xcrun simctl getenv "$SIM_UDID" SIMULATOR_MAINSCREEN_SCALE)"

  printf '%s\t%s\t%s\t%s\t%s\n' "$SIM_NAME" "$SIM_UDID" "$WIDTH" "$HEIGHT" "$SCALE" >>"$SIM_METRICS"
done

if [ "$RUN_RESPONSIVE" = "1" ]; then
  ZZIRIT_IOS_RESPONSIVE_REPORT_DIR="$PROJECT_ROOT/artifacts/ios-responsive" \
  ZZIRIT_IOS_RESPONSIVE_SIMULATORS="$SIMULATORS" \
  ZZIRIT_IOS_START_EXPO="$START_EXPO" \
  bash "$PROJECT_ROOT/scripts/review/ios-responsive-check.sh" >"$RESPONSIVE_LOG" 2>&1
fi

if [ "$RUN_DEVICE_SMOKE" = "1" ]; then
  ZZIRIT_IOS_DEVICE_REPORT_DIR="$PROJECT_ROOT/artifacts/ios-device" \
  ZZIRIT_IOS_DEVICE_ID="$DEVICE_ID" \
  ZZIRIT_IOS_APP_BUNDLE_ID="$APP_BUNDLE_ID" \
  bash "$PROJECT_ROOT/scripts/review/ios-device-smoke.sh" >"$DEVICE_LOG" 2>&1
fi

node - "$DEVICE_ID" "$DEVICE_DETAILS" "$DEVICE_DISPLAYS" "$SIM_METRICS" "$SUMMARY_PATH" "$RESPONSIVE_LOG" "$DEVICE_LOG" "$RUN_RESPONSIVE" "$RUN_DEVICE_SMOKE" <<'NODE'
const fs = require('fs');

const [
  deviceId,
  detailsPath,
  displaysPath,
  simMetricsPath,
  summaryPath,
  responsiveLogPath,
  deviceLogPath,
  runResponsive,
  runDeviceSmoke,
] = process.argv.slice(2);

const detailsText = fs.readFileSync(detailsPath, 'utf8');
const displaysText = fs.readFileSync(displaysPath, 'utf8');
const simMetricsText = fs.readFileSync(simMetricsPath, 'utf8');

function extract(pattern, text) {
  const match = text.match(pattern);
  return match ? match[1] : null;
}

const deviceName = extract(/• name: (.+)/, detailsText) || deviceId;
const modelName = extract(/• marketingName: (.+)/, detailsText) || 'unknown';
const boundsMatch = displaysText.match(/bounds: \([^)]+,\s*([0-9.]+),\s*([0-9.]+)\)/);
const scaleMatch = displaysText.match(/pointScale: ([0-9.]+)/);
const backlightMatch = displaysText.match(/Main display backlight state: (.+)/);

const deviceWidth = boundsMatch ? Number(boundsMatch[1]) : null;
const deviceHeight = boundsMatch ? Number(boundsMatch[2]) : null;
const deviceScale = scaleMatch ? Number(scaleMatch[1]) : null;
const deviceRatio = deviceWidth && deviceHeight ? deviceHeight / deviceWidth : null;

const simulators = simMetricsText
  .trim()
  .split('\n')
  .filter(Boolean)
  .map((line) => {
    const [name, udid, width, height, scale] = line.split('\t');
    const parsedWidth = width === 'missing' ? null : Number(width);
    const parsedHeight = height === 'missing' ? null : Number(height);
    const parsedScale = scale === 'missing' ? null : Number(scale);
    const ratio = parsedWidth && parsedHeight ? parsedHeight / parsedWidth : null;
    const delta = ratio && deviceRatio ? Math.abs(ratio - deviceRatio) / deviceRatio : null;
    const pixelMatch =
      parsedWidth === deviceWidth && parsedHeight === deviceHeight && parsedScale === deviceScale;

    return {
      name,
      udid,
      width: parsedWidth,
      height: parsedHeight,
      scale: parsedScale,
      ratio,
      delta,
      pixelMatch,
    };
  });

simulators.sort((a, b) => {
  if (a.delta === null) return 1;
  if (b.delta === null) return -1;
  return a.delta - b.delta;
});

const closest = simulators.find((sim) => sim.delta !== null) || null;
const rows = simulators.map((sim) => {
  const ratio = sim.ratio ? sim.ratio.toFixed(4) : 'n/a';
  const delta = sim.delta !== null ? `${(sim.delta * 100).toFixed(3)}%` : 'n/a';
  const note = sim.pixelMatch
    ? 'exact-match'
    : closest && sim.name === closest.name
      ? 'closest'
      : '';

  return `| ${sim.name} | ${sim.width ?? 'n/a'}x${sim.height ?? 'n/a'} | ${sim.scale ?? 'n/a'} | ${ratio} | ${delta} | ${note} |`;
});

const lines = [
  '# iOS Device Parity',
  '',
  `- Reference device: ${deviceName} / ${modelName}`,
  `- Device selector: ${deviceId}`,
  `- Device size: ${deviceWidth ?? 'n/a'}x${deviceHeight ?? 'n/a'} @${deviceScale ?? 'n/a'}x`,
  `- Device ratio: ${deviceRatio ? deviceRatio.toFixed(4) : 'n/a'}`,
  `- Backlight: ${backlightMatch ? backlightMatch[1] : 'unknown'}`,
  `- Device details: ${detailsPath}`,
  `- Device displays: ${displaysPath}`,
  '',
  '| Target | Size | Scale | Ratio | Delta vs Device | Note |',
  '| --- | --- | --- | --- | --- | --- |',
  ...rows,
  '',
];

if (closest) {
  lines.push(`- Closest simulator: ${closest.name}`);
}

const exactMatch = simulators.find((sim) => sim.pixelMatch);
if (exactMatch) {
  lines.push(`- Exact simulator parity: ${exactMatch.name}`);
}

if (runResponsive === '1') {
  lines.push(`- Responsive run log: ${responsiveLogPath}`);
}

if (runDeviceSmoke === '1') {
  lines.push(`- Device smoke log: ${deviceLogPath}`);
}

lines.push('');
fs.writeFileSync(summaryPath, `${lines.join('\n')}\n`);
NODE

echo "[ios-parity] Summary: $SUMMARY_PATH"
