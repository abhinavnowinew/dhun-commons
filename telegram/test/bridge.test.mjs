import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { startBridge } from "../bridge.mjs";
import { base58EncodeHex, lezFromLepta } from "../lib/chain.mjs";
import { loadConfig } from "../lib/config.mjs";
import { inboxMessages, writeJsonAtomic } from "../lib/relay.mjs";
import {
  startSequencer,
  startTelegram,
  waitFor,
  writeSnapshot,
} from "../testkit/stubs.mjs";

const FUNDER = "440af262ae55e6721a09b896b83fac32723588fa8d6d7ee538c2a5400319089f";
const DHUN = "08f0c8b80393d1ca702310fe851f1bf0c904d044768e3ee60889b1d1842da08c";
const STEWARD = "2694ae11d4dc6197f061375f65337bfd903ecee7657408e76f54f6be5a0c0503";
const HASH = "683eef0c1fcee4f06cfcccd41e89f679bbcdb5fa8c09f8046db41351ec6c271d";
const SECOND_HASH = "a225dd37a7b7bb1c20db2fbd4c8a5313e10a2f7b1c7e6f0a9c4d5e6f7a8b9c0d";

async function setup(t, options = {}) {
  const telegram = await startTelegram();
  const sequencer = await startSequencer(options.sequencer ?? {});
  const base = fs.mkdtempSync(path.join(os.tmpdir(), "dhun-telegram-"));
  const walletRoot = path.join(base, "wallet");
  const relayDir = path.join(base, "relay");
  fs.mkdirSync(path.join(walletRoot, "test", "dhun_chain"), { recursive: true });
  fs.writeFileSync(
    path.join(walletRoot, "test", "dhun_chain", "roles.json"),
    JSON.stringify({
      version: 1,
      roles: { funder: FUNDER, dhun: DHUN, steward: STEWARD },
    })
  );

  const config = loadConfig({
    TELEGRAM_BOT_TOKEN: "TESTTOKEN",
    DHUN_TELEGRAM_API_BASE: telegram.url,
    TELEGRAM_ALLOWED_CHAT_IDS: options.allow ?? "42",
    DHUN_RELAY_DIR: relayDir,
    DHUN_WALLET_DIR: walletRoot,
    LEZ_SEQUENCER_URL: sequencer.url,
    DHUN_POLL_MS: "20",
    DHUN_TELEGRAM_POLL_SECONDS: "0",
    DHUN_QUIET: "1",
    ...(options.env ?? {}),
  });

  if (options.snapshot) writeSnapshot(relayDir, options.snapshot);
  if (options.subscribers) {
    writeJsonAtomic(path.join(relayDir, "subscribers.json"), { chats: options.subscribers });
  }

  const bridge = await startBridge(config);
  t.after(async () => {
    bridge.stop();
    await bridge.done;
    await telegram.close();
    await sequencer.close();
    fs.rmSync(base, { recursive: true, force: true });
  });

  return { telegram, sequencer, config, bridge, relayDir };
}

function replies(telegram, chatId) {
  return telegram.sent.filter((entry) => entry.chat_id === String(chatId));
}

function replyWith(telegram, chatId, needle) {
  return waitFor(() => replies(telegram, chatId).find((entry) => entry.text.includes(needle)));
}

test("base58 addresses and LEZ amounts match the app", () => {
  assert.equal(base58EncodeHex(FUNDER), "5acQUys3zmsmtDg5Ku6ZjiFycewbsLBAUXDY4EHN8W2i");
  assert.equal(base58EncodeHex(DHUN), "buDJvLwzujZbWawTPwMUfbpnFBTvmiZP2QMmMCtAgGs");
  assert.equal(base58EncodeHex(STEWARD), "3bbzBKGZ2UuCi5VxSnWWxfgbqkvLoRBQTtK3SrRAkDrr");
  assert.equal(lezFromLepta("100000000"), "0.1");
  assert.equal(lezFromLepta("1234567890"), "1.23456789");
  assert.equal(lezFromLepta("0"), "0");
});

test("status reads the sequencer and the app snapshot", async (t) => {
  const { telegram } = await setup(t, {
    sequencer: {
      height: 67240,
      balances: {
        [base58EncodeHex(FUNDER)]: "100000000",
        [base58EncodeHex(DHUN)]: "0",
        [base58EncodeHex(STEWARD)]: "0",
      },
    },
    snapshot: {
      chain: {
        status: "ready",
        height: 67240,
        network: "LEZ public testnet",
        lastTx: { txHash: HASH, confirmed: false, amount: "0.01" },
      },
    },
  });
  telegram.pushText(42, "/status");
  const reply = await replyWith(telegram, 42, "Dhun Commons");
  assert.match(reply.text, /App · wallet · role Funder · snapshot /);
  assert.match(reply.text, /block 67,240/);
  assert.match(reply.text, /Funder 0\.1 LEZ/);
  assert.match(reply.text, /Dhun 0 LEZ/);
  assert.match(reply.text, /submitted, unverified/);
  assert.doesNotMatch(reply.text, /settled/);
});

