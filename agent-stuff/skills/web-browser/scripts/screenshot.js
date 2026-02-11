#!/usr/bin/env node

import { tmpdir } from "node:os";
import { join } from "node:path";
import { writeFileSync } from "node:fs";
import { closeBrowserSafe, connectBrowser, getPageForCommand } from "./pw.js";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

// Global timeout
const globalTimeout = setTimeout(() => {
  console.error("✗ Global timeout exceeded (15s)");
  process.exit(1);
}, 15000);

try {
  log("connecting...");
  const browser = await connectBrowser(5000);
  let page;
  try {
    page = await getPageForCommand(browser);
  } catch (e) {
    if (e.message === "No active tab found") {
      console.error("✗ No active tab found");
      process.exit(1);
    }
    throw e;
  }

  log("taking screenshot...");
  const data = await page.screenshot({ type: "png" });

  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const filename = `screenshot-${timestamp}.png`;
  const filepath = join(tmpdir(), filename);

  writeFileSync(filepath, data);
  console.log(filepath);

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
