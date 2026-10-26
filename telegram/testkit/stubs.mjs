import http from "node:http";
import path from "node:path";
import { ensureDir, writeJsonAtomic } from "../lib/relay.mjs";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function listen(server) {
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  return `http://127.0.0.1:${server.address().port}`;
}

async function readBody(request) {
  let body = "";
  for await (const chunk of request) body += chunk;
  return body;
}

function reply(response, value) {
  response.setHeader("content-type", "application/json");
  response.end(JSON.stringify(value));
}

export async function startTelegram(token = "TESTTOKEN") {
  const sent = [];
  const queue = [];
  let nextId = 1;

  const server = http.createServer(async (request, response) => {
    const url = new URL(request.url, "http://127.0.0.1");
    const body = await readBody(request);
    const payload = body ? JSON.parse(body) : {};

    if (url.pathname === `/bot${token}/getMe`) {
      return reply(response, {
        ok: true,
        result: { id: 1, is_bot: true, first_name: "Dhun", username: "dhun_test_bot" },
      });
    }
    if (url.pathname === `/bot${token}/getUpdates`) {
      const offset = Number(payload.offset || 0);
      const updates = queue.filter((entry) => entry.update_id >= offset);
      if (!updates.length) await sleep(10);
      return reply(response, { ok: true, result: updates });
    }
    if (url.pathname === `/bot${token}/sendMessage`) {
      sent.push({ chat_id: String(payload.chat_id), text: payload.text });
      return reply(response, { ok: true, result: { message_id: sent.length } });
    }
    response.statusCode = 404;
    return reply(response, { ok: false, description: "not found" });
  });

  const url = await listen(server);
  return {
    url,
    sent,
    pushText(chatId, text, from = { id: chatId, first_name: "Abhi" }) {
      queue.push({
        update_id: nextId++,
        message: {
          message_id: nextId,
          date: Math.floor(Date.now() / 1000),
          chat: { id: chatId, type: "private" },
          from: { is_bot: false, ...from },
          text,
        },
      });
    },
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

export async function startSequencer({ height = 100, balances = {}, tx = null } = {}) {
  const state = { height, balances, tx, methods: [] };
  const server = http.createServer(async (request, response) => {
    const body = await readBody(request);
    let payload = {};
    try {
      payload = JSON.parse(body);
    } catch {
      payload = {};
    }
    state.methods.push(payload.method);
    let result = null;
    let error = null;
    switch (payload.method) {
      case "getLastBlockId":
        result = state.height;
        break;
      case "getAccountBalance":
        result = state.balances[payload.params?.account_id] ?? 0;
        break;
      case "getTransaction":
        result = state.tx;
        break;
      default:
        error = { message: "unsupported method" };
    }
    reply(
      response,
      error
        ? { jsonrpc: "2.0", id: payload.id, error }
        : { jsonrpc: "2.0", id: payload.id, result }
    );
  });

  const url = await listen(server);
  return {
    url,
    state,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

export function writeSnapshot(dir, patch = {}) {
  ensureDir(dir);
  const data = {
    app: "dhun_commons",
    version: "0.2.0",
    publishedAt: Date.now(),
    page: "wallet",
    role: "funder",
    room: "room-msig",
    proposals: [],
    offers: [],
    activities: [],
    messages: [],
    chain: {
      status: "ready",
      height: 67240,
      network: "LEZ public testnet",
      sequencer: "https://testnet.lez.logos.co",
      accounts: [],
      lastTx: {},
    },
    ...patch,
  };
  writeJsonAtomic(path.join(dir, "state.json"), data);
  return data;
}

export async function waitFor(check, timeoutMs = 4000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const value = check();
    if (value) return value;
    await sleep(20);
  }
  throw new Error("timed out waiting for condition");
}
