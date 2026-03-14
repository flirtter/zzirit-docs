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

function nowIso() {
  return new Date().toISOString();
}

function writeJson(filePath, payload) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(payload, null, 2) + "\n");
}

function summarizeBodyText(bodyText) {
  return {
    hasSignupDialog: /Figma 가입하기|Sign up for Figma/i.test(bodyText),
    hasSignupPrompt: /가입 계속|Google 계정으로 계속하기|이메일로 계속하기/.test(bodyText),
    hasRestrictedPrompt: /댓글 달기, 편집, 검사 등의 기능을 이용하려면 가입하세요/.test(bodyText),
    hasExportWord: /내보내기|Export/.test(bodyText),
    hasCommentWord: /댓글/.test(bodyText),
  };
}

async function main() {
  const url = process.env.ZZIRIT_FIGMA_AUTH_URL || process.argv[2] || "";
  const profileDir = process.env.ZZIRIT_FIGMA_PLAYWRIGHT_USER_DATA_DIR || "";
  const storageStatePath = process.env.ZZIRIT_FIGMA_PLAYWRIGHT_STORAGE_STATE || "";
  const statusPath =
    process.env.ZZIRIT_FIGMA_AUTH_STATUS_PATH ||
    path.join(path.dirname(storageStatePath || profileDir || "."), "auth-status.json");
  const channel = process.env.ZZIRIT_FIGMA_PLAYWRIGHT_CHANNEL || "chrome";
  const pollMs = Number.parseInt(process.env.ZZIRIT_FIGMA_AUTH_POLL_MS || "5000", 10);

  if (!url || !profileDir || !storageStatePath) {
    throw new Error("ZZIRIT_FIGMA_AUTH_URL, ZZIRIT_FIGMA_PLAYWRIGHT_USER_DATA_DIR, and ZZIRIT_FIGMA_PLAYWRIGHT_STORAGE_STATE are required");
  }

  const moduleDir = findPlaywrightModuleDir();
  if (!moduleDir) {
    throw new Error("Could not locate playwright module under ~/.npm/_npx");
  }

  fs.mkdirSync(profileDir, { recursive: true });
  fs.mkdirSync(path.dirname(storageStatePath), { recursive: true });

  const playwright = require(moduleDir);
  const { chromium, devices } = playwright;

  const context = await chromium.launchPersistentContext(profileDir, {
    ...devices["Desktop Chrome HiDPI"],
    viewport: { width: 1600, height: 1100 },
    locale: "ko-KR",
    timezoneId: "Asia/Seoul",
    channel,
    headless: false,
    args: [
      "--hide-crash-restore-bubble",
      "--disable-session-crashed-bubble",
      "--disable-features=Translate,OptimizationGuideModelDownloading",
    ],
  });

  let shuttingDown = false;
  async function persistStatus(page, phase) {
    const bodyText = (await page.locator("body").innerText().catch(() => "")).replace(/\s+/g, " ");
    const cookies = await context.cookies("https://www.figma.com").catch(() => []);
    const summary = summarizeBodyText(bodyText);
    await context.storageState({ path: storageStatePath }).catch(() => {});
    writeJson(statusPath, {
      phase,
      updated_at: nowIso(),
      url: page.url(),
      title: await page.title().catch(() => ""),
      cookies: cookies.map((cookie) => ({
        name: cookie.name,
        domain: cookie.domain,
        expires: cookie.expires,
      })),
      summary,
    });
    console.log(
      JSON.stringify(
        {
          phase,
          updated_at: nowIso(),
          summary,
          storage_state: storageStatePath,
          status_path: statusPath,
        },
        null,
        2,
      ),
    );
  }

  async function shutdown() {
    if (shuttingDown) {
      return;
    }
    shuttingDown = true;
    try {
      const page = context.pages()[0];
      if (page) {
        await persistStatus(page, "shutdown");
      } else {
        await context.storageState({ path: storageStatePath }).catch(() => {});
      }
    } finally {
      await context.close().catch(() => {});
    }
  }

  process.on("SIGINT", () => {
    shutdown().finally(() => process.exit(0));
  });
  process.on("SIGTERM", () => {
    shutdown().finally(() => process.exit(0));
  });

  const page = context.pages()[0] || (await context.newPage());
  await page.goto(url, {
    waitUntil: "domcontentloaded",
    timeout: 120000,
  });
  await page.waitForTimeout(5000);
  await persistStatus(page, "opened");

  const timer = setInterval(async () => {
    const activePage = context.pages()[0];
    if (!activePage || activePage.isClosed()) {
      clearInterval(timer);
      await shutdown();
      process.exit(0);
      return;
    }
    await persistStatus(activePage, "poll");
  }, pollMs);
}

main().catch((error) => {
  console.error(String(error?.stack || error));
  process.exit(1);
});
