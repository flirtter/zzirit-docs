import { Buffer } from 'node:buffer';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const projectRoot = process.env.ZZIRIT_IOS_PROJECT_ROOT || path.resolve(process.cwd());
const reportRoot =
  process.env.ZZIRIT_APPIUM_REPORT_DIR || path.join(projectRoot, 'artifacts', 'appium');
const timestamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..+/, '').replace('T', '-');
const reportDir = path.join(reportRoot, timestamp);
const appiumServerUrl = process.env.ZZIRIT_APPIUM_SERVER_URL || 'http://127.0.0.1:4725/wd/hub';
const bundleId = process.env.ZZIRIT_IOS_APP_BUNDLE_ID || 'com.flirtter.zziritApp';
const deviceName = process.env.ZZIRIT_IOS_SIMULATOR_NAME || 'iPhone 17 Pro';
const platformVersion = process.env.ZZIRIT_IOS_PLATFORM_VERSION || '26.2';
const udid = process.env.ZZIRIT_IOS_SIMULATOR_UDID;

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

async function clickElement(sessionId, element) {
  const elementId = element.ELEMENT || element['element-6066-11e4-a52e-4f735466cecf'];
  if (!elementId) {
    return false;
  }

  await request('POST', `/session/${sessionId}/element/${elementId}/click`, {});
  return true;
}

async function dismissStartupAlert(sessionId) {
  try {
    const alertText = await request('GET', `/session/${sessionId}/alert/text`);
    await request('POST', `/session/${sessionId}/alert/dismiss`, {});
    await sleep(1500);
    return `webdriver-alert:${alertText.value}`;
  } catch (error) {
    if (!(error instanceof Error) || !error.message.includes('no such alert')) {
      throw error;
    }
  }

  const cancelSelectors = [
    "name == '취소'",
    "label == '취소'",
    "name == 'Cancel'",
    "label == 'Cancel'",
    "name == 'Not Now'",
    "label == 'Not Now'",
  ];

  for (const selector of cancelSelectors) {
    const element = await findElement(sessionId, '-ios predicate string', selector);
    if (!element) {
      continue;
    }

    const clicked = await clickElement(sessionId, element);
    if (clicked) {
      await sleep(1500);
      return selector;
    }
  }

  return null;
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
    capabilities: {
      alwaysMatch: capabilities,
    },
  });

  const sessionId = sessionResponse.value.sessionId || sessionResponse.sessionId;

  try {
    const dismissedAlert = await dismissStartupAlert(sessionId);

    const [contexts, source, screenshot] = await Promise.all([
      request('GET', `/session/${sessionId}/contexts`),
      request('GET', `/session/${sessionId}/source`),
      request('GET', `/session/${sessionId}/screenshot`),
    ]);

    const sourceXml = source.value;
    const screenshotBase64 = screenshot.value;

    await writeFile(path.join(reportDir, 'session.json'), JSON.stringify(sessionResponse, null, 2));
    await writeFile(path.join(reportDir, 'contexts.json'), JSON.stringify(contexts, null, 2));
    await writeFile(path.join(reportDir, 'source.xml'), sourceXml);
    await writeFile(path.join(reportDir, 'screenshot.png'), Buffer.from(screenshotBase64, 'base64'));

    const redboxPatterns = [
      'redbox-error',
      'Unable to resolve module',
      'Invariant Violation',
      'TypeError:',
      'ReferenceError:',
    ];
    const redboxHits = redboxPatterns.filter((pattern) => sourceXml.includes(pattern));

    const summary = [
      '# iOS Appium Smoke',
      '',
      `- Server: ${appiumServerUrl}`,
      `- Session: ${sessionId}`,
      `- Bundle ID: ${bundleId}`,
      `- Device: ${deviceName}`,
      `- Platform: ${platformVersion}`,
      `- Dismissed alert: ${dismissedAlert ?? 'none'}`,
      `- Contexts: ${contexts.value.join(', ')}`,
      `- Source: ${path.join(reportDir, 'source.xml')}`,
      `- Screenshot: ${path.join(reportDir, 'screenshot.png')}`,
      `- Redbox hits: ${redboxHits.length ? redboxHits.join(', ') : 'none'}`,
      '',
    ].join('\n');

    await writeFile(path.join(reportDir, 'summary.md'), summary);

    process.stdout.write(`${summary}\n`);

    if (redboxHits.length > 0) {
      process.exitCode = 1;
    }
  } finally {
    await request('DELETE', `/session/${sessionId}`).catch(() => undefined);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
