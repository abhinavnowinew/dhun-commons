import fs from "node:fs";
import path from "node:path";

export const STATE_FILE = "state.json";
export const INBOX_FILE = "inbox.json";
export const BRIDGE_FILE = "bridge.json";
export const SUBSCRIBERS_FILE = "subscribers.json";

export function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

export function readJson(file, fallback = null) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return fallback;
  }
}

export function writeJsonAtomic(file, value) {
  ensureDir(path.dirname(file));
  const tmp = `${file}.${process.pid}.${Date.now()}.tmp`;
  fs.writeFileSync(tmp, `${JSON.stringify(value, null, 2)}\n`);
  fs.renameSync(tmp, file);
}

export function readSnapshot(dir) {
  const file = path.join(dir, STATE_FILE);
  try {
    const stat = fs.statSync(file);
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    return data && typeof data === "object" ? { data, at: stat.mtimeMs } : null;
  } catch {
    return null;
  }
}

export function inboxMessages(dir) {
  const data = readJson(path.join(dir, INBOX_FILE), { messages: [] });
  if (Array.isArray(data)) return data;
  return Array.isArray(data?.messages) ? data.messages : [];
}

export function appendInbox(dir, message) {
  const messages = inboxMessages(dir).concat(message).slice(-100);
  writeJsonAtomic(path.join(dir, INBOX_FILE), { version: 1, messages });
  return messages.length;
}

export function writeHeartbeat(dir, beat) {
  writeJsonAtomic(path.join(dir, BRIDGE_FILE), beat);
}

export function subscribers(dir) {
  const data = readJson(path.join(dir, SUBSCRIBERS_FILE), { chats: [] });
  const chats = Array.isArray(data) ? data : data?.chats;
  return new Set((Array.isArray(chats) ? chats : []).map(String));
}

export function setSubscribers(dir, chats) {
  writeJsonAtomic(path.join(dir, SUBSCRIBERS_FILE), { chats: [...chats].map(String) });
}