test("balance lists the three party accounts", async (t) => {
  const { telegram } = await setup(t, {
    sequencer: {
      balances: {
        [base58EncodeHex(FUNDER)]: "100000000",
        [base58EncodeHex(DHUN)]: "0",
        [base58EncodeHex(STEWARD)]: "2500000000",
      },
    },
  });
  telegram.pushText(42, "/balance");
  const reply = await replyWith(telegram, 42, "Funder ·");
  assert.match(reply.text, /Funder · 0\.1 LEZ/);
  assert.match(reply.text, /Dhun · 0 LEZ/);
  assert.match(reply.text, /Steward · 2\.5 LEZ/);
  assert.match(reply.text, /Read from the sequencer just now/);
});

test("unknown chats are rejected with their id", async (t) => {
  const { telegram } = await setup(t, { allow: "42" });
  telegram.pushText(99, "/status");
  const reply = await replyWith(telegram, 99, "not bound");
  assert.match(reply.text, /Chat id: 99/);
  assert.equal(replies(telegram, 42).length, 0);
  assert.doesNotMatch(reply.text, /block/);
});

test("verify never calls an unknown hash settled", async (t) => {
  const { telegram, sequencer } = await setup(t);
  telegram.pushText(42, `/verify ${HASH}`);
  const missing = await replyWith(telegram, 42, "does not report");
  assert.match(missing.text, /remains submitted, not settled/);

  sequencer.state.tx = { tx_hash: HASH };
  telegram.pushText(42, `/verify ${HASH}`);
  const found = await replyWith(telegram, 42, "not a finality guarantee");
  assert.match(found.text, /Sequencer returned a record/);
});

test("/say queues a room message for the app", async (t) => {
  const { telegram, relayDir } = await setup(t);
  telegram.pushText(42, "/say Two more seed lots arrive Friday");
  await replyWith(telegram, 42, "Queued for the app");
  const message = await waitFor(() =>
    inboxMessages(relayDir).find((entry) => entry.text.includes("Two more seed lots"))
  );
  assert.equal(message.kind, "room");
  assert.equal(message.chatId, "42");
  assert.equal(message.author, "Abhi");
  assert.match(message.id, /^[0-9a-f-]{36}$/);
});

test("snapshot commands answer inventory, proposals, activity and room", async (t) => {
  const { telegram } = await setup(t, {
    snapshot: {
      proposals: [
        {
          id: "PROP-108",
          title: "Execute Amla release",
          amount: 1200,
          quorum: 2,
          approvals: [{}, {}],
        },
      ],
      offers: [
        { id: "OFF-01", title: "Certified sarson seed", price: 380, unit: "20 kg lot", stock: 6, season: "Rabi" },
        { id: "OFF-09", title: "Moth beans", price: 120, unit: "5 kg", stock: 9, season: "Kharif" },
      ],
      activities: [{ title: "Walk the rabi seedbed", status: "planned", at: Date.now() }],
      messages: [
        { role: "funder", text: "Amla release is ready", at: Date.now() },
        { role: "system", text: "Proposal created", at: Date.now() },
      ],
    },
  });

  telegram.pushText(42, "/inventory rabi");
  const stock = await replyWith(telegram, 42, "OFF-01");
  assert.match(stock.text, /Certified sarson seed/);
  assert.doesNotMatch(stock.text, /OFF-09/);
  assert.match(stock.text, /not live farmer data/);

  telegram.pushText(42, "/proposals");
  const queue = await replyWith(telegram, 42, "PROP-108");
  assert.match(queue.text, /2\/2 approvals/);
  assert.match(queue.text, /never signs/);

  telegram.pushText(42, "/activity");
  const work = await replyWith(telegram, 42, "Walk the rabi seedbed");
  assert.match(work.text, /planned/);

  telegram.pushText(42, "/room");
  const room = await replyWith(telegram, 42, "Amla release is ready");
  assert.match(room.text, /Logos Messaging peer delivery is separate/);
});

test("push updates follow block height and transfer status", async (t) => {
  const { telegram, sequencer, relayDir } = await setup(t, {
    subscribers: ["42"],
    sequencer: { height: 100 },
    snapshot: {
      chain: {
        status: "ready",
        height: 100,
        lastTx: { txHash: HASH, confirmed: false, amount: "0.01" },
      },
    },
  });

  await waitFor(() => fs.existsSync(path.join(relayDir, "bridge.json")));
  await waitFor(() => sequencer.state.methods.includes("getLastBlockId"));
  await new Promise((resolve) => setTimeout(resolve, 80));
  sequencer.state.height = 101;
  const block = await replyWith(telegram, 42, "Block 101");
  assert.match(block.text, /was 100/);

  writeSnapshot(relayDir, {
    chain: {
      status: "ready",
      height: 101,
      lastTx: { txHash: HASH, confirmed: true, amount: "0.01" },
    },
  });
  const transfer = await replyWith(telegram, 42, "now reported by the sequencer");
  assert.match(transfer.text, /Not a finality guarantee/);

  writeSnapshot(relayDir, {
    chain: {
      status: "ready",
      height: 101,
      lastTx: { txHash: SECOND_HASH, confirmed: false, amount: "0.02" },
    },
  });
  const next = await replyWith(telegram, 42, "is submitted, not verified");
  assert.match(next.text, /a225dd37/);
});
