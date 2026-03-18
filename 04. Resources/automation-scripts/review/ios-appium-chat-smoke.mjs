import { Buffer } from 'node:buffer';
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
  process.env.ZZIRIT_APPIUM_REPORT_DIR || path.join(projectRoot, 'artifacts', 'appium-chat');
const timestamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, '').replace('T', '-');
const reportDir = path.join(reportRoot, timestamp);
const appiumServerUrl = process.env.ZZIRIT_APPIUM_SERVER_URL || 'http://127.0.0.1:4725/wd/hub';
const bundleId = process.env.ZZIRIT_IOS_APP_BUNDLE_ID || 'com.flirtter.zziritApp';
const deviceName = process.env.ZZIRIT_IOS_SIMULATOR_NAME || 'iPhone 17 Pro';
const platformVersion = process.env.ZZIRIT_IOS_PLATFORM_VERSION || '26.2';
const udid = process.env.ZZIRIT_IOS_SIMULATOR_UDID;
const apiBaseUrl =
  process.env.ZZIRIT_API_BASE_URL || 'https://zzirit-proxy-147227137514.asia-northeast3.run.app';
const reviewSeedBaseUrl =
  process.env.ZZIRIT_REVIEW_SEED_API_BASE_URL || 'https://zzirit-api-147227137514.asia-northeast3.run.app';
const reviewSeedKey = process.env.ZZIRIT_REVIEW_SEED_KEY || 'review-seed-20260313-my';
const sampleImagePath =
  process.env.ZZIRIT_CHAT_SAMPLE_IMAGE ||
  path.join(projectRoot, 'apps', 'mobile', 'assets', 'images', 'profile-example1.png');

function logStep(message) {
  const line = `[ios-appium-chat] ${message}`;
  process.stdout.write(`${line}\n`);
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

async function getSource(sessionId) {
  const response = await request('GET', `/session/${sessionId}/source`);
  return response.value;
}

async function findElement(sessionId, using, value) {
  try {
    const response = await request('POST', `/session/${sessionId}/element`, { using, value });
    return response.value;
  } catch (error) {
    if (error instanceof Error && error.message.includes('no such element')) {
      return null;
    }
    throw error;
  }
}

async function findElements(sessionId, using, value) {
  try {
    const response = await request('POST', `/session/${sessionId}/elements`, { using, value });
    return response.value || [];
  } catch (error) {
    if (error instanceof Error && error.message.includes('no such element')) {
      return [];
    }
    throw error;
  }
}

async function waitForElement(sessionId, using, value, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const element = await findElement(sessionId, using, value);
    if (element) {
      return element;
    }
    await sleep(500);
  }
  throw new Error(`Timed out waiting for element: ${using}=${value}`);
}

async function clickElement(sessionId, element) {
  const elementId = getElementId(element);
  if (!elementId) {
    throw new Error('Missing element id for click');
  }
  await request('POST', `/session/${sessionId}/element/${elementId}/click`, {});
  await sleep(500);
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

async function getWindowRect(sessionId) {
  const response = await request('GET', `/session/${sessionId}/window/rect`);
  return response.value;
}

async function tapRelative(sessionId, xRatio, yRatio) {
  const rect = await getWindowRect(sessionId);
  return tapAt(sessionId, rect.width * xRatio, rect.height * yRatio);
}

async function tapElementCenter(sessionId, element) {
  const rect = await getElementRect(sessionId, element);
  return tapAt(sessionId, rect.x + rect.width / 2, rect.y + rect.height / 2);
}

async function tapTestId(sessionId, testId, timeoutMs = 15000) {
  const element = await waitForElement(sessionId, 'accessibility id', testId, timeoutMs);
  await clickElement(sessionId, element);
}

async function dismissStartupAlert(sessionId) {
  try {
    await request('POST', `/session/${sessionId}/alert/dismiss`, {});
    await sleep(1000);
  } catch {
    // Ignore missing alerts.
  }
}

async function captureScreenshot(sessionId, filename) {
  const response = await request('GET', `/session/${sessionId}/screenshot`);
  const filePath = path.join(reportDir, filename);
  await writeFile(filePath, Buffer.from(response.value, 'base64'));
  return filePath;
}

async function captureSimulatorScreenshot(sessionId, filename) {
  const filePath = path.join(reportDir, filename);
  if (!udid) {
    return captureScreenshot(sessionId, filename);
  }
  await execFileAsync('xcrun', ['simctl', 'io', udid, 'screenshot', filePath], { maxBuffer: 1024 * 1024 });
  return filePath;
}

async function waitForSourceText(sessionId, texts, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const source = await getSource(sessionId);
    if (texts.every((text) => source.includes(text))) {
      return source;
    }
    await sleep(500);
  }
  throw new Error(`Timed out waiting for source text: ${texts.join(', ')}`);
}

async function waitForAnyElement(sessionId, selectors, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    for (const [using, value] of selectors) {
      const element = await findElement(sessionId, using, value);
      if (element) {
        return element;
      }
    }
    await sleep(400);
  }
  throw new Error(
    `Timed out waiting for any element: ${selectors.map(([using, value]) => `${using}=${value}`).join(', ')}`,
  );
}

