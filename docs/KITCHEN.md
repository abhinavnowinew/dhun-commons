# Kitchen: menu photo → farm sourcing → pantry

The Kitchen tab turns a menu for a number of guests into four things:

1. a **sourcing plan** from the seeded farm map, with each ingredient tied to a
   zone, a Market lot or a field-plot estimate;
2. **waste-part uses** for stalks, leaves, peels, roots and seeds, with a
   caution on every line;
3. **lesser-known native additions** that fit the menu and the season;
4. a **guarded pantry** of preserves with a shelf life over 20 days, plus a
   guest memorabilia label for a checked batch.

The planner is deterministic and offline. No model is required, and no photo
leaves the machine. A local vision model can be used as an optional shortcut
for reading a menu photo; it only transcribes dish names and the guest count.
Quantities, prices, sourcing and safety rules always come from the built-in
planner in [`qml/kitchen.js`](../qml/kitchen.js).

## Using the tab

1. Open **Kitchen** in the sidebar.
2. Choose a photo, keep the illustrative sample, or type the menu lines.
3. Set the guest count and the planning month, then press **Plan the menu**.
4. Read the sourcing list by zone. A *Market lot* line has seeded stock; a
   *field plot* line has no Market listing and is an estimate to confirm with
   the grower, not a live inventory promise.
5. Read **Waste parts → kitchen use** and **Native additions**.
6. Tick the four assurance boxes in **Safety gate for excess food**. Cooked
   leftovers stay blocked until every box is true. Without the gate, only raw,
   citrus, dairy and dry routes are offered.
7. Read **Pantry routes over 20 days**, then the guest memorabilia label. Give
   a jar only from a batch you checked, label allergens and storage, and never
   sell it.

The farm map is the native **Field map** tab. Produce pins carry their
ingredient name permanently; the embedded field studio also shows permanent
name labels on the Leaflet map. Lots and plots are seeded rehearsal data, not
live farmer inventory.

## The sample menu

`qml/assets/menu-sample.jpg` is a synthetic, illustrative photograph made for
this demo. It is not a real Dhun menu and carries no guest data. The hand-typed
sample menus in `qml/kitchen.js` are:

| Menu | Guests | Month |
|---|---|---|
| Rabi thali | 24 | December |
| Kharif thali | 18 | September |
| Zaid thali | 30 | May |

## Optional local vision model

### What it does

Pressing **Read photo**:

1. asks the module backend (`startMenuPhoto`) to read the local image — PNG,
   JPEG or WebP, ≤ 8 MiB; HEIC is refused with an error;
2. the backend sends an OpenAI-compatible `POST /v1/chat/completions` request to
   a **loopback** endpoint with the image as a `data:` URI, then stores the
   outcome in `modelState`/`modelReply`;
3. the tab polls those properties every 400 ms, then parses a strict JSON reply
   of dish names, optional guest count and optional notes;
4. matches the names against the built-in dish library and reports unmatched
   lines instead of inventing ingredients;
5. rebuilds the plan from the matched lines.

The request lives in the backend on purpose. Basecamp sandboxes plugin QML
network access with a deny-all access-manager factory
(`app/restricted/QmlSandbox.cpp`, `DenyAllNAMFactory`), so a QML
`XMLHttpRequest` to `127.0.0.1:11434` fails inside the app even when the same
request works from a plain Qt harness. The backend runs in the host process and
can still reach a loopback server. A side effect is that remote endpoints are
refused in two places: the tab checks the endpoint before calling the slot, and
`loopbackChatUrl` re-validates it in C++.

The endpoint must be `127.0.0.1`, `localhost` or `[::1]`. The default is
`http://127.0.0.1:11434/v1` with model `qwen2.5vl:3b`, the build this machine has
installed and the one tested below; the model field is editable, and
`qwen2.5vl:7b` reads denser menus more reliably if you have the memory for it.

### Free models verified for this task

Licences below were checked against the Hugging Face model API on 2026-10-27.
This repository bundles no model. Qwen2.5-VL 3B was installed and run locally
for the check in the next section; no other model here has been run by us.

