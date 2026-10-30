#!/usr/bin/env node
// Link this Mac as a secondary Signal device. `signal-cli link` prints a
// sgnl:// URI; Signal only accepts it by scanning, so render it as a QR image.
import { execFile, spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { loadConfig } from "./lib/config.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));

function renderQr(uri) {
  const out = path.join(os.tmpdir(), `dhun-signal-link-${Date.now()}.png`);
  const swift = path.join(here, "lib", "qr.swift");
  const bin = path.join(os.tmpdir(), "dhun-signal-qr");
  if (!fs.existsSync(bin) || fs.statSync(bin).mtimeMs < fs.statSync(swift).mtimeMs) {
    const built = spawn("/usr/bin/swiftc", ["-O", swift, "-o", bin], { stdio: "inherit" });
    if (built.status !== 0) return null;
  }
  const done = spawn(bin, [uri, out], { stdio: "inherit" });
  return done.status === 0 ? out : null;
}

const config = loadConfig();
if (!config.account) {
  console.error("Set DHUN_SIGNAL_ACCOUNT to the number the bot should link to, e.g. DHUN_SIGNAL_ACCOUNT=+9198... node link.mjs");
  process.exit(1);
}

const deviceName = process.argv[2] || "Dhun Commons";
const args = [];
if (config.dataDir) args.push("--data-dir", config.dataDir);
args.push("-a", config.account, "link", "-n", deviceName);

console.log(`Linking ${config.account} as "${deviceName}"…`);
const child = spawn(config.cli, args, { stdio: ["ignore", "pipe", "pipe"] });

let printed = false;
let buffer = "";
const onData = (chunk) => {
  buffer += chunk.toString();
  const match = buffer.match(/sgnl:\/\/linkdevice\?[^\s"']+/);
  if (match && !printed) {
    printed = true;
    const uri = match[0];
    const png = renderQr(uri);
    console.log("\nOn your phone: Signal → Settings → Linked devices → Link new device.");
    if (png) {
      console.log(`QR image: ${png}`);
      execFile("open", [png], () => {});
    } else {
      console.log(`QR rendering failed. Link URI:\n${uri}`);
    }
    console.log("\nWaiting for the scan…");
  }
};
child.stdout.on("data", onData);
child.stderr.on("data", onData);

child.on("exit", (code) => {
  if (code === 0) {
    console.log("Linked. Next: add the bot to your Signal group, then run `node groups.mjs`.");
  } else {
    console.error(`signal-cli link exited with ${code}.`);
    process.exit(code ?? 1);
  }
});
