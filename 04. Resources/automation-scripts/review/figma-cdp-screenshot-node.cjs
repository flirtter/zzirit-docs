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

async function main() {
  const cdpUrl = process.env.ZZIRIT_FIGMA_CDP_URL || "http://127.0.0.1:9222";
  const fileKey = process.env.FIGMA_FILE_KEY || "ZhysC3KZLAmKerfHTpg3G6";
  const nodeId = process.env.FIGMA_NODE_ID || "";
  const outputPath = process.env.FIGMA_OUTPUT_PATH || "";

  if (!nodeId || !outputPath) {
    throw new Error("FIGMA_NODE_ID and FIGMA_OUTPUT_PATH are required");
  }

  const moduleDir = findPlaywrightModuleDir();
  if (!moduleDir) {
    throw new Error("Could not locate playwright module under ~/.npm/_npx");
  }

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  const { chromium } = require(moduleDir);
  const browser = await chromium.connectOverCDP(cdpUrl);
  const context = browser.contexts()[0];
  if (!context) {
    throw new Error("No browser context available over CDP");
  }
  const page = context.pages()[0] || (await context.newPage());
  const safeNodeId = encodeURIComponent(nodeId.replace(/:/g, "-"));
  const targetUrl = `https://www.figma.com/design/${fileKey}/ZZIRIT---Master-Design--Copy-?node-id=${safeNodeId}`;

  await page.bringToFront();
  await page.goto(targetUrl, { waitUntil: "domcontentloaded", timeout: 120000 });
  await page.waitForTimeout(6000);
  await dismissNoise(page);
  await page.keyboard.press("Shift+2").catch(() => {});
  await page.waitForTimeout(1200);
  await page.screenshot({ path: outputPath, fullPage: false });

  const bodyText = (await page.locator("body").innerText().catch(() => "")).replace(/\s+/g, " ");
  console.log(
    JSON.stringify(
      {
        status: "captured",
        outputPath,
        nodeId,
        signup: /Figma 가입하기|가입 계속|Google 계정으로 계속하기/.test(bodyText),
        restricted: /댓글 달기, 편집, 검사 등의 기능을 이용하려면 가입하세요/.test(bodyText),
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
