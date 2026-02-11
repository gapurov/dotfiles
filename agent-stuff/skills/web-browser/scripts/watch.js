#!/usr/bin/env node

import {
  createWriteStream,
  existsSync,
  mkdirSync,
  readFileSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { closeBrowserSafe, connectBrowser, getPageTargetId } from "./pw.js";

const LOG_ROOT = join(homedir(), ".cache/agent-web/logs");
const PID_FILE = join(LOG_ROOT, ".pid");

function ensureDir(dir) {
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
}

function isProcessAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function getDateDir() {
  const now = new Date();
  const yyyy = String(now.getFullYear());
  const mm = String(now.getMonth() + 1).padStart(2, "0");
  const dd = String(now.getDate()).padStart(2, "0");
  return join(LOG_ROOT, `${yyyy}-${mm}-${dd}`);
}

function safeFileName(value) {
  return value.replace(/[^a-zA-Z0-9._-]/g, "_");
}

function inferValueType(value) {
  if (value === null) {
    return { type: "object", subtype: "null" };
  }
  if (Array.isArray(value)) {
    return { type: "object", subtype: "array" };
  }
  return { type: typeof value, subtype: null };
}

async function serializeConsoleArg(arg) {
  const description = arg.toString();
  try {
    const value = await arg.jsonValue();
    const inferred = inferValueType(value);
    return {
      type: inferred.type,
      subtype: inferred.subtype,
      value,
      description,
    };
  } catch {
    return {
      type: null,
      subtype: null,
      value: null,
      description,
    };
  }
}

function stackFromLocation(location) {
  if (!location || (!location.url && location.lineNumber == null)) return null;
  return [
    {
      functionName: null,
      url: location.url || null,
      lineNumber: location.lineNumber ?? null,
      columnNumber: location.columnNumber ?? null,
    },
  ];
}

function compactErrorStack(error) {
  if (!error?.stack) return null;
  const lines = String(error.stack).split("\n").slice(0, 8);
  const frames = [];

  for (const rawLine of lines) {
    const line = rawLine.trim();
    const match = line.match(/at\s+(?:(.*?)\s+\()?(.+):(\d+):(\d+)\)?$/);
    if (!match) continue;
    frames.push({
      functionName: match[1] || null,
      url: match[2] || null,
      lineNumber: Number(match[3]),
      columnNumber: Number(match[4]),
    });
  }

  return frames.length > 0 ? frames : null;
}

function parseMimeType(contentType) {
  if (!contentType) return null;
  return contentType.split(";")[0]?.trim() || null;
}

function createFallbackTargetId() {
  const stamp = Date.now().toString(36);
  const random = Math.random().toString(36).slice(2, 8);
  return `page_${stamp}_${random}`;
}

ensureDir(LOG_ROOT);

if (existsSync(PID_FILE)) {
  try {
    const existing = Number(readFileSync(PID_FILE, "utf8").trim());
    if (existing && isProcessAlive(existing)) {
      console.log("✓ watch already running");
      process.exit(0);
    }
  } catch {
    // Ignore and overwrite stale pid.
  }
}

writeFileSync(PID_FILE, String(process.pid));

const dateDir = getDateDir();
ensureDir(dateDir);

const targetState = new Map();
const pageToTarget = new WeakMap();
const attachedPages = new WeakSet();
const attachedContexts = new WeakSet();

let browser = null;
let contextScanTimer = null;
let shuttingDown = false;

function getStreamForTarget(targetId) {
  let state = targetState.get(targetId);
  if (!state) {
    state = { stream: null };
    targetState.set(targetId, state);
  }

  if (state.stream) return state.stream;

  const filename = `${safeFileName(targetId)}.jsonl`;
  const filepath = join(dateDir, filename);
  state.stream = createWriteStream(filepath, { flags: "a" });
  return state.stream;
}

function writeLog(targetId, payload) {
  const stream = getStreamForTarget(targetId);
  const record = {
    ts: new Date().toISOString(),
    targetId,
    ...payload,
  };
  stream.write(`${JSON.stringify(record)}\n`);
}

async function safeTitle(page) {
  try {
    return await page.title();
  } catch {
    return null;
  }
}

function closeTarget(targetId) {
  const state = targetState.get(targetId);
  if (state?.stream) {
    state.stream.end();
  }
  targetState.delete(targetId);
}

async function attachPage(page) {
  if (attachedPages.has(page)) return;
  attachedPages.add(page);

  let targetId = await getPageTargetId(page);
  if (!targetId) {
    targetId = createFallbackTargetId();
  }
  if (targetState.has(targetId)) {
    targetId = `${targetId}_${createFallbackTargetId()}`;
  }

  pageToTarget.set(page, targetId);
  targetState.set(targetId, { stream: null });

  writeLog(targetId, {
    type: "target.attached",
    url: page.url() || null,
    title: await safeTitle(page),
  });

  const requestIds = new WeakMap();
  let nextRequestId = 0;

  const getRequestId = (request) => {
    let id = requestIds.get(request);
    if (!id) {
      nextRequestId += 1;
      id = `req-${nextRequestId}`;
      requestIds.set(request, id);
    }
    return id;
  };

  const logTargetInfo = async () => {
    writeLog(targetId, {
      type: "target.info",
      url: page.url() || null,
      title: await safeTitle(page),
    });
  };

  page.on("framenavigated", (frame) => {
    if (frame !== page.mainFrame()) return;
    void logTargetInfo();
  });

  page.on("domcontentloaded", () => {
    void logTargetInfo();
  });

  page.on("console", async (msg) => {
    const args = await Promise.all(msg.args().map((arg) => serializeConsoleArg(arg)));
    writeLog(targetId, {
      type: "console",
      level: msg.type() || null,
      args,
      stack: stackFromLocation(msg.location()),
    });
  });

  page.on("pageerror", (error) => {
    const stack = compactErrorStack(error);
    const firstFrame = stack?.[0] || {};

    writeLog(targetId, {
      type: "exception",
      text: error?.name || null,
      description: error?.message || String(error),
      lineNumber: firstFrame.lineNumber ?? null,
      columnNumber: firstFrame.columnNumber ?? null,
      url: firstFrame.url ?? null,
      stack,
    });
  });

  page.on("request", (request) => {
    writeLog(targetId, {
      type: "network.request",
      requestId: getRequestId(request),
      method: request.method() || null,
      url: request.url() || null,
      documentURL: request.frame()?.url() || null,
      initiator: request.resourceType() || null,
      hasPostData: request.postData() != null,
    });
  });

  page.on("response", async (response) => {
    const request = response.request();
    const contentType = await response.headerValue("content-type");

    writeLog(targetId, {
      type: "network.response",
      requestId: getRequestId(request),
      url: response.url() || null,
      status: response.status(),
      statusText: response.statusText() || null,
      mimeType: parseMimeType(contentType),
      fromDiskCache: false,
      fromServiceWorker: response.fromServiceWorker(),
    });
  });

  page.on("requestfailed", (request) => {
    const failure = request.failure();
    const errorText = failure?.errorText || null;

    writeLog(targetId, {
      type: "network.failure",
      requestId: getRequestId(request),
      errorText,
      canceled: typeof errorText === "string" && errorText.includes("ERR_ABORTED"),
    });
  });

  page.on("close", () => {
    closeTarget(targetId);
  });
}

function attachContext(context) {
  if (attachedContexts.has(context)) return;
  attachedContexts.add(context);

  for (const page of context.pages()) {
    void attachPage(page).catch((e) => {
      console.error("watch: attach page error:", e.message);
    });
  }

  context.on("page", (page) => {
    void attachPage(page).catch((e) => {
      console.error("watch: attach page error:", e.message);
    });
  });
}

function scanContexts() {
  if (!browser) return;
  for (const context of browser.contexts()) {
    attachContext(context);
  }
}

async function cleanup(code = 0) {
  if (shuttingDown) return;
  shuttingDown = true;

  if (contextScanTimer) {
    clearInterval(contextScanTimer);
    contextScanTimer = null;
  }

  for (const targetId of targetState.keys()) {
    closeTarget(targetId);
  }

  await closeBrowserSafe(browser);

  try {
    unlinkSync(PID_FILE);
  } catch {
    // Ignore missing file cleanup errors.
  }

  process.exit(code);
}

async function main() {
  browser = await connectBrowser(5000);
  scanContexts();
  contextScanTimer = setInterval(scanContexts, 2000);

  browser.on("disconnected", () => {
    console.error("✗ watch disconnected from Chrome");
    void cleanup(1);
  });

  process.on("SIGINT", () => {
    void cleanup(0);
  });

  process.on("SIGTERM", () => {
    void cleanup(0);
  });

  console.log("✓ watch started");
}

try {
  await main();
} catch (e) {
  console.error("✗ watch failed:", e.message);
  await cleanup(1);
}
