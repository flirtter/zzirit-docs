#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

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
    return { width: 1800, height: 1200 };
  }
  const parts = raw.split(",").map((item) => Number.parseInt(item.trim(), 10));
  if (parts.length !== 2 || parts.some((item) => !Number.isFinite(item) || item <= 0)) {
    return { width: 1800, height: 1200 };
  }
  return { width: parts[0], height: parts[1] };
}

async function maybeClick(page, locator) {
  try {
    await locator.click({ timeout: 1500 });
    await page.waitForTimeout(300);
    return true;
  } catch {
    return false;
  }
}

async function dismissNoise(page) {
  await maybeClick(page, page.getByTestId("cookie-opt-out-button"));
  await maybeClick(page, page.getByTestId("cookie-dismiss-button"));
  await maybeClick(page, page.getByText("쿠키 허용 안 함", { exact: true }));
  await maybeClick(page, page.getByText("모든 쿠키 허용", { exact: true }));
  await maybeClick(page, page.getByText("Accept all cookies", { exact: true }));
  await maybeClick(page, page.getByLabel("닫기").first());
  await maybeClick(page, page.getByTestId("close-button"));
}

function readClipboardInfo() {
  try {
    return execFileSync("osascript", ["-e", "clipboard info"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
  } catch (error) {
    return String(error.stderr || error.message || error);
  }
}

async function focusEditorCanvas(page, viewport) {
  const editor = page.getByLabel("편집기").first();
  if (await editor.count()) {
    const box = await editor.boundingBox().catch(() => null);
    if (box) {
      await page.mouse.click(
        Math.floor(box.x + Math.min(box.width * 0.5, viewport.width * 0.5)),
        Math.floor(box.y + Math.min(box.height * 0.5, viewport.height * 0.45)),
      );
      await page.waitForTimeout(300);
      return;
    }
  }
  await page.mouse.click(Math.floor(viewport.width / 2), Math.floor(viewport.height / 2));
  await page.waitForTimeout(300);
}

function saveClipboardPng(outputPath) {
  const escapedPath = outputPath.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  const script = `
set outFile to POSIX file "${escapedPath}"
set pngData to the clipboard as «class PNGf»
set fileRef to open for access outFile with write permission
try
  set eof of fileRef to 0
  write pngData to fileRef
  close access fileRef
on error errMsg number errNum
  try
    close access fileRef
  end try
  error errMsg number errNum
end try
`;

  execFileSync("osascript", ["-e", script], {
    stdio: ["ignore", "pipe", "pipe"],
  });
}

async function main() {
  const url = process.env.ZZIRIT_PLAYWRIGHT_URL || "";
  const outputPath = process.env.ZZIRIT_PLAYWRIGHT_OUTPUT_PATH || "";
  const userDataDir = process.env.ZZIRIT_PLAYWRIGHT_USER_DATA_DIR || "";
  const storageState = process.env.ZZIRIT_PLAYWRIGHT_STORAGE_STATE || "";
  const channel = process.env.ZZIRIT_PLAYWRIGHT_CHANNEL || "chrome";
  const deviceName = process.env.ZZIRIT_PLAYWRIGHT_DEVICE || "Desktop Chrome HiDPI";
  const timeoutMs = Number.parseInt(process.env.ZZIRIT_PLAYWRIGHT_TIMEOUT_MS || "90000", 10);
  const waitMs = Number.parseInt(process.env.ZZIRIT_PLAYWRIGHT_WAIT_MS || "10000", 10);
  const viewport = parseViewport(process.env.ZZIRIT_PLAYWRIGHT_VIEWPORT || "");
  const headless = process.env.ZZIRIT_PLAYWRIGHT_HEADLESS === "1";
  const debugShot = process.env.ZZIRIT_PLAYWRIGHT_DEBUG_SHOT || "";
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
  if (debugShot) {
    fs.mkdirSync(path.dirname(debugShot), { recursive: true });
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
        headless,
        args: [
          "--hide-crash-restore-bubble",
          "--disable-session-crashed-bubble",
          "--disable-features=Translate,OptimizationGuideModelDownloading",
        ],
      });
    } else {
      browser = await chromium.launch({
        channel,
        headless,
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

    const signUpDialog = page.getByText(/Figma 가입하기|Sign up for Figma/i).first();
    if (await signUpDialog.isVisible().catch(() => false)) {
      throw new Error("Figma signup modal is blocking copy-as-PNG actions");
    }

    await focusEditorCanvas(page, viewport);

    await page.keyboard.press("Shift+Digit2").catch(() => {});
    await page.waitForTimeout(800);
    await page.keyboard.press("Meta+Shift+C");
    await page.waitForTimeout(2000);

    let clipboardInfo = readClipboardInfo();
    if (!clipboardInfo.includes("PNG")) {
      await focusEditorCanvas(page, viewport);
      await page.keyboard.press("Control+Shift+C").catch(() => {});
      await page.waitForTimeout(2000);
      clipboardInfo = readClipboardInfo();
    }
    if (!clipboardInfo.includes("PNG")) {
      if (debugShot) {
        await page.screenshot({ path: debugShot, fullPage: false }).catch(() => {});
      }
      throw new Error(`Clipboard does not contain PNG data: ${clipboardInfo}`);
    }

    saveClipboardPng(outputPath);

    if (debugShot) {
      await page.screenshot({ path: debugShot, fullPage: false }).catch(() => {});
    }
    console.log(JSON.stringify({ status: "copied", outputPath, clipboardInfo }, null, 2));
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
