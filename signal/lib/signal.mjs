import { splitText } from "../../telegram/lib/telegram.mjs";
import { createRpcClient } from "./rpc.mjs";
import { splitChatKey } from "./envelope.mjs";

// Transport over `signal-cli jsonRpc` on stdio. The bridge only needs three
// things from it: deliver incoming envelopes, send text to a chat key, and say
// who the linked account is.
export function createSignalTransport(config, { log = () => {}, rpcFactory = createRpcClient } = {}) {
  const args = [];
  if (config.dataDir) args.push("--data-dir", config.dataDir);
  args.push("-a", config.account, "jsonRpc");
  const rpc = rpcFactory({ bin: config.cli, args, log });

  let self = { number: config.account, uuid: "" };
  const listeners = new Set();

  rpc.onNotification((message) => {
    if (message.method === "receive") {
      const envelope = message.params?.envelope ?? message.params?.result?.envelope;
      for (const listener of listeners) listener(envelope);
    } else if (message.method === "exit") {
      for (const listener of listeners) listener(null);
    }
  });

  async function resolveSelf() {
    try {
      const accounts = await rpc.request("listAccounts");
      const list = Array.isArray(accounts) ? accounts : [];
      const entry = list.find((item) => item.number === config.account) ?? list[0];
      if (entry?.uuid) self = { number: entry.number ?? config.account, uuid: entry.uuid };
    } catch {
      // Older builds do not expose listAccounts; mention detection then falls
      // back to name matching and direct replies.
    }
    return self;
  }

  return {
    async start() {
      await resolveSelf();
      return self;
    },
    self() {
      return self;
    },
    onEnvelope(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    async send(chatId, text) {
      const { kind, id } = splitChatKey(chatId);
      for (const chunk of splitText(text)) {
        const params = kind === "group" ? { groupId: id } : { recipient: [id] };
        await rpc.request("send", { ...params, message: chunk });
      }
    },
    stop() {
      rpc.stop();
    },
  };
}
