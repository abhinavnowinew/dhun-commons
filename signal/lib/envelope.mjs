// Turn a signal-cli envelope into the shape the shared command engine and the
// ask queue understand. Chat keys are prefixed so a group id can never collide
// with a sender id.
export function chatKey(kind, id) {
  return `${kind}:${id}`;
}

export function splitChatKey(key) {
  const text = String(key ?? "");
  const mark = text.indexOf(":");
  if (mark === -1) return { kind: "dm", id: text };
  return { kind: text.slice(0, mark), id: text.slice(mark + 1) };
}

export function normalizeEnvelope(envelope, self = {}) {
  if (!envelope || typeof envelope !== "object") return null;
  const data = envelope.dataMessage;
  if (!data || typeof data.message !== "string") return null;
  if (envelope.sourceUuid && self.uuid && envelope.sourceUuid === self.uuid) return null;

  const group = data.groupInfo?.groupId || envelope.dataMessage?.groupInfo?.groupId;
  const groupName = data.groupInfo?.groupName || "";
  const kind = group ? "group" : "dm";
  const id = group || envelope.sourceUuid || envelope.sourceNumber || envelope.source;
  if (!id) return null;

  const name = envelope.sourceName || envelope.sourceNumber || envelope.sourceUuid || "Signal";
  const mentions = Array.isArray(data.mentions) ? data.mentions : [];
  const quote = data.quote && typeof data.quote === "object" ? data.quote : null;

  return {
    channel: "signal",
    chatId: chatKey(kind, id),
    chatKind: kind,
    groupId: group || "",
    groupName,
    text: data.message,
    from: {
      uuid: envelope.sourceUuid || "",
      number: envelope.sourceNumber || envelope.source || "",
      name,
    },
    mentionsSelf: Boolean(
      self.uuid && mentions.some((mention) => mention?.uuid === self.uuid)
    ),
    quotesSelf: Boolean(self.uuid && quote?.author === self.uuid),
    quotedText: typeof quote?.text === "string" ? quote.text : "",
    sentAt: Number(envelope.timestamp ?? data.timestamp ?? 0),
  };
}

// The engine speaks Telegram update shapes; adapt rather than fork it.
export function toEngineUpdate(message) {
  return {
    message: {
      chat: { id: message.chatId },
      text: message.text,
      from: {
        id: message.from.uuid || message.from.number,
        first_name: message.from.name,
      },
    },
  };
}

export function isCommand(text) {
  return String(text ?? "").trim().startsWith("/");
}

export function addressesBot(message, { botNames = [], answerAll = false } = {}) {
  if (message.mentionsSelf || message.quotesSelf) return true;
  if (answerAll) return true;
  const text = String(message.text ?? "").toLowerCase();
  const stem = text.replace(/^\/\S+\s*/, "");
  return botNames.some((name) => name && stem.includes(String(name).toLowerCase()));
}
