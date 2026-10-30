# Xenia — inference over Logos delivery

Dhun's assistant (and Signal free-text replies) routes prompts through
[**Xenia**](https://github.com/hackyguru/xenia) when its router is ready: the
`inference` core module seals the prompt to a provider, the provider runs a local
Ollama model and answers over the same Logos delivery content topic. No API key,
no inference server, no prompt text on the wire.

```
Dhun Commons (Basecamp)                          provider node (logoscore CLI)
inference module  ── /inference/1/<room>/json ──▶  inference_provider ──▶ ollama
        ▲                                                │
        └──────────── response {id, text, model} ◀───────┘
```

The assistant falls back in this order: **Xenia** (when the identity exists, is
unlocked and at least one provider is live) → **local Ollama loopback** →
**OpenRouter** (only if a key is configured) → **built-in guidance**. Kitchen
planning never uses Xenia or any remote provider; it stays loopback-only.

## What is installed where

| Piece | Where | Built from |
|-------|-------|-----------|
| `inference` core module | `~/Library/Application Support/Logos/LogosBasecamp/modules/inference` | `xenia/inference-core` (`nix build`) |
| Dhun Commons UI | `.../LogosBasecamp/plugins/dhun_commons` | this repo |
| `inference_provider` + `delivery_module` (dev) | `xenia/cli-provider/modules` | `cli-provider/setup-modules.sh` |
| `logoscore` CLI | `~/.logoscore-cli/bin/logoscore` | `nix build github:logos-co/logos-logoscore-cli/<rev>#cli` |

Dhun vendors the inference contract in [`interfaces/inference.lidl`](../interfaces/inference.lidl)
so its build never has to evaluate Xenia's nested flake.

## One-time: install the core module

```bash
cd xenia/inference-core
nix build . -o result
# extract variants/darwin-arm64/* + manifest.json + a `variant` file
# into ~/Library/Application Support/Logos/LogosBasecamp/modules/inference
```

Quit Basecamp while replacing modules, then reopen it. The Dhun launcher log
should show `Loading core dependencies for "dhun_commons" : QList("lez_core",
"chat_module", "inference")` and `Module loaded: inference`.

## One-time: provider node

`logoscore` is the headless host for the provider module. The rev below is the
one Xenia's deploy script pins as verified:

```bash
NIX_CONFIG="experimental-features = nix-command flakes" \
  nix build "github:logos-co/logos-logoscore-cli/679a9af8fd0064c2997c2ea3ed1fa53b422bfe0d#cli" \
  -o ~/.logoscore-cli

cd xenia/cli-provider
./setup-modules.sh          # stages delivery_module + inference_provider (nix builds)
```

Start ollama with a text-capable model, then run the provider:

```bash
ollama serve &                                  # or the Ollama app
INFERENCE_MODEL=qwen2.5vl:3b ./inference-provider.sh agora
```

- Room defaults to `agora`; both sides must use the same room. Dhun reads
  `DHUN_XENIA_ROOM` and otherwise uses `agora`.
- The provider listens on Waku TCP port `60010` (Basecamp uses `60000`), so both
  can run on one Mac.
- First run creates the provider's identity and prints its seed once into
  `/tmp/logoscore-inference.log`.
- `curl http://localhost:11434/api/tags` must list `INFERENCE_MODEL` or prompts
  come back `[inference failed]`.

## Identity, in the app

The Xenia identity is created or unlocked from the **Ask Dhun** panel — the app
never auto-creates one:

- *Create identity* → optional passphrase; the seed phrase is shown once in the
  chat and stored nowhere in Dhun.
- *Unlock* → passphrase for an encrypted key file. The hint explains which of
  the two is needed.

Availability is honest: the panel shows the room, the provider's model and the
reason when the router is not ready (no identity, locked, or no live provider).

## Verification

1. `curl -s http://localhost:11434/api/tags` lists the model.
2. Provider prints `provider id <40-hex fingerprint>` and its stats endpoint
   answers — `logoscore call inference_provider stats`.
3. In Basecamp, `aiStatus` shows `"provider": "xenia"`, `"mode":
   "xenia-delivery"`, the room and model; the assistant header reads
   `Xenia · <model>`.
4. Send a prompt: the reply bubble is tagged `Xenia · <model> · <n> s`, and the
   provider's `promptsSeen` / `responsesSent` counters increase.

## Limits

- Answered by the provider's local model, so latency and quality are the
  provider's — the app reports round-trip seconds, it cannot speed them up.
- A prompt that gets no response within 100 s returns an honest error; check the
  room, that the provider is running, and that both delivery nodes have peered.
- Dhun caps prompts at 12,000 characters and asks for answers under ~180 words.
- Signal replies use the same path; if Xenia is not ready the bridge answer falls
  back to built-in guidance rather than inventing a model reply.

## Transport note · 2026-10-30

On this Mac the app and the headless provider both use the `logos.test` preset
(cluster 2, Waku pubsub `/waku/2/rs/2/4`). The app-side routing and slot wiring are
in place — `xeniaState` starts delivery, `aiChat` prefers Xenia, and `/status`
answers over Signal — but provider capability announces did not cross between the
two nodes on the public fleet, so the app roster stayed empty and prompts fell
through to the local Ollama loopback path. A third rig node on the same cluster
behaved the same way in both directions.

The provider now accepts an optional direct libp2p dial to the app node:

```sh
export INFERENCE_DIAL_PEER=16Uiu2HAm…   # app delivery node peer id
export INFERENCE_DIAL_ADDR=/ip4/127.0.0.1/tcp/63569
```

Both variables must be set; the dial runs right after `start`. Treat direct peering
as an experiment, not a guarantee: it was wired but not yet observed to deliver a
roster update on this machine. Until it does, an honest `provider: "local"` reply
with the built-in/Ollama fallback is the expected behaviour, not a bug to paper
over.
