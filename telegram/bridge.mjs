#!/usr/bin/env node
import { pathToFileURL } from "node:url";
import { loadConfig } from "./lib/config.mjs";
import { createChain } from "./lib/chain.mjs";
import { createEngine } from "./lib/commands.mjs";
import * as relay from "./lib/relay.mjs";
import { createTelegramApi } from "./lib/telegram.mjs";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export async function startBridge(config, options = {}) {
  const fetchImpl = options.fetchImpl ?? fetch;
  const chain = createChain(config, fetchImpl);
  const api = createTelegramApi(config, fetchImpl);
  const engine = createEngine(config, { chain, relay });

  const me = await api.getMe();
  engine.setBot(me.username ? `@${me.username}` : me.first_name || "");
  relay.ensureDir(config.relayDir);
  config.log(
    `telegram bridge · ${me.username ? `@${me.username}` : me.first_name} · relay ${config.relayDir}`
  );

  const controller = new AbortController();
  let offset = 0;

  const send = (chatId, text) =>
    api.sendMessage(chatId, text).catch((error) => {
      config.log(`send failed: ${api.redact(error.message)}`);
    });

  const tickTimer = setInterval(
    () => {
      engine.tick(send).catch(() => {});
    },
    Math.max(250, Math.min(config.pollMs, 5000))
  );
  tickTimer.unref?.();

  const loop = (async () => {
    while (!controller.signal.aborted) {
      try {
        const updates = await api.getUpdates(offset, controller.signal);
        for (const update of updates) {
          offset = Math.max(offset, Number(update.update_id) + 1);
          const chatId = update?.message?.chat?.id;
          if (chatId === undefined) continue;
          const replies = await engine.handleUpdate(update);
          for (const text of replies) await send(chatId, text);
        }
      } catch (error) {
        if (controller.signal.aborted) break;
        const status = error.status ? ` (${error.status})` : "";
        config.log(`poll failed${status}: ${api.redact(error.message)}`);
        await sleep(error.retryAfter ? error.retryAfter * 1000 : 3000);
      }
    }
  })();

  return {
    engine,
    api,
    stop: () => {
      controller.abort();
      clearInterval(tickTimer);
    },
    done: loop,
  };
}

const isMain = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isMain) {
  const config = loadConfig();
  if (process.argv.includes("--check")) {
    const problems = [];
    if (!config.token) problems.push("TELEGRAM_BOT_TOKEN is not set.");
    if (!config.allowed.size && !config.open)
      problems.push("TELEGRAM_ALLOWED_CHAT_IDS is empty (or set DHUN_TELEGRAM_OPEN=1).");
    console.log(`relay dir:   ${config.relayDir}`);
    console.log(`wallet root: ${config.walletRoot}`);
    console.log(`sequencer:   ${config.sequencer}`);
    console.log(`allowed:     ${config.allowed.size ? [...config.allowed].join(", ") : "none"}`);
    if (problems.length) {
      for (const problem of problems) console.error(`missing: ${problem}`);
      process.exit(1);
    }
    console.log("config ok");
    process.exit(0);
  }

  if (!config.token) {
    console.error("TELEGRAM_BOT_TOKEN is not set. Create a bot with @BotFather and export the token.");
    process.exit(1);
  }
  if (!config.allowed.size && !config.open) {
    console.error(
      "TELEGRAM_ALLOWED_CHAT_IDS is empty. Send /id to the bot, then allow that chat id."
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
