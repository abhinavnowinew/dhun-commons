import { spawn } from "node:child_process";
import readline from "node:readline";

// Line-delimited JSON-RPC over the child process stdio, which is how
// `signal-cli jsonRpc` speaks. Every request needs a unique id; the daemon
// answers on the same channel and pushes incoming envelopes as notifications
// with method "receive".
export function createRpcClient({ bin, args = [], env, log = () => {}, requestTimeoutMs = 30000 }) {
  const child = spawn(bin, args, {
    stdio: ["pipe", "pipe", "pipe"],
    env: { ...process.env, ...env },
  });

  const pending = new Map();
  const listeners = new Set();
  let nextId = 1;
  let closed = false;

  const lines = readline.createInterface({ input: child.stdout });
  lines.on("line", (line) => {
    const text = line.trim();
    if (!text.startsWith("{")) return;
    let message;
    try {
      message = JSON.parse(text);
    } catch {
      log(`signal-cli sent a non-JSON line: ${text.slice(0, 120)}`);
      return;
    }
    if (message.id !== undefined && pending.has(String(message.id))) {
      const entry = pending.get(String(message.id));
      pending.delete(String(message.id));
      clearTimeout(entry.timer);
      if (message.error) {
        const error = new Error(message.error.message ?? "signal-cli error");
        error.code = message.error.code;
        entry.reject(error);
      } else {
        entry.resolve(message.result);
      }
      return;
    }
    if (message.method) {
      for (const listener of listeners) listener(message);
    }
  });

  const stderr = readline.createInterface({ input: child.stderr });
  stderr.on("line", (line) => {
    const text = line.trim();
    if (text) log(`signal-cli: ${text.slice(0, 200)}`);
  });

  child.on("exit", (code) => {
    closed = true;
    for (const [, entry] of pending) {
      clearTimeout(entry.timer);
      entry.reject(new Error(`signal-cli exited (${code})`));
    }
    pending.clear();
    for (const listener of listeners) listener({ method: "exit", params: { code } });
  });

  function request(method, params = {}) {
    if (closed) return Promise.reject(new Error("signal-cli is not running"));
    const id = String(nextId++);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        pending.delete(id);
        reject(new Error(`signal-cli did not answer ${method} in ${requestTimeoutMs}ms`));
      }, requestTimeoutMs);
      pending.set(id, { resolve, reject, timer });
      child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
    });
  }

  return {
    request,
    onNotification(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    stop() {
      closed = true;
      child.kill("SIGTERM");
    },
    get closed() {
      return closed;
    },
  };
}
