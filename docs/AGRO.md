# Agro and conservation advisory

The **Agro & conservation** tab (key `agro`, between Field map and Kitchen) turns a
gridded weather forecast into two kinds of guidance for Dhun's five field zones:

- **Agronomy** — what today asks of sowing, irrigation, spraying, harvest, nursery
  stock and field crews.
- **Conservation** — what the week means for soil cover, runoff and erosion, the
  water budget, native planting, fire risk and wildlife water points.

Everything on the page is **advisory**. No rule moves money, changes field state,
proposes a treasury action or speaks for the land. The page never writes to the relay.

## Where the numbers come from

| Source | Use | Notes |
| --- | --- | --- |
| [Open-Meteo](https://open-meteo.com/) `api.open-meteo.com/v1/forecast` | Daily and current values | Free, no key. Data CC BY 4.0. |
| [Ventusky](https://www.ventusky.com/) | Live atlas opened in the system browser | No public API; the app builds deep links only, it does not embed or scrape. |
| Google Maps | Satellite plot link | Opened externally, same coordinates as the zone. |

The backend slot `agroForecast(requestJson)` performs the fetch. It accepts
`{location, label, latitude, longitude, days, timezone}` and returns a compact
JSON object:

```json
{
  "success": true,
  "source": "open-meteo",
  "attribution": "Forecast data by Open-Meteo (CC BY 4.0)",
  "latitude": 26.7088,
  "longitude": 75.5868,
  "timezone": "Asia/Kolkata",
  "fetchedAt": 1793361000000,
  "cached": false,
  "current": { "temp": 27.2, "rh": 53, "rain": 0, "code": 1, "wind": 11.2,
               "gust": 28.1, "direction": 46, "soil": 0.176, "soilTemp": 29.9 },
  "days": [
    { "date": "2026-10-30", "code": 1, "tMax": 31.4, "tMin": 17.2, "rain": 0,
      "chance": 4, "wind": 12.1, "gust": 27.8, "direction": 44, "rh": 48,
      "et0": 4.6, "uv": 6.4, "soil": 0.18, "dew": 14.1, "cloud": 12 }
  ]
}
```

- `days` is clamped to 1–14 and defaults to 7.
- The timezone defaults to `Asia/Kolkata` and is validated before use.
- Coordinates default to the estate centre and are validated to
  latitude −90…90 and longitude −180…180.
- Successful replies are cached in memory for 30 minutes per coordinate/day/timezone
  key; a cached reply sets `"cached": true` and keeps its original `fetchedAt`.
- Network timeout is 8 seconds with a 9-second guard. Failures return
  `{success: false, error, source: "open-meteo"}` and the page keeps the last good
  forecast on screen.

Requesting `current` and `daily` in one call keeps it to one HTTPS request per zone
per half hour.

## Zones

Coordinates sit around the Dhun estate near Chak Gulabpura, Rajasthan. They are the
same five zones used by the landscape atlas and the Community Makes web app.

| id | Zone | Latitude | Longitude |
| --- | --- | --- | --- |
| `farms` | Farms & market garden | 26.7088 | 75.5868 |
| `orchard` | Orchards & groves | 26.7122 | 75.5906 |
| `kitchen` | Kitchen garden | 26.7143 | 75.5936 |
| `dairy` | Dairy & poultry | 26.7077 | 75.5958 |
| `estate` | Dhun estate centre | 26.7113 | 75.5901 |

All five are within about 1.5 km, so the forecast is nearly identical between them;
the zone selector mainly changes the Ventusky and satellite links and the label.

## Agronomy rules

Rules live in `qml/agro.js` (`dayAdvisories`). They are pure functions over one day
object, so they can be exercised headlessly (see `tests/Flow.qml`).

| Trigger | Tone | Advisory |
| --- | --- | --- |
| rain ≥ 25 mm | red | Heavy rain — runoff and erosion, secure beds and inputs |
| rain ≥ 8 mm | green | Soaking rain — switch off drip 24–48 h, direct-sow into moisture |
| rain ≥ 2 mm | blue | Light rain — hold irrigation, scout leaf spots |
| chance ≥ 60% | amber | Rain may pass — do not count it as irrigation |
| tMax ≥ 42 °C | red | Severe heat — dawn/dusk water, 50% shade net |
| tMax ≥ 38 °C | amber | Heat stress — water seedlings first, mulch basins |
| tMax ≥ 35 °C | blue | Warm day — check 10 cm moisture before evening |
| tMin ≤ 5 °C | red | Frost risk — cover at dusk, no burning |
| tMin ≤ 8 °C | amber | Cold night — close nursery, hold transplants |
| gust ≥ 50 km/h | red | Damaging gusts — stake crops, secure net |
| gust ≥ 35 km/h | amber | Windy — spray only in the morning lull |
| RH ≥ 85% with 18–32 °C, or tMax − dew ≤ 2 | amber | Fungal pressure — airflow over spraying |
| soil < 0.08 and rain < 5 mm | amber | Dry topsoil — irrigate seedbeds, top up mulch |
| soil > 0.34 | blue | Wet topsoil — keep traffic off |
| ET0 ≥ 6.5 mm and rain < 8 mm | amber | High water demand — add 20–30% to drip |
| UV ≥ 9 | blue | Very high UV — shift crew hours |
| none crossed | green | Workable field day |

The page shows at most six cards for today.

## Conservation rules

Rules live in `qml/agro.js` (`conservationAdvisories`) and read the whole week plus
the current reading. They do not replace a soil test, a grazing plan or a fire plan.

| Reading | Tone | Advisory |
| --- | --- | --- |
| ≥ 40 mm rain in 72 h | red | Runoff watch — drains and bunds before the rain |
| one day ≥ 25 mm | red | Erosion risk — no tillage while saturated |
| week ≥ 25 mm | amber | Sheet-flow watch — walk the bund line, protect grass strips |
| rain − ET0 ≤ −20 mm | amber | Irrigation deficit — stagger zones, read the borewell meter |
| rain − ET0 ≥ +30 mm | blue | Surplus water — recharge pits, spreader bund cuts |
| otherwise | green | Water budget roughly balanced |
| week rain < 5 mm and ET0 ≥ 20 mm | amber | Bare-soil exposure — mulch or residue on every bed |
| topsoil > 0.34 | blue | Saturated topsoil — keep stock and tractors off |
| June–September | green | Native planting window — khejri, neem, ber, local grasses |
| October–November | blue | Seed collection — several parents, label and bank |
| December–February | amber | Winter sapling care — mulch basins, tree guards |
| March–May | amber | Summer survival watering — deep dawn water |
| ≥ 38 °C with RH ≤ 25% | red | Fire weather — no burning, clear biomass, water ready |
| RH < 30% with gusts ≥ 35 km/h | amber | Wind-driven fire spread — no machinery on cured grass |
| tMax ≥ 40 °C | amber | Wildlife water stress — shade and shallow water |
| tMin ≤ 5 °C | blue | Cold-night shelter — keep water ice-free, leave margins |
| ≥ 20 mm rain inbound | blue | Recharge opportunity — desilt pits before the shower |

At most six conservation cards are shown.

## Field windows

The same week is summarised into four inferred windows:

- **Sow / transplant** — 5–25 mm rain, tMax < 38 °C, gusts < 40 km/h.
- **Spray or foliar feed** — rain < 1 mm, wind < 16 km/h, 12–34 °C.
- **Harvest and dry** — rain < 2 mm, RH < 75%, gusts < 25 km/h.
- **Hold field work** — rain ≥ 8 mm.

These are heuristics, not a scheduling system. The page says so in the card.

## Ventusky links

Ventusky has no public API, so the page builds deep links:

- Atlas: `https://www.ventusky.com/?p=<lat>;<lon>;<zoom>&l=<layer>`
- Embed form (kept in `agro.js` for reuse): `https://embed.ventusky.com/?p=…&l=…`

Layers: rain (3 h), rain chance, air temperature at 2 m, wind at 10 m, gusts,
humidity, dew point, cloud cover and soil temperature at 5 cm. Links open in the
system browser via `Qt.openUrlExternally`.

## Limits and honesty

- One forecast grid point cannot see a bed, a soil test, a spray record or a canopy.
  The page repeats this in its footer.
- Probabilities and volumes are model output; a rain gauge still wins.
- No advisory is an instruction to burn, spray a banned product or move stock.
  Fire guidance is protective only.
- The page makes no claim about carbon or biodiversity outcomes; it suggests
  practices, it does not certify them.
- UI copy says **advisory only** and the backend returns Open-Meteo's CC BY 4.0
  attribution with every reply.

## Tests

`tests/Flow.qml` exercises the rules headlessly:

```sh
export QML2_IMPORT_PATH=/Applications/LogosBasecamp.app/Contents/Resources/qt/qml
export QT_PLUGIN_PATH=/Applications/LogosBasecamp.app/Contents/Resources/qt/plugins
export QT_QPA_PLATFORM_PLUGIN_PATH="$QT_PLUGIN_PATH/platforms"
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
/nix/store/fn7iqppsl6z7ikbspxnjirwdz345w8mj-qtdeclarative-6.9.2/bin/qml tests/Flow.qml
```

Sixteen agro checks cover zone lookup, the Ventusky URL, heavy-rain and heat flags,
the workable-day fallback, wet-week runoff and surplus, dry-week fire and wildlife
rules, the irrigation deficit, the four field windows, the weekly summary and both
backend-payload outcomes.

## Build and install

```sh
NIX_CONFIG="experimental-features = nix-command flakes" nix build .#lgx-portable
```

Flatten the archive into
`~/Library/Application Support/Logos/LogosBasecamp/plugins/dhun_commons` exactly as in
the top-level README. The tab is native QML; nothing extra is needed beyond the
`dhun_commons` module already required by the app.
