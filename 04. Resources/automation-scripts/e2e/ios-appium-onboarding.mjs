import { Buffer } from 'node:buffer';
import { execFile } from 'node:child_process';
import { access, mkdir, writeFile } from 'node:fs/promises';
import { promisify } from 'node:util';
import path from 'node:path';

const execFileAsync = promisify(execFile);

const projectRoot = process.env.ZZIRIT_IOS_PROJECT_ROOT || path.resolve(process.cwd());
const reportRoot =
  process.env.ZZIRIT_APPIUM_REPORT_DIR || path.join(projectRoot, 'artifacts', 'appium-onboarding');
const timestamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, '').replace('T', '-');
const reportDir = process.env.ZZIRIT_APPIUM_RUN_DIR || path.join(reportRoot, timestamp);
const appiumServerUrl = process.env.ZZIRIT_APPIUM_SERVER_URL || 'http://127.0.0.1:4725/wd/hub';
const bundleId = process.env.ZZIRIT_IOS_APP_BUNDLE_ID || 'com.flirtter.zziritApp';
const deviceName = process.env.ZZIRIT_IOS_SIMULATOR_NAME || 'iPhone 17 Pro';
const platformVersion = process.env.ZZIRIT_IOS_PLATFORM_VERSION || '26.2';
const udid = process.env.ZZIRIT_IOS_SIMULATOR_UDID;
const stopAfter = (process.env.ZZIRIT_APPIUM_STOP_AFTER || '').trim().toLowerCase();
const appScheme = process.env.ZZIRIT_IOS_APP_SCHEME || 'zzirit';

function getElementId(element) {
  return element.ELEMENT || element['element-6066-11e4-a52e-4f735466cecf'];
}

