# Signal relay

The Signal relay lets a Signal group talk to Dhun Commons. You link your own Signal
number as a secondary device, the bridge reads group messages with `signal-cli`, and
anything addressed to the app is queued for the Basecamp module. The module answers
through the same assistant that runs in the app, and the bridge posts the reply back
into the group.

It is the same channel-agnostic engine as the Telegram relay (`telegram/lib/commands.mjs`)
with a second transport and one addition: free-text questions are escalated to the app
as *asks*, and the app answers them as *answers*. Nothing is signed; no command moves
value.

## What moves where

```text
Signal group ──► signal-cli (linked device) ──► signal/bridge.mjs
                                                      │
                          commands:  /status /balance … (same as Telegram)
                          questions: dhun_commons  ──► dhun_relay/asks.json
                                                      ▲
  requests answered by the app:  dhun_relay/answers.json ──► reply in the group
  heartbeat: dhun_relay/signal_bridge.json
```

`dhun_relay/` is the same folder the Telegram relay uses:
`~/Library/Application Support/Logos/LogosBasecamp/dhun_relay/`.

| File | Written by | Contents |
| --- | --- | --- |
| `asks.json` | the bridge | up to 30 free-text questions `{ id, channel: "signal", chatId, chatKind, groupName, author, authorId, text, at }` |
| `answers.json` | the app | up to 50 answers `{ id, channel: "signal", text, source: "dhun_commons", at }` |
| `signal_bridge.json` | the bridge | heartbeat `{ at, pid, channel: "signal", account, pending }` |
| `state.json`, `inbox.json`, … | shared | published and polled exactly as in the Telegram relay |

The app removes an answered ask and writes the answer atomically (`QSaveFile`). The
bridge matches answers by ask id, posts the text, then drops the ask. A question that
is not answered within `DHUN_SIGNAL_ASK_TIMEOUT_MS` gets one honest notice and is
dropped; it is never answered silently or invented.

## Linking your number

Signal does not give bots their own number; the bridge is a *linked device* of your
account. Linking shows a QR code that you scan from your phone
(**Settings → Linked devices → Link new device**).

```sh
cd signal
npm run link -- --account +91XXXXXXXXXX
```

The script starts `signal-cli link` in a throwaway data directory, renders the `sgnl://`
URI as a QR PNG with CoreImage, and opens the image. Scanning it links the device.
Keep that data directory: it holds the device keys.

## Finding the group id

```sh
cd signal
npm run groups -- --account +91XXXXXXXXXX
```

Prints every group's name, base64 id and member count, and marks the ids already in
`DHUN_SIGNAL_ALLOWED_GROUPS`. Copy the id of the group Dhun should answer in.

## Running the bridge

```sh
cd signal
DHUN_SIGNAL_ACCOUNT=+91XXXXXXXXXX \
DHUN_SIGNAL_ALLOWED_GROUPS=<group id> \
npm start
```

Then open Dhun Commons in Basecamp. The module answers asks from its relay timer
(every 6 seconds) and the reply appears in the group. `npm run check` validates the
account, allowlist and `signal-cli` presence without contacting Signal.

| Variable | Default | Meaning |
| --- | --- | --- |
| `DHUN_SIGNAL_ACCOUNT` | — | required; the linked account's number |
| `DHUN_SIGNAL_CLI` | `signal-cli` | binary path |
| `DHUN_SIGNAL_DATA_DIR` | `~/.local/share/dhun-signal` | signal-cli data directory (linked-device keys) |
| `DHUN_SIGNAL_ALLOWED_GROUPS` | — | comma-separated group ids; everything else is ignored |
| `DHUN_SIGNAL_ALLOWED_SENDERS` | — | optional direct-message allowlist (sender uuid or number) |
| `DHUN_SIGNAL_OPEN` | unset | `1` disables the group allowlist (throwaway only) |
| `DHUN_SIGNAL_DM_OPEN` | unset | `1` allows 1:1 messages from anyone |
| `DHUN_SIGNAL_ANSWER_ALL` | unset | `1` answers every free-text message, not only addressed ones |
| `DHUN_SIGNAL_BOT_NAMES` | `dhun,commons,500-acre` | keywords that address the app in a group |
| `DHUN_SIGNAL_ASK_TIMEOUT_MS` | `90000` | how long to wait for the app |
| `DHUN_SIGNAL_ASK_POLL_MS` | `1500` | how often the bridge reads `answers.json` |
| `DHUN_RELAY_DIR` | `…/dhun_relay` | relay directory, shared with the Telegram bridge |
| `DHUN_QUIET` | unset | `1` suppresses log lines |

## How a question is addressed

In a group, a message reaches the app when **any** of these hold:

- it `@`-mentions the linked account,
- it quotes one of the app's earlier messages,
- it contains one of the bot names (`dhun`, `commons`, `500-acre` by default),
- `DHUN_SIGNAL_ANSWER_ALL=1`.

In an allowed direct message, the question is taken directly. Commands (`/status`,
`/balance`, `/proposals`, …) work the same way as in Telegram and are answered by the
bridge itself from the published snapshot.

## The app side

`src/dhun_commons_backend.cpp` adds two slots:

- `signalRelay()` — reads `asks.json`, drops ids that already have an answer, and
  returns the newest few asks plus the bridge heartbeat.
- `publishSignalAnswer(id, text)` — writes `answers.json` atomically and removes the
  ask.

`qml/Main.qml` polls `signalRelay()` every 6 seconds while the module is ready, sends
each unseen question through `aiChat` with the assistant's system prompt and the local
rehearsal context, and falls back to the built-in guidance when no model answers. The
answer is posted back with `publishSignalAnswer`. One question is in flight at a time.

## Tests

```sh
cd signal
npm test
```

The tests use a fake transport and relay directory. They cover allowlisted-group
commands, ignored groups, the unbound-DM refusal that names the sender's chat id, free
text addressed by name and by mention and by quote, plain chatter being ignored, the
timeout notice, and self-messages. `rpc.test.mjs` drives the JSON-RPC client against a
small fake `signal-cli`.

## Limits

- `signal-cli` is a third-party client; the bridge trusts what it reports.
- Replies are not end-to-end verifiable by the group — quote the app's message when you
  want to be sure which answer you are reading.
- The bridge never reads the wallet, never signs, and never approves a proposal.
