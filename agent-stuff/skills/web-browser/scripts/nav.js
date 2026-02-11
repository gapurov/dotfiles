#!/usr/bin/env node

import { closeBrowserSafe, connectBrowser, getPageForCommand } from "./pw.js";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const url = process.argv[2];
const newTab = process.argv[3] === "--new";

if (!url) {
  console.log("Usage: nav.js <url> [--new]");
  console.log("\nExamples:");
  console.log("  nav.js https://example.com       # Navigate current tab");
  console.log("  nav.js https://example.com --new # Open in new tab");
  process.exit(1);
}

// Global timeout
const globalTimeout = setTimeout(() => {
  console.error("✗ Global timeout exceeded (45s)");
  process.exit(1);
}, 45000);

try {
  log("connecting...");
  const browser = await connectBrowser(5000);
  let page;

  log("getting page...");
  try {
    page = await getPageForCommand(browser, { newTab });
  } catch (e) {
    if (e.message === "No active tab found") {
      console.error("✗ No active tab found");
      process.exit(1);
    }
    throw e;
  }

  log("navigating...");
  await page.goto(url, { timeout: 30000, waitUntil: "domcontentloaded" });

  console.log(newTab ? "✓ Opened:" : "✓ Navigated to:", url);

  log("closing...");
  await closeBrowserSafe(browser);
  log("done");
} catch (e) {
  console.error("✗", e.message);
  process.exit(1);
} finally {
  clearTimeout(globalTimeout);
  setTimeout(() => process.exit(0), 100);
}
