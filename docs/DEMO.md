# Dhun Commons — demo guide

This is the operating guide for the Dhun Commons Basecamp module. It documents what to
click, what the numbers should be, and exactly which parts are real, which are LEZ
testnet state and which are local rehearsal data.

> Two layers coexist. **On-chain accounts** in **Wallet** is a real client for the LEZ
> public testnet through the `lez_core` module: local wallet files, three public
> accounts, block height, balances and public-transfer submission. **Everything else**
> — the DHN treasury, proposals, escrows, signatures and field data — is a local
> rehearsal and moves no funds. The Funder account holds 0.1 LEZ on the public testnet
> in this evaluation; Dhun and Steward hold 0. A submitted transfer is reported as
> *submitted* until the sequencer reports the hash, and on 2026-10-26 the sequencer
> stopped producing blocks, so the last transfer remained unconfirmed. Nothing
> described here is an audited or production multisig. The production design is in
> [RFP-005-proposal.md](RFP-005-proposal.md).

## Build and install

Requirements: Nix with flakes, Logos Basecamp 0.2.x, Apple silicon, and the `lez_core`
module (0.5.1) installed in Basecamp's modules directory. Both modules must be the
portable `darwin-arm64` variant.

```sh
git init
git add -A                      # the flake only sees tracked files
NIX_CONFIG="experimental-features = nix-command flakes" nix build .#lgx-portable
```

Do **not** use the default `.#lgx` target: it produces `darwin-arm64-dev`, whose dylibs
link into the Nix store, and Basecamp 0.2.3 only loads `darwin-arm64`. Installing the
dev payload still opens the app, but the QML bridge cannot load
`dhun_commons_replica_factory.dylib` against the bundle's Qt, so
`logos.module("dhun_commons")` returns null and **On-chain accounts** stays at
**CONNECTING** forever. Verify the payload with
`otool -L …/dhun_commons_replica_factory.dylib`: each Qt entry must read `@rpath/…`,
never `/nix/store/…`. The 0.2.3-dev `lgpm` CLI cannot install a portable LGX either —
it appends `-dev` to the platform. Flatten the archive instead:

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

Apply the same steps to the `lez_core` LGX under `modules/lez_core`, using its own
manifest and payload. The build is unsigned. After restarting Basecamp, **Dhun
Commons** appears in the app sidebar.

On this machine, Basecamp 0.2.3 crashes inside the PCRE2 JIT while it vets QML import
paths (`RestrictedUrlInterceptor::qmldirDeclaresNativePlugin`, SIGTRAP in
`pcre2_jit_compile_16`). The crash is in the host, not in Dhun Commons, and it happens
for any plugin tree it scans. Launch Basecamp with `QT_ENABLE_REGEXP_JIT=0` in the
environment (for Dock launches, `launchctl setenv QT_ENABLE_REGEXP_JIT 0`) to fall back
to the interpreter. Revert with `launchctl unsetenv QT_ENABLE_REGEXP_JIT`.

`metadata.json` declares `"dependencies": ["lez_core"]` as a string array because
Basecamp 0.2.3's plugin loader calls `QString::fromVariant` on each entry; an object-form
dependency is silently skipped.

For this evaluation `lez_core` was built from the pinned upstream source
(`logos-execution-zone` v0.3.1, `lez_core` 0.5.1). The machine has only the macOS
Command Line Tools, not Xcode's Metal Toolchain, so the wallet FFI was built with CPU
kernels and stub Metal outputs. The Metal prover paths are disabled in the pinned
risc0 circuit crates, so the stub output is embedded but never loaded; proving uses the
CPU kernels. This is a local workaround, not a Logos release artifact. Prefer an
official `lez_core` LGX when available, especially before using an account that holds
value.

The QML pages make no direct network calls. Two exceptions are explicit: the C++
backend talks to the LEZ sequencer through `lez_core`, and the **Field map** hosts a
bundled web studio in QtWebView that loads Google satellite tiles and geocoding when a
runtime Maps key is present. Without a key, or without QtWebView, the field page stays
on its local plan view. No key is bundled with the module. See
[FIELD-MAP.md](FIELD-MAP.md) for setup and limits.

