import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { startBridge } from "../bridge.mjs";
import { loadConfig } from "../lib/config.mjs";
import { readAsks } from "../lib/asks.mjs";
import { writeJsonAtomic } from "../../telegram/lib/relay.mjs";
import { startSequencer, waitFor, writeSnapshot } from "../../telegram/testkit/stubs.mjs";
import { base58EncodeHex } from "../../telegram/lib/chain.mjs";

const FUNDER = "440af262ae55e6721a09b896b83fac32723588fa8d6d7ee538c2a5400319089f";
const DHUN = "08f0c8b80393d1ca702310fe851f1bf0c904d044768e3ee60889b1d1842da08c";
const STEWARD = "2694ae11d4dc6197f061375f65337bfd903ecee7657408e76f54f6be5a0c0503";
const SELF = { number: "+15550000", uuid: "SELF-UUID" };
const GROUP = "GrOuPiD==";
const MEMBER = { uuid: "USER-UUID", number: "+15550001", name: "Asha" };

function fakeTransport(self = SELF) {
  const listeners = [];
  const sent = [];
  return {
    sent,
    async start() {
      return self;
    },
    self() {
      return self;
    },
    onEnvelope(listener) {
      listeners.push(listener);
      return () => {};
    },
    async send(chatId, text) {
      sent.push({ chatId, text });
    },
    stop() {},
    deliver(envelope) {
      for (const listener of listeners) listener(envelope);
    },
  };
}

function envelope({
  text,
  group = GROUP,
  sender = MEMBER,
  ts = Date.now(),
  mentions = [],
  quote = null,
  groupName = "Dhun Commons",
}) {
  return {
    source: sender.number,
    sourceNumber: sender.number,
    sourceUuid: sender.uuid,
    sourceName: sender.name,
    sourceDevice: 1,
    timestamp: ts,
    dataMessage: {
      timestamp: ts,
      message: text,
      mentions,
      ...(quote ? { quote } : {}),
      ...(group ? { groupInfo: { groupId: group, groupName } } : {}),
    },
  };
}

async function setup(t, options = {}) {
  const sequencer = await startSequencer(options.sequencer ?? {});
  const base = fs.mkdtempSync(path.join(os.tmpdir(), "dhun-signal-"));
  const walletRoot = path.join(base, "wallet");
  const relayDir = path.join(base, "relay");
  fs.mkdirSync(path.join(walletRoot, "test", "dhun_chain"), { recursive: true });
  fs.writeFileSync(
    path.join(walletRoot, "test", "dhun_chain", "roles.json"),
    JSON.stringify({ version: 1, roles: { funder: FUNDER, dhun: DHUN, steward: STEWARD } })
  );

  const config = loadConfig({
    DHUN_SIGNAL_ACCOUNT: SELF.number,
    DHUN_SIGNAL_ALLOWED_GROUPS: options.groups ?? GROUP,
    DHUN_SIGNAL_ALLOWED_SENDERS: options.senders ?? "",
    DHUN_SIGNAL_ASK_TIMEOUT_MS: String(options.askTimeoutMs ?? 5000),
    DHUN_SIGNAL_ASK_POLL_MS: "20",
    DHUN_RELAY_DIR: relayDir,
    DHUN_WALLET_DIR: walletRoot,
    LEZ_SEQUENCER_URL: sequencer.url,
    DHUN_POLL_MS: "20",
    DHUN_QUIET: "1",
    ...(options.env ?? {}),
  });

  if (options.snapshot) writeSnapshot(relayDir, options.snapshot);

  const transport = fakeTransport();
  const bridge = await startBridge(config, { transport });
  t.after(async () => {
    bridge.stop();
    await sequencer.close();
    fs.rmSync(base, { recursive: true, force: true });
  });

  return { transport, sequencer, config, bridge, relayDir };
}

function sentTo(transport, chatId) {
  return transport.sent.filter((entry) => entry.chatId === chatId);
}

function replyWith(transport, chatId, needle) {
  return waitFor(() => sentTo(transport, chatId).find((entry) => entry.text.includes(needle)));
}