async function request(method, pathname, body) {
  const response = await fetch(`${appiumServerUrl}${pathname}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error(`${method} ${pathname} failed: ${JSON.stringify(payload)}`);
  }
  return payload;
}

async function sleep(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function openSimulatorUrl(url) {
  if (!udid) {
    throw new Error('Simulator UDID is required to open deeplinks during Appium onboarding');
  }

  await execFileAsync('xcrun', ['simctl', 'openurl', udid, url]);
  await sleep(4000);
}

function isSignupSource(source) {
  return (
    (source.includes('이메일 주소를') && source.includes('다음')) ||
    (source.includes('이미 계정이 있으신가요? 로그인') &&
      source.includes('다음') &&
      source.includes('XCUIElementTypeTextField') &&
      !source.includes('XCUIElementTypeSecureTextField'))
  );
}

function isSignupPasswordSource(source) {
  return source.includes('비밀번호를') && source.includes('가입하기');
}

function detectOnboardingResumeStage(source) {
  if (isSignupSource(source)) {
    return 'signup';
  }

  if (isSignupPasswordSource(source)) {
    return 'signup-password';
  }

  if (source.includes('onboarding-step-nickname') || (source.includes('프로필을 만들어볼까요.') && source.includes('당신의 이름은?'))) {
    return 'nickname';
  }

  if (source.includes('onboarding-step-intro') || (source.includes('관심사 기반 매칭과') && source.includes('실시간 채팅 지원'))) {
    return 'intro';
  }

  if (source.includes('onboarding-step-location') || (source.includes('정확한 매칭을 위해') && source.includes('위치 정보가 필요해요'))) {
    return 'location';
  }

  if (source.includes('onboarding-step-photo-intro') || (source.includes('프로필 사진 등록을 위해') && source.includes('카메라 접근이 필요해요'))) {
    return 'photo-intro';
  }

  if (source.includes('onboarding-step-photo-upload') || (source.includes('사진을 업로드 해보세요!') && source.includes('프로필 사진'))) {
    return 'photo-upload';
  }

  if (source.includes('onboarding-step-notification') || (source.includes('매칭 알림을 놓치지 마세요!') && source.includes('다음'))) {
    return 'notification';
  }

  if (source.includes('onboarding-step-basic-info') || (source.includes('필수 정보를 알려주세요!') && source.includes('생년월일'))) {
    return 'basic-info';
  }

  if (source.includes('onboarding-step-essentials') || (source.includes('나를 표현하고 매칭율을') && source.includes('어떤 일을 하고 계신가요?'))) {
    return 'matching';
  }

  if (source.includes('onboarding-step-welcome') || (source.includes('축하합니다!') && source.includes('시작하기'))) {
    return 'welcome';
  }

  if (source.includes('미팅') && source.includes('채팅') && source.includes('MY')) {
    return 'tabs';
  }

  return null;
}

async function getSource(sessionId) {
  const source = await request('GET', `/session/${sessionId}/source`);
  return source.value;
}

async function findElement(sessionId, using, value) {
  try {
    const response = await request('POST', `/session/${sessionId}/element`, {
      using,
      value,
    });
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
    const response = await request('POST', `/session/${sessionId}/elements`, {
      using,
      value,
    });
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
    await dismissTransientAlert(sessionId);
    const element = await findElement(sessionId, using, value);
    if (element) {
      return element;
    }
    await sleep(500);
  }

  throw new Error(`Timed out waiting for element: ${using}=${value}`);
}

async function waitForAnyElement(sessionId, selectors, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    await dismissTransientAlert(sessionId);
    for (const [using, value] of selectors) {
      const element = await findElement(sessionId, using, value);
      if (element) {
        return { using, value, element };
      }
    }
    await sleep(500);
  }

  throw new Error(
    `Timed out waiting for any element: ${selectors.map(([using, value]) => `${using}=${value}`).join(', ')}`,
  );
}

async function clickElement(sessionId, element) {
  const elementId = getElementId(element);
  if (!elementId) {
    throw new Error('Missing element id for click');
  }
  await request('POST', `/session/${sessionId}/element/${elementId}/click`, {});
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
  await sleep(500);
}

async function getWindowRect(sessionId) {
  const response = await request('GET', `/session/${sessionId}/window/rect`);
  return response.value;
}

async function tapRelative(sessionId, xRatio, yRatio) {
  try {
    const rect = await getWindowRect(sessionId);
    return tapAt(sessionId, rect.width * xRatio, rect.height * yRatio);
  } catch (error) {
    await clickSimulatorViewportRelative(xRatio, yRatio);
    return 'simulator-relative';
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

async function tapElementCenter(sessionId, element) {
  const rect = await getElementRect(sessionId, element);
  return tapAt(sessionId, rect.x + rect.width / 2, rect.y + rect.height / 2);
}

async function tapTestId(sessionId, testId, timeoutMs = 15000) {
  const element = await waitForElement(sessionId, 'accessibility id', testId, timeoutMs);
  await clickElement(sessionId, element);
  await sleep(600);
}

async function tapTestIdOrLabel(sessionId, testId, label, timeoutMs = 15000) {
  const element = await findElement(sessionId, 'accessibility id', testId);
  if (element) {
    await clickElement(sessionId, element);
    await sleep(600);
    return `testid:${testId}`;
  }

  await tapLabel(sessionId, label).catch(async () => {
    const labelElement = await waitForElement(
      sessionId,
      '-ios predicate string',
      `name CONTAINS[c] '${escapePredicate(label)}' OR label CONTAINS[c] '${escapePredicate(label)}' OR value CONTAINS[c] '${escapePredicate(label)}'`,
      timeoutMs,
    );
    await tapElementCenter(sessionId, labelElement);
  });
  await sleep(600);
  return `label:${label}`;
}

async function selectVisiblePickerOption(sessionId, optionPrefix, preferredTestId, preferredLabel, timeoutMs = 10000) {
  const direct = await findElement(sessionId, 'accessibility id', preferredTestId);
  if (direct) {
    await tapElementCenter(sessionId, direct);
    await sleep(600);
    return `testid:${preferredTestId}`;
  }

  const visibleOptions = await findElements(
    sessionId,
    '-ios predicate string',
    `name BEGINSWITH '${escapePredicate(optionPrefix)}' AND visible == 1`,
  );
  if (visibleOptions.length > 0) {
    await tapElementCenter(sessionId, visibleOptions[0]);
    await sleep(600);
    return `visible:${optionPrefix}*`;
  }

  return tapTestIdOrLabel(sessionId, preferredTestId, preferredLabel, timeoutMs);
}

async function tapFirstPhotoFromPicker(sessionId, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    await dismissTransientAlert(sessionId);

    const namedImages = await findElements(
      sessionId,
      '-ios predicate string',
      "type == 'XCUIElementTypeImage' AND (name CONTAINS[c] '사진' OR label CONTAINS[c] '사진')",
    );
    if (namedImages.length > 0) {
      await tapElementCenter(sessionId, namedImages[0]);
      await sleep(1200);
      return 'named-image';
    }

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
          candidateRects.find(({ rect }) => rect.y >= 440 && rect.width >= 100 && rect.height >= 100) ||
          candidateRects.find(({ rect }) => rect.width >= 100 && rect.height >= 100);
        if (!candidate) {
          continue;
        }
        await tapElementCenter(sessionId, candidate.element);
        await sleep(1200);
        return className;
      }
    }

    await sleep(500);
  }

  throw new Error('Timed out selecting a photo from the iOS photo picker');
}

async function waitForPhotoPickerStage(sessionId, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    await dismissTransientAlert(sessionId);
    const source = await getSource(sessionId);

    if (
      source.includes('라이브러리에서 선택') ||
      source.includes('사진 찍기') ||
      source.includes('onboarding-photo-library')
    ) {
      return 'sheet';
    }

    if (
      source.includes('PXGGridLayout-Info') ||
      (source.includes('사진') && source.includes('취소') && source.includes('완료'))
    ) {
      return 'picker';
    }

    if (source.includes('사진을 업로드 해보세요!') && source.includes('프로필 사진')) {
      return 'upload';
    }

    await sleep(400);
  }

  throw new Error('Timed out determining the photo picker stage');
}

async function openLibraryPickerFromUploadStep(sessionId, timeoutMs = 25000) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    const slot = await waitForElement(sessionId, 'accessibility id', 'onboarding-photo-slot-1', 5000);
    await tapElementCenter(sessionId, slot);
    await sleep(900);
    const stage = await waitForPhotoPickerStage(sessionId, 2500).catch(() => 'upload');

    if (stage === 'sheet') {
      const libraryOption =
        (await findElement(sessionId, 'accessibility id', 'onboarding-photo-library')) ||
        (await findElement(
          sessionId,
          '-ios predicate string',
            "type == 'XCUIElementTypeButton' AND (name CONTAINS[c] '라이브러리에서 선택' OR label CONTAINS[c] '라이브러리에서 선택')",
        ));
      if (libraryOption) {
        await tapElementCenter(sessionId, libraryOption).catch(async () => {
          await clickElement(sessionId, libraryOption);
        });
      } else {
        try {
          await tapLabel(sessionId, '라이브러리에서 선택');
        } catch {
          await clickSimulatorViewportRelative(0.5, 0.9);
        }
      }
      await sleep(900);
      await dismissAlert(sessionId, 'accept').catch(() => null);
      await sleep(1800);
      const nextStage = await waitForPhotoPickerStage(sessionId, 7000).catch(() => 'upload');
      if (nextStage === 'picker') {
        return 'sheet->picker';
      }
      if (nextStage === 'sheet') {
        await clickSimulatorViewportRelative(0.5, 0.9);
        await sleep(1800);
        const retriedStage = await waitForPhotoPickerStage(sessionId, 7000).catch(() => 'upload');
        if (retriedStage === 'picker') {
          return 'sheet->picker-simulator';
        }
        await sleep(600);
        continue;
      }
      await sleep(600);
      continue;
    } else if (stage === 'picker') {
      return 'direct-picker';
    }

    await clickSimulatorViewportRelative(0.5, 0.9);
    await sleep(2200);
    await sleep(800);
  }

  throw new Error('Timed out opening the iOS photo library picker');
}

async function selectPhotoFromPicker(sessionId, timeoutMs = 20000) {
  const currentStage = await waitForPhotoPickerStage(sessionId, 5000).catch(() => 'upload');
  if (currentStage === 'sheet') {
    await openLibraryPickerFromUploadStep(sessionId, Math.min(timeoutMs, 10000));
  }

  try {
    const pickedBy = await tapFirstPhotoFromPicker(sessionId, Math.min(timeoutMs, 8000));
    const cropConfirm = await findElement(sessionId, 'accessibility id', 'onboarding-photo-confirm');
    if (cropConfirm) {
      return `${pickedBy}->direct-crop`;
    }
    const confirmedBy = await confirmPhotoPickerSelection(sessionId, Math.min(timeoutMs, 8000));
    return `${pickedBy}->${confirmedBy}`;
  } catch {
    // Fall back to a real macOS click on the Simulator viewport when Appium cannot drive PHPicker.
    for (let attempt = 0; attempt < 3; attempt += 1) {
      await sleep(2200);
      await clickSimulatorViewportRelative(0.5, 0.5515);
      await sleep(2000);
      const cropConfirm = await findElement(sessionId, 'accessibility id', 'onboarding-photo-confirm');
      if (cropConfirm) {
        return `simulator-grid#${attempt + 1}`;
      }
    }
    return 'simulator-grid-unverified';
  }
}

