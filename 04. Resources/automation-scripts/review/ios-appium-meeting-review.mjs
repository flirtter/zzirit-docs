#!/usr/bin/env node
import { Buffer } from 'node:buffer';
import { execFile } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

const projectRoot = process.env.ZZIRIT_IOS_PROJECT_ROOT || '/Users/user/zzirit-v2';
const simulatorName = process.env.ZZIRIT_IOS_SIMULATOR_NAME || 'iPhone 17 Pro';
const deviceUdid = process.env.ZZIRIT_IOS_SIMULATOR_UDID || '';
const bundleId = process.env.ZZIRIT_IOS_BUNDLE_ID || 'com.flirtter.zziritApp';
const appiumBaseUrl = process.env.APPIUM_BASE_URL || 'http://127.0.0.1:4726/wd/hub';
const seedApiBaseUrl =
  process.env.ZZIRIT_REVIEW_SEED_API_BASE_URL ||
  'https://zzirit-api-147227137514.asia-northeast3.run.app';
const seedKey = process.env.ZZIRIT_REVIEW_SEED_KEY || 'review-seed-20260313-my';
const openReviewScript =
  process.env.ZZIRIT_MEETING_REVIEW_OPEN_SCRIPT ||
  path.join(projectRoot, 'scripts/review/open-ios-seeded-review.sh');

const now = new Date();
const timestamp = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(
  now.getDate(),
).padStart(2, '0')}-${String(now.getHours()).padStart(2, '0')}${String(now.getMinutes()).padStart(
  2,
  '0',
)}${String(now.getSeconds()).padStart(2, '0')}`;
const reportDir = path.join(projectRoot, 'artifacts/appium-meeting', timestamp);

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function request(method, endpoint, body) {
  const response = await fetch(`${appiumBaseUrl}${endpoint}`, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${method} ${endpoint} failed: ${JSON.stringify(payload)}`);
  }
  return payload;
}

async function seedReviewData() {
  const response = await fetch(`${seedApiBaseUrl}/v1/review-seed/my`, {
    method: 'POST',
    headers: { 'X-Review-Seed-Key': seedKey },
  });
  if (!response.ok) {
    throw new Error(`review seed failed: ${response.status} ${await response.text()}`);
  }
}

async function getSimulatorViewport() {
  const lines = [
    'tell application "Simulator" to activate',
    'tell application "System Events"',
    'tell process "Simulator"',
    'repeat 20 times',
    'try',
    'set frontmost to true',
    'set win to first window whose subrole is "AXStandardWindow"',
    'set {xPos, yPos} to position of win',
    'set {wVal, hVal} to size of win',
    'return (xPos as string) & "," & (yPos as string) & "," & (wVal as string) & "," & (hVal as string)',
    'end try',
    'delay 0.2',
    'end repeat',
    'error "Unable to locate Simulator viewport"',
    'end tell',
    'end tell',
  ];
  const args = lines.flatMap((line) => ['-e', line]);
  const { stdout } = await execFileAsync('osascript', args, { maxBuffer: 1024 * 1024 });
  const [x, y, width, height] = stdout
    .trim()
    .split(',')
    .map((value) => Number.parseFloat(value.trim()));
  if ([x, y, width, height].some((value) => Number.isNaN(value))) {
    throw new Error(`Could not parse Simulator viewport: ${stdout}`);
  }
  return { x, y, width, height };
}

async function clickSimulatorViewportRelative(xRatio, yRatio) {
  const viewport = await getSimulatorViewport();
  const absX = viewport.x + viewport.width * xRatio;
  const absY = viewport.y + viewport.height * yRatio;
  const swiftCode = [
    'import Foundation',
    'import CoreGraphics',
    `let point = CGPoint(x: ${absX}, y: ${absY})`,
    'let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)',
    'let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)',
    'let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)',
    'move?.post(tap: .cghidEventTap)',
    'usleep(80000)',
    'down?.post(tap: .cghidEventTap)',
    'usleep(80000)',
    'up?.post(tap: .cghidEventTap)',
  ].join('\n');
  await execFileAsync('swift', ['-e', swiftCode], { maxBuffer: 1024 * 1024 });
  await sleep(900);
}

async function resolveDeviceUdid() {
  if (deviceUdid) {
    return deviceUdid;
  }
  const { stdout } = await execFileAsync('bash', [
    '-lc',
    `xcrun simctl list devices available | awk -v name="${simulatorName}" '$0 ~ name { match($0, /\\([0-9A-Fa-f-]+\\)/); if (RSTART) { print substr($0, RSTART + 1, RLENGTH - 2); exit } }'`,
  ]);
  const udid = stdout.trim();
  if (!udid) {
    throw new Error(`Unable to resolve simulator device id for: ${simulatorName}`);
  }
  return udid;
}

async function openSeededReview(nextRoute, udid) {
  await seedReviewData();
  await execFileAsync('xcrun', ['simctl', 'terminate', udid, bundleId]).catch(() => undefined);
  await execFileAsync('bash', [openReviewScript, simulatorName, nextRoute], {
    maxBuffer: 1024 * 1024,
  });
  await sleep(6000);
}

