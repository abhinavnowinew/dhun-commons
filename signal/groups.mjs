#!/usr/bin/env node
// Print the Signal groups this account is a member of, so the bridge can be
// allowlisted by id instead of by display name.
import { loadConfig } from "./lib/config.mjs";
import { createRpcClient } from "./lib/rpc.mjs";

const config = loadConfig();
if (!config.account) {
  console.error("Set DHUN_SIGNAL_ACCOUNT first (see link.mjs).");
  process.exit(1);
}

const args = [];
if (config.dataDir) args.push("--data-dir", config.dataDir);
args.push("-a", config.account, "jsonRpc");

const rpc = createRpcClient({ bin: config.cli, args, log: (line) => console.error(line) });
try {
  const groups = await rpc.request("listGroups");
  const list = Array.isArray(groups) ? groups : [];
  if (!list.length) {
    console.log("No groups yet. Add the linked account to your Signal group, then run this again.");
  }
  for (const group of list) {
    const members = Array.isArray(group.members) ? group.members.length : 0;
    const current = config.groups.has(group.id) ? "  ← allowlisted" : "";
    console.log(`${group.name || "(unnamed)"}\n  id: ${group.id}\n  members: ${members}${current}\n`);
  }
} catch (error) {
  console.error(`listGroups failed: ${error.message}`);
  process.exit(1);
} finally {
  rpc.stop();
}
