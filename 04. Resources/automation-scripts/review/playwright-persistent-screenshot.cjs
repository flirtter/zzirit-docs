#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");

function findPlaywrightModuleDir() {
  const explicit = process.env.ZZIRIT_PLAYWRIGHT_MODULE_DIR;
  if (explicit && fs.existsSync(explicit)) {
    return explicit;
  }

  const npxRoot = path.join(os.homedir(), ".npm", "_npx");
  if (!fs.existsSync(npxRoot)) {
    return "";
  }

  const candidates = [];
  for (const entry of fs.readdirSync(npxRoot, { withFileTypes: true })) {
    if (!entry.isDirectory()) {
      continue;
    }
    const moduleDir = path.join(npxRoot, entry.name, "node_modules", "playwright");
    if (!fs.existsSync(moduleDir)) {
      continue;
    }
    const stat = fs.statSync(moduleDir);
    candidates.push({ moduleDir, mtimeMs: stat.mtimeMs });
  }

  candidates.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return candidates[0]?.moduleDir ?? "";
}

function parseViewport(raw) {
  if (!raw) {
    return { width: 1440, height: 2400 };
  }
  const parts = raw.split(",").map((item) => Number.parseInt(item.trim(), 10));
  if (parts.length !== 2 || parts.some((item) => !Number.isFinite(item) || item <= 0)) {
    return { width: 1440, height: 2400 };
  }
  return { width: parts[0], height: parts[1] };
}

async function maybeClick(page, locatorText) {
  try {
    const locator = page.getByText(locatorText, { exact: true }).first();
    await locator.click({ timeout: 1500 });
    await page.waitForTimeout(300);
    return true;
  } catch {
    return false;
  }
}

async function dismissNoise(page) {
  await maybeClick(page, "모두 쿠키 허용");
  await maybeClick(page, "쿠키 허용 안 함");
  await maybeClick(page, "Accept all cookies");
  await maybeClick(page, "Reject all");

  try {
    await page.addStyleTag({
      content: `
        [class*="cookie"], [id*="cookie"] {
          display: none !important;
        }
      `,
    });
  } catch {}
}

async function main() {
  const url = process.env.ZZIRIT_PLAYWRIGHT_URL || "";
  const outputPath = process.env.ZZIRIT_PLAYWRIGHT_OUTPUT_PATH || "";
  const userDataDir = process.env.ZZIRIT_PLAYWRIGHT_USER_DATA_DIR || "";
  const storageState = process.env.ZZIRIT_PLAYWRIGHT_STORAGE_STATE || "";
  const saveStorage = process.env.ZZIRIT_PLAYWRIGHT_SAVE_STORAGE || "";
  const channel = process.env.ZZIRIT_PLAYWRIGHT_CHANNEL || "chrome";
  const deviceName = process.env.ZZIRIT_PLAYWRIGHT_DEVICE || "Desktop Chrome HiDPI";
  const timeoutMs = Number.parseInt(process.env.ZZIRIT_PLAYWRIGHT_TIMEOUT_MS || "90000", 10);
  const waitMs = Number.parseInt(process.env.ZZIRIT_PLAYWRIGHT_WAIT_MS || "8000", 10);
  const viewport = parseViewport(process.env.ZZIRIT_PLAYWRIGHT_VIEWPORT || "");
  const moduleDir = findPlaywrightModuleDir();

  if (!url || !outputPath) {
    throw new Error("ZZIRIT_PLAYWRIGHT_URL and ZZIRIT_PLAYWRIGHT_OUTPUT_PATH are required");
  }
  if (!moduleDir) {
    throw new Error("Could not locate playwright module under ~/.npm/_npx");
  }

  const playwright = require(moduleDir);
  const { chromium, devices } = playwright;
  const device = devices[deviceName] || {};

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  if (saveStorage) {
    fs.mkdirSync(path.dirname(saveStorage), { recursive: true });
  }

  const baseContextOptions = {
    ...device,
    viewport,
    locale: "ko-KR",
    timezoneId: "Asia/Seoul",
    ignoreHTTPSErrors: true,
  };

  let browser = null;
  let context = null;
  try {
    if (userDataDir) {
      fs.mkdirSync(userDataDir, { recursive: true });
      context = await chromium.launchPersistentContext(userDataDir, {
        ...baseContextOptions,
        channel,
        headless: true,
        args: [
          "--hide-crash-restore-bubble",
          "--disable-session-crashed-bubble",
          "--disable-features=Translate,OptimizationGuideModelDownloading",
        ],
      });
    } else {
      browser = await chromium.launch({
        channel,
        headless: true,
      });
      context = await browser.newContext({
        ...baseContextOptions,
        storageState: storageState || undefined,
      });
    }

    const page = context.pages()[0] || (await context.newPage());
    page.setDefaultNavigationTimeout(timeoutMs);
    page.setDefaultTimeout(timeoutMs);

    await page.goto(url, {
      waitUntil: "domcontentloaded",
      timeout: timeoutMs,
    });
    await page.waitForTimeout(waitMs);
    await dismissNoise(page);
    await page.screenshot({
      path: outputPath,
      fullPage: true,
    });

    if (saveStorage) {
      await context.storageState({ path: saveStorage });
    }
  } finally {
    if (context) {
      await context.close().catch(() => {});
    }
    if (browser) {
      await browser.close().catch(() => {});
    }
  }
}

main().catch((error) => {
  console.error(String(error?.stack || error));
  process.exit(1);
});