## Rehearsal flow

### 0. Reset first

Open **About** (the `?` icon in the top bar) → **Reset rehearsal** if the state was used
before. The seed is deterministic: 150,000 DHN in circulation across the vault, escrows,
role wallets, conservation reserve and external float.

### 1. Overview

The overview shows the treasury, the ready Amla milestone and the proposal queue.

Expected: total supply **150,000 DHN**; `PROP-108` (release Amla M1) is **ready**. The
ledger shows the treasury opened with a 150,000 DHN tranche.

### 2. Wallet and quorum

Open **Wallet**. Use the role switcher in the top bar to move between **Funder**
(Dhun Capital Circle), **Dhun Field Unit** and **Steward** (Khejri Mandal).

1. Open `PROP-108` — *Release Amla milestone M1*, 3,200 DHN.
2. Read the **instruction** block: target `dhun_multisig::release`, amount, expiry,
   quorum and digest. This is the rehearsal's decode-before-sign panel.
3. It already has approvals from Dhun and the Funder. Press **Execute**.

Expected: project escrow decreases by 3,200; the steward receives 2,944; the
conservation reserve receives 256 (8%); total supply stays 150,000.

`PROP-109` (compost, 640 DHN) has one approval. Open it and co-sign from a second role
to demonstrate approval collection. It is a purchase above the 500 DHN single-signer
allowance, so it must go through quorum.

### 2a. On-chain accounts (real LEZ testnet)

The **On-chain accounts** card sits above the proposal queue on **Wallet**. It is backed
by the `dhun_commons` C++ module and the `lez_core` module, not by QML demo state.

1. If no wallet exists, the card says **NO WALLET**. Enter a password of at least eight
   characters and press **Create wallet**. The wallet file and three public accounts are
   created locally. The recovery phrase appears once in a modal; write it down before
   closing. It is not stored in QML or in the repository. The password gates creation
   only: `lez_core` 0.5.1 ignores it and writes the wallet file as plain JSON.
2. If wallet files already exist, the module opens them on launch (there is no password
   prompt on reopen; `lez_core::open` does not take one). Press **Open saved wallet** if
   it did not open automatically.
3. Press **Refresh**. The status pill moves to **CONNECTED** and the card shows the real
   block height, the three base58 addresses, the sequencer URL and the wallet directory.
   The first read also happens automatically after the wallet is ready.
4. Expected balances on this device: **Funder 0.1 LEZ** (funded externally from a claimd
   faucet on 2026-10-26, not by this app), **Dhun 0** and **Steward 0**. The **UNFUNDED**
   pill only appears when every account reads zero. There is no in-app faucet. The
   official `logos-co/lez-faucet` still refuses this deployment by design: its startup
   fingerprint needs `getProgramIds` to return `authenticated_transfer` and `pinata`,
   while this sequencer returns only `privacy_preserving_circuit`.
5. Try a **Public transfer** from Funder to Dhun (for example `0.01`). The backend signs
   and submits a real transaction and the card labels the returned hash **Submitted**
   with **Verify with sequencer**. It stays submitted until the sequencer reports the
   hash; do not call it settled before that. A transfer from an unfunded account is
   rejected with `INSUFFICIENT_FUNDS` (`wallet FFI error 9`) and no hash is invented.

Observed on 2026-10-26 and 2026-10-27: the app read block 67,240 and balances
100,000,000 / 0 / 0 lepta, matching direct `getAccountBalance` RPC. A 0.01 LEZ
Funder → Dhun transfer was submitted at 17:04
(hash `683eef0c1fcee4f06cfcccd41e89f679bbcdb5fa8c09f8046db41351ec6c271d`). The
sequencer then stalled at 67,240, so the card stayed at **Submitted · awaiting
verification** and its own check reported the hash as not found.

The sequencer resumed later that day. `getTransaction` returned the hash with block
67,293, and direct `getAccountBalance` at block 67,389 read Funder 89,996,136 lepta
(0.089996136 LEZ after the transfer and fee), Dhun 10,000,000 lepta (0.01 LEZ) and
Steward 0. Inclusion is not finality; neither the panel nor this document calls the
transfer settled. Wallet files and the sequencer are shown at the bottom of the
account column. The DHN balances elsewhere on the page are separate rehearsal data.

