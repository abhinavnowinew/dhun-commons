import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createRpcClient } from "../lib/rpc.mjs";

function fakeCli(t, body) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "dhun-signal-cli-"));
  const file = path.join(dir, "fake-signal-cli");
  fs.writeFileSync(file, `#!/usr/bin/env node\n${body}\n`, { mode: 0o755 });
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return file;
}

test("requests are matched by id and notifications are delivered", async (t) => {
  const bin = fakeCli(
    t,
    `
const readline = require("node:readline");
const rl = readline.createInterface({ input: process.stdin });
rl.on("line", (line) => {
  const request = JSON.parse(line);
  if (request.method === "send") {
    console.log(JSON.stringify({ jsonrpc: "2.0", id: request.id, result: { timestamp: 42 } }));
    console.log(JSON.stringify({ jsonrpc: "2.0", method: "receive", params: { envelope: { sourceUuid: "U1" } } }));
  }
  if (request.method === "listAccounts") {
    console.log(JSON.stringify({ jsonrpc: "2.0", id: request.id, result: [{ number: "+1555", uuid: "SELF" }] }));
  }
});
setInterval(() => {}, 1000);
`
  );

  const rpc = createRpcClient({ bin, args: [], log: () => {} });
  t.after(() => rpc.stop());

  const received = [];
  rpc.onNotification((message) => {
    if (message.method === "receive") received.push(message.params.envelope);
  });

  const result = await rpc.request("send", { recipient: ["U1"], message: "hello" });
  assert.equal(result.timestamp, 42);
  for (let i = 0; i < 100 && !received.length; i += 1) {
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  assert.deepEqual(received, [{ sourceUuid: "U1" }]);

  const accounts = await rpc.request("listAccounts");
  assert.equal(accounts[0].uuid, "SELF");
});

test("an RPC error rejects with the daemon message", async (t) => {
  const bin = fakeCli(
    t,
    `
const readline = require("node:readline");
const rl = readline.createInterface({ input: process.stdin });
rl.on("line", (line) => {
  const request = JSON.parse(line);
  console.log(JSON.stringify({ jsonrpc: "2.0", id: request.id, error: { code: -1, message: "not linked" } }));
});
setInterval(() => {}, 1000);
`
  );

  const rpc = createRpcClient({ bin, args: [], log: () => {} });
  t.after(() => rpc.stop());
  await assert.rejects(() => rpc.request("send", {}), /not linked/);
});