async function confirmPhotoPickerSelection(sessionId, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    await dismissTransientAlert(sessionId);

    for (const label of ['완료', 'Update', 'Done', '추가', '선택']) {
      try {
        const escapedLabel = escapePredicate(label);
        const element =
          (await findElement(sessionId, 'accessibility id', label)) ||
          (await findElement(
            sessionId,
            '-ios predicate string',
            `name == '${escapedLabel}' OR label == '${escapedLabel}' OR value == '${escapedLabel}'`,
          )) ||
          (await findElement(
            sessionId,
            '-ios predicate string',
            `name CONTAINS[c] '${escapedLabel}' OR label CONTAINS[c] '${escapedLabel}' OR value CONTAINS[c] '${escapedLabel}'`,
          ));
        if (!element) {
          throw new Error('missing picker confirm element');
        }
        await tapElementCenter(sessionId, element);
        await sleep(1200);
        return label;
      } catch {
        // Try the next label variant.
      }
    }

    await tapRelative(sessionId, 0.9045, 0.1548);
    await sleep(1200);
    return 'blind-top-right';

    await sleep(500);
  }

  throw new Error('Timed out confirming the iOS photo picker selection');
}

async function clearElement(sessionId, element) {
  const elementId = getElementId(element);
  if (!elementId) {
    return;
  }

  await request('POST', `/session/${sessionId}/element/${elementId}/clear`, {}).catch(() => undefined);
}

async function typeIntoElement(sessionId, element, text) {
  const elementId = getElementId(element);
  if (!elementId) {
    throw new Error('Missing element id for text input');
  }

  await clickElement(sessionId, element);
  await clearElement(sessionId, element);
  await request('POST', `/session/${sessionId}/element/${elementId}/value`, {
    text,
    value: Array.from(text),
  });
  await sleep(400);
}

async function typeKeys(sessionId, text) {
  const actions = Array.from(text).flatMap((character) => [
    { type: 'keyDown', value: character },
    { type: 'keyUp', value: character },
  ]);

  await request('POST', `/session/${sessionId}/actions`, {
    actions: [
      {
        type: 'key',
        id: 'keyboard',
        actions,
      },
    ],
  });

  await request('DELETE', `/session/${sessionId}/actions`).catch(() => undefined);
  await sleep(400);
}

