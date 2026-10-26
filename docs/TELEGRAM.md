# Telegram relay

The Telegram relay is an optional local service that lets you read Dhun Commons state
and queue a room message from Telegram, without giving the bot custody, a wallet or a
signing key. It is a plain Node process with no dependencies; it does not run on the
Logos network and it is not a second admin surface for the treasury.

Everything it reports is either a file the app publishes or a public sequencer read.
Nothing it does is signed, and no command approves or moves value.

## What moves where

```text
Logos Basecamp (dhun_commons module)          Telegram Bot API
        │  publishTelegramState (every 5s)          ▲
        ▼                                           │ long poll (25s)
  dhun_relay/state.json ──────────┐                 │
                                  ├─ telegram/bridge.mjs ── commands + pushes
  dhun_relay/inbox.json  ◄────────┘                 │
  dhun_relay/bridge.json  (heartbeat)               ▼
  dhun_relay/acked.json                your Telegram chat
```

`dhun_relay/` lives at
`~/Library/Application Support/Logos/LogosBasecamp/dhun_relay/`.
The path can be overridden with `DHUN_RELAY_DIR` on both sides; the app side has no
setting for it, so keep the default unless you are only running the bridge tests.

| File | Written by | Contents |
| --- | --- | --- |
| `state.json` | the app, atomically via `QSaveFile` | page, role, pending proposals with approvals, offers, today's field activities, the last 8 room messages, cached chain status/height/accounts/last transfer, and the current queue length |
| `inbox.json` | the bridge | up to 100 queued `/say` messages, each `{ id, kind: "room", text, at, chatId, author }` |
| `bridge.json` | the bridge | heartbeat `{ at, pid, bot, sequencer, relayDir, pollMs }`; the app shows `BRIDGE ONLINE` while it is under 45 seconds old |
| `acked.json` | the app | ids the operator posted or dismissed, capped at 200 |

The app writes `state.json` only while a Dhun Commons view is open. Open the module once
after launching Basecamp; otherwise `TELEGRAM RELAY` reads `BACKEND OFFLINE`.

## Setup

