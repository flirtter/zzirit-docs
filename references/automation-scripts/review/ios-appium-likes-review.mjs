import { Buffer } from 'node:buffer';
import { execFile } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = process.env.ZZIRIT_IOS_PROJECT_ROOT || path.resolve(scriptDir, '..', '..');
const reportRoot =
  process.env.ZZIRIT_APPIUM_LIKES_REPORT_DIR || path.join(projectRoot, 'artifacts', 'appium-likes');
const timestamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, '').replace('T', '-');
const reportDir = path.join(reportRoot, timestamp);
const appiumServerUrl = process.env.ZZIRIT_APPIUM_SERVER_URL || 'http://127.0.0.1:4726/wd/hub';
const bundleId = process.env.ZZIRIT_IOS_APP_BUNDLE_ID || 'com.flirtter.zziritApp';
const deviceName = process.env.ZZIRIT_IOS_SIMULATOR_NAME || 'iPhone 17 Pro';
const platformVersion = process.env.ZZIRIT_IOS_PLATFORM_VERSION || '26.2';
const udid = process.env.ZZIRIT_IOS_SIMULATOR_UDID;
const seedApiBaseUrl =
  process.env.ZZIRIT_REVIEW_SEED_API_BASE_URL || 'https://zzirit-api-147227137514.asia-northeast3.run.app';
const reviewSeedKey = process.env.ZZIRIT_REVIEW_SEED_KEY || 'review-seed-20260313-my';
const openReviewScript =
  process.env.ZZIRIT_LIKES_REVIEW_OPEN_SCRIPT ||
  path.join(projectRoot, 'scripts', 'review', 'open-ios-seeded-review.sh');

function logStep(message) {
  process.stdout.write(`[ios-appium-likes] ${message}\n`);
}

function getElementId(element) {
  return element?.ELEMENT || element?.['element-6066-11e4-a52e-4f735466cecf'] || null;
}