### 3. Market and the allowance path

Open **Market** and switch to **Dhun** (allowance 500 DHN).

1. Buy `OFF-01` — certified sarson seed, 380 DHN. This is **within** the role allowance,
   so it settles immediately: Dhun −380, supplier +380, supply unchanged.
2. Buy `OFF-07` — native hedge saplings, 1,100 DHN. This is **above** the 500 DHN
   allowance, so it creates a purchase proposal. `OFF-07` is a covenant offer: the
   execution routes 5% to the conservation reserve.
3. Co-sign the proposal from Steward or Funder and execute. Expected: supplier receives
   1,045; conservation receives 55; stock decreases by one.

The Funder has an allowance of 0. Purchases made as Funder always go through quorum —
that is deliberate role separation, not a bug.

### 4. Projects and competing bids

Open **Projects**, switch to **Dhun**, and open `PRJ-03` — *Seed bank fit-out*.

Three bids compete for the same programme. Compare their price, duration and
conservation detail, then select the local stone-plinth bid (`BID-201`, 5,600 DHN,
21 days) and propose the award. Switch to Funder or Steward to co-sign, then execute.

Expected: `PROP-107` executes; project escrow pays 5,600; the project becomes active.
The losing bids are rejected, not silently ignored.

### 5. Time-boxed cultivation challenges

Open **Challenges**. `CH-01` — *Sow sarson before the window closes* — is open for 72
hours.

1. As **Dhun**, claim the window. The countdown and claim state change; the Funder
   cannot claim field windows.
2. Submit evidence: seed-lot photo note, drill calibration and 12 geotagged points.
3. Propose the bounty release (2,400 DHN, 5% conservation). Co-sign from another role
   and execute.

Expected: challenge escrow decreases by 2,400; Dhun receives 2,280; conservation
receives 120; total supply stays 150,000. The challenge closes as executed.

### 6. Coordination room

Open **Room**. The room switcher shows the multisig room and the soil, amla, seed and
habitat channels. Every proposal and execution appends a system message to the bound
room. Send a message as the current role; it is stored locally with the role's identity.

The **LOGOS MESSAGING** card at the bottom left of the room is live when Basecamp
exposes `chat_module`. It runs `init` (preset `logos.test`), `health`, `get_address`,
`status`, `list_conversations`, creates the group "Dhun Commons" once, and lists its
members. The card shows the node state and peer count reported by the module and its
real chat address (copy with **Copy**). Sending a message adds it to the local
transcript and hands it to `chat_module.send_message`; the card reports how many were
submitted and states that peer delivery is not acknowledged.

Observed on 2026-10-26: **node online · 0 peers**, one submitted message. With no second
peer the group has not delivered anything to another person, and the UI says so.

The room transcript itself is still local QML state; the Logos group mirrors messages
but does not render peer traffic into the in-app transcript.

### 6a. Telegram relay (optional)

Above the composer there is a collapsed **TELEGRAM RELAY** bar. With the bridge running
it reads `BRIDGE ONLINE`, the snapshot age and the queued count. Expand it to see queued
`/say` messages, **Post to room**, **Dismiss** and **Publish snapshot**. Posting appends
`Telegram · <author>: <text>` to the Multisig room and mirrors it to Logos Messaging;
neither action signs or approves anything. Setup, commands and the token boundary are in
[docs/TELEGRAM.md](TELEGRAM.md).

Observed on 2026-10-27 with a stub Bot API (no token in this workspace): the app
published `state.json`, `/status` read block 67,394 and the live balances, `/say` wrote
`inbox.json`, and the bar showed `1 queued` with the snapshot age. The new payload was
installed and Basecamp was restarted for this check. The expanded panel was verified
through the harness rather than by clicking, because the screen locked during the run.

### 7. Landscape atlas

Open **Landscape**. Filter by season and zone; open a plant to see its window and the
offers connected to it. Covenant offers route 5% to the conservation reserve when
purchased; the map itself does not enforce the covenant — the purchase and release
logic does.

### 8. Field map and the embedded studio

