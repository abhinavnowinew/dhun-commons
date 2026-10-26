import { randomUUID } from "node:crypto";
import { formatBlock, lezFromLepta, shortHash } from "./chain.mjs";

const ROLE_LABELS = { funder: "Funder", dhun: "Dhun", steward: "Steward" };

function titleRole(role) {
  return ROLE_LABELS[String(role ?? "")] || String(role || "unknown");
}

function ageLabel(ms) {
  const seconds = Math.max(0, Math.round(ms / 1000));
  if (seconds < 3) return "just now";
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 48) return `${hours}h ago`;
  return `${Math.round(hours / 24)}d ago`;
}

function displayName(from) {
  if (!from) return "Telegram";
  const name = [from.first_name, from.last_name].filter(Boolean).join(" ").trim();
  return name || from.username || String(from.id ?? "Telegram");
}

function cleanError(message) {
  return String(message ?? "unknown error").replace(/\s+/g, " ").slice(0, 200);
}

function formatTime(at) {
  const date = new Date(Number(at));
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
}

const HELP = [
  "Dhun Commons relay",
  "/status — app snapshot, block height, balances",
  "/balance — the three LEZ accounts",
  "/verify <hash> — ask the sequencer about a transfer",
  "/proposals — pending multisig queue",
  "/inventory [season] — market stock from the snapshot",
  "/activity — field work recorded today",
  "/room — last room messages",
  "/say <text> — queue a message for the Dhun Commons room",
  "/update on|off — push block and transfer changes here",
  "/id — this chat's id",
].join("\n");

