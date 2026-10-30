import { loadConfig as loadTelegramConfig } from "../../telegram/lib/config.mjs";

function list(value) {
  return String(value ?? "")
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function integer(value, fallback, minimum = 0) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) && parsed >= minimum ? parsed : fallback;
}

export function loadConfig(env = process.env) {
  const base = loadTelegramConfig(env);
  return {
    ...base,
    account: String(env.DHUN_SIGNAL_ACCOUNT ?? "").trim(),
    cli: String(env.DHUN_SIGNAL_CLI ?? "signal-cli").trim(),
    dataDir: String(env.DHUN_SIGNAL_DATA_DIR ?? "").trim(),
    groups: new Set(list(env.DHUN_SIGNAL_ALLOWED_GROUPS)),
    senders: new Set(list(env.DHUN_SIGNAL_ALLOWED_SENDERS)),
    open: env.DHUN_SIGNAL_OPEN === "1",
    dmOpen: env.DHUN_SIGNAL_DM_OPEN === "1",
    answerAll: env.DHUN_SIGNAL_ANSWER_ALL === "1",
    botNames: list(env.DHUN_SIGNAL_BOT_NAMES ?? "dhun,commons,500-acre"),
    askTimeoutMs: integer(env.DHUN_SIGNAL_ASK_TIMEOUT_MS, 90000, 50),
    askPollMs: integer(env.DHUN_SIGNAL_ASK_POLL_MS, 1500, 20),
    channelName: "Signal",
    accessEnv: "DHUN_SIGNAL_ALLOWED_GROUPS",
  };
}