test("commands answer inside an allowlisted group", async (t) => {
  const { transport } = await setup(t, {
    sequencer: {
      height: 67240,
      balances: { [base58EncodeHex(FUNDER)]: "100000000" },
    },
    snapshot: { chain: { status: "ready", height: 67240 } },
  });

  transport.deliver(envelope({ text: "/status" }));
  const reply = await replyWith(transport, `group:${GROUP}`, "Dhun Commons");
  assert.match(reply.text, /block 67,240/);
  assert.match(reply.text, /Funder 0\.1 LEZ/);
});

test("groups that were never allowlisted are ignored", async (t) => {
  const { transport, bridge } = await setup(t);
  transport.deliver(envelope({ text: "/status", group: "Tk9QRQ==" }));
  await new Promise((resolve) => setTimeout(resolve, 120));
  assert.equal(transport.sent.length, 0);
  assert.equal(bridge.asks().length, 0);
});

test("unbound direct messages are told their sender id", async (t) => {
  const { transport } = await setup(t);
  transport.deliver(envelope({ text: "/status", group: "" }));
  const reply = await replyWith(transport, "dm:USER-UUID", "not bound");
  assert.match(reply.text, /Chat id: dm:USER-UUID/);
  assert.match(reply.text, /DHUN_SIGNAL_ALLOWED_GROUPS/);
});

test("free text that names the bot becomes an ask and is answered", async (t) => {
  const { transport, relayDir } = await setup(t);
  transport.deliver(envelope({ text: "dhun, what is in the pantry this week?" }));

  const ask = await waitFor(() => readAsks(relayDir)[0]);
  assert.equal(ask.chatId, `group:${GROUP}`);
  assert.equal(ask.author, "Asha");
  assert.match(ask.text, /pantry this week/);

  writeJsonAtomic(path.join(relayDir, "answers.json"), {
    version: 1,
    answers: [{ id: ask.id, text: "Amla, sarson seed and moth beans, per the snapshot.", at: Date.now() }],
  });

  const reply = await replyWith(transport, `group:${GROUP}`, "Amla, sarson seed");
  assert.ok(reply);
  await waitFor(() => readAsks(relayDir).length === 0);
});

test("an @mention is enough to be addressed", async (t) => {
  const { transport, relayDir } = await setup(t);
  transport.deliver(
    envelope({
      text: "what should we cook?",
      mentions: [{ start: 0, length: 0, uuid: SELF.uuid }],
    })
  );
  const ask = await waitFor(() => readAsks(relayDir)[0]);
  assert.match(ask.text, /what should we cook/);
});

test("a reply to the bot is addressed", async (t) => {
  const { transport, relayDir } = await setup(t);
  transport.deliver(
    envelope({
      text: "and the kitchen?",
      quote: { author: SELF.uuid, text: "Amla is ready" },
    })
  );
  const ask = await waitFor(() => readAsks(relayDir)[0]);
  assert.match(ask.text, /and the kitchen/);
});

test("plain chatter in the group is left alone", async (t) => {
  const { transport, relayDir } = await setup(t);
  transport.deliver(envelope({ text: "see you at the field tomorrow" }));
  await new Promise((resolve) => setTimeout(resolve, 100));
  assert.equal(transport.sent.length, 0);
  assert.equal(readAsks(relayDir).length, 0);
});

test("unanswered asks time out with an honest notice", async (t) => {
  const { transport } = await setup(t, { askTimeoutMs: 120 });
  transport.deliver(envelope({ text: "dhun, status?" }));
  const reply = await waitFor(() =>
    sentTo(transport, `group:${GROUP}`).find((entry) => entry.text.includes("not answering right now")),
    4000
  );
  assert.ok(reply);
});

test("messages sent by the linked account itself are ignored", async (t) => {
  const { transport, relayDir } = await setup(t);
  transport.deliver(
    envelope({ text: "dhun echo", sender: { uuid: SELF.uuid, number: SELF.number, name: "Me" } })
  );
  await new Promise((resolve) => setTimeout(resolve, 100));
  assert.equal(readAsks(relayDir).length, 0);
});
