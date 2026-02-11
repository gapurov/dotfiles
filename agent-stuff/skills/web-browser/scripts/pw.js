#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { chromium } from "playwright";

const SESSION_FILE = join(homedir(), ".cache/agent-web/session.json");
const DEFAULT_DEBUG_URL = "http://127.0.0.1:9222";

function withTimeout(promise, timeoutMs, message) {
  let timer;
  const timeoutPromise = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(message)), timeoutMs);
  });
  return Promise.race([promise, timeoutPromise]).finally(() => clearTimeout(timer));
}

function getSessionDebugUrl() {
  if (!existsSync(SESSION_FILE)) return null;
  try {
    const raw = readFileSync(SESSION_FILE, "utf8");
    const parsed = JSON.parse(raw);
    if (typeof parsed?.debugUrl === "string" && parsed.debugUrl.length > 0) {
      return parsed.debugUrl;
    }
  } catch {
    // Ignore malformed session file.
  }
  return null;
}

export async function connectBrowser(timeoutMs = 5000) {
  const envDebugUrl = process.env["AGENT_WEB_DEBUG_URL"]?.trim() || null;
  const sessionDebugUrl = getSessionDebugUrl();
  const allowLegacy9222 = process.env["AGENT_WEB_ALLOW_LEGACY_9222"] === "1";
  const candidates = [];

  if (envDebugUrl) {
    candidates.push(envDebugUrl);
  }
  if (sessionDebugUrl && !candidates.includes(sessionDebugUrl)) {
    candidates.push(sessionDebugUrl);
  }
  if (allowLegacy9222 && !candidates.includes(DEFAULT_DEBUG_URL)) {
    candidates.push(DEFAULT_DEBUG_URL);
  }

  if (candidates.length === 0) {
    throw new Error(
      "No managed debug session configured. Run ./scripts/start.js or set AGENT_WEB_DEBUG_URL."
    );
  }

  let lastError = null;
  for (const debugUrl of candidates) {
    try {
      return await withTimeout(
        chromium.connectOverCDP(debugUrl),
        timeoutMs,
        `Connection timeout - failed to connect to ${debugUrl}`
      );
    } catch (e) {
      lastError = e;
    }
  }

  const reason = lastError?.message || "unknown error";
  throw new Error(
    `Connection failed for managed session. Tried: ${candidates.join(", ")}. Last error: ${reason}`
  );
}

export function getAllPages(browser) {
  return browser.contexts().flatMap((context) => context.pages());
}

export function getActivePage(browser) {
  return getAllPages(browser).at(-1) || null;
}

export async function getContextForNewPage(browser) {
  const context = browser.contexts().at(-1);
  if (!context) {
    throw new Error("No active browser context found");
  }
  return context;
}

export async function getPageForCommand(browser, { newTab = false } = {}) {
  if (newTab) {
    const context = await getContextForNewPage(browser);
    return context.newPage();
  }

  const page = getActivePage(browser);
  if (!page) {
    throw new Error("No active tab found");
  }
  return page;
}

export async function getPageTargetId(page) {
  const session = await page.context().newCDPSession(page);
  try {
    const info = await session.send("Target.getTargetInfo");
    return info?.targetInfo?.targetId || null;
  } finally {
    try {
      await session.detach();
    } catch {
      // Ignore cleanup failures.
    }
  }
}

export async function closeBrowserSafe(browser) {
  // For connectOverCDP flows, process exit closes the transport naturally.
  // Avoid explicit close to reduce risk of affecting an existing user session.
  void browser;
}