async function request(method, pathname, body) {
  const response = await fetch(`${appiumServerUrl}${pathname}`, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${method} ${pathname} failed: ${JSON.stringify(payload)}`);
  }
  return payload;
}

async function sleep(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForElement(sessionId, using, value, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const response = await request('POST', `/session/${sessionId}/element`, { using, value });
      if (response.value) {
        return response.value;
      }
    } catch (error) {
      if (!(error instanceof Error) || !error.message.includes('no such element')) {
        throw error;
      }
    }
    await sleep(400);
  }
  throw new Error(`Timed out waiting for element: ${using}=${value}`);
}

async function clickElement(sessionId, element) {
  const elementId = getElementId(element);
  if (!elementId) {
    throw new Error('Missing element id for click');
  }
  await request('POST', `/session/${sessionId}/element/${elementId}/click`, {});
  await sleep(700);
}

async function getElementRect(sessionId, element) {
  const elementId = getElementId(element);
  if (!elementId) {
    throw new Error('Missing element id for rect');
  }
  const response = await request('GET', `/session/${sessionId}/element/${elementId}/rect`);
  return response.value;
}

async function tapAt(sessionId, x, y) {
  await request('POST', `/session/${sessionId}/actions`, {
    actions: [
      {
        type: 'pointer',
        id: 'finger1',
        parameters: { pointerType: 'touch' },
        actions: [
          { type: 'pointerMove', duration: 0, x: Math.round(x), y: Math.round(y) },
          { type: 'pointerDown', button: 0 },
          { type: 'pause', duration: 80 },
          { type: 'pointerUp', button: 0 },
        ],
      },
    ],
  });
  await request('DELETE', `/session/${sessionId}/actions`).catch(() => undefined);
  await sleep(700);
}

async function getSimulatorViewport() {
  const lines = [
    'tell application "Simulator" to activate',
    'tell application "System Events"',
    'tell process "Simulator"',
    'tell front window',
    'repeat with e in (UI elements)',
    'try',
    'if role of e is "AXGroup" then',
    'set {xPos, yPos} to position of e',
    'set {wPos, hPos} to size of e',
    'return (xPos as text) & "," & (yPos as text) & "," & (wPos as text) & "," & (hPos as text)',
    'end if',
    'end try',
    'end repeat',
    'end tell',
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

async function tapElementCenter(sessionId, element) {
  const rect = await getElementRect(sessionId, element);
  await tapAt(sessionId, rect.x + rect.width / 2, rect.y + rect.height / 2);
}

async function tapTestId(sessionId, testId, timeoutMs = 15000, options = {}) {
  const element = await waitForElement(sessionId, 'accessibility id', testId, timeoutMs);
  if (options.centerTap) {
    await tapElementCenter(sessionId, element);
    return;
  }
  await clickElement(sessionId, element);
}

async function captureScreenshot(sessionId, filename) {
  const response = await request('GET', `/session/${sessionId}/screenshot`);
  const filePath = path.join(reportDir, filename);
  await writeFile(filePath, Buffer.from(response.value, 'base64'));
  return filePath;
}

async function captureSource(sessionId, filename) {
  const response = await request('GET', `/session/${sessionId}/source`);
  const filePath = path.join(reportDir, filename);
  await writeFile(filePath, response.value);
  return filePath;
}

async function openSeededReview(nextRoute) {
  await fetch(`${seedApiBaseUrl}/v1/review-seed/my`, {
    method: 'POST',
    headers: { 'X-Review-Seed-Key': reviewSeedKey },
  });

  await execFileAsync('bash', [openReviewScript, deviceName, nextRoute], {
    maxBuffer: 1024 * 1024,
  });
  await sleep(10000);
}

async function openLikesReview(nextRoute = '/likes?tab=received') {
  await openSeededReview(nextRoute);
}

async function createSession() {
  const caps = {
    platformName: 'iOS',
    'appium:automationName': 'XCUITest',
    'appium:deviceName': deviceName,
    'appium:platformVersion': platformVersion,
    'appium:bundleId': bundleId,
    'appium:newCommandTimeout': 120,
    'appium:noReset': true,
    'appium:forceAppLaunch': false,
    'appium:shouldTerminateApp': false,
    ...(udid ? { 'appium:udid': udid } : {}),
  };

  const response = await request('POST', '/session', {
    capabilities: { alwaysMatch: caps, firstMatch: [{}] },
  });
  return response.value?.sessionId || response.sessionId;
}

async function deleteSession(sessionId) {
  if (!sessionId) {
    return;
  }
  await request('DELETE', `/session/${sessionId}`).catch(() => undefined);
}

async function writeSummary(lines) {
  await writeFile(path.join(reportDir, 'summary.md'), `${lines.join('\n')}\n`);
}

async function waitForReceivedReady(sessionId, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const receivedTab = await waitForElement(
      sessionId,
      'accessibility id',
      'likes-tab-received',
      4000,
    ).catch(() => null);
    if (receivedTab) {
      return;
    }
    await sleep(500);
  }
  throw new Error('Timed out waiting for received likes screen');
}

async function ensureUnlockDialog(sessionId) {
  const tryTapUnlock = async () => {
    const cta = await waitForElement(sessionId, 'accessibility id', 'likes-unlock-cta', 6000).catch(
      () => null,
    );
    if (cta) {
      await tapElementCenter(sessionId, cta);
      return true;
    }
    return false;
  };

  if (await tryTapUnlock()) {
    return;
  }

  await openLikesReview('/likes?tab=received');
  await waitForReceivedReady(sessionId, 15000);
  if (await tryTapUnlock()) {
    return;
  }

  await clickSimulatorViewportRelative(0.5, 0.9);
  await sleep(1000);
  const confirm = await waitForElement(
    sessionId,
    'accessibility id',
    'likes-dialog-confirm',
    5000,
  ).catch(() => null);
  if (confirm) {
    return;
  }

  throw new Error('Timed out opening received likes unlock dialog');
}

async function main() {
  await mkdir(reportDir, { recursive: true });

  await openLikesReview('/likes?tab=received');
  const sessionId = await createSession();
  const notes = [];

  try {
    await waitForReceivedReady(sessionId, 20000);
    await captureScreenshot(sessionId, '01-received-locked.png');

    await ensureUnlockDialog(sessionId);
    await sleep(700);
    await waitForElement(sessionId, 'accessibility id', 'likes-dialog-confirm', 2500).catch(async () => {
      await clickSimulatorViewportRelative(0.5, 0.94);
    });
    await sleep(700);
    await captureScreenshot(sessionId, '02-unlock-dialog.png');
    await waitForElement(sessionId, 'accessibility id', 'likes-dialog-confirm', 10000);

    await tapTestId(sessionId, 'likes-dialog-confirm', 10000);
    await sleep(1200);
    await captureScreenshot(sessionId, '03-received-unlocked.png');

    await tapTestId(sessionId, 'likes-card-received-review-received-1', 12000, { centerTap: true }).catch(async () => {
      await tapTestId(sessionId, 'likes-card-received-review-match-1', 12000, { centerTap: true });
    });
    await waitForElement(sessionId, 'accessibility id', 'likes-preview-close', 10000);
    await captureScreenshot(sessionId, '04-preview-modal.png');
    await tapTestId(sessionId, 'likes-preview-close', 5000);

    await tapTestId(sessionId, 'likes-tab-sent', 10000);
    await sleep(800);
    await captureScreenshot(sessionId, '05-sent.png');

    await tapTestId(sessionId, 'likes-tab-zzirit', 10000);
    await sleep(800);
    await captureScreenshot(sessionId, '06-zzirit.png');
    notes.push('status: success');
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    notes.push('status: failure');
    notes.push(`failure: ${message}`);
    await captureScreenshot(sessionId, 'failure.png').catch(() => undefined);
    await captureSource(sessionId, 'failure-source.xml').catch(() => undefined);
    throw error;
  } finally {
    await writeSummary([
      '# iOS Likes Review',
      '',
      `- device: ${deviceName}`,
      `- bundle_id: ${bundleId}`,
      `- report_dir: ${reportDir}`,
      ...notes.map((note) => `- ${note}`),
      '',
      '## Artifacts',
      '- 01-received-locked.png',
      '- 02-unlock-dialog.png',
      '- 03-received-unlocked.png',
      '- 04-preview-modal.png',
      '- 05-sent.png',
      '- 06-zzirit.png',
    ]);
    await deleteSession(sessionId);
  }

  logStep(`report_dir=${reportDir}`);
}

main().catch((error) => {
  const message = error instanceof Error ? error.stack || error.message : String(error);
  process.stderr.write(`${message}\n`);
  process.exit(1);
});