async function createSession() {
  const response = await request('POST', '/session', {
    capabilities: {
      alwaysMatch: {
        platformName: 'iOS',
        'appium:automationName': 'XCUITest',
        'appium:deviceName': simulatorName,
        'appium:platformVersion': process.env.ZZIRIT_IOS_PLATFORM_VERSION || '26.2',
        'appium:bundleId': bundleId,
        'appium:newCommandTimeout': 120,
        'appium:noReset': true,
        'appium:forceAppLaunch': false,
        'appium:shouldTerminateApp': false,
        ...(deviceUdid ? { 'appium:udid': deviceUdid } : {}),
      },
      firstMatch: [{}],
    },
  });
  return response.value.sessionId;
}

async function deleteSession(sessionId) {
  try {
    await request('DELETE', `/session/${sessionId}`);
  } catch {}
}

async function waitForElement(sessionId, using, value, timeoutMs = 15000) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    try {
      const response = await request('POST', `/session/${sessionId}/element`, { using, value });
      if (response.value?.ELEMENT || response.value?.['element-6066-11e4-a52e-4f735466cecf']) {
        return response.value;
      }
    } catch (error) {
      if (!(error instanceof Error) || !error.message.includes('no such element')) {
        throw error;
      }
    }
    await sleep(350);
  }
  throw new Error(`Timed out waiting for ${using}=${value}`);
}

async function clickElement(sessionId, element) {
  const elementId = element.ELEMENT || element['element-6066-11e4-a52e-4f735466cecf'];
  await request('POST', `/session/${sessionId}/element/${elementId}/click`, {});
}

async function tapTestId(sessionId, testId, timeoutMs = 15000) {
  const element = await waitForElement(sessionId, 'accessibility id', testId, timeoutMs);
  await clickElement(sessionId, element);
}

async function dismissLocationPrompt(sessionId) {
  const candidates = ['앱을 사용하는 동안 허용', '한 번 허용', '허용 안 함'];
  for (const label of candidates) {
    try {
      const element = await waitForElement(sessionId, 'accessibility id', label, 1500);
      await clickElement(sessionId, element);
      await sleep(1200);
      return true;
    } catch {}
  }

  const sourceResponse = await request('GET', `/session/${sessionId}/source`).catch(() => null);
  const source = String(sourceResponse?.value ?? '');
  const looksLikeLocationAlert =
    source.includes('XCUIElementTypeAlert') ||
    source.includes('현재 위치') ||
    source.includes('Would Like to Use') ||
    source.includes('앱을 사용하는 동안 허용') ||
    source.includes('한 번 허용');

  if (!looksLikeLocationAlert) {
    return false;
  }

  await clickSimulatorViewportRelative(0.5, 0.585).catch(() => undefined);
  await sleep(1200);
  return false;
}

async function captureScreenshot(sessionId, filename) {
  const response = await request('GET', `/session/${sessionId}/screenshot`);
  const filePath = path.join(reportDir, filename);
  await writeFile(filePath, Buffer.from(response.value, 'base64'));
}

async function captureSource(sessionId, filename) {
  const response = await request('GET', `/session/${sessionId}/source`);
  await writeFile(path.join(reportDir, filename), String(response.value ?? ''));
}

async function writeSummary(lines) {
  await writeFile(path.join(reportDir, 'summary.md'), lines.join('\n'));
}

async function main() {
  await mkdir(reportDir, { recursive: true });
  const udid = await resolveDeviceUdid();
  await openSeededReview('/meeting', udid);
  const sessionId = await createSession();
  const summary = [
    '# Appium Meeting Review',
    '',
    `- device: ${simulatorName}`,
    `- bundle_id: ${bundleId}`,
    `- report_dir: ${reportDir}`,
    '',
    '## Artifacts',
  ];

  try {
    try {
      await waitForElement(sessionId, 'accessibility id', 'meeting-create-fab', 10000);
    } catch {
      await openSeededReview('/meeting', udid);
      await waitForElement(sessionId, 'accessibility id', 'meeting-create-fab', 12000);
    }
    await captureScreenshot(sessionId, '01-meeting-list.png');
    summary.push('- 01-meeting-list.png');
    await dismissLocationPrompt(sessionId);

    await tapTestId(sessionId, 'meeting-create-fab');
    await waitForElement(sessionId, 'accessibility id', 'meeting-create-screen', 15000);
    await captureScreenshot(sessionId, '02-create-meeting.png');
    summary.push('- 02-create-meeting.png');

    await tapTestId(sessionId, 'meeting-create-location');
    await waitForElement(sessionId, 'accessibility id', 'meeting-location-picker-apply', 15000);
    await captureScreenshot(sessionId, '03-location-picker.png');
    summary.push('- 03-location-picker.png');

    await execFileAsync('xcrun', ['simctl', 'openurl', udid, 'zzirit:///meeting-detail?id=review-meeting-1']);
    await sleep(3000);
    await waitForElement(sessionId, 'accessibility id', 'meeting-detail-screen', 15000);
    await captureScreenshot(sessionId, '04-meeting-detail.png');
    summary.push('- 04-meeting-detail.png');

    summary.push('', '- status: success');
    await writeSummary(summary);
  } catch (error) {
    await captureScreenshot(sessionId, 'failure.png').catch(() => undefined);
    await captureSource(sessionId, 'failure-source.xml').catch(() => undefined);
    summary.push('', '- status: failure', `- error: ${error instanceof Error ? error.message : String(error)}`);
    await writeSummary(summary);
    throw error;
  } finally {
    await deleteSession(sessionId);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