async function typeIntoSecureElement(sessionId, element, text) {
  const elementId = getElementId(element);
  if (!elementId) {
    throw new Error('Missing element id for secure text input');
  }

  await clickElement(sessionId, element);
  await typeKeys(sessionId, text);
}

function escapePredicate(text) {
  return text.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

async function tapLabel(sessionId, label) {
  const escapedLabel = escapePredicate(label);
  const predicate =
    `name == '${escapedLabel}' OR label == '${escapedLabel}' OR value == '${escapedLabel}'`;
  const containsPredicate =
    `name CONTAINS[c] '${escapedLabel}' OR label CONTAINS[c] '${escapedLabel}' OR value CONTAINS[c] '${escapedLabel}'`;
  const strategies = [
    ['accessibility id', label],
    ['-ios predicate string', predicate],
    ['-ios predicate string', containsPredicate],
  ];

  for (const [using, value] of strategies) {
    const element = await findElement(sessionId, using, value);
    if (!element) {
      continue;
    }
    await clickElement(sessionId, element);
    await sleep(600);
    return using;
  }

  throw new Error(`Could not find tappable label: ${label}`);
}

async function dismissAlert(sessionId, action = 'dismiss') {
  try {
    const alertText = await request('GET', `/session/${sessionId}/alert/text`);
    await request('POST', `/session/${sessionId}/alert/${action}`, {});
    await sleep(1200);
    return `${action}:${alertText.value}`;
  } catch (error) {
    if (error instanceof Error && error.message.includes('no such alert')) {
      return null;
    }
    throw error;
  }
}

async function dismissKeyboard(sessionId) {
  try {
    await request('POST', `/session/${sessionId}/appium/device/hide_keyboard`, {});
    await sleep(400);
    return 'hide_keyboard';
  } catch {
    // Fall through to label-based dismissal.
  }

  for (const label of ['Done', 'done', '완료']) {
    try {
      await tapLabel(sessionId, label);
      return label;
    } catch {
      // Try the next label variant.
    }
  }

  return null;
}

async function dismissTransientAlert(sessionId) {
  const alertText = await getAlertText(sessionId);
  if (!alertText) {
    return null;
  }

  return dismissAlert(sessionId, 'dismiss');
}

async function waitForSourceText(sessionId, texts, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    await dismissTransientAlert(sessionId);
    const source = await getSource(sessionId);
    assertNoRuntimeOverlay(source);
    if (texts.every((text) => source.includes(text))) {
      return source;
    }
    await sleep(500);
  }

  throw new Error(`Timed out waiting for source text: ${texts.join(', ')}`);
}

async function ensureSignupStart(sessionId) {
  const deadline = Date.now() + 25000;
  let tappedEntryStart = false;
  let deepLinkAttempts = 0;
  let attemptedMyEditClose = false;

  while (Date.now() < deadline) {
    await dismissTransientAlert(sessionId);
    const source = await getSource(sessionId);
    assertNoRuntimeOverlay(source);

    const detectedStage = detectOnboardingResumeStage(source);
    if (detectedStage) {
      return { source, stage: detectedStage };
    }

    if (source.includes('사진 찍기') && source.includes('라이브러리에서 선택')) {
      await clickSimulatorViewportRelative(0.5, 0.2).catch(() => undefined);
      await sleep(1000);
      continue;
    }

    if (
      source.includes('이메일로 시작') &&
      source.includes('카카오로 시작') &&
      source.includes('애플로 시작')
    ) {
      if (!tappedEntryStart) {
        await tapLabel(sessionId, '이메일로 시작');
        tappedEntryStart = true;
        continue;
      }

      if (deepLinkAttempts < 3) {
        deepLinkAttempts += 1;
        await openSimulatorUrl(`${appScheme}:///signup`);
        continue;
      }
    }

    if (
      source.includes('로그인') &&
      source.includes('이메일 입력') &&
      source.includes('비밀번호 입력') &&
      deepLinkAttempts < 3
    ) {
      deepLinkAttempts += 1;
      await openSimulatorUrl(`${appScheme}:///signup`);
      continue;
    }

    if (source.includes('프로필 수정')) {
      if (!attemptedMyEditClose) {
        attemptedMyEditClose = true;
        for (const closeTestId of ['my-edit-close-button', 'settings-back-button']) {
          const closeButton = await findElement(sessionId, 'accessibility id', closeTestId);
          if (closeButton) {
            await clickElement(sessionId, closeButton).catch(() => undefined);
            await sleep(1000);
            break;
          }
        }
        await clickSimulatorViewportRelative(0.5, 0.2).catch(() => undefined);
        await sleep(1000);
        continue;
      }

      if (deepLinkAttempts < 3) {
        deepLinkAttempts += 1;
        await openSimulatorUrl(`${appScheme}:///signup`);
        continue;
      }
    }

    if (((source.includes('MY') && source.includes('내 위치')) || source.includes('알림 설정')) && deepLinkAttempts < 3) {
      deepLinkAttempts += 1;
      await openSimulatorUrl(`${appScheme}:///signup`);
      continue;
    }

    if (
      (
        source.includes('meeting-detail-screen') ||
        source.includes('meeting-create-screen') ||
        source.includes('meeting-location-picker-apply') ||
        source.includes('meeting-create-fab') ||
        source.includes('모집 마감하기')
      ) &&
      deepLinkAttempts < 3
    ) {
      deepLinkAttempts += 1;
      await openSimulatorUrl(`${appScheme}:///signup`);
      continue;
    }

    await sleep(500);
  }

  throw new Error('Timed out waiting for signup start screen');
}

