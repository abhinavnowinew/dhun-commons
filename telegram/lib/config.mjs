import os from "node:os";
import path from "node:path";

export function defaultRelayDir() {
  return path.join(
    os.homedir(),
    "Library",
    "Application Support",
    "Logos",
    "LogosBasecamp",
    "dhun_relay"
  );
}

export function defaultWalletRoot() {
  return path.join(
    os.homedir(),
    "Library",
    "Application Support",
    "Logos",
    "LogosBasecamp",
    "module_data",
    "lez_core"
  );
}

function integer(value, fallback, minimum = 0) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) && parsed >= minimum ? parsed : fallback;
}

function chatIds(value) {
  return new Set(
    String(value ?? "")
      .split(",")
      .map((entry) => entry.trim())
      .filter(Boolean)
  );
}

export function loadConfig(env = process.env) {
  const token = String(env.TELEGRAM_BOT_TOKEN ?? "").trim();
  const quiet = env.DHUN_QUIET === "1";
  return {
    token,
    apiBase: String(env.DHUN_TELEGRAM_API_BASE ?? "https://api.telegram.org").replace(/\/+$/, ""),
    allowed: chatIds(env.TELEGRAM_ALLOWED_CHAT_IDS),
    open: env.DHUN_TELEGRAM_OPEN === "1",
    relayDir: String(env.DHUN_RELAY_DIR ?? defaultRelayDir()),
    walletRoot: String(env.DHUN_WALLET_DIR ?? defaultWalletRoot()),
    sequencer: String(env.LEZ_SEQUENCER_URL ?? "https://testnet.lez.logos.co").replace(/\/+$/, ""),
    pollMs: integer(env.DHUN_POLL_MS, 15000, 1),
    longPollSeconds: integer(env.DHUN_TELEGRAM_POLL_SECONDS, 25, 0),
    log: quiet ? () => {} : (...args) => console.log(...args),
  };
}