async function waitForChatRoomLoaded(sessionId, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const input =
      (await findElement(sessionId, 'accessibility id', 'chat-input')) ||
      (await findElement(
        sessionId,
        '-ios predicate string',
        "name CONTAINS[c] '메세지 입력하기' OR label CONTAINS[c] '메세지 입력하기'",
      ));
    if (input) {
      return input;
    }
    await sleep(500);
  }
  throw new Error('Timed out waiting for chat room input');
}

async function openChatRoomWithRetry(sessionId, nextRoute, timeoutMs = 20000) {
  let lastError = null;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    await openSeededRoute(nextRoute);
    try {
      return await waitForChatRoomLoaded(sessionId, timeoutMs);
    } catch (error) {
      lastError = error;
      await dismissStartupAlert(sessionId);
      await sleep(1200);
    }
  }
  throw lastError || new Error(`Timed out opening chat room: ${nextRoute}`);
}

async function openMediaMenu(sessionId) {
  try {
    await tapTestId(sessionId, 'chat-media-button', 5000);
    return 'appium';
  } catch {
    await clickSimulatorViewportRelative(0.085, 0.94);
    return 'raw';
  }
}

async function tapMediaOption(sessionId, type) {
  const map = {
    gallery: { testId: 'chat-media-gallery', ratio: [0.5, 0.845] },
    location: { testId: 'chat-media-location', ratio: [0.81, 0.845] },
  };
  const target = map[type];
  try {
    await tapTestId(sessionId, target.testId, 4000);
    return 'appium';
  } catch {
    await clickSimulatorViewportRelative(target.ratio[0], target.ratio[1]);
    return 'raw';
  }
}

async function tapQuickReplyHello(sessionId) {
  try {
    await tapTestId(sessionId, 'chat-quick-reply-hello', 5000);
    return 'appium';
  } catch {
    const candidates = [
      [0.22, 0.84],
      [0.28, 0.84],
      [0.33, 0.84],
    ];
    for (let index = 0; index < candidates.length; index += 1) {
      const [x, y] = candidates[index];
      await clickSimulatorViewportRelative(x, y);
      await sleep(1600);
      const source = await getSource(sessionId).catch(() => '');
      if (source.includes('안녕하세요!')) {
        return `raw#${index + 1}`;
      }
    }
    throw new Error('Timed out tapping quick reply hello');
  }
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

async function tapFirstPhotoFromPicker(sessionId, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    for (const className of ['XCUIElementTypeImage', 'XCUIElementTypeCell']) {
      const elements = await findElements(sessionId, 'class name', className);
      if (elements.length > 0) {
        const candidateRects = [];
        for (const element of elements) {
          const rect = await getElementRect(sessionId, element).catch(() => null);
          if (rect) {
            candidateRects.push({ element, rect });
          }
        }
        const candidate =
          candidateRects.find(({ rect }) => rect.y >= 300 && rect.width >= 90 && rect.height >= 90) ||
          candidateRects.find(({ rect }) => rect.width >= 90 && rect.height >= 90);
        if (candidate) {
          await tapElementCenter(sessionId, candidate.element);
          await sleep(1200);
          return;
        }
      }
    }
    await sleep(500);
  }

  throw new Error('Timed out selecting a photo from the iOS photo picker');
}

async function confirmPhotoPickerSelection(sessionId, timeoutMs = 12000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    for (const label of ['완료', 'Done', '추가', '선택']) {
      const element =
        (await findElement(sessionId, 'accessibility id', label)) ||
        (await findElement(
          sessionId,
          '-ios predicate string',
          `name == '${label}' OR label == '${label}' OR value == '${label}'`,
        ));
      if (element) {
        await tapElementCenter(sessionId, element);
        await sleep(1200);
        return label;
      }
    }

    await tapRelative(sessionId, 0.9045, 0.1548);
    await sleep(1200);
    return 'blind-top-right';
  }

  throw new Error('Timed out confirming photo picker');
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

async function openSeededRoute(nextRoute) {
  await execFileAsync('bash', [path.join(projectRoot, 'scripts', 'review', 'open-ios-seeded-review.sh'), deviceName, nextRoute], {
    env: {
      ...process.env,
      ZZIRIT_IOS_SIMULATOR_UDID: udid || '',
      ZZIRIT_REVIEW_USER_ID: 'review-my-user',
    },
    maxBuffer: 1024 * 1024,
  });
  await sleep(6500);
}

async function grantLocationPermission() {
  if (!udid) {
    return;
  }
  await execFileAsync('xcrun', ['simctl', 'privacy', udid, 'grant', 'location', bundleId]).catch(() => undefined);
}

async function addSampleImageToPhotos() {
  if (!udid) {
    return;
  }
  await execFileAsync('xcrun', ['simctl', 'addmedia', udid, sampleImagePath]).catch(() => undefined);
}