async function getAlertText(sessionId) {
  try {
    const response = await request('GET', `/session/${sessionId}/alert/text`);
    return response.value;
  } catch (error) {
    if (error instanceof Error && error.message.includes('no such alert')) {
      return null;
    }
    throw error;
  }
}

async function captureScreenshot(sessionId, filename) {
  const screenshot = await request('GET', `/session/${sessionId}/screenshot`);
  const screenshotPath = path.join(reportDir, filename);
  await writeFile(screenshotPath, Buffer.from(screenshot.value, 'base64'));
  return screenshotPath;
}

async function captureSource(sessionId, filename, { assertWarningFree = false } = {}) {
  const source = await getSource(sessionId);
  if (assertWarningFree) {
    assertNoRuntimeOverlay(source);
  }
  const sourcePath = path.join(reportDir, filename);
  await writeFile(sourcePath, source);
  return sourcePath;
}

function assertNoRuntimeOverlay(source) {
  const runtimeOverlayIndicators = [
    'Uncaught Error',
    'Unhandled JS Exception',
    'Cannot find native module',
    'TypeError:',
    'ReferenceError:',
  ];

  for (const indicator of runtimeOverlayIndicators) {
    if (source.includes(indicator)) {
      throw new Error(`Runtime overlay detected: ${indicator}`);
    }
  }
}

async function writeSuccessSummary({
  reportDir,
  appiumServerUrl,
  sessionId,
  bundleId,
  deviceName,
  platformVersion,
  signupEmail,
  signupNickname,
  profileNickname,
  notes,
  stoppedAt = '',
}) {
  const existingArtifactLines = [];
  const maybeAddArtifact = async (label, filename) => {
    const artifactPath = path.join(reportDir, filename);
    try {
      await access(artifactPath);
      existingArtifactLines.push(`- ${label}: ${artifactPath}`);
    } catch {
      // Skip artifacts not generated in resumed runs.
    }
  };

  const summaryLines = [
    '# iOS Appium Onboarding',
    '',
    `- Server: ${appiumServerUrl}`,
    `- Session: ${sessionId}`,
    `- Bundle ID: ${bundleId}`,
    `- Device: ${deviceName}`,
    `- Platform: ${platformVersion}`,
    `- Signup email: ${signupEmail}`,
    `- Signup nickname: ${signupNickname}`,
    `- Profile nickname: ${profileNickname}`,
    '- Runtime warnings: none detected',
    `- Notes: ${notes.length ? notes.join(', ') : 'none'}`,
  ];

  await maybeAddArtifact('Login screenshot', '01-login.png');
  await maybeAddArtifact('Signup email screenshot', '02-signup.png');
  await maybeAddArtifact('Signup password screenshot', '03-signup-password.png');
  await maybeAddArtifact('Nickname screenshot', '04-nickname.png');
  await maybeAddArtifact('Intro screenshot', '05-intro.png');
  await maybeAddArtifact('Location screenshot', '06-location.png');
  await maybeAddArtifact('Photo intro screenshot', '07-photo-intro.png');
  await maybeAddArtifact('Photo upload screenshot', '08-photo-upload.png');
  await maybeAddArtifact('Notification screenshot', '09-notification.png');
  await maybeAddArtifact('Basic info screenshot', '10-basic-info.png');
  await maybeAddArtifact('Matching screenshot', '11-matching.png');
  await maybeAddArtifact('Welcome screenshot', '12-welcome.png');
  await maybeAddArtifact('Tabs screenshot', '13-tabs.png');
  summaryLines.push(...existingArtifactLines);

  if (stoppedAt) {
    summaryLines.push(`- Stopped at: ${stoppedAt}`);
  } else {
    await maybeAddArtifact('MY screenshot', '14-my.png');
    await maybeAddArtifact('My edit screenshot', '15-my-edit.png');
    await maybeAddArtifact('Updated MY screenshot', '16-my-updated.png');
    await maybeAddArtifact('Settings screenshot', '17-settings.png');
    await maybeAddArtifact('Likes received screenshot', '18-likes-received.png');
    await maybeAddArtifact('Likes sent screenshot', '19-likes-sent.png');
    summaryLines.push(...existingArtifactLines.splice(existingArtifactLines.length - 6));
  }

  await maybeAddArtifact('Final source', 'final-source.xml');
  summaryLines.push(...existingArtifactLines.splice(existingArtifactLines.length - 1));
  summaryLines.push('');

  const summary = summaryLines.join('\n');
  await writeFile(path.join(reportDir, 'summary.md'), summary);
  process.stdout.write(`${summary}\n`);
}