| Model | Hugging Face ID | Licence | Notes |
|---|---|---|---|
| Qwen2.5-VL 7B Instruct | `Qwen/Qwen2.5-VL-7B-Instruct` | Apache-2.0 | Strong document and scene-text reading; better accuracy when memory allows |
| LLaVA-OneVision Qwen2 7B | `llava-hf/llava-onevision-qwen2-7b-ov-hf` | Apache-2.0 | General vision, good menu/whiteboard reading |
| Moondream 2 | `vikhyatk/moondream2` | Apache-2.0 | Very small; faster on CPU, weaker on dense handwriting |
| InternVL 2.5 8B | `OpenGVLab/InternVL2_5-8B` | MIT | Strong OCR; heavier setup |
| Florence-2 large | `microsoft/Florence-2-large` | MIT | OCR/region tasks; not a chat model, needs a wrapper |

The table lists repositories whose Hub API response carried a licence on
2026-10-27. Some Qwen2.5-VL 3B and MiniCPM-V entries returned no licence tag in
that check, so they are not in the table; confirm the licence on the model card
of the exact tag you pull before redistributing a model.

### Verified local run, 2026-10-27

One real model-assisted pass was run on this machine: `qwen2.5vl:3b` on Ollama
0.40.7 at `http://127.0.0.1:11434`, reading `qml/assets/menu-sample.jpg` at
temperature 0. The 7B build was the intended default but its download was
interrupted by a network/DNS failure, so the smaller 3B build was used.

The model returned in 15.5 s (1,806 prompt tokens, 76 completion tokens):

````text
```json
{
  "dishes": [
    "Bajra Roti",
    "Moth Dal",
    "Sarson Saag",
    "Gajar Halwa",
    "Kheera Raita",
    "Nimbu Pani"
  ],
  "servings": null,
  "notes": ["unreadable"]
}
```
````

That reply is a useful stress case, because it is wrapped in markdown fences and
because it contradicts itself: every dish name is correct, yet `notes` says
`unreadable` and `servings` is null. The app's reply parser strips the fences,
matched all six lines against the dish library (6 of 6, no unmatched lines) and
ignored the stray note. Because the model gave no guest count, the plan was
built with 24 guests entered by hand — exactly what the Kitchen tab asks the
cook to do.

The planner output from that transcribed menu:

| Result | Value |
|---|---|
| Sourcing lines | 11 across Farms & Market Garden, Dairy & Poultry, Orchards & Groves, Kitchen Garden |
| Cost | ₹3,483 total (₹481 Market, ₹3,002 plot estimate) |
| Coverage | 5 of 11 covered by seeded Market stock; 6 plot estimates |
| Waste routes | 10 ingredients, 20 parts (stalks, roots, peels, tops, bran, whey, soaking water, husks, zest, seeds, stems) |
| Native additions | Moringa leaves, sangri (khejri pod), ker buds |
| Preserves >20 days | 9 routes listed; 3 cooked routes blocked by the safety gate |
| Memorabilia | Batch `DHN-K-QU84D`, cultured ghee from surplus milk, 6 months, **not for sale** |

With all four safety assurances ticked, the three cooked routes (dried roti
crisps, oil-and-salt vegetable pickle, dehydrated dal papad) unlock and the same
6-month ghee batch becomes the memorabilia pick.

### Verified inside Basecamp, 2026-10-27

The same request was repeated from the installed app (module 0.3.1 in Basecamp
0.3.2, plugin QML sandbox active):

- **Check server** reported `Local server reachable at
  http://127.0.0.1:11434/v1/models · qwen2.5vl:3b`; Ollama logged
  `GET /v1/models` 200 from `127.0.0.1`.
- **Read photo** produced, in Ollama's access log, `POST /v1/chat/completions`
  from `127.0.0.1` with status 200 in 12.45 s and 1,806 prompt tokens (104
  text, 1,702 image) plus 76 completion tokens — the same image and prompt as
  the standalone run above.