Open **Field map**. The page starts the bundled studio in QtWebView.

1. Without a Maps key the studio shows the **local plan view**: 12 produce pins with
   photos, the growing zones, the role's agenda, the 7-day calendar and the wallet rail.
   The same data is available in the native plan view if QtWebView fails.
2. For satellite imagery, open the **Google Maps key** dialog in the studio header and
   paste a browser key with Maps JavaScript API and Geocoding API enabled. The key stays
   in the web view's `localStorage`; it is never bundled or committed. See
   [FIELD-MAP.md](FIELD-MAP.md) for restrictions.
3. Select a produce pin (for example bajra or amla). The card shows the lot, stock,
   season, price and grower. Press **Procure**, choose a quantity and confirm.
   - Within the 500 DHN role allowance the purchase settles immediately.
   - Above the allowance it becomes a purchase proposal. Co-sign from another role and
     execute; the lot stock decrements and a field order is recorded with the transaction.
4. Press **Mark work**, choose a type (sowing, irrigation, compost, harvest, pruning,
   scouting, nursery), a produce, a zone and a date. The activity is pinned on the map,
   appears in the role's calendar and adds one room note.
5. Open an activity and mark it **done**, or switch role in the top bar. The studio
   agenda follows the active role, and plans made in the studio flow back into the
   wallet state.
6. Press **Record clip**. The studio offers a 20-second camera capture and an **Attach a
   clip** fallback. Where the web view allows local storage, the clip stays on the
   device; the field feed gets an update and the room gets a text note, never the video.
   In Basecamp 0.2.3 the camera permission may be refused by the host; use the attach
   fallback.
7. **Local server / Bundled** switches the studio source. To use the system browser
   (**Browser**), run `scripts/serve-map.sh` first.

Expected: the studio status pill changes from **OPENING STUDIO** to **LIVE GOOGLE
STUDIO**; the native fallback shows **NATIVE FIELD DESK**. Field activity counts in the
sidebar badge count today's unfinished work for the active role.

### 9. Kitchen

Open **Kitchen**. The page loads the rabi sample: 24 guests, December, six dishes.

1. Press **Plan the menu**. The stats row should read 6 dishes, 11 farm lines, 45%
   Market cover, an estimated cost near ₹3,483 and 6 allowed routes over 20 days.
2. Read **Source from the farm map** by zone. A *Market lot* line has seeded stock; a
   *field plot* line (sarson, gajar, kheera, ghee, dhaniya, pudina) is an estimate to
   confirm with the grower. The group headers link to the farm map, and the Field map's
   produce markers carry permanent names.
3. Read **Waste parts → kitchen use** (stalks, roots, peels, bran, soaking water) and
   **Native additions** (moringa, sangri, ker in December). Every line carries a
   caution; none is a medical claim.
4. In **Safety gate for excess food**, tick all four boxes. Before that, cooked routes
   such as dried roti and vegetable pickle are shown as **BLOCKED** with reasons; raw
   citrus-salt and dairy routes remain allowed. Plate waste is never preserved.
5. Read **Pantry routes over 20 days** and the guest memorabilia label. The label says
   **GUEST MEMORABILIA · NOT FOR SALE** and carries a deterministic batch code.
6. Choose a PNG/JPEG/WebP photo or keep the synthetic sample. **Read photo** only works
   against a loopback OpenAI-compatible vision server; without one the built-in planner
   reads the typed lines and no model is called. See [KITCHEN.md](KITCHEN.md).

### 10. Node, steward signup and rewards

Open **Node & rewards**. The hero reports the live host state twice: Logos Messaging on
the left and the LEZ sequencer on the right. Outside Basecamp both read **NOT HOSTED**
or **LEZ UNINITIALIZED**; the page never substitutes a placeholder for a ready node.

1. Read the **Logos Messaging node** card. *Delivery* mirrors the module's chat state,
   *Peers* mirrors its peer count and *Route address* is only filled once the node
   issues one. One peer is this device; delivery to a second peer is never claimed.
2. Read the **LEZ sequencer** card. Network, endpoint, height and the three party
   accounts come from `lez_core`. Wallet accounts belong to Funder, Dhun and Steward,
   not to each profile; steward profiles share the steward wallet until a payout lands.
