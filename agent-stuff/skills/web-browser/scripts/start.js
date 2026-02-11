#!/usr/bin/env node

import { spawn, execSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { createServer } from "node:net";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const useProfile = process.argv[2] === "--profile";

if (process.argv[2] && process.argv[2] !== "--profile") {
  console.log("Usage: start.js [--profile]");
  console.log("\nOptions:");
  console.log("  --profile  Copy your default Chrome profile (cookies, logins)");
  console.log("\nExamples:");
  console.log("  start.js            # Start with fresh profile");
  console.log("  start.js --profile  # Start with your Chrome profile");
  process.exit(1);
}

const CACHE_ROOT = join(homedir(), ".cache/agent-web");
const DEFAULT_USER_DATA_DIR = join(CACHE_ROOT, "chrome-data");
const SESSION_FILE = join(CACHE_ROOT, "session.json");
const WATCHER_PID_FILE = join(homedir(), ".cache/agent-web/logs/.pid");
const CHROME_BINARY = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const CHROME_APP = "Google Chrome";

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

function readSession() {
  if (!existsSync(SESSION_FILE)) return null;
  try {
    const raw = readFileSync(SESSION_FILE, "utf8");
    const parsed = JSON.parse(raw);
    if (typeof parsed?.debugUrl !== "string") return null;
    return parsed;
  } catch {
    return null;
  }
}

function deleteSessionFile() {
  if (!existsSync(SESSION_FILE)) return;
  try {
    unlinkSync(SESSION_FILE);
  } catch {
    // Ignore cleanup errors.
  }
}

function writeSession(session) {
  ensureDir(CACHE_ROOT);
  writeFileSync(SESSION_FILE, `${JSON.stringify(session, null, 2)}\n`);
}

function readPidFromFile(filePath) {
  if (!existsSync(filePath)) return null;
  try {
    const value = Number(readFileSync(filePath, "utf8").trim());
    return Number.isFinite(value) && value > 0 ? value : null;
  } catch {
    return null;
  }
}

function sanitizeUserDataDir(userDataDir) {
  const staleLocks = [
    "SingletonLock",
    "SingletonSocket",
    "SingletonCookie",
    "DevToolsActivePort",
    "Default/LOCK",
  ];

  for (const relativePath of staleLocks) {
    const fullPath = join(userDataDir, relativePath);
    try {
      rmSync(fullPath, { force: true });
    } catch {
      // Ignore missing/stale cleanup failures.
    }
  }
}

function stopExistingWatcher() {
  const pid = readPidFromFile(WATCHER_PID_FILE);
  if (!pid) return;
  if (!isProcessAlive(pid)) {
    try {
      unlinkSync(WATCHER_PID_FILE);
    } catch {
      // Ignore stale pid file cleanup errors.
    }
    return;
  }
  try {
    process.kill(pid, "SIGTERM");
  } catch {
    // Ignore kill failures.
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function readProcessCommand(pid) {
  try {
    return execSync(`ps -p ${pid} -o command=`, { encoding: "utf8" }).trim();
  } catch {
    return null;
  }
}

function isManagedChromeCommand(cmd, session) {
  if (!cmd) return false;
  const userDataDir = session?.userDataDir || DEFAULT_USER_DATA_DIR;
  return (
    cmd.includes(CHROME_BINARY) &&
    cmd.includes(`--remote-debugging-port=${session.port}`) &&
    cmd.includes(`--user-data-dir=${userDataDir}`)
  );
}

function isManagedChromeSession(session) {
  if (!session?.pid || !Number.isFinite(session.port)) return false;
  const cmd = readProcessCommand(session.pid);
  return isManagedChromeCommand(cmd, session);
}

function findPidByDebugPort(port) {
  try {
    const output = execSync(`lsof -nP -iTCP:${port} -sTCP:LISTEN -t`, {
      encoding: "utf8",
    }).trim();
    const pid = Number(output.split("\n")[0]);
    return Number.isFinite(pid) && pid > 0 ? pid : null;
  } catch {
    return null;
  }
}

async function waitForEndpoint(debugUrl, attempts = 30, delayMs = 500) {
  const endpoint = `${debugUrl}/json/version`;
  for (let i = 0; i < attempts; i++) {
    try {
      const response = await fetch(endpoint);
      if (response.ok) return true;
    } catch {
      // Retry until timeout.
    }
    await sleep(delayMs);
  }
  return false;
}

async function waitForEndpointDown(debugUrl, attempts = 20, delayMs = 250) {
  for (let i = 0; i < attempts; i++) {
    try {
      const response = await fetch(`${debugUrl}/json/version`);
      if (!response.ok) return true;
    } catch {
      return true;
    }
    await sleep(delayMs);
  }
  return false;
}

async function getFreePort() {
  return new Promise((resolve, reject) => {
    const server = createServer();
    server.unref();
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      if (!address || typeof address === "string") {
        server.close(() => reject(new Error("Failed to allocate debug port")));
        return;
      }
      const { port } = address;
      server.close((error) => {
        if (error) reject(error);
        else resolve(port);
      });
    });
  });
}

function launchChrome({ port, userDataDir }) {
  const args = [
    "-na",
    CHROME_APP,
    "--args",
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${userDataDir}`,
    "--profile-directory=Default",
    "--disable-search-engine-choice-screen",
    "--no-first-run",
    "--disable-features=ProfilePicker",
    "about:blank",
  ];

  const child = spawn("open", args, { detached: true, stdio: "ignore" });
  child.unref();
  return child.pid ?? null;
}

function startWatcher() {
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  const watcherPath = join(scriptDir, "watch.js");
  spawn(process.execPath, [watcherPath], { detached: true, stdio: "ignore" }).unref();
}

async function stopManagedSession(session) {
  if (!session?.debugUrl || !Number.isFinite(session.port)) return;

  let pid = findPidByDebugPort(session.port);
  if (!pid && session.pid && isProcessAlive(session.pid) && isManagedChromeSession(session)) {
    pid = session.pid;
  }
  if (!pid || !isProcessAlive(pid)) return;

  const cmd = readProcessCommand(pid);
  if (!isManagedChromeCommand(cmd, session)) return;

  try {
    process.kill(pid, "SIGTERM");
  } catch {
    return;
  }

  const stopped = await waitForEndpointDown(session.debugUrl, 20, 250);
  if (stopped) return;

  try {
    process.kill(pid, "SIGKILL");
  } catch {
    // Ignore kill failures.
  }
}

ensureDir(CACHE_ROOT);
ensureDir(DEFAULT_USER_DATA_DIR);

const existingSession = readSession();
if (existingSession?.debugUrl) {
  const healthy = await waitForEndpoint(existingSession.debugUrl, 2, 300);
  if (healthy && !useProfile) {
    startWatcher();
    const existingPort = (() => {
      try {
        return new URL(existingSession.debugUrl).port;
      } catch {
        return "unknown";
      }
    })();
    console.log(`✓ Chrome session ready on :${existingPort}`);
    process.exit(0);
  }
}

if (useProfile && existingSession) {
  await stopManagedSession(existingSession);
}

const userDataDir = useProfile
  ? join(CACHE_ROOT, `chrome-data-profile-${Date.now()}`)
  : DEFAULT_USER_DATA_DIR;
ensureDir(userDataDir);

if (useProfile) {
  execSync(
    `rsync -a --delete "${process.env["HOME"]}/Library/Application Support/Google/Chrome/" "${userDataDir}/"`,
    { stdio: "pipe" }
  );
}

sanitizeUserDataDir(userDataDir);

const port = await getFreePort();
const debugUrl = `http://127.0.0.1:${port}`;
const chromePid = launchChrome({ port, userDataDir });

const connected = await waitForEndpoint(debugUrl, 40, 300);
if (!connected) {
  deleteSessionFile();
  console.error(`✗ Failed to connect to Chrome on ${debugUrl}`);
  process.exit(1);
}

const resolvedChromePid = findPidByDebugPort(port);

writeSession({
  debugUrl,
  port,
  pid: resolvedChromePid || chromePid,
  userDataDir,
  startedAt: new Date().toISOString(),
  copiedProfile: useProfile,
});

stopExistingWatcher();
await sleep(300);
startWatcher();

console.log(
  `✓ Chrome started on :${port} (isolated session)${
    useProfile ? " with your profile copy" : ""
  }`
);