Before the backend transport, the same click failed because the sandbox blocks
plugin QML networking; the probe and the chat request both reach the model now.

### Ollama

```sh
ollama pull qwen2.5vl:7b   # or qwen2.5vl:3b, the tag tested above (3.2 GB)
ollama serve               # listens on 127.0.0.1:11434 by default
```

Keep the default loopback bind. In the Kitchen tab use
`http://127.0.0.1:11434/v1` and the tag you pulled — `qwen2.5vl:3b` is the
default in the form and what the 2026-10-27 run used; switch to `qwen2.5vl:7b`
when you have the memory — then **Check server**. Recent Ollama builds accept
`image_url` data URIs on the OpenAI-compatible endpoint. If a build does not,
use llama.cpp below.

### llama.cpp

```sh
llama-server \
  -m Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf \
  --mmproj mmproj-Qwen2.5-VL-7B-Instruct-f16.gguf \
  --host 127.0.0.1 --port 8080
```

Use `http://127.0.0.1:8080/v1` in the Kitchen tab. The model field is passed
through; llama-server accepts the served model name.

### Hardware

A 7B vision model at 4-bit needs roughly 5–6 GB of memory; a 3B model about
2–3 GB. CPU inference works but can take tens of seconds per photo. The request
timeout is 180 seconds.

## Safety rules

The pantry is deliberately conservative.

- **Plate waste is never preserved.** The *Never served* assurance is required
  for every cooked-food route.
- A long shelf life **does not make unsafe food safe**. Cooling within two
  hours, refrigeration below 5 °C and an untouched batch are all required
  before a cooked preserve is offered.
- The dehydrator route is blocked unless a dehydrator is actually available.
- Shelf lives are kitchen guidance, not a guarantee. A clean jar, correct
  storage and a checked batch matter more than the number on the label.
- Compost is always available and is the safe route when a gate fails.
- When no long-life route is allowed, the tab shows why each route is blocked
  rather than hiding it.

## Waste and native guidance

- Waste parts are used only when the part is edible and clean; anything
  doubtful goes to compost. Roots are never taken from unknown ground.
- Native additions are culinary suggestions with sourcing and caution notes.
  They are not nutrition or medical claims; introduce small portions and check
  allergies.
- The memorabilia label says **NOT FOR SALE**. Guest memorabilia is not a
  commercial product.

## Data honesty

- Market stock, prices and grower names come from the seeded rehearsal state.
  They are not live farmer inventory.
- Field-plot costs are estimates based on the seed ingredient price.
- Photos are read on the local machine. The built-in planner never calls a
  model; only **Read photo** does, and only against a loopback endpoint.
- Model output is treated as a transcript, not as advice. The model supplies
  dish names and, when it can, the guest count; every quantity, price, waste
  use, native pick and shelf life comes from `qml/kitchen.js`.
- A model can be confidently wrong, including about its own output. In the
  2026-10-27 run it read all six dishes correctly and still reported
  `unreadable` in its notes, so the tab names the model that extracted the lines
  and shows its notes, and the cook is asked to review the lines.

## Tests

```sh
# 101 wallet, field, relay and kitchen checks
QML2_IMPORT_PATH=/Applications/LogosBasecamp.app/Contents/Resources/qt/qml \
QT_PLUGIN_PATH=/Applications/LogosBasecamp.app/Contents/Resources/qt/plugins \
QT_QPA_PLATFORM_PLUGIN_PATH=$QT_PLUGIN_PATH/platforms \
DYLD_FRAMEWORK_PATH=/Applications/LogosBasecamp.app/Contents/Frameworks \
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
/nix/store/fn7iqppsl6z7ikbspxnjirwdz345w8mj-qtdeclarative-6.9.2/bin/qml tests/Flow.qml
```

The kitchen checks cover menu parsing, per-head quantities, plot fallback,
waste-part coverage, native picks, the safety gate, >20-day filtering,
memorabilia labelling, loopback validation and fenced JSON replies.