export function createEngine(config, deps) {
  const chain = deps.chain;
  const relay = deps.relay;
  const clock = deps.now ?? Date.now;
  const startedAt = clock();
  let botName = "";
  let lastHeight = null;
  let lastTxKey = "";
  let lastTickAt = 0;

  function allowed(chatId) {
    return config.open || config.allowed.has(String(chatId));
  }

  function unauthorized(chatId) {
    return [
      "This relay is not bound to this chat.",
      `Chat id: ${chatId}`,
      "Add it to TELEGRAM_ALLOWED_CHAT_IDS and restart the bridge.",
    ].join("\n");
  }

  function snapshot() {
    return relay.readSnapshot(config.relayDir);
  }

  function snapshotLine(snap) {
    if (!snap) return "App · no snapshot yet — open Dhun Commons once.";
    const data = snap.data;
    return `App · ${data.page ?? "?"} · role ${titleRole(data.role)} · snapshot ${ageLabel(clock() - snap.at)}`;
  }

  async function balanceLine() {
    const wallet = chain.roles();
    if (!wallet) return "Balances · no LEZ wallet found on this Mac.";
    const parts = [];
    let failures = 0;
    for (const role of ["funder", "dhun", "steward"]) {
      const hex = wallet.roles[role];
      if (!hex) continue;
      try {
        const lepta = await chain.balanceLepta(hex);
        parts.push(`${ROLE_LABELS[role]} ${lezFromLepta(lepta) ?? "?"} LEZ`);
      } catch {
        failures += 1;
      }
    }
    if (!parts.length) return "Balances · sequencer did not answer the balance queries.";
    return `Balances · ${parts.join(" · ")}${failures ? " · some unread" : ""}`;
  }

  async function balancesDetail(snap) {
    const wallet = chain.roles();
    if (!wallet) return ["Balances · no LEZ wallet found on this Mac."];
    const lines = [];
    let fresh = 0;
    for (const role of ["funder", "dhun", "steward"]) {
      const hex = wallet.roles[role];
      if (!hex) continue;
      try {
        const lepta = await chain.balanceLepta(hex);
        lines.push(`${ROLE_LABELS[role]} · ${lezFromLepta(lepta) ?? "?"} LEZ · ${shortHash(hex, 6)}`);
        fresh += 1;
      } catch {
        lines.push(`${ROLE_LABELS[role]} · unavailable · ${shortHash(hex, 6)}`);
      }
    }
    if (!lines.length) return ["Balances · no party accounts in the wallet."];
    lines.push(fresh === lines.length ? "Read from the sequencer just now." : "Some balances could not be read.");
    return lines;
  }

  async function status(snap) {
    const lines = ["Dhun Commons · live check", snapshotLine(snap)];
    let height = null;
    try {
      height = await chain.height();
    } catch {
      height = null;
    }
    if (height !== null) {
      lines.push(`Chain · block ${formatBlock(height)} · LEZ public testnet`);
    } else if (snap?.data?.chain?.height) {
      lines.push(`Chain · block ${formatBlock(snap.data.chain.height)} (cached, sequencer unreachable)`);
    } else {
      lines.push("Chain · sequencer unreachable");
    }
    lines.push(await balanceLine());
    const tx = snap?.data?.chain?.lastTx;
    if (tx?.txHash) {
      lines.push(
        tx.confirmed === true
          ? `Transfer · sequencer-reported, not a finality guarantee · ${shortHash(tx.txHash)}`
          : `Transfer · submitted, unverified · ${shortHash(tx.txHash)}`
      );
    }
    const queued = relay.inboxMessages(config.relayDir).length;
    lines.push(queued ? `Relay · ${queued} queued for the app` : "Relay · queue empty");
    return lines.join("\n");
  }

  function proposals(snap) {
    const list = Array.isArray(snap?.data?.proposals) ? snap.data.proposals : [];
    if (!list.length) return "No pending proposals in the app snapshot.";
    const lines = [`Pending proposals · ${snap ? `snapshot ${ageLabel(clock() - snap.at)}` : "no snapshot"}`];
    for (const item of list.slice(0, 8)) {
      const approvals = Array.isArray(item.approvals) ? item.approvals.length : Number(item.approvals) || 0;
      const quorum = Number(item.quorum) || 0;
      lines.push(
        `${item.id} · ${item.title} · ${item.amount ?? "?"} DHN · ${approvals}/${quorum || "?"} approvals`
      );
    }
    if (list.length > 8) lines.push(`+${list.length - 8} more in the app.`);
    lines.push("Approvals happen in Wallet; this bot never signs.");
    return lines.join("\n");
  }

  function inventory(snap, season) {
    const list = Array.isArray(snap?.data?.offers) ? snap.data.offers : [];
    if (!list.length) return "No inventory in the app snapshot. Open Market or Field once.";
    const wanted = String(season || "").trim().toLowerCase();
    const filtered = wanted
      ? list.filter((offer) => String(offer.season || "").toLowerCase().includes(wanted))
      : list;
    if (!filtered.length) return `No ${season} stock in the app snapshot.`;
    const lines = [`Inventory${wanted ? ` · ${season}` : ""} · snapshot ${ageLabel(clock() - snap.at)}`];
    for (const offer of filtered.slice(0, 8)) {
      lines.push(`${offer.id} · ${offer.title} · ${offer.price} DHN / ${offer.unit} · stock ${offer.stock}`);
    }
    if (filtered.length > 8) lines.push(`+${filtered.length - 8} more in the app.`);
    lines.push("Rehearsal inventory from the app; not live farmer data.");
    return lines.join("\n");
  }

  function activity(snap) {
    const list = Array.isArray(snap?.data?.activities) ? snap.data.activities : [];
    if (!list.length) return "No field work recorded for the current role today.";
    const lines = [`Field work today · snapshot ${ageLabel(clock() - snap.at)}`];
    for (const item of list.slice(0, 8)) {
      lines.push(`${formatTime(item.at)} · ${item.title} · ${item.status}`);
    }
    if (list.length > 8) lines.push(`+${list.length - 8} more in the app.`);
    lines.push("Local rehearsal data from the app snapshot.");
    return lines.join("\n");
  }

  function room(snap) {
    const list = Array.isArray(snap?.data?.messages) ? snap.data.messages : [];
    if (!list.length) return "No room messages in the app snapshot yet.";
    const lines = [`Room · ${snap.data.room ?? "room-msig"} · snapshot ${ageLabel(clock() - snap.at)}`];
    for (const message of list.slice(-6)) {
      const who = message.role === "system" ? "·" : titleRole(message.role);
      lines.push(`[${formatTime(message.at)}] ${who}: ${String(message.text ?? "").slice(0, 180)}`);
    }
    lines.push("Snapshot only; Logos Messaging peer delivery is separate.");
    return lines.join("\n");
  }

  async function verify(hash) {
    const value = String(hash ?? "").trim();
    if (!/^[0-9a-fA-F]{64}$/.test(value)) {
      return "Send a 32-byte transaction hash: /verify <64 hex characters>.";
    }
    let record;
    try {
      record = await chain.transaction(value);
    } catch (error) {
      return `Could not query the sequencer (${cleanError(error.message)}). The transfer remains unverified.`;
    }
    if (record === null || record === undefined) {
      return `Sequencer does not report ${shortHash(value, 12)}. It remains submitted, not settled.`;
    }
    return `Sequencer returned a record for ${shortHash(value, 12)}. That is the sequencer's view, not a finality guarantee — check an explorer before treating value as settled.`;
  }

  async function handleUpdate(update) {
    const message = update?.message;
    if (!message || typeof message.text !== "string") return [];
    const chatId = message.chat?.id;
    if (chatId === undefined) return [];
    if (!allowed(chatId)) return [unauthorized(chatId)];

    const text = message.text.trim();
    if (!text.startsWith("/")) return [];
    const space = text.search(/\s/);
    const command = (space === -1 ? text : text.slice(0, space)).replace(/@\w+$/, "").toLowerCase();
    const rest = space === -1 ? "" : text.slice(space + 1).trim();
    const snap = snapshot();

    try {
      switch (command) {
        case "/start":
          relay.writeHeartbeat(config.relayDir, heartbeat());
          return [
            `${HELP}\n\nYour chat id: ${chatId}`,
          ];
        case "/help":
          return [HELP];
        case "/id":
          return [`Chat id: ${chatId}`];
        case "/ping":
          return [`pong · bridge up ${ageLabel(clock() - startedAt)} · relay ${config.relayDir}`];
        case "/status":
          return [await status(snap)];
        case "/balance":
          return [(await balancesDetail(snap)).join("\n")];
        case "/verify":
          return [await verify(rest)];
        case "/proposals":
          return [proposals(snap)];
        case "/inventory":
          return [inventory(snap, rest)];
        case "/activity":
          return [activity(snap)];
        case "/room":
          return [room(snap)];
        case "/say": {
          const value = rest.slice(0, 500).trim();
          if (!value) return ["Send the message after the command: /say We need two more seed lots."];
          relay.appendInbox(config.relayDir, {
            id: randomUUID(),
            kind: "room",
            text: value,
            at: clock(),
            chatId: String(chatId),
            author: displayName(message.from),
          });
          return [
            "Queued for the app. Open Rooms → Telegram relay and press Post to add it to the room. Nothing is signed.",
          ];
        }
        case "/update": {
          const mode = rest.toLowerCase();
          if (mode !== "on" && mode !== "off") return ["Use /update on or /update off."];
          const chats = relay.subscribers(config.relayDir);
          if (mode === "on") chats.add(String(chatId));
          else chats.delete(String(chatId));
          relay.setSubscribers(config.relayDir, chats);
          return [
            mode === "on"
              ? "Push updates on: new blocks and transfer status changes will arrive here."
              : "Push updates off.",
          ];
        }
        default:
          if (command.startsWith("/")) return [`Unknown command ${command}.\n\n${HELP}`];
          return [];
      }
    } catch (error) {
      return [`Command failed: ${cleanError(error.message)}`];
    }
  }

  function heartbeat() {
    return {
      at: clock(),
      pid: process.pid,
      bot: botName,
      sequencer: config.sequencer,
      relayDir: config.relayDir,
      pollMs: config.pollMs,
    };
  }

  async function tick(send) {
    const at = clock();
    if (at - lastTickAt < config.pollMs) return;
    lastTickAt = at;
    try {
      relay.writeHeartbeat(config.relayDir, heartbeat());
    } catch {
      // Heartbeat is advisory; keep polling.
    }

    let height = null;
    try {
      height = await chain.height();
    } catch {
      return;
    }
    if (lastHeight === null) {
      lastHeight = height;
    } else if (height !== lastHeight) {
      const previous = lastHeight;
      lastHeight = height;
      for (const chat of relay.subscribers(config.relayDir)) {
        await send(chat, `Block ${formatBlock(height)} · LEZ public testnet (was ${formatBlock(previous)})`);
      }
    }

    const snap = snapshot();
    const tx = snap?.data?.chain?.lastTx;
    if (tx?.txHash) {
      const key = `${tx.txHash}:${tx.confirmed === true ? "reported" : "submitted"}`;
      if (lastTxKey && key !== lastTxKey) {
        const text =
          tx.confirmed === true
            ? `Transfer ${shortHash(tx.txHash)} is now reported by the sequencer. Not a finality guarantee — verify before settling.`
            : `Transfer ${shortHash(tx.txHash)} is submitted, not verified.`;
        for (const chat of relay.subscribers(config.relayDir)) await send(chat, text);
      }
      lastTxKey = key;
    }
  }

  return {
    handleUpdate,
    tick,
    setBot(name) {
      botName = String(name || "");
    },
    heartbeat,
    startedAt,
  };
}