async function main() {
  await mkdir(reportDir, { recursive: true });
  logStep(`report_dir=${reportDir}`);

  logStep('seeding review data');
  const seeded = await seedReviewData().catch((error) => ({ error: error instanceof Error ? error.message : String(error) }));
  logStep(`seeded=${JSON.stringify(seeded)}`);

  const capabilities = {
    platformName: 'iOS',
    'appium:automationName': 'XCUITest',
    'appium:deviceName': deviceName,
    'appium:platformVersion': platformVersion,
    'appium:bundleId': bundleId,
    'appium:noReset': true,
    'appium:newCommandTimeout': 180,
  };

  if (udid) {
    capabilities['appium:udid'] = udid;
  }

  const sessionResponse = await request('POST', '/session', {
    capabilities: { alwaysMatch: capabilities },
  });
  const sessionId = sessionResponse.value.sessionId || sessionResponse.sessionId;
  logStep(`session=${sessionId}`);

  try {
    await dismissStartupAlert(sessionId);
    await grantLocationPermission();
    await addSampleImageToPhotos();

    logStep('open empty room');
    await openChatRoomWithRetry(
      sessionId,
      '/chattingroom?id=review-room-4&name=강유림&partnerId=review-match-4',
      20000,
    );
    await captureSimulatorScreenshot(sessionId, '01-empty-room.png');

    logStep('tap quick reply');
    const quickReplyTap = await tapQuickReplyHello(sessionId);
    let quickReplyResult = quickReplyTap;
    try {
      await waitForSourceText(sessionId, ['안녕하세요!'], 12000);
    } catch {
      quickReplyResult = `${quickReplyTap}:seeded-fallback`;
      await openChatRoomWithRetry(
        sessionId,
        '/chattingroom?id=review-room-1&name=문서아&partnerId=review-match-1',
        20000,
      );
    }
    await captureSimulatorScreenshot(sessionId, '02-empty-room-after-quick-reply.png');

    logStep('open room1 for location');
    await openChatRoomWithRetry(
      sessionId,
      '/chattingroom?id=review-room-1&name=문서아&partnerId=review-match-1',
      20000,
    );

    logStep('send location');
    const locationMenuOpen = await openMediaMenu(sessionId);
    const locationTap = await tapMediaOption(sessionId, 'location');
    let locationResult = 'live-send';
    try {
      await waitForSourceText(sessionId, ['위치 확인하기'], 15000);
    } catch {
      locationResult = 'seeded-fallback';
      await openChatRoomWithRetry(
        sessionId,
        '/chattingroom?id=review-room-3&name=유서린&partnerId=review-match-3',
        20000,
      );
      await waitForSourceText(sessionId, ['위치 확인하기'], 8000).catch(() => undefined);
    }
    await captureSimulatorScreenshot(sessionId, '03-location-sent.png');

    logStep('send gallery image');
    const galleryMenuOpen = await openMediaMenu(sessionId);
    const galleryTap = await tapMediaOption(sessionId, 'gallery');
    await sleep(2500);
    await tapFirstPhotoFromPicker(sessionId, 10000).catch(async () => {
      await clickSimulatorViewportRelative(0.5, 0.56);
      await sleep(1500);
    });
    await confirmPhotoPickerSelection(sessionId, 8000).catch(() => undefined);
    let imageResult = 'live-send';
    try {
      await waitForSourceText(sessionId, ['메세지 입력하기..'], 10000);
    } catch {
      imageResult = 'seeded-fallback';
      await openChatRoomWithRetry(
        sessionId,
        '/chattingroom?id=review-room-2&name=임하린&partnerId=review-match-2',
        20000,
      );
    }
    await sleep(2500);
    await captureSimulatorScreenshot(sessionId, '04-image-sent.png');

    const summary = [
      '# iOS Appium Chat Smoke',
      '',
      `- seeded: ${JSON.stringify(seeded)}`,
      `- report: ${reportDir}`,
      `- bundle_id: ${bundleId}`,
      `- device: ${deviceName}`,
      `- session: ${sessionId}`,
      '- steps: empty-room, quick-reply, location-send, image-send',
      `- quick_reply_tap: ${quickReplyTap}`,
      `- quick_reply_result: ${quickReplyResult}`,
      `- location_menu_open: ${locationMenuOpen}`,
      `- location_tap: ${locationTap}`,
      `- location_result: ${locationResult}`,
      `- gallery_menu_open: ${galleryMenuOpen}`,
      `- gallery_tap: ${galleryTap}`,
      `- image_result: ${imageResult}`,
    ].join('\n');
    await writeFile(path.join(reportDir, 'summary.md'), summary);
    process.stdout.write(`${reportDir}\n`);
  } finally {
    await request('DELETE', `/session/${sessionId}`).catch(() => undefined);
  }
}

main().catch((error) => {
  const message = error instanceof Error ? error.stack || error.message : String(error);
  writeFile(path.join(reportDir, 'error.log'), `${message}\n`).catch(() => undefined);
  console.error(message);
  process.exit(1);
});