3. Read **Who is actually here**. Unique visitors and page views are the Qoder Sites
   analytics for this catalog over the last 30 days, with the checked timestamp. The
   host does not report downloads or installs, so the page prints that instead of an
   invented install count. Wallet holders are the funded LEZ accounts on this device;
   profiles are local names.
4. Press **Join as a steward** (or the sidebar chip, or **Create your profile** on the
   hero). Enter a name of at least two characters, a place and an optional note. The
   drawer creates a profile with the **steward** role, signs the top bar as that person
   and writes a 10 DHN onboarding reward entry. Profiles are local settings, not chain
   accounts, and reset removes them. Funder and Dhun remain seeded rehearsal roles; a
   new signup never receives either.
5. Read **How to earn DHN**. Each rule states its evidence and daily cap: a ready node
   day (25, once per device per calendar day), a filed field task (8), a challenge with
   evidence attached (15), a filed kitchen plan (5, once per day) and a new steward
   profile (10, once). **Go** routes to the page that produces the evidence.
6. On **Earned on this device**, choose **Propose payout** for a profile. The entry
   becomes a treasury proposal from the vault to the steward wallet for the earned
   total. It still needs two of three signatures, and execution moves existing DHN —
   the ledger line reads *treasury funded, not minted* and supply is unchanged.

Node-day credit requires the Logos Messaging node to report ready; the page records one
day per device while it stays ready and stops when the app closes. It is evidence of a
local node, not proof of a second peer or of chain finality.


## What is real in this build

- The LEZ testnet account panel: wallet creation on device, a locally produced recovery
  phrase, three public account IDs and base58 addresses, the current testnet block
  height, balances read through `lez_core`, public-transfer submission and
  sequencer-status polling. No transaction hash is fabricated.
- The full QML interface, navigation and local persistence (`QtCore.Settings`).
- The proposal state machine: pending, ready, timelocked display, executed, rejected,
  expired (the seeds include ready and pending proposals).
- Reward entries for a ready node day, a filed field task, challenge evidence, a filed
  kitchen plan and a steward signup. They are earned locally, paid only through a
  treasury reward proposal, and execution moves existing DHN without changing supply.
- Steward profiles created with a name, stored in this module's settings and signed in
  the top bar. They are local identities with the steward role; they are not chain
  accounts and do not receive owner keys.
- The catalog analytics shown on Overview and Node & rewards: Qoder Sites reports page
  views and unique visitors only. Downloads and installs are not reported, so no install
  count is shown. Wallet holders are the funded LEZ accounts on this device.
- Role-specific allowances (Funder 0, Dhun 500, Steward 500), approval collection and
  the 2-of-3 quorum.
- Escrow accounting, market stock, purchase covenant split, challenge bounty split,
  project bid selection and the ledger.
- Room system messages, the seasonal atlas filters and the live `chat_module` connection
  behind the Logos Messaging card.
- The field calendar: activity creation, role filtering, planned/done state, produce
  stock changes and field order records in the wallet state.
- The embedded studio bridge: role, inventory, activities, status changes, produce
  selections and clip-update notes flow between the web studio and QML.
- The kitchen planner: menu parsing, per-head quantities, sourcing lines, waste-part
  guidance, native suggestions, safety gating, >20-day filtering and memorabilia
  labeling are deterministic local logic. Photo reading is local-only when a loopback
  vision model is running.
- Google satellite tiles and geocoding, when a runtime key and network are present.

## What is simulated

- The DHN treasury, its `txid`s, DHN account balances and proposal execution. They are
  local QML state with deterministic demo identifiers, not LEZ transactions.
- DHN role addresses, key fingerprints, payload digests and approval signatures.
  Signatures are deterministic demo strings, not BIP-340 signatures. They are separate
  from the real public accounts in the LEZ panel.
- Room transcript and the Logos Messaging client. `chat_module` over `delivery_module` is
  a real module call: init, address, group creation and message submission are observed
  in the log. What is *not* observed is peer delivery — this device has no second peer,
  so no message has been delivered to another person, and the UI reports only
  *submitted*.
