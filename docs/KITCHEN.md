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

1. asks the Dhun Commons backend (`readPhotoBase64`) to read a local image and
   return base64 (PNG, JPEG or WebP, ≤ 8 MiB; HEIC is refused with an error);
2. sends an OpenAI-compatible `POST /v1/chat/completions` request to a
   **loopback** endpoint with the image as a `data:` URI;
3. parses a strict JSON reply of dish names, optional guest count and optional
   notes;
4. matches the names against the built-in dish library and reports unmatched
   lines instead of inventing ingredients;
5. rebuilds the plan from the matched lines.

The endpoint must be `127.0.0.1`, `localhost` or `[::1]`. The QML client refuses
any other host before opening a request. The default is
`http://127.0.0.1:11434/v1` with model `qwen2.5vl:7b`.

### Free models verified for this task

Licences below were checked against the Hugging Face model API on 2026-10-27.
No model is bundled, installed or claimed to be running by this repository.

| Model | Hugging Face ID | Licence | Notes |
|---|---|---|---|
| Qwen2.5-VL 7B Instruct | `Qwen/Qwen2.5-VL-7B-Instruct` | Apache-2.0 | Strong document and scene-text reading; recommended default |
| LLaVA-OneVision Qwen2 7B | `llava-hf/llava-onevision-qwen2-7b-ov-hf` | Apache-2.0 | General vision, good menu/whiteboard reading |
| Moondream 2 | `vikhyatk/moondream2` | Apache-2.0 | Very small; faster on CPU, weaker on dense handwriting |
| InternVL 2.5 8B | `OpenGVLab/InternVL2_5-8B` | MIT | Strong OCR; heavier setup |
| Florence-2 large | `microsoft/Florence-2-large` | MIT | OCR/region tasks; not a chat model, needs a wrapper |

Models that returned no licence tag in the API response (for example some
Qwen2.5-VL 3B and MiniCPM-V repositories) are deliberately not listed.

### Ollama

```sh
ollama pull qwen2.5vl:7b
ollama serve            # listens on 127.0.0.1:11434 by default
```

Keep the default loopback bind. In the Kitchen tab use
`http://127.0.0.1:11434/v1`, model `qwen2.5vl:7b`, then **Check server**. Recent
Ollama builds accept `image_url` data URIs on the OpenAI-compatible endpoint.
If a build does not, use llama.cpp below.

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