async function main() {
  await mkdir(reportDir, { recursive: true });

  const signupSuffix = timestamp.replace(/[^0-9]/g, '').slice(-8);
  const signupEmail = `qa-${signupSuffix}@example.com`;
  const signupNickname = `가입${signupSuffix}`;
  const profileNickname = `프로필${signupSuffix}`;
  const notes = [];

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
    capabilities: {
      alwaysMatch: capabilities,
    },
  });

  const sessionId = sessionResponse.value.sessionId || sessionResponse.sessionId;
  let currentPhase = 'session-start';
  let lastSourceHint = '';
  const rememberSource = async () => {
    const source = await getSource(sessionId);
    lastSourceHint = source.slice(0, 2000);
    return source;
  };

  try {
    const initialAlert = await dismissAlert(sessionId, 'dismiss');
    if (initialAlert) {
      notes.push(`dismissed-startup-alert:${initialAlert}`);
    }

    currentPhase = 'ensure-signup-start';
    const signupStart = await ensureSignupStart(sessionId);
    lastSourceHint = signupStart.source.slice(0, 2000);
    currentPhase = signupStart.stage;

    if (signupStart.stage === 'signup') {
      await captureScreenshot(sessionId, '01-login.png');
      currentPhase = 'signup-email';
      await waitForSourceText(sessionId, ['이메일 주소를', '다음']);
      await captureScreenshot(sessionId, '02-signup.png');

      const signupEmailInput =
        (await findElement(sessionId, 'accessibility id', 'signup-email-input')) ||
        (await waitForElement(sessionId, 'class name', 'XCUIElementTypeTextField', 10000));
      await typeIntoElement(sessionId, signupEmailInput, signupEmail);
      await dismissKeyboard(sessionId);
      await tapTestIdOrLabel(sessionId, 'signup-primary-button', '다음', 10000);
      await sleep(1200);
      await captureScreenshot(sessionId, '02-after-email-next.png');
      await captureSource(sessionId, '02-after-email-next.xml');

      currentPhase = 'signup-password';
    } else {
      notes.push(`resumed-onboarding-at:${signupStart.stage}`);
    }

    if (currentPhase === 'signup-password') {
      await waitForSourceText(sessionId, ['비밀번호를', '가입하기']);
      await captureScreenshot(sessionId, '03-signup-password.png');

      const signupPasswordInput =
        (await findElement(sessionId, 'accessibility id', 'signup-password-input')) ||
        (await waitForElement(sessionId, 'class name', 'XCUIElementTypeSecureTextField', 10000));
      await typeIntoSecureElement(sessionId, signupPasswordInput, 'password123');
      await dismissKeyboard(sessionId);
      const signupButton =
        (await findElement(sessionId, 'accessibility id', 'signup-primary-button')) ||
        (await findElement(sessionId, 'accessibility id', '가입하기'));
      if (signupButton) {
        await tapElementCenter(sessionId, signupButton);
      } else {
        await tapLabel(sessionId, '가입하기');
      }

      currentPhase = 'nickname';
      await waitForSourceText(sessionId, ['프로필을 만들어볼까요.', '당신의 이름은?']);
    }

    if (currentPhase === 'nickname') {
      await captureScreenshot(sessionId, '04-nickname.png');

      const nicknameInput = await waitForElement(
        sessionId,
        'accessibility id',
        'onboarding-nickname-input',
      );
      await typeIntoElement(sessionId, nicknameInput, profileNickname);
      await dismissKeyboard(sessionId);
      await tapTestId(sessionId, 'onboarding-primary-button');

      currentPhase = 'intro';
    }

    if (currentPhase === 'intro') {
      await waitForSourceText(sessionId, ['관심사 기반 매칭과', '실시간 채팅 지원']);
      await captureScreenshot(sessionId, '05-intro.png');
      await tapTestId(sessionId, 'onboarding-primary-button');

      currentPhase = 'location';
    }

    if (currentPhase === 'location') {
      await waitForSourceText(sessionId, ['정확한 매칭을 위해', '위치 정보가 필요해요'], 25000);
      await captureScreenshot(sessionId, '06-location.png');
      await tapTestId(sessionId, 'onboarding-primary-button');
      try {
        const locationAlert = await dismissAlert(sessionId, 'accept');
        if (locationAlert) {
          notes.push(`accepted-location-alert:${locationAlert}`);
        }
      } catch {
        // Location prompt may be absent if previously decided.
      }

      currentPhase = 'photo-intro';
    }

    if (currentPhase === 'photo-intro') {
      await waitForSourceText(sessionId, ['프로필 사진 등록을 위해', '카메라 접근이 필요해요'], 25000);
      await captureScreenshot(sessionId, '07-photo-intro.png');
      await tapTestId(sessionId, 'onboarding-primary-button');

      currentPhase = 'photo-upload';
    }

    if (currentPhase === 'photo-upload') {
      await waitForSourceText(sessionId, ['사진을 업로드 해보세요!', '프로필 사진'], 25000);
      await captureScreenshot(sessionId, '08-photo-upload.png');
      const pickerOpenPath = await openLibraryPickerFromUploadStep(sessionId, 25000);
      notes.push(`opened-photo-picker:${pickerOpenPath}`);

      try {
        const libraryAlert = await dismissAlert(sessionId, 'accept');
        if (libraryAlert) {
          notes.push(`accepted-photo-library-alert:${libraryAlert}`);
        }
      } catch {
        // Photo library prompt may be absent if previously decided.
      }

      currentPhase = 'photo-picker';
      const pickerConfirm = await selectPhotoFromPicker(sessionId, 25000);
      notes.push(`confirmed-photo-picker:${pickerConfirm}`);
      currentPhase = 'photo-crop-confirm';
      const cropAction = await waitForAnyElement(
        sessionId,
        [
          ['accessibility id', 'onboarding-photo-confirm-primary'],
          ['accessibility id', 'onboarding-photo-confirm'],
        ],
        25000,
      );
      if (cropAction.value === 'onboarding-photo-confirm-primary') {
        await tapElementCenter(sessionId, cropAction.element).catch(() => undefined);
      } else {
        await tapElementCenter(sessionId, cropAction.element).catch(() => undefined);
        await clickSimulatorViewportRelative(0.916, 0.03);
      }
      await waitForSourceText(sessionId, ['사진을 업로드 해보세요!', '프로필 사진'], 25000);
      await tapTestId(sessionId, 'onboarding-primary-button');

      currentPhase = 'notification';
    }

    if (currentPhase === 'notification') {
      await waitForSourceText(sessionId, ['매칭 알림을 놓치지 마세요!', '다음'], 25000);
      await captureScreenshot(sessionId, '09-notification.png');
      await tapTestId(sessionId, 'onboarding-primary-button');

      try {
        const notificationAlert = await dismissAlert(sessionId, 'accept');
        if (notificationAlert) {
          notes.push(`accepted-notification-alert:${notificationAlert}`);
        }
      } catch {
        // Notification prompt may be absent if previously decided.
      }

      currentPhase = 'basic-info';
    }

    if (currentPhase === 'basic-info') {
      await waitForSourceText(sessionId, ['필수 정보를 알려주세요!', '생년월일'], 25000);
      await captureScreenshot(sessionId, '10-basic-info.png');
      await tapTestId(sessionId, 'onboarding-gender-female');
      await tapTestId(sessionId, 'onboarding-birthYear-button');
      await selectVisiblePickerOption(
        sessionId,
        'onboarding-birthYear-option-',
        'onboarding-birthYear-option-1997',
        '1997년',
      );
      await tapTestId(sessionId, 'onboarding-birthMonth-button');
      await selectVisiblePickerOption(
        sessionId,
        'onboarding-birthMonth-option-',
        'onboarding-birthMonth-option-10',
        '10월',
      );
      await tapTestId(sessionId, 'onboarding-birthDay-button');
      await selectVisiblePickerOption(
        sessionId,
        'onboarding-birthDay-option-',
        'onboarding-birthDay-option-24',
        '24일',
      );
      await tapTestId(sessionId, 'onboarding-primary-button');

      currentPhase = 'matching';
    }

    if (currentPhase === 'matching') {
      await waitForSourceText(sessionId, ['나를 표현하고 매칭율을', '어떤 일을 하고 계신가요?'], 25000);
      await captureScreenshot(sessionId, '11-matching.png');
      await tapLabel(sessionId, '직장인').catch(() => undefined);
      await tapLabel(sessionId, '카페').catch(() => undefined);
      await tapLabel(sessionId, '직관적').catch(() => undefined);
      await tapLabel(sessionId, '와인').catch(() => undefined);
      await tapTestId(sessionId, 'onboarding-primary-button');

      currentPhase = 'welcome';
    }

    if (currentPhase === 'welcome') {
      await waitForSourceText(sessionId, ['축하합니다!', '시작하기'], 25000);
      await captureScreenshot(sessionId, '12-welcome.png');
      await tapTestId(sessionId, 'onboarding-start-button');
    }

    const editedNickname = `${profileNickname}수정`;

    currentPhase = 'tabs';
    const finalSource = await waitForSourceText(sessionId, ['미팅', '채팅', 'MY'], 25000);
    await writeFile(path.join(reportDir, 'source.xml'), finalSource);
    await captureScreenshot(sessionId, '13-tabs.png');
    await captureSource(sessionId, 'final-source.xml', { assertWarningFree: true });
    await writeFile(path.join(reportDir, 'session.json'), JSON.stringify(sessionResponse, null, 2));

    if (stopAfter === 'tabs' || stopAfter === 'lightning') {
      await writeSuccessSummary({
        reportDir,
        appiumServerUrl,
        sessionId,
        bundleId,
        deviceName,
        platformVersion,
        signupEmail,
        signupNickname,
        profileNickname,
        notes,
        stoppedAt: 'tabs',
      });
      return;
    }

    await tapLabel(sessionId, 'MY').catch(() => undefined);
    await waitForAnyElement(
      sessionId,
      [
        ['accessibility id', 'settings-button'],
        ['accessibility id', 'my-edit-button'],
        ['accessibility id', 'my-preview-button'],
      ],
      6000,
    ).catch(async () => {
      notes.push(`my-home-recover:deeplink:${appScheme}:///my`);
      await openSimulatorUrl(`${appScheme}:///my`);
      await waitForAnyElement(
        sessionId,
        [
          ['accessibility id', 'settings-button'],
          ['accessibility id', 'my-edit-button'],
          ['accessibility id', 'my-preview-button'],
        ],
        25000,
      );
    });
    await captureScreenshot(sessionId, '14-my.png');

    await tapTestIdOrLabel(sessionId, 'my-edit-button', '수정하기', 15000).catch(async () => {
      await openSimulatorUrl(`${appScheme}:///my-edit`);
    });
    await waitForAnyElement(
      sessionId,
      [
        ['accessibility id', 'my-edit-submit-button'],
        ['accessibility id', 'my-edit-close-button'],
      ],
      25000,
    );
    await captureScreenshot(sessionId, '15-my-edit.png');

    const editFields = await findElements(sessionId, 'class name', 'XCUIElementTypeTextField');
    if (editFields.length < 1) {
      throw new Error('My edit nickname input is not ready');
    }

    await typeIntoElement(sessionId, editFields[0], editedNickname);
    await dismissKeyboard(sessionId);
    await tapTestIdOrLabel(sessionId, 'my-edit-submit-button', '수정하기', 15000);

    await waitForAnyElement(
      sessionId,
      [
        ['accessibility id', 'settings-button'],
        ['accessibility id', 'my-edit-button'],
        ['accessibility id', 'my-preview-button'],
      ],
      25000,
    );
    const updatedMySource = await getSource(sessionId);
    await writeFile(path.join(reportDir, 'my-source.xml'), updatedMySource);
    await captureScreenshot(sessionId, '16-my-updated.png');
    await tapTestIdOrLabel(sessionId, 'settings-button', 'settings-button', 15000).catch(async () => {
      await openSimulatorUrl(`${appScheme}:///settings`);
    });
    await waitForAnyElement(
      sessionId,
      [
        ['accessibility id', 'settings-back-button'],
      ],
      25000,
    );
    const settingsSource = await getSource(sessionId);
    await writeFile(path.join(reportDir, 'settings-source.xml'), settingsSource);
    await captureScreenshot(sessionId, '17-settings.png');
    await tapTestIdOrLabel(sessionId, 'settings-back-button', 'settings-back-button', 15000);
    await waitForAnyElement(
      sessionId,
      [
        ['accessibility id', 'settings-button'],
        ['accessibility id', 'my-edit-button'],
      ],
      25000,
    );
    await captureSource(sessionId, 'final-source.xml', { assertWarningFree: true });
    await writeFile(path.join(reportDir, 'session.json'), JSON.stringify(sessionResponse, null, 2));

    try {
      await openSimulatorUrl(`${appScheme}:///likes?tab=received&source=my`).catch(() => undefined);
      const receivedLikesEvidence = await waitForAnyElement(
        sessionId,
        [
          ['accessibility id', 'likes-tab-received'],
          ['-ios predicate string', `name CONTAINS[c] '받은 Like' OR label CONTAINS[c] '받은 Like' OR value CONTAINS[c] '받은 Like'`],
        ],
        12000,
      );
      notes.push(`likes-received-capture:${receivedLikesEvidence.using}:${receivedLikesEvidence.value}`);
      await captureScreenshot(sessionId, '18-likes-received.png');
      await tapTestIdOrLabel(sessionId, 'likes-tab-sent', '보낸 Like', 12000);
      const sentLikesEvidence = await waitForAnyElement(
        sessionId,
        [
          ['accessibility id', 'likes-tab-sent'],
          ['-ios predicate string', `name CONTAINS[c] '보낸 Like' OR label CONTAINS[c] '보낸 Like' OR value CONTAINS[c] '보낸 Like'`],
        ],
        12000,
      );
      notes.push(`likes-sent-capture:${sentLikesEvidence.using}:${sentLikesEvidence.value}`);
      await captureScreenshot(sessionId, '19-likes-sent.png');
    } catch (error) {
      notes.push(`likes-extension-skipped:${error instanceof Error ? error.message : String(error)}`);
    }

    await writeSuccessSummary({
      reportDir,
      appiumServerUrl,
      sessionId,
      bundleId,
      deviceName,
      platformVersion,
      signupEmail,
      signupNickname,
      profileNickname,
      notes,
    });
  } catch (error) {
    const failureAlertText = await getAlertText(sessionId).catch(() => null);
    const failureScreenshot = await captureScreenshot(sessionId, 'failure.png').catch(() => null);
    const failureSource = await captureSource(sessionId, 'failure-source.xml').catch(() => null);
    const latestSource = await rememberSource().catch(() => null);
    if (latestSource) {
      lastSourceHint = latestSource.slice(0, 2000);
    }
    const failureSummary = [
      '# iOS Appium Onboarding Failure',
      '',
      `- Error: ${error instanceof Error ? error.message : String(error)}`,
      `- Phase: ${currentPhase}`,
      `- Alert text: ${failureAlertText ?? 'none'}`,
      `- Failure screenshot: ${failureScreenshot ?? 'none'}`,
      `- Failure source: ${failureSource ?? 'none'}`,
      `- Source hint: ${lastSourceHint ? lastSourceHint.replaceAll('\n', ' ') : 'none'}`,
      '',
    ].join('\n');
    await writeFile(path.join(reportDir, 'summary.md'), failureSummary);
    throw error;
  } finally {
    await request('DELETE', `/session/${sessionId}`).catch(() => undefined);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
