import { Buffer } from 'node:buffer';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const projectRoot = process.env.ZZIRIT_IOS_PROJECT_ROOT || path.resolve(process.cwd());
const reportRoot =
  process.env.ZZIRIT_APPIUM_REPORT_DIR || path.join(projectRoot, 'artifacts', 'appium-seeded-login');
const timestamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, '').replace('T', '-');
const reportDir = path.join(reportRoot, timestamp);
const appiumServerUrl = process.env.ZZIRIT_APPIUM_SERVER_URL || 'http://127.0.0.1:4725/wd/hub';
const bundleId = process.env.ZZIRIT_IOS_APP_BUNDLE_ID || 'com.flirtter.zziritApp';
const deviceName = process.env.ZZIRIT_IOS_SIMULATOR_NAME || 'iPhone 17 Pro';
const platformVersion = process.env.ZZIRIT_IOS_PLATFORM_VERSION || '26.2';
const udid = process.env.ZZIRIT_IOS_SIMULATOR_UDID;
const reviewEmail = process.env.ZZIRIT_REVIEW_EMAIL || 'review.my@zzirit.app';
const reviewPassword = process.env.ZZIRIT_REVIEW_PASSWORD || 'Review123!';

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
  const source = await request('GET', `/session/${sessionId}/source`);
  return source.value;
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

async function clickElement(sessionId, element) {
  const elementId = getElementId(element);
  if (!elementId) {
    throw new Error('Missing element id');
  }
  await request('POST', `/session/${sessionId}/element/${elementId}/click`, {});
  await sleep(500);
}

async function typeIntoElement(sessionId, element, text) {
  const elementId = getElementId(element);
  if (!elementId) {
    throw new Error('Missing element id');
  }
  await clickElement(sessionId, element).catch(() => undefined);
  await request('POST', `/session/${sessionId}/element/${elementId}/clear`, {}).catch(() => undefined);
  await request('POST', `/session/${sessionId}/element/${elementId}/value`, {
    text,
    value: text.split(''),
  });
  await sleep(400);
}

async function dismissKeyboard(sessionId) {
  await request('POST', `/session/${sessionId}/appium/device/hide_keyboard`, {}).catch(() => undefined);
  await sleep(400);
}

async function dismissStartupAlert(sessionId) {
  try {
    await request('POST', `/session/${sessionId}/alert/dismiss`, {});
    await sleep(1000);
    return true;
  } catch {
    return false;
  }
}

async function waitForLoginInputs(sessionId, timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const emailFields = await findElements(sessionId, 'class name', 'XCUIElementTypeTextField');
    const passwordFields = await findElements(sessionId, 'class name', 'XCUIElementTypeSecureTextField');
    if (emailFields.length > 0 && passwordFields.length > 0) {
      return {
        emailField: emailFields[0],
        passwordField: passwordFields[0],
      };
    }
    await sleep(500);
  }
  throw new Error('Timed out waiting for login inputs');
}

async function tapLabel(sessionId, label) {
  const predicate = `name == '${label}' OR label == '${label}' OR value == '${label}'`;
  const element =
    (await findElement(sessionId, 'accessibility id', label)) ||
    (await findElement(sessionId, '-ios predicate string', predicate));

  if (!element) {
    throw new Error(`Could not find label: ${label}`);
  }

  await clickElement(sessionId, element);
}

async function waitForSourceText(sessionId, texts, timeoutMs = 20000) {
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

async function captureScreenshot(sessionId, filename) {
  const response = await request('GET', `/session/${sessionId}/screenshot`);
  const filePath = path.join(reportDir, filename);
  await writeFile(filePath, Buffer.from(response.value, 'base64'));
  return filePath;
}

async function main() {
  await mkdir(reportDir, { recursive: true });

  const capabilities = {
    platformName: 'iOS',
    'appium:automationName': 'XCUITest',
    'appium:deviceName': deviceName,
    'appium:platformVersion': platformVersion,
    'appium:bundleId': bundleId,
    'appium:noReset': true,
    'appium:newCommandTimeout': 120,
  };

  if (udid) {
    capabilities['appium:udid'] = udid;
  }

  const sessionResponse = await request('POST', '/session', {
    capabilities: { alwaysMatch: capabilities },
  });
  const sessionId = sessionResponse.value.sessionId || sessionResponse.sessionId;

  try {
    await dismissStartupAlert(sessionId);

    const initialSource = await getSource(sessionId);
    if (initialSource.includes('미팅') && initialSource.includes('채팅') && initialSource.includes('MY')) {
      await captureScreenshot(sessionId, 'already-authenticated.png');
      await writeFile(
        path.join(reportDir, 'summary.md'),
        ['# iOS Seeded Login', '', '- state: already-authenticated', `- report: ${reportDir}`].join('\n'),
      );
      process.stdout.write(`${reportDir}\n`);
      return;
    }

    const { emailField, passwordField } = await waitForLoginInputs(sessionId, 25000);
    await captureScreenshot(sessionId, '01-login.png');

    await typeIntoElement(sessionId, emailField, reviewEmail);
    await typeIntoElement(sessionId, passwordField, reviewPassword);
    await dismissKeyboard(sessionId);
    await tapLabel(sessionId, '다음');

    const finalSource = await waitForSourceText(sessionId, ['미팅', '채팅', 'MY'], 25000);
    await captureScreenshot(sessionId, '02-tabs.png');
    await writeFile(path.join(reportDir, 'source.xml'), finalSource);
    await writeFile(
      path.join(reportDir, 'summary.md'),
      [
        '# iOS Seeded Login',
        '',
        '- state: logged-in',
        `- session: ${sessionId}`,
        `- report: ${reportDir}`,
        `- email: ${reviewEmail}`,
      ].join('\n'),
    );
    process.stdout.write(`${reportDir}\n`);
  } finally {
    await request('DELETE', `/session/${sessionId}`).catch(() => undefined);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