1. Create a bot with [@BotFather](https://t.me/BotFather) and keep its token out of the
   repository. The token is the whole bot identity; anyone with it can read the bot's
   updates.
2. Start the bridge once with no allowlist to discover your chat id:

   ```sh
   cd telegram
   TELEGRAM_BOT_TOKEN=<token> npm start
   ```

   Send `/id` to the bot, read the reply, then stop the bridge.
3. Run it with your chat id allowed:

   ```sh
   cd telegram
   TELEGRAM_BOT_TOKEN=<token> TELEGRAM_ALLOWED_CHAT_IDS=<chat id> npm start
   ```

   Then open **Dhun Commons → Coordination room** in Basecamp. The
   `TELEGRAM RELAY` bar above the composer should read `BRIDGE ONLINE` within a few
   seconds and show the last snapshot age.

`npm run check` validates configuration without contacting Telegram:

```sh
TELEGRAM_BOT_TOKEN=<token> TELEGRAM_ALLOWED_CHAT_IDS=<chat id> npm run check
```

| Variable | Default | Meaning |
| --- | --- | --- |
| `TELEGRAM_BOT_TOKEN` | — | required; bot token from @BotFather |
| `TELEGRAM_ALLOWED_CHAT_IDS` | — | comma-separated chat ids; every other chat is ignored |
| `DHUN_TELEGRAM_OPEN` | unset | `1` disables the allowlist. Only for a throwaway bot |
| `DHUN_RELAY_DIR` | `~/Library/Application Support/Logos/LogosBasecamp/dhun_relay` | relay directory |
| `DHUN_WALLET_DIR` | `…/module_data/lez_core` | where the bridge looks for `*/dhun_chain/roles.json` to map role → public account |
| `LEZ_SEQUENCER_URL` | `https://testnet.lez.logos.co` | read-only sequencer endpoint |
| `DHUN_POLL_MS` | `15000` | heartbeat and push interval |
| `DHUN_TELEGRAM_POLL_SECONDS` | `25` | long-poll wait |
| `DHUN_QUIET` | unset | `1` suppresses log lines |

The bridge never reads `storage.json`, never asks for the wallet password and never
touches the recovery phrase. It needs `roles.json` only to learn which public account id
belongs to Funder, Dhun and Steward. If that file is missing it still answers `/status`,
`/proposals`, `/activity` and `/room` from `state.json`; only `/balance` and `/verify`
need the account mapping and a reachable sequencer.

## Commands

| Command | Reply |
| --- | --- |
| `/start`, `/help` | the command list and the custody disclaimer |
| `/id` | the chat id, for the allowlist |
| `/ping` | liveness with the time |
| `/status` | app page and role, snapshot age, block height, balances, last transfer, queue length |
| `/balance` | the three public accounts, read from the sequencer for that request |
| `/verify <64 hex>` | the sequencer record for a transfer hash. Reports *submitted / included*, never *settled*, and says inclusion is not a finality guarantee |
| `/proposals` | open proposals with approvals and quorum, and a note that approval happens in Wallet |
| `/inventory [season]` | the offer list from the snapshot, optionally filtered by season |
| `/activity` | today's field activities from the snapshot |
| `/room` | the tail of the coordination room |
| `/say <text>` | queues the text in `inbox.json`; the app shows it under `TELEGRAM RELAY`, where **Post to room** adds it and **Dismiss** acknowledges it |
| `/update on`, `/update off` | starts or stops pushes for block-height changes and transfer-status changes (default off) |

Unauthorized chats get one short refusal and are ignored afterwards. Pushes are
deduplicated: a block push fires only when the height changes, and a transfer push only
when the hash or the confirmed flag changes.

## The app side

`Main.qml` publishes the snapshot every 5 seconds and polls the inbox every 4 seconds
through the module's `publishTelegramState`, `telegramInbox` and `ackTelegramMessage`
slots. New queued ids raise a toast. The relay bar sits above the room composer and
offers:

- **Post to room** — appends `Telegram · <author>: <text>` to the Multisig room, mirrors
  it to Logos Messaging with the normal room mirror (so it is *submitted* to the local
  node, not peer-delivered), and acknowledges the id.
- **Dismiss** — acknowledges without adding anything to the room.
- **Publish snapshot** — forces an immediate publish instead of waiting for the timer.

Relay messages are unsigned text. Posting one does not approve a proposal, does not
carry a signature and does not touch the treasury state machine beyond the room
transcript.

## Honest boundary

- No bot token exists in this workspace. The bridge was exercised against a local stub
  Bot API and the live sequencer; real Telegram delivery is not claimed here.
- The Telegram Bot API is a third party. Whatever you send the bot and whatever it
  replies is visible to Telegram, and the relay files are readable by your OS account.
  Do not paste the recovery phrase, wallet contents or anything you would not put in the
  room.
- The bridge only reads public account balances. It does not decrypt notes, sign
  transactions, call `lez_core`, or write to the wallet directory.
- Sequencer inclusion is not finality, and the bot says so in `/verify`.

## Running it at login (optional)

A minimal launchd agent, with the token in a private file rather than in the plist:

```text
~/Library/LaunchAgents/life.dhun.telegram-bridge.plist
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>life.dhun.telegram-bridge</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/env</string>
    <string>node</string>
    <string>/ABSOLUTE/PATH/dhun-commons/telegram/bridge.mjs</string>
  </array>
  <key>WorkingDirectory</key><string>/ABSOLUTE/PATH/dhun-commons/telegram</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>TELEGRAM_BOT_TOKEN</key><string>REPLACE_AT_RUNTIME</string>
    <key>TELEGRAM_ALLOWED_CHAT_IDS</key><string>REPLACE_AT_RUNTIME</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/dhun-bridge.log</string>
  <key>StandardErrorPath</key><string>/tmp/dhun-bridge.err</string>
</dict>
</plist>
```

A plist is world-readable on most setups. If you use launchd, put the two values in a
`chmod 600` environment file instead and have a wrapper script source it. For occasional
use, `npm start` in a terminal is simpler and leaves no copy of the token on disk.

## Tests

```sh
cd telegram
npm test
```

Eight tests run against an in-process stub Bot API and stub sequencer: base58 and lepta
conversion, `/status`, `/balance`, the unauthorized-chat refusal, the `/verify` wording,
the `/say` → inbox round trip, snapshot-driven commands, and block/transfer pushes. They
do not contact Telegram or the real sequencer.

The QML side adds five relay assertions to `tests/Flow.qml` (queue exposure, post,
attribution, selective acknowledgement, dismiss), for 72 checks total.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| `409 Conflict` in the log | a second poller is running with the same token (another terminal, launchd, or a webhook) |
| `401 Unauthorized` | the token is wrong or was revoked by @BotFather |
| Bot replies `Not authorized.` | the chat id is not in `TELEGRAM_ALLOWED_CHAT_IDS` |
| Bar shows `NO BRIDGE` | `bridge.json` is missing or older than 45 seconds; start the bridge |
| Bar shows `BACKEND OFFLINE` | Basecamp has not opened Dhun Commons, or the module host is not available |
| Queue never empties | Post or Dismiss did not reach the backend; check Basecamp's log, then press **Publish snapshot** |
| `/balance` says it has no account mapping | no `roles.json` under `DHUN_WALLET_DIR` (create the wallet in the app first) |
