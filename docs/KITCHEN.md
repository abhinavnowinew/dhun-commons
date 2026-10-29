# Kitchen: menu photo → farm sourcing → pantry

The Kitchen tab turns a menu for a number of guests into four things:

1. a **sourcing plan** from the seeded farm map, with each ingredient tied to a
   zone, a Market lot or a field-plot estimate;
2. **waste-part uses** for stalks, leaves, peels, roots and seeds, with a
   caution on every line;
3. **lesser-known native additions** that fit the menu and the season;
4. a **guarded pantry** of preserves with a shelf life over 20 days, plus a
   guest memorabilia label for a checked batch.

The built-in planner remains deterministic and authoritative for quantities,
local sourcing, costs, waste uses and food-safety rules. When Ollama is running
on loopback, **Suggest menu locally** asks it to choose dishes from the built-in
library; the Kitchen call is local-only and cannot fall back to OpenRouter. If
Ollama is unavailable, the offline planner remains available. Photo reading is
also optional and uses a loopback model.

## Using the tab

1. Open **Kitchen** in the sidebar.
2. Type the cuisine, occasion, guest preferences and any allergies; set the
   guest count and planning month. You can also choose a photo to transcribe.
3. Press **Suggest menu locally** to ask Ollama for library dishes, or use the
   built-in planner. Review/edit the menu, then press **Recalculate sourcing**.
4. Read the total and per-person estimate, then the sourcing list by zone. A
   *Market lot* is seeded rehearsal stock; unlisted needs and lot shortfalls are
   estimates to confirm with the grower, not live inventory.
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

## Menu suggestions and planning

The prompt accepts requests such as *"A warming vegetarian lunch for 20;
prefer produce already listed locally."* Add food preferences or allergies in
the prompt and verify ingredients before cooking. A number of guests in the
prompt updates the guest field; otherwise the chosen guest count is kept.

The local model receives only the request, guest count, planning month, allowed
dishes with their ingredient lists, and the app's seeded produce lots. It returns
candidate dish names and optional short waste tips. The app accepts only dish
names from its library; it ignores model-supplied prices, quantities and stock.
The built-in planner then scales the ingredient amounts and computes itemized
sourcing estimates. If local inference is unavailable, Kitchen does not contact
a remote provider and offers the deterministic built-in planner instead.

The **Built-in planner** uses direct dish names, mood routes (cold, tired, hot,
light, festive, fresh), and seasonal fallback menus. It remains available even
when Ollama is offline. The **Cook without waste** card, field-map sourcing,
market coverage and pantry safety gate always come from local app logic.

## Optional local vision model

### What it does

Pressing **Read photo locally**:

1. asks the module backend (`startMenuPhoto`) to read the local image — PNG,
   JPEG or WebP, ≤ 8 MiB; HEIC is refused with an error;
2. the backend sends an OpenAI-compatible `POST /v1/chat/completions` request to
   a **loopback** endpoint with the image as a `data:` URI and returns the
   finished result as one JSON snapshot — the slot waits on the reply (185 s
   transfer timeout, 190 s guard) instead of reporting progress separately;
3. the tab's `logos.watch` callback parses that snapshot as a strict JSON reply
   of dish names, optional guest count and optional notes;
4. matches the names against the built-in dish library and reports unmatched
   lines instead of inventing ingredients;
5. rebuilds the plan from the matched lines.

The result comes back through the slot's return value on purpose. With a
`.rep` PROP, the replica in the UI process kept reading its cached value, so an
earlier asynchronous build posted the request successfully but the tab never
saw the stored reply. A slot invoked through `logos.watch` is the supported path for a value that
crosses the module boundary; the page also uses this pattern for its quiet
startup check of the local model server.

The request lives in the backend on purpose. Basecamp sandboxes plugin QML
network access with a deny-all access-manager factory
(`app/restricted/QmlSandbox.cpp`, `DenyAllNAMFactory`), so a QML
`XMLHttpRequest` to `127.0.0.1:11434` fails inside the app even when the same
request works from a plain Qt harness. The backend runs in the host process and
can still reach a loopback server. A side effect is that remote endpoints are
refused in two places: the tab checks the endpoint before calling the slot, and
`loopbackChatUrl` re-validates it in C++.

The photo reader uses a loopback endpoint (`127.0.0.1`, `localhost` or
`[::1]`) and the local model default bundled into the page code. The everyday
Kitchen workflow hides endpoint and model settings; there is no cloud photo
upload. Typed menu suggestions use the chat model Ollama advertises locally.

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