- Account funding on the LEZ testnet. The app can create accounts but cannot fund them;
  there is no in-app faucet, and `logos-co/lez-faucet` is incompatible with this
  deployment because the sequencer's `getProgramIds` does not report the
  `authenticated_transfer` and `pinata` programs it fingerprints. The Funder account was
  funded externally (0.1 LEZ, block 67,236); a transfer from an unfunded account is
  rejected with `INSUFFICIENT_FUNDS`.
- Timelock enforcement and selective disclosure. The UI describes the intended policy;
  neither is enforced against a chain here.
- Fiat settlement and supplier delivery. There is no external payment rail.
- Field inventory, grower names, plots, prices, stock, activities, updates and clips.
  They are seeded or created locally; there is no farmer feed, live GPS, cross-user sync
  or upload. Field orders and stock changes use the rehearsal ledger. The Kitchen
  sourcing plan reads the same seeded Market lots and field-plot estimates, so its
  coverage and cost are planning figures, not live availability.
- The sample menu photo is synthetic and illustrative. No local vision model is bundled,
  installed or claimed to be running; the deterministic planner works without one.
- Clip storage depends on the web view's IndexedDB support. Camera capture additionally
  depends on the host granting camera and microphone permission; Basecamp 0.2.3 does not
  declare the required usage descriptions.
- Google geocoding returns real external results when a key and network are present.
  Place details and the Places API are not used.

No real funds or personal data are involved. The module ships no API key. If the user
supplies a Maps key, the embedded web view makes network requests to Google Maps; chat
and field records stay local.

## Automated checks

The in-repo flow harness exercises 121 assertions across all proposal kinds, roles,
escrows, covenants, supply conservation, the native field page, field orders, the
studio bridge events, the Telegram relay queue, the kitchen planner, node-day rewards,
steward signup and reward payouts:

```sh
export QML2_IMPORT_PATH=/Applications/LogosBasecamp.app/Contents/Resources/qt/qml
export QT_PLUGIN_PATH=/Applications/LogosBasecamp.app/Contents/Resources/qt/plugins
export QT_QPA_PLATFORM_PLUGIN_PATH="$QT_PLUGIN_PATH/platforms"
export DYLD_FRAMEWORK_PATH=/Applications/LogosBasecamp.app/Contents/Frameworks
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software

/nix/store/fn7iqppsl6z7ikbspxnjirwdz345w8mj-qtdeclarative-6.9.2/bin/qml tests/Flow.qml
```

Expected final line:

```text
qml: SUMMARY checks=121 failures=0 supply=170000 issued=170000
```

The 170,000 supply is correct: the harness executes the 20,000 DHN Tranche C mint,
after which total supply equals issued supply.

The harness sets `webStudioEnabled=false`, and the field page only creates the QtWebView
when the studio is both requested and enabled. That keeps the offscreen run away from
macOS `QQuickViewController`, which segfaults without a native window. The embedded
satellite studio is therefore checked live in Basecamp, not by this harness.

## Known limits

- Basecamp must be restarted after installing or rebuilding the LGX.
- The module is unsigned and packaged for the portable `darwin-arm64` variant; it is for
  local evaluation, not distribution. Basecamp 0.2.3 will not load the `darwin-arm64-dev`
  default build.
- `lez_core` (0.5.1) must be installed separately, also as a portable `darwin-arm64`
  variant. Without it the chain card stays in an error/connecting state; there is no
  bundled chain client. Basecamp 0.2.3 requires the string dependency form
  `"dependencies": ["lez_core"]`; object-form dependencies are silently ignored.
- The panel reads public account balances and block height straight from the sequencer.
  It does not scan private note history (`sync_to_block`); private and shielded transfers
  are out of scope for this build.
- On 2026-10-26 the Funder account held 0.1 LEZ from an external faucet; the panel read
  it at block 67,240. A 0.01 LEZ transfer was submitted (hash `683eef0c…`) while the
  sequencer was stalled. It later resumed: `getTransaction` returned the hash with block
  67,293 and balances at block 67,389 read 89,996,136 / 10,000,000 / 0 lepta. That is
  sequencer inclusion, not finality, and the transfer is never labelled settled. There
  is still no in-app faucet, and the official `logos-co/lez-faucet` remains incompatible
  with this deployment.
