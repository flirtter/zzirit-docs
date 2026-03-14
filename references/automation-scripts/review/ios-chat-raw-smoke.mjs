import { execFile } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot =
  process.env.ZZIRIT_IOS_PROJECT_ROOT || path.resolve(scriptDir, '..', '..');
const reportRoot =
  process.env.ZZIRIT_CHAT_RAW_REPORT_DIR || path.join(projectRoot, 'artifacts', 'chat-raw');
const timestamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, '').replace('T', '-');
const reportDir = path.join(reportRoot, timestamp);
const deviceName = process.env.ZZIRIT_IOS_SIMULATOR_NAME || 'iPhone 17 Pro';
const udid = process.env.ZZIRIT_IOS_SIMULATOR_UDID || '';
const bundleId = process.env.ZZIRIT_IOS_APP_BUNDLE_ID || 'com.flirtter.zziritApp';
const apiBaseUrl =
  process.env.ZZIRIT_API_BASE_URL || 'https://zzirit-api-147227137514.asia-northeast3.run.app';
const reviewSeedBaseUrl =
  process.env.ZZIRIT_REVIEW_SEED_API_BASE_URL || apiBaseUrl;
const reviewSeedKey = process.env.ZZIRIT_REVIEW_SEED_KEY || 'review-seed-20260313-my';
const sampleImagePath =
  process.env.ZZIRIT_CHAT_SAMPLE_IMAGE ||
  path.join(projectRoot, 'apps', 'mobile', 'assets', 'images', 'profile-example1.png');

function logStep(message) {
  process.stdout.write(`[ios-chat-raw] ${message}\n`);
}

async function sleep(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function seedReviewData() {
  if (!reviewSeedKey) {
    return { skipped: true };
  }

  const response = await fetch(`${reviewSeedBaseUrl}/v1/review-seed/my`, {
    method: 'POST',
    headers: { 'X-Review-Seed-Key': reviewSeedKey },
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`Failed to seed review data: ${JSON.stringify(payload)}`);
  }
  return payload;
}

async function addSampleImageToPhotos() {
  if (!udid) {
    return;
  }
  await execFileAsync('xcrun', ['simctl', 'addmedia', udid, sampleImagePath]).catch(() => undefined);
}

async function grantLocationPermission() {
  if (!udid) {
    return;
  }
  await execFileAsync('xcrun', ['simctl', 'privacy', udid, 'grant', 'location', bundleId]).catch(() => undefined);
}

async function grantMediaPermissions() {
  if (!udid) {
    return;
  }
  for (const service of ['photos', 'photos-add', 'camera']) {
    await execFileAsync('xcrun', ['simctl', 'privacy', udid, 'grant', service, bundleId]).catch(
      () => undefined,
    );
  }
}

async function openSeededRoute(nextRoute) {
  await execFileAsync('bash', [path.join(projectRoot, 'scripts', 'review', 'open-ios-seeded-review.sh'), deviceName, nextRoute], {
    env: {
      ...process.env,
      ZZIRIT_IOS_SIMULATOR_UDID: udid,
      ZZIRIT_REVIEW_USER_ID: 'review-my-user',
    },
    maxBuffer: 1024 * 1024,
  });
}

async function captureSimulatorScreenshot(filename) {
  if (!udid) {
    throw new Error('Simulator UDID is required for raw chat smoke screenshots');
  }
  const filePath = path.join(reportDir, filename);
  await execFileAsync('xcrun', ['simctl', 'io', udid, 'screenshot', filePath], { maxBuffer: 1024 * 1024 });
  return filePath;
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
    'usleep(70000)',
    'down?.post(tap: .cghidEventTap)',
    'usleep(70000)',
    'up?.post(tap: .cghidEventTap)',
  ].join('\n');
  await execFileAsync('swift', ['-e', swiftCode], { maxBuffer: 1024 * 1024 });
  await sleep(1000);
}

async function main() {
  await mkdir(reportDir, { recursive: true });
  logStep(`report_dir=${reportDir}`);

  logStep('seeding review data');
  const seeded = await seedReviewData();
  logStep(`seeded=${JSON.stringify(seeded)}`);

  await grantLocationPermission();
  await grantMediaPermissions();
  await addSampleImageToPhotos();

  logStep('open empty room');
  await openSeededRoute('/chattingroom?id=review-room-4&name=강유림&partnerId=review-match-4');
  await sleep(6500);
  await captureSimulatorScreenshot('01-empty-room.png');

  logStep('tap quick reply');
  await clickSimulatorViewportRelative(0.24, 0.84);
  await sleep(3200);
  await captureSimulatorScreenshot('02-empty-room-after-quick-reply.png');

  logStep('open room3 seeded location state');
  await openSeededRoute('/chattingroom?id=review-room-3&name=유서린&partnerId=review-match-3');
  await sleep(6500);
  await captureSimulatorScreenshot('03-location-sent.png');

  logStep('open room2 seeded image state');
  await openSeededRoute('/chattingroom?id=review-room-2&name=임하린&partnerId=review-match-2');
  await sleep(6500);
  await captureSimulatorScreenshot('04-image-room-seeded.png');

  logStep('open room1 for gallery send');
  await openSeededRoute('/chattingroom?id=review-room-1&name=문서아&partnerId=review-match-1');
  await sleep(6500);
  await clickSimulatorViewportRelative(0.085, 0.94);
  await clickSimulatorViewportRelative(0.50, 0.845);
  await sleep(2800);
  await clickSimulatorViewportRelative(0.22, 0.30);
  await sleep(1800);
  await clickSimulatorViewportRelative(0.50, 0.56);
  await sleep(1800);
  await clickSimulatorViewportRelative(0.9045, 0.1548);
  await sleep(2200);
  await clickSimulatorViewportRelative(0.9045, 0.1548);
  await sleep(4200);
  await captureSimulatorScreenshot('05-image-send-attempt.png');

  const summary = [
    '# iOS Chat Raw Smoke',
    '',
    `- report: ${reportDir}`,
    `- device: ${deviceName}`,
    `- udid: ${udid || 'unknown'}`,
    `- api_base_url: ${apiBaseUrl}`,
    `- review_seed_base_url: ${reviewSeedBaseUrl}`,
    `- seeded: ${JSON.stringify(seeded)}`,
    '- steps:',
    '  - empty room screenshot',
    '  - quick reply raw tap',
    '  - seeded location room screenshot',
    '  - seeded image room screenshot',
    '  - gallery send attempt raw tap',
  ].join('\n');
  await writeFile(path.join(reportDir, 'summary.md'), summary);
  process.stdout.write(`${reportDir}\n`);
}

main().catch(async (error) => {
  const message = error instanceof Error ? error.stack || error.message : String(error);
  await mkdir(reportDir, { recursive: true }).catch(() => undefined);
  await writeFile(path.join(reportDir, 'error.log'), `${message}\n`).catch(() => undefined);
  console.error(message);
  process.exit(1);
});
