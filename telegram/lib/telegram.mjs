export function splitText(text, limit = 3900) {
  const value = String(text ?? "");
  if (value.length <= limit) return [value];
  const chunks = [];
  let current = "";
  for (const line of value.split("\n")) {
    if ((current + "\n" + line).length > limit && current) {
      chunks.push(current);
      current = line;
    } else {
      current = current ? `${current}\n${line}` : line;
    }
    while (current.length > limit) {
      chunks.push(current.slice(0, limit));
      current = current.slice(limit);
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

export function createTelegramApi(config, fetchImpl = fetch) {
  const base = `${config.apiBase}/bot${config.token}`;

  function redact(text) {
    return config.token ? String(text).split(config.token).join("<token>") : String(text);
  }

  async function call(method, payload, signal) {
    let response;
    try {
      response = await fetchImpl(`${base}/${method}`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload ?? {}),
        signal: signal ?? AbortSignal.timeout(30000),
      });
    } catch (error) {
      throw new Error(redact(error.message));
    }
    let body = null;
    try {
      body = await response.json();
    } catch {
      body = null;
    }
    if (!body || body.ok !== true) {
      const description = body?.description || `HTTP ${response.status}`;
      const error = new Error(redact(description));
      error.status = response.status;
      error.retryAfter = body?.parameters?.retry_after;
      throw error;
    }
    return body.result;
  }

  return {
    call,
    redact,
    getMe: () => call("getMe", {}),
    getUpdates: (offset, signal) =>
      call(
        "getUpdates",
        { offset, timeout: config.longPollSeconds, allowed_updates: ["message"] },
        signal
      ),
    async sendMessage(chatId, text) {
      for (const chunk of splitText(text)) {
        await call("sendMessage", {
          chat_id: chatId,
          text: chunk,
          disable_web_page_preview: true,
        });
      }
    },
  };
}
