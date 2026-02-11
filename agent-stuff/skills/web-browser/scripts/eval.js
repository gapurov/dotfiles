#!/usr/bin/env node

import { closeBrowserSafe, connectBrowser, getPageForCommand } from "./pw.js";

const DEBUG = process.env.DEBUG === "1";
const log = DEBUG ? (...args) => console.error("[debug]", ...args) : () => {};

const code = process.argv.slice(2).join(" ");
if (!code) {
  console.log("Usage: eval.js 'code'");
  console.log("\nExamples:");
  console.log('  eval.js "document.title"');
  console.log("  eval.js \"document.querySelectorAll('a').length\"");
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
  try {
    page = await getPageForCommand(browser);
  } catch (e) {
    if (e.message === "No active tab found") {
      console.error("✗ No active tab found");
      process.exit(1);
    }
    throw e;
  }

  log("evaluating...");
  const expression = `(async () => { return (${code}); })()`;
  const result = await page.evaluate(
    (wrappedExpression) => window.eval(wrappedExpression),
    expression
  );

  log("formatting result...");
  if (Array.isArray(result)) {
    for (let i = 0; i < result.length; i++) {
      if (i > 0) console.log("");
      for (const [key, value] of Object.entries(result[i])) {
        console.log(`${key}: ${value}`);
      }
    }
  } else if (typeof result === "object" && result !== null) {
    for (const [key, value] of Object.entries(result)) {
      console.log(`${key}: ${value}`);
    }
  } else {
    console.log(result);
  }

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