- Logos Messaging reports **0 peers** on this device. Initiating the chat, creating the
  group and submitting a message are real module calls; delivery to a second peer has
  never been observed, so none is claimed.
- The locally built `lez_core`/wallet FFI in this evaluation skips Metal compilation
  (stub metallib) because the machine has no Metal Toolchain. The GPU prover paths are
  disabled in the pinned risc0 crates, so CPU kernels are used; one funded transfer was
  signed and submitted on this path, and the sequencer did not include it. Use an
  official `lez_core` LGX for value-bearing use.
- `lez_core` 0.5.1 does not use the wallet password and saves the wallet file as plain
  JSON, including key material (upstream marks storage encryption as a TODO). The field
  only gates creation, and reopening calls `lez_core::open` with no password. Protect the
  OS account; the recovery phrase is shown once and is never written by Dhun Commons.
  Do not put real value on this wallet until upstream storage encryption lands.
- State persists in `com.logos.LogosBasecamp` preferences. Use **About → Reset
  rehearsal** to return to the seed.
- The sandbox blocks QML network access; satellite imagery comes from the embedded web
  view, not QML. Chat, inventory and field records remain local.
- Embedded studio mode needs QtWebView in the host. Without it the page uses the native
  plan view, which has no Google tiles, geocoding or clip capture.
- The camera path is not verified in Basecamp: the app does not declare camera and
  microphone usage descriptions. Use **Attach a clip** or the native composer.
- Kitchen photo reading needs a separate loopback vision server; no model ships with the
  module. The backend reads PNG, JPEG and WebP up to 8 MiB and refuses HEIC. The QML
  client refuses any endpoint that is not `127.0.0.1`, `localhost` or `[::1]`.
- The Maps key is stored in the web view's `localStorage`. A `file://` studio cannot use
  website-referrer restrictions; use API restrictions only or local server mode. Rotate
  keys that were shared during testing. No key is included in the repository or LGX.

## File map

| Path | Purpose |
| --- | --- |
| `qml/Main.qml` | Application conductor, proposal execution and economy |
| `qml/seed.js` | Deterministic rehearsal state |
| `qml/logic.js` | Proposal/escrow/covenant/formatting logic |
| `qml/pages/` | Overview, Field map, Kitchen, Market, Projects, Challenges, Wallet, Node & rewards, Room, Landscape |
| `qml/pages/FieldMap.qml` | Embedded studio host, bridge, native plan view and field calendar |
| `qml/pages/Kitchen.qml` | Menu photo, model client, sourcing, waste/native cards, safety gate, pantry label |
| `qml/pages/Node.qml` | Node and LEZ status, catalog counts, reward rules and payout queue |
| `qml/kitchen.js` | Dish library, per-head planner, waste and native data, preserves and safety rules |
| `qml/rewards.js` | Reward rules, profiles and earned totals |
| `qml/web/` | Bundled field studio (Maps, activities, clips, procurement) |
| `qml/components/StudioWebView.qml` | Guarded QtWebView host with native fallback |
| `qml/drawers/` | Proposal, purchase, treasury, allocation, project, challenge, profile, about |
| `src/dhun_commons.rep` | Universal module interface: wallet, refresh, transfer, verify and photo-read slots |
| `src/dhun_commons_backend.{h,cpp}` | LEZ wallet directory, account mapping, balances, transfers, local photo reader |
| `metadata.json`, `CMakeLists.txt` | Universal module metadata, `lez_core` dependency and build |
| `scripts/make-catalog.mjs` | Generates and validates the public Basecamp catalog files |
| `tests/Flow.qml` | 121-check headless flow harness |
| `docs/FIELD-MAP.md` | Maps key setup, studio architecture, data limits and camera caveat |
| `docs/KITCHEN.md` | Kitchen workflow, free local vision models, safety rules and limits |
| `docs/PUBLISHING.md` | Catalog schema, release hosting and Basecamp repository setup |
| `docs/RFP-005-proposal.md` | Production design and RFP submission draft |
