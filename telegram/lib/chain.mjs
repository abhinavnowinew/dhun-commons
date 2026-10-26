import fs from "node:fs";
import path from "node:path";

const BASE58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
export const LEPTA_DECIMALS = 9n;

export function base58EncodeHex(hex) {
  const clean = String(hex ?? "").trim().toLowerCase();
  if (!/^[0-9a-f]+$/.test(clean) || clean.length % 2 !== 0) return "";
  const bytes = Buffer.from(clean, "hex");
  let value = 0n;
  for (const byte of bytes) value = value * 256n + BigInt(byte);
  let encoded = "";
  while (value > 0n) {
    encoded = BASE58[Number(value % 58n)] + encoded;
    value /= 58n;
  }
  for (const byte of bytes) {
    if (byte !== 0) break;
    encoded = "1" + encoded;
  }
  return encoded || "1";
}

export function lezFromLepta(value) {
  const text = String(value ?? "").trim();
  if (!/^\d+$/.test(text)) return null;
  const lepta = BigInt(text);
  const whole = lepta / 10n ** LEPTA_DECIMALS;
  const fraction = lepta % 10n ** LEPTA_DECIMALS;
  if (fraction === 0n) return whole.toString();
  const digits = fraction.toString().padStart(Number(LEPTA_DECIMALS), "0").replace(/0+$/, "");
  return `${whole}.${digits}`;
}

export function formatBlock(height) {
  const value = Number(height);
  return Number.isFinite(value) ? value.toLocaleString("en-US") : String(height ?? "");
}

export function shortHash(hash, head = 8) {
  const text = String(hash ?? "");
  return text.length > head ? `${text.slice(0, head)}…` : text;
}

export function discoverRoles(root) {
  let entries = [];
  try {
    entries = fs.readdirSync(root, { withFileTypes: true });
  } catch {
    return null;
  }
  const candidates = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const dir = path.join(root, entry.name, "dhun_chain");
    const file = path.join(dir, "roles.json");
    try {
      const stat = fs.statSync(file);
      const data = JSON.parse(fs.readFileSync(file, "utf8"));
      const roles = data && typeof data.roles === "object" ? data.roles : {};
      if (Object.keys(roles).length > 0) candidates.push({ dir, roles, mtimeMs: stat.mtimeMs });
    } catch {
      // Not a wallet directory; keep looking.
    }
  }
  candidates.sort((a, b) => b.mtimeMs - a.mtimeMs);
  return candidates[0] ?? null;
}

export function createChain(config, fetchImpl = fetch) {
  async function rpc(method, params, timeoutMs = 15000) {
    const response = await fetchImpl(config.sequencer, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!response.ok) throw new Error(`sequencer HTTP ${response.status}`);
    const body = await response.json();
    if (body && body.error) {
      const message = body.error.message || body.error.code || "sequencer error";
      throw new Error(String(message));
    }
    return body ? body.result : null;
  }

  return {
    rpc,
    async height() {
      const value = await rpc("getLastBlockId", []);
      const height = Number(value);
      if (!Number.isFinite(height)) throw new Error("sequencer returned no block height");
      return height;
    },
    async balanceLepta(accountHex) {
      const address = base58EncodeHex(accountHex);
      if (!address) throw new Error("invalid account id");
      const value = await rpc("getAccountBalance", { account_id: address });
      const text = String(value ?? "").trim();
      if (!/^\d+$/.test(text)) throw new Error("sequencer returned no balance");
      return text;
    },
    async transaction(hash) {
      return rpc("getTransaction", { tx_hash: String(hash).trim() });
    },
    roles() {
      return discoverRoles(config.walletRoot);
    },
  };
}
