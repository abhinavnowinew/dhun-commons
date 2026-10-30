#!/usr/bin/env node
import { randomUUID } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { createChain } from "../telegram/lib/chain.mjs";
import { createEngine } from "../telegram/lib/commands.mjs";
import * as relay from "../telegram/lib/relay.mjs";
import { loadConfig } from "./lib/config.mjs";
import {
  appendAsk,
  readAnswers,
  readAsks,
  removeAsk,
} from "./lib/asks.mjs";
import {
  addressesBot,
  chatKey,
  isCommand,
  normalizeEnvelope,
  toEngineUpdate,
} from "./lib/envelope.mjs";
import { createSignalTransport } from "./lib/signal.mjs";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const HEARTBEAT_FILE = "signal_bridge.json";

export async function startBridge(config, options = {}) {
  const fetchImpl = options.fetchImpl ?? fetch;
  const transport = options.transport ?? createSignalTransport(config, { log: config.log });
  const chain = createChain(config, fetchImpl);
  const allowed = new Set([...config.groups].map((id) => chatKey("group", id)));
  for (const sender of config.senders) allowed.add(chatKey("dm", sender));
  const engine = createEngine(
    { ...config, allowed, open: config.open },
    { chain, relay, now: options.now }
  );

  let self = await transport.start();
  engine.setBot(self.number || config.account);
  relay.ensureDir(config.relayDir);
  config.log(
    `signal bridge · ${self.number || config.account}${self.uuid ? ` · ${self.uuid.slice(0, 8)}` : ""} · relay ${config.relayDir}`
  );

  const startedAt = Date.now();
  // signal-cli replays recent history on reconnect; never answer old messages.
  const historyCutoff = startedAt - 120000;
  const pending = new Map();
  let stopped = false;

  const send = (chatId, text) =>
    transport.send(chatId, text).catch((error) => {
      config.log(`send failed: ${error.message}`);
    });

  function isAllowed(message) {
    if (config.open) return true;
    if (message.chatKind === "group") return config.groups.has(message.groupId);
    return (
      config.dmOpen ||
      config.senders.has(message.from.number) ||
      config.senders.has(message.from.uuid)
    );
  }

  async function handleEnvelope(raw) {
    if (stopped) return;
    const message = normalizeEnvelope(raw, self);
    if (!message) return;
    if (message.sentAt && message.sentAt < historyCutoff) return;

    const text = String(message.text ?? "").trim();
    if (!text) return;

    if (!isAllowed(message)) {
      if (message.chatKind === "dm") {
        await send(message.chatId, engine.unauthorized(message.chatId));
      } else {
        config.log(`ignored message from an unlisted group ${message.groupId}`);
      }
      return;
    }

    if (isCommand(text)) {
      const replies = await engine.handleUpdate(toEngineUpdate(message));
      for (const reply of replies) await send(message.chatId, reply);
      return;
    }

    if (!addressesBot(message, { botNames: config.botNames, answerAll: config.answerAll })) {
      return;
    }

    const ask = {
      id: randomUUID(),
      channel: "signal",
      chatId: message.chatId,
      chatKind: message.chatKind,
      groupName: message.groupName,
      author: message.from.name,
      authorId: message.from.uuid || message.from.number,
      text: text.slice(0, 2000),
      at: Date.now(),
    };
    appendAsk(config.relayDir, ask);
    pending.set(ask.id, { ...ask, noticed: false });
    config.log(`queued ask ${ask.id} from ${ask.author} in ${ask.chatId}`);

    if (message.chatKind === "dm") {
      await send(
        message.chatId,
        "Queued for Dhun Commons. I'll answer here as soon as the app responds."
      );
    }
  }

  async function answerPending() {
    if (!pending.size) return;
    const answers = readAnswers(config.relayDir);
    for (const [id, ask] of [...pending]) {
      const answer = answers.find((entry) => entry.id === id);
      if (answer) {
        const text = String(answer.text ?? "").trim();
        await send(
          ask.chatId,
          text || `${ask.author}, the app could not answer that one (${answer.error ?? "no output"}).`
        );
        pending.delete(id);
        removeAsk(config.relayDir, id);
        continue;
      }
      if (Date.now() - ask.at > config.askTimeoutMs) {
        pending.delete(id);
        removeAsk(config.relayDir, id);
        await send(
          ask.chatId,
          "Dhun Commons is not answering right now — open the app on the Mac and ask again."
        );
      }
    }
  }

  transport.onEnvelope((envelope) => {
    if (!envelope) return;
    handleEnvelope(envelope).catch((error) => {
      config.log(`message failed: ${error.message}`);
    });
  });

  const answerTimer = setInterval(() => {
    answerPending().catch(() => {});
  }, config.askPollMs);
  answerTimer.unref?.();

  const tickTimer = setInterval(
    () => {
      engine.tick(send).catch(() => {});
      relay
        .writeJsonAtomic(path.join(config.relayDir, HEARTBEAT_FILE), {
          at: Date.now(),
          pid: process.pid,
          channel: "signal",
          account: config.account,
          pending: pending.size,
        });
    },
    Math.max(250, Math.min(config.pollMs, 5000))
  );
  tickTimer.unref?.();

  relay.writeJsonAtomic(path.join(config.relayDir, HEARTBEAT_FILE), {
    at: Date.now(),
    pid: process.pid,
    channel: "signal",
    account: config.account,
    pending: 0,
  });

  // signal-cli replays recent history on reconnect; never answer old messages.
  return {
    engine,
    transport,
    handleEnvelope,
    pending,
    asks() {
      return readAsks(config.relayDir);
    },
    self: () => self,
    stop: () => {
      stopped = true;
      clearInterval(answerTimer);
      clearInterval(tickTimer);
      transport.stop();
    },
    get stopped() {
      return stopped;
    },
    historyCutoff,
  };
}

const isMain = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isMain) {
  const config = loadConfig();

  if (process.argv.includes("--check")) {
    const problems = [];
    if (!config.account) problems.push("DHUN_SIGNAL_ACCOUNT is not set.");
    if (!config.groups.size && !config.open)
      problems.push("DHUN_SIGNAL_ALLOWED_GROUPS is empty (or set DHUN_SIGNAL_OPEN=1).");
    if (!fs.existsSync(config.cli) && !process.env.PATH?.split(":").some((dir) => fs.existsSync(path.join(dir, config.cli))))
      problems.push(`signal-cli not found (${config.cli}). Run: nix profile install nixpkgs#signal-cli`);
    console.log(`relay dir:   ${config.relayDir}`);
    console.log(`wallet root: ${config.walletRoot}`);
    console.log(`sequencer:   ${config.sequencer}`);
    console.log(`account:     ${config.account || "none"}`);
    console.log(`groups:      ${config.groups.size ? [...config.groups].join(", ") : "none"}`);
    if (problems.length) {
      for (const problem of problems) console.error(`missing: ${problem}`);
      process.exit(1);
    }
    console.log("config ok");
    process.exit(0);
  }

  if (!config.account) {
    console.error("DHUN_SIGNAL_ACCOUNT is not set. Link a number first: npm run link");
    process.exit(1);
  }
  if (!config.groups.size && !config.open) {
    console.error(
      "DHUN_SIGNAL_ALLOWED_GROUPS is empty. Add the bot to the group, then run npm run groups."
    );
    process.exit(1);
  }

  startBridge(config).catch((error) => {
    console.error(`bridge stopped: ${error.message}`);
    process.exit(1);
  });

  for (const signal of ["SIGINT", "SIGTERM"]) {
    process.on(signal, () => process.exit(0));
  }
}
