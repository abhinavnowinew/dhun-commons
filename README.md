# Dhun Commons

A wallet and coordination surface built for the Logos Basecamp, and an application-first proposal for [RFP-005 — Multisig and Coordination](https://github.com/logos-co/rfp/blob/master/RFPs/RFP-005-multisig-and-coordination.md).

The proposal is a **draft** in [docs/RFP-005-proposal.md](docs/RFP-005-proposal.md); it has not been submitted, funded or audited. The Basecamp module is a working demonstration with a real LEZ public-testnet account panel, not an on-chain multisig. See [docs/DEMO.md](docs/DEMO.md) for exactly which parts are local rehearsal data.

Three parties hold one seasonal treasury:

- **Funder** — issues and places DHN, funds programmes, approves releases.
- **Dhun Field Unit** — coordinates the landscape, competes for programme awards, claims cultivation windows.
- **Khejri Mandal (stewards)** — bids, executes field work and returns evidence.

The wallet demonstrates the full coordination loop in one place: a 2-of-3 proposal queue with decode-before-sign, external token sales, a resource market settled in DHN, competing project bids, time-boxed cultivation challenges, milestone release with a conservation covenant, an encrypted coordination room and the seasonal landscape atlas.

The **Field map** adds the physical layer: an embedded satellite studio showing where
produce is grown, a role-aware field calendar for sowing, irrigation, compost and
harvest work, short field clips and produce procurement straight from the map. Google
Maps is optional and activated with a key supplied at runtime; without it the page
falls back to a local plan view. Produce markers carry permanent ingredient names.
See [docs/FIELD-MAP.md](docs/FIELD-MAP.md).

The **Kitchen** tab turns a menu photo and a guest count into a sourcing plan from the
farm map, a waste-part plan for stalks, leaves, roots and peels, seasonal native
additions, and a guarded pantry of preserves over 20 days with a guest memorabilia
label. The planner is deterministic and offline; a free local vision model is optional
and restricted to loopback. See [docs/KITCHEN.md](docs/KITCHEN.md).

## What this build is

A **working demonstration** with two clearly separated layers:

- **LEZ public testnet.** A C++ backend on top of `lez_core` creates a local wallet,
  derives three public accounts (Funder, Dhun, Steward), reads the real block
  height and balances from `https://testnet.lez.logos.co`, and can submit a public
  transfer or poll a transaction hash. The Funder account was funded externally with
  0.1 LEZ on 2026-10-26 (funding transaction `a225dd37…` in block 67,236). A 0.01 LEZ
  Funder→Dhun transfer submitted from the app was included in block 67,293 when the
  sequencer resumed on 2026-10-27; at block 67,389 the sequencer reports balances
  Funder 0.089996136 / Dhun 0.01 / Steward 0 LEZ. Sequencer inclusion is not treated
  as finality.
- **Logos Messaging.** The Coordination room is backed by `chat_module` over
  `delivery_module` (preset `logos.test`). The module reports its node address, creates
  the "Dhun Commons" group and accepts mirrored messages. Peer delivery is not claimed:
  this device has no second peer, and a message is labelled *submitted* only.
- **Telegram relay (optional).** A local Node bridge answers `/status`, `/balance`,
  `/verify`, `/proposals`, `/inventory`, `/activity` and `/room`, pushes block and
  transfer changes, and queues `/say` messages into the room. It reads public data and
  the app snapshot only: no key material, no signatures, no transfers. See
  [docs/TELEGRAM.md](docs/TELEGRAM.md).
- **Kitchen planner.** Menu transcription, per-head quantities, farm sourcing, waste
  uses, native additions, food-safety gating and long-life preserves are deterministic
  local logic. Market stock, plot estimates and grower names are rehearsal data. No
  model is installed or bundled; the optional photo reader only calls a loopback
  OpenAI-compatible endpoint, and no photo leaves the machine.
- **DHN treasury rehearsal.** The proposal state machine, allowances, escrow accounting,
  conservation splits, role separation, room transcripts and ledger are real application
  logic running on deterministic local DHN data. Their `txid`s and signatures are demo
  strings; they are not LEZ transactions.

Other limits:

- DHN has no on-chain program and no real funds or market value.
- Room messages reach the local Logos Messaging node, not a second person: no peer has
  been observed on this device, so no message has been peer-delivered.
- Field inventory, activities, clips and orders are local rehearsal data. The embedded
  studio can load Google satellite tiles when a runtime Maps key is configured, but it
  is not a live farmer network and does not sync between users.
- The Telegram relay needs your own bot token and a running `telegram/bridge.mjs`. It
  never signs, approves or sends value, and Telegram messages only reach Logos
  Messaging when a member posts them to the room while the node is online.
- State persists locally through `QtCore.Settings` and can be reset from **About → Reset rehearsal**. The LEZ wallet files live in the wallet directory shown in the panel.

The production architecture, milestones, budget and RFP-005 requirement mapping are in
[docs/RFP-005-proposal.md](docs/RFP-005-proposal.md). Proposal-stage design decisions are
logged in [docs/design-decisions.md](docs/design-decisions.md).

## Build and install

Requires Nix with flakes enabled, Logos Basecamp 0.2.x and the `lez_core` module
(version 0.5.1) in the Basecamp modules directory. `dhun_commons` declares
`lez_core` as a string dependency (`"dependencies": ["lez_core"]`). Basecamp 0.2.3
only parses array-of-strings dependencies; an object such as
`{"name": "lez_core", "version": ">=0.5.1"}` is silently skipped by its loader.

```sh
git init
git add -A          # flakes only see tracked files
NIX_CONFIG="experimental-features = nix-command flakes" nix build .#lgx-portable
```

Use the **portable** target. The default `.#lgx` builds the `darwin-arm64-dev`
variant whose dylibs link into the Nix store; Basecamp 0.2.3 only loads a
`darwin-arm64` variant. Installing the dev payload looks like it works — the app
opens — but the QML bridge cannot load `dhun_commons_replica_factory.dylib` into
the bundle's Qt, so `logos.module("dhun_commons")` returns null and the on-chain
card stays at **CONNECTING**. Check with
`otool -L …/dhun_commons_replica_factory.dylib`: every Qt entry must read
`@rpath/…`, not `/nix/store/…`. The `lgpm` 0.2.3-dev CLI also appends `-dev` to the
platform name and therefore cannot install a portable LGX. Install it by
flattening the archive instead:

```sh
OUT=$(NIX_CONFIG="experimental-features = nix-command flakes" nix build .#lgx-portable --print-out-paths --no-link)
WORK=$(mktemp -d) && tar -xzf "$OUT/logos-dhun_commons-module.lgx" -C "$WORK"
INST="$HOME/Library/Application Support/Logos/LogosBasecamp/plugins/dhun_commons"
mkdir -p "$INST"
cp "$WORK/manifest.json" "$INST/"
cp -R "$WORK/assets" "$INST/"
cp -R "$WORK/variants/darwin-arm64/." "$INST/"
printf 'darwin-arm64' > "$INST/variant"
```

Restart Basecamp and open **Dhun Commons** from the module list. Install
`lez_core` first if it is not already in `modules/`. Both modules must be the
portable `darwin-arm64` variant.

The LGX archive is unsigned. The `lez_core` used during this evaluation was built
from the pinned upstream source (`logos-execution-zone` v0.3.1 / `lez_core` 0.5.1).
This machine has only the macOS Command Line Tools, not Xcode's Metal Toolchain, so
the wallet FFI was built with its CPU kernels and stub Metal outputs; see
[docs/DEMO.md](docs/DEMO.md#lez-testnet-panel). That is a local build workaround, not
an official Logos artifact. Use an official `lez_core` LGX when one is published.

## LEZ testnet panel

Open **Wallet** and find **On-chain accounts** above the proposal queue.

1. With no wallet on the device, choose a password of at least eight characters and
   press **Create wallet**. The backend creates the wallet file locally and three
   public accounts, then shows the recovery phrase once. Save it offline; Dhun Commons
   does not store it.
2. Press **Refresh** (or wait for the automatic read) to get the current testnet block
   height and the balances for the three accounts.
3. The Funder account on this device was funded externally with 0.1 LEZ
   (100,000,000 lepta) on 2026-10-26, and the panel shows that balance with the
   `CONNECTED` pill. Dhun started at 0 and holds 0.01 LEZ after the transfer below;
   Steward still reads 0. There is no in-app faucet: the funding came from an external
   claimd faucet, not from this app. The official `logos-co/lez-faucet` is still not
   usable against this deployment, because its startup fingerprint requires the
   sequencer's `getProgramIds` to report the `authenticated_transfer` and `pinata`
   programs while this sequencer reports only `privacy_preserving_circuit`.
4. Submit a **Public transfer**. With a funded sender the backend returns a real
   transaction hash and the card labels it **Submitted** with **Verify with sequencer**.
   It stays *submitted* until the sequencer reports the hash; a rejection from an
   unfunded account is shown as `INSUFFICIENT_FUNDS` instead of a hash.

Observed on 2026-10-26 against the public testnet: the app read block 67,240 and
balances Funder 100,000,000 lepta / Dhun 0 / Steward 0, matching direct
`getAccountBalance` RPC. A 0.01 LEZ transfer from Funder to Dhun was submitted from
the app at 17:04 (hash `683eef0c…`). The sequencer then stayed at block 67,240 and
`getTransaction` returned null, so the panel kept the transfer at **Submitted ·
awaiting verification** and its own check reported it as not found.

On 2026-10-27 the sequencer resumed. `getTransaction` returned the hash with block
67,293; direct `getAccountBalance` at block 67,389 read Funder 89,996,136 lepta
(0.089996136 LEZ after the 0.01 transfer and fee), Dhun 10,000,000 lepta (0.01 LEZ)
and Steward 0. The app's **Verify with sequencer** uses the same RPC path. This
confirms sequencer inclusion, not finality; the panel and this repository do not call
the transfer settled.

`lez_core` 0.5.1 ignores the password and writes its wallet file as plain JSON (the
upstream source marks storage encryption as a TODO). The password field only gates
creation; protect the OS account and back up the recovery phrase, which is the real
secret. `open()` takes no password.

## Logos Messaging

The **Coordination room** starts `chat_module` (over `delivery_module`, preset
`logos.test`) when the module host is available. The card at the bottom of the room
shows the node state and the peer count reported by the module, and exposes the
module's real chat address for copying. The room creates the group "Dhun Commons" on
first use and mirrors each sent message into it.

Observed on 2026-10-26: `init` → `health` → `get_address` → `status` →
`list_conversations` → `create_group_conversation` → `list_group_members` all
returned; the card read **node online · 0 peers** and a message was accepted by
`send_message` ("1 submitted"). No second peer was present, so no message has been
peer-delivered and the app does not claim it has.

## Telegram relay

`telegram/` is a zero-dependency Node service that bridges Telegram and this installation.
It long-polls the Bot API (no webhook), reads the public sequencer directly, and exchanges
files with the app in `~/Library/Application Support/Logos/LogosBasecamp/dhun_relay/`:

- the app writes `state.json` (page, role, proposals, offers, today's field work, room tail,
  cached chain state) through `publishTelegramState`;
- the bridge answers commands, writes `inbox.json` for `/say`, and writes a `bridge.json`
  heartbeat; the app shows `BRIDGE ONLINE` when the beat is under 45 seconds old;
- **Post to room** adds a queued message to the coordination room and hands it to Logos
  Messaging; **Dismiss** acknowledges it.

```sh
cd telegram
TELEGRAM_BOT_TOKEN=... TELEGRAM_ALLOWED_CHAT_IDS=<your chat id> npm start
npm test          # 8 tests against a stub Bot API and stub sequencer
```

`/status`, `/balance`, `/verify <hash>`, `/proposals`, `/inventory [season]`, `/activity`,
`/room`, `/say <text>`, `/update on|off` and `/id` are implemented. Setup, the allowlist,
the launchd sketch and the exact boundaries are in [docs/TELEGRAM.md](docs/TELEGRAM.md).

Observed on 2026-10-27 with the Bot API replaced by a local stub (no bot token was
available in this workspace): `/status` read block 67,389 and the live balances,
`/verify 683eef0c…` returned the sequencer record at block 67,293, and `/say` wrote
`inbox.json`. The app side was exercised against the same relay files after the LGX
rebuild. Live Telegram delivery is not claimed until you run it with your own token.

## Demo path

1. **Overview** — see the treasury, the ready Amla release and the signature queue.
2. **Wallet** — create or open the LEZ wallet, read the real testnet height and account
   balances, then switch role between Funder, Dhun and Steward. Open `PROP-108`, decode
   the instruction and execute; co-sign `PROP-109` to see approval collection.
3. **Market** — buy within the 500 DHN role allowance, or propose a purchase above it. Covenant offers route 5% to the reserve.
4. **Projects** — switch to Dhun, open the seed-bank programme, compare three competing bids and propose an award.
5. **Challenges** — claim a 72-hour sowing window as Dhun, file evidence, propose the bounty release and approve it from a second role.
6. **Coordination room** — every proposal and execution appends a system message to the bound room. If the Telegram bridge is running, open **TELEGRAM RELAY**, post a queued `/say` message to the room or dismiss it, and press **Publish snapshot**.
7. **Kitchen** — load the rabi sample, keep 24 guests and December, then plan. Read the
   sourcing list by zone, the waste-part and native cards, tick the safety gate to
   unlock cooked preserves, and read the >20-day pantry and memorabilia label. Choose a
   menu photo or press **Read photo** only if you have a loopback vision model running.
8. **Landscape** — filter the atlas by season and zone; covenants are enforced at release, not by the map.
9. **Field map** — open the embedded satellite studio. Without a key it shows the local
   plan view. Add a Google Maps key from the studio header, then select a produce pin,
   mark field work, record or attach a clip and procure a lot. Purchases above the role
   allowance become proposals; field orders appear in the wallet state.

## Layout

```
qml/
  Main.qml            application conductor, state machine and economy
  seed.js             deterministic rehearsal state
  logic.js            proposal, escrow, formatting and covenant logic
  kitchen.js          menu parser, per-head planner, waste/native data, pantry safety
  data.js             landscape zones, seasons, ingredient catalogue and field activities
  theme.js            design tokens
  components/         cards, rows, pills, sheets, fields, guarded WebView host
  pages/              Overview, Field map, Kitchen, Market, Projects, Challenges, Wallet, Room, Landscape
  drawers/            proposal, purchase, treasury, allocation, project, challenge, about
  web/                bundled field studio (Google Maps, activities, clips, procurement)
  assets/produce/     generated produce photography
  assets/menu-sample.jpg  synthetic, illustrative menu photo
src/
  dhun_commons.rep    universal module interface (slots and properties)
  dhun_commons_backend.*  LEZ wallet, accounts, balances, transfer and photo-read slots
  icons/icon.png      module icon
metadata.json         universal module metadata and lez_core dependency
CMakeLists.txt        logos_module() build
scripts/              local studio server and catalog generator/validator
catalog/              published catalog files, once a release is hosted
telegram/             Telegram bridge: Bot API long poll, relay files, 8 tests
docs/                 RFP proposal, field map, kitchen, publishing and demo notes
tests/Flow.qml        headless 101-check flow harness
.github/workflows/    CI: bridge tests, manifest and catalog checks, secret guard
```

The packaged studio lives at `qml/web/` because the LGX includes `qml/`.

See [docs/DEMO.md](docs/DEMO.md) for the full walkthrough, expected numbers and the
list of simulated behaviour, [docs/FIELD-MAP.md](docs/FIELD-MAP.md) for Maps key
setup, data limits and the camera caveat, [docs/KITCHEN.md](docs/KITCHEN.md) for the
kitchen planner and local model setup, and [docs/TELEGRAM.md](docs/TELEGRAM.md) for
the relay's commands, files and token boundary.

## Publishing this repository

The working tree is a normal git repository with one initial commit; no remote is
configured. To publish it under your account:

```sh
git remote add origin git@github.com:<you>/dhun-commons.git
git push -u origin main
```

or, with the GitHub CLI:

```sh
gh repo create dhun-commons --private --source . --remote origin --push
```

Basecamp apps are discovered through a module **catalog**, not a central store. The
catalog generator and validator are in `scripts/make-catalog.mjs`; the full release
steps are in [docs/PUBLISHING.md](docs/PUBLISHING.md). In short: build the portable
LGX, attach it to a public GitHub release, generate `catalog/logos-repo.json` and
`catalog/index.json`, commit them, then add the raw descriptor URL in Basecamp
Settings → Repositories. Nothing has been pushed or published from this machine, so
there is no public catalog URL yet.

CI runs on every push: bridge tests, the manifest/catalog checks and the secret guard.
The guard fails the build if a Telegram token pattern, a Google Maps key pattern, or a
wallet/env file is committed. Keep the bot token in your shell or a private file, never
in the tree.
