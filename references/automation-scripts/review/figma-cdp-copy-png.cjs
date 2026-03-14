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

async function maybeClick(page, locator) {
  try {
    await locator.click({ timeout: 1500 });
    await page.waitForTimeout(250);
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
  await maybeClick(page, page.getByLabel("닫기").first());
  await maybeClick(page, page.getByTestId("close-button"));
}

async function focusSelection(page) {
  const selectedInput = page.locator('input[aria*="선택됨"]').first();
  if (await selectedInput.count()) {
    await selectedInput.click({ timeout: 3000 }).catch(() => {});
    await page.waitForTimeout(250);
    return "selected-input";
  }

  const editor = page.getByLabel("편집기").first();
  const box = await editor.boundingBox().catch(() => null);
  if (box) {
    await page.mouse.click(Math.floor(box.x + box.width / 2), Math.floor(box.y + box.height / 2));
    await page.waitForTimeout(250);
    return "editor-center";
  }

  await page.mouse.click(900, 500);
  await page.waitForTimeout(250);
  return "fallback-center";
}

async function main() {
  const cdpUrl = process.env.ZZIRIT_FIGMA_CDP_URL || "http://127.0.0.1:9222";
  const fileKey = process.env.FIGMA_FILE_KEY || "ZhysC3KZLAmKerfHTpg3G6";
  const nodeId = process.env.FIGMA_NODE_ID || "";
  const outputPath = process.env.FIGMA_OUTPUT_PATH || "";
  const debugPath = process.env.ZZIRIT_FIGMA_DEBUG_PATH || "";
  const mode = process.env.ZZIRIT_FIGMA_COPY_MODE || "shortcut";

  if (!nodeId || !outputPath) {
    throw new Error("FIGMA_NODE_ID and FIGMA_OUTPUT_PATH are required");
  }

  const moduleDir = findPlaywrightModuleDir();
  if (!moduleDir) {
    throw new Error("Could not locate playwright module under ~/.npm/_npx");
  }
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  if (debugPath) {
    fs.mkdirSync(path.dirname(debugPath), { recursive: true });
  }

  const { chromium } = require(moduleDir);
  const browser = await chromium.connectOverCDP(cdpUrl);
  const context = browser.contexts()[0];
  if (!context) {
    throw new Error("No browser context available over CDP");
  }
  const page = context.pages()[0] || (await context.newPage());
  const safeNodeId = nodeId.replace(":", "-");
  const targetUrl = `https://www.figma.com/design/${fileKey}/ZZIRIT---Master-Design--Copy-?node-id=${safeNodeId}`;

  await page.bringToFront();
  await page.goto(targetUrl, { waitUntil: "domcontentloaded", timeout: 120000 });
  await page.waitForTimeout(6000);
  await dismissNoise(page);
  const focusSource = await focusSelection(page);
  await page.waitForTimeout(500);

  if (mode === "context-menu") {
    await page.mouse.click(900, 500, { button: "right" });
    await page.waitForTimeout(1000);
    const item = page.getByText(/Copy as PNG|PNG로 복사/, { exact: false }).first();
    if (!(await maybeClick(page, item))) {
      throw new Error("Context menu item 'Copy as PNG' not found");
    }
  } else {
    await page.keyboard.press("Meta+Shift+C").catch(() => {});
    await page.waitForTimeout(1200);
    let info = readClipboardInfo();
    if (!info.includes("PNG")) {
      await page.keyboard.press("Control+Shift+C").catch(() => {});
      await page.waitForTimeout(1200);
      info = readClipboardInfo();
    }
  }

  const clipboardInfo = readClipboardInfo();
  if (!clipboardInfo.includes("PNG")) {
    if (debugPath) {
      await page.screenshot({ path: debugPath, fullPage: false }).catch(() => {});
    }
    throw new Error(`Clipboard does not contain PNG data: ${clipboardInfo}`);
  }

  saveClipboardPng(outputPath);

  if (debugPath) {
    await page.screenshot({ path: debugPath, fullPage: false }).catch(() => {});
  }

  console.log(
    JSON.stringify(
      {
        status: "copied",
        nodeId,
        outputPath,
        debugPath,
        clipboardInfo,
        focusSource,
        mode,
      },
      null,
      2,
    ),
  );
  await browser.close();
}

main().catch((error) => {
  console.error(String(error?.stack || error));
  process.exit(1);
});
