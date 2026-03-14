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

async function main() {
  const cdpUrl = process.env.ZZIRIT_FIGMA_CDP_URL || "http://127.0.0.1:9222";
  const moduleDir = findPlaywrightModuleDir();
  if (!moduleDir) {
    throw new Error("Could not locate playwright module under ~/.npm/_npx");
  }

  const { chromium } = require(moduleDir);
  const browser = await chromium.connectOverCDP(cdpUrl);
  const context = browser.contexts()[0];
  const pages = context ? context.pages() : [];
  const results = [];

  for (const page of pages) {
    const bodyText = (await page.locator("body").innerText().catch(() => "")).replace(/\s+/g, " ");
    results.push({
      url: page.url(),
      title: await page.title().catch(() => ""),
      signup: /Figma 가입하기|가입 계속|Google 계정으로 계속하기/.test(bodyText),
      restricted: /댓글 달기, 편집, 검사 등의 기능을 이용하려면 가입하세요/.test(bodyText),
      exportWord: /내보내기|Export/.test(bodyText),
    });
  }

  console.log(JSON.stringify(results, null, 2));
  await browser.close();
}

main().catch((error) => {
  console.error(String(error?.stack || error));
  process.exit(1);
});