The same request was repeated from the installed app (module 0.3.2 in Basecamp
0.3.2, plugin QML sandbox active):

- **Check server** reported `Local server reachable at
  http://127.0.0.1:11434/v1/models · qwen2.5vl:3b`; Ollama logged
  `GET /v1/models` 200 from `127.0.0.1`.
- **Read photo** produced, in Ollama's access log, `POST /v1/chat/completions`
  from `127.0.0.1` with status 200 in 14.27 s and 1,806 prompt tokens (104
  text, 1,702 image) plus 76 completion tokens — the same image and prompt as
  the standalone run above. Seconds later the tab showed the model provenance
  line (“Extracted by qwen2.5vl:3b on loopback · review the lines and the safety
  gate.”), which is set only after the reply parses, matches the dish library
  and the plan rebuilds; the session log held no QML errors. While the call was
  in flight the page still painted “Working…” and its status line.
- An earlier 0.3.1 build used the same backend request and got the same 200
  reply (12.45 s on a cold model), but its tab kept reading cached
  `modelState`/`modelReply` properties and stayed on “Working…”. That is why
  0.3.2 returns the result from the slot itself.

Before the backend transport, the same click failed because the sandbox blocks
plugin QML networking; the probe and the chat request both reach the model now.

### Ollama

```sh
ollama serve               # listens on 127.0.0.1:11434 by default
ollama pull qwen2.5vl:3b   # optional; this machine already has it installed
```

Keep Ollama bound to loopback. Kitchen checks availability when it opens and
uses the model Ollama advertises (or `DHUN_LOCAL_MODEL` if configured in the
launch environment). The normal page has no endpoint or model fields. If the
local model is unavailable, typed suggestions do not fall back to cloud
inference. The optional photo reader also uses loopback; recent Ollama builds
accept `image_url` data URIs on its OpenAI-compatible endpoint.

### llama.cpp

```sh
llama-server \
  -m Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf \
  --mmproj mmproj-Qwen2.5-VL-7B-Instruct-f16.gguf \
  --host 127.0.0.1 --port 8080
```

For text chat, a loopback server that exposes the OpenAI-compatible `/v1/models`
and `/v1/chat/completions` endpoints can be selected through
`DHUN_LOCAL_MODEL_ENDPOINT` and `DHUN_LOCAL_MODEL` in the app's launch
environment. Kitchen still enforces local-only requests. The photo reader uses
the page's built-in Ollama loopback defaults.

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
- Field-plot costs and the cost of any shortfall beyond a listed Market lot are
  estimates based on seeded ingredient prices; totals include both listed-lot
  and estimated portions. Itemized costs add up to the estimate total.
- The app has no live pantry or farmer inventory ledger. Market lots and field
  plot records are local rehearsal data; confirm availability and price before
  sourcing or buying.
- Typed menu suggestions and photo reading use loopback Ollama only. Kitchen
  sets a `localOnly` flag at the backend boundary, so an unavailable local model
  cannot trigger remote inference or paid OpenRouter usage.
- Model output is treated as a suggestion. It supplies recognized dish names
  and optional waste tips only; guest-scaled quantities, price estimates,
  sourcing status, waste routes and safety rules come from local app logic.
- Allergies are not certified by this demo. Verify the full ingredient list
  and cross-contact risk before cooking or serving.

## Tests

```sh
# 140 wallet, field, relay, kitchen, assistant and reward checks
QML2_IMPORT_PATH=/Applications/LogosBasecamp.app/Contents/Resources/qt/qml \
QT_PLUGIN_PATH=/Applications/LogosBasecamp.app/Contents/Resources/qt/plugins \
QT_QPA_PLATFORM_PLUGIN_PATH=$QT_PLUGIN_PATH/platforms \
DYLD_FRAMEWORK_PATH=/Applications/LogosBasecamp.app/Contents/Frameworks \
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
/nix/store/fn7iqppsl6z7ikbspxnjirwdz345w8mj-qtdeclarative-6.9.2/bin/qml tests/Flow.qml
```

The kitchen checks cover menu parsing, guest scaling, per-person totals,
itemized costs and partial-lot estimates, plot fallback, waste-part coverage,
native picks, safety gates, >20-day filtering, memorabilia labelling, loopback
validation and local-model reply parsing.
