# Field map and embedded studio

The **Field map** page puts the Dhun field operation on a satellite map: where produce
is grown, what work is planned on each plot, and which lots can be procured from the
wallet. It is a local rehearsal surface inside Logos Basecamp, not a live farmer
network.

The page is backed by a bundled web studio (`qml/web/`) that runs in QtWebView when the
host provides it. If WebView is unavailable, the page falls back to a native plan view
with the same calendar and procurement rail. The native view is a stylised plan, not a
Google map.

## What the page does

- **Produce on the land.** Twelve seeded lots (bajra, amla, sarson, methi, guava, etc.)
  are pinned around the Dhun site at Chak Gulabpura. Each pin carries a photo, season,
  price in DHN, live-in-rehearsal stock and the growing zone. Selecting a pin opens the
  lot card and a procure action.
- **Search.** The studio searches local produce, growers, field zones and the site
  first. With a Maps key it can also geocode an arbitrary place through the Google
  Maps Geocoding API. It does **not** use the Places API, extra place photos or live
  vendor listings.
- **Field activities.** Mark sowing, irrigation, compost, harvest, pruning, scouting,
  nursery or other work with a produce, zone, date, notes and visibility. Each activity
  is pinned at the lot or at a typed plot, and appears in the role's agenda and the
  7-day calendar. Activities can be marked planned or done.
- **Clips and updates.** The studio offers a 20-second camera capture and a file-attach
  fallback. Where the web view supports IndexedDB the clip is stored locally and adds an
  update to the field feed; the wallet room receives a text note, not the video.
- **Procurement.** A produce selection can open the wallet purchase drawer at the
  chosen quantity. Purchases within the role allowance settle directly; larger
  purchases become proposals. Confirmed purchases decrement the lot and record a field
  order in the wallet ledger.
- **Role sync.** Switching role in the wallet switches the studio's agenda and actions
  through the QML bridge. Studio-created activities, status changes, clip updates and
  produce selections are pushed back into the wallet state.

All field state is local rehearsal data. There is no server, no cross-user sharing, no
live inventory feed, no GPS tracking and no chain submission behind the map.

## Opening the map

1. Install the module (see the [README](../README.md)) and restart Basecamp.
2. Open **Field map** in the sidebar.
3. The studio starts in **bundled** mode from a `file://` URL. Without a Google key it
   shows the local plan view: produce pins, zones, activities and the wallet rail still
   work.
4. To use Google satellite, add a key once in the studio's **Google Maps key** dialog
   (the key button in the studio header, or **Add key** in the notice).
5. The key is written to the web view's `localStorage` only. It is never bundled,
   written to the repository or sent anywhere except Google's Maps endpoints.

The toolbar also has:

- **Local server / Bundled** — switch the studio source. Local server mode expects
  `scripts/serve-map.sh` on port 8788.
- **Reconnect** — reload the studio after a load failure.
- **Browser** — open the studio in the system browser. Run the local server first.
- **Mark work** and **Record clip** — jump to the studio composer; when the studio is
  unavailable, **Mark work** opens the native composer.

### Local server mode

```sh
./scripts/serve-map.sh
# http://127.0.0.1:8788/qml/web/
```

Use it for browser development, DevTools and for a conventional `http://127.0.0.1:8788`
origin in Google key referrer restrictions. It is not required for normal Basecamp use.

### Native fallback

If QtWebView cannot load (host without QtWebView, a failed page load, or the test
harness), the page shows the native plan view instead. It includes:

- a stylised map with 35 produce dots, 12 photo pins, activity pins and the Dhun site;
- the same role-aware 7-day calendar and activity list;
- the produce wallet rail with **Procure** actions;
- a native activity composer.

The native fallback does not record video, geocode places or draw Google tiles.

## Google Maps key

Use a **browser key**, not a server key.

1. In Google Cloud Console, enable **Maps JavaScript API** and **Geocoding API**.
2. Create an API key and restrict it to those two APIs.
3. Recommended referrer restrictions:
   - localhost / external browser: `http://127.0.0.1:8788/*`
   - embedded bundled studio: a `file://` page has no useful HTTP referrer, so a key
     restricted to website referrers will be rejected. Use API restrictions only for
     the embedded build, or use local server mode with a localhost referrer.
4. Open the Field map, open the key dialog, paste the key and save. The studio reloads.
5. If Google rejects the key, the studio keeps the local plan view and shows a
   **Fix key** notice with the expected referrer.

The key is visible to anyone with access to the web view profile and is stored in
plain text in its `localStorage`. Treat it as a public browser key: restrict it, set
quotas, and rotate it if it is shared or committed by mistake. A production deployment
should broker keys at the host instead of asking each user for one.

## Architecture

```
qml/pages/FieldMap.qml              native page, studio host, bridge, calendar, wallet rail
qml/components/StudioWebView.qml    guarded loader (falls back if QtWebView is missing)
qml/components/StudioWebViewImpl.qml  QtWebView instance and load signals
qml/web/index.html                  bundled studio markup
qml/web/app.js                      map, produce, activities, clips, procurement, bridge
qml/web/core.js                     pure studio helpers
qml/web/data.js                     studio seed catalogue and plots
qml/web/config.js                   non-secret configuration (no key)
qml/assets/produce/                 generated produce photography
scripts/serve-map.sh                localhost server for development
```

The QML bridge polls `window.dhunBridge.drainJSON()` every 1.1 seconds. Studio events:

| Event | Wallet effect |
| --- | --- |
| `ready` | Push role, inventory and activities into the studio |
| `role` | Switch the wallet role |
| `activity` | Create or update a field activity |
| `activity-status` | Mark a field activity planned or done |
| `open-offer` | Open the purchase drawer at the requested quantity |
| `update` | Add a field-feed update and one room note; never upload the clip |

QML calls into the studio through `window.dhunStudio`: `setRole`, `syncInventory`,
`syncActivities`, `importActivity`, `setActivityStatus`, `recordOrder`,
`openComposer`, `resetSchedule`, `openSetup` and `snapshot`.

The LGX package contains `qml/`; the studio is shipped at `qml/web/`. The `web/` folder
at the repository root was the first build and is not packaged.

## Camera and clip limits

Basecamp 0.2.3 does not declare `NSCameraUsageDescription` or
`NSMicrophoneUsageDescription`. An embedded web view cannot be assumed to receive
camera or microphone permission from the host. The studio therefore offers:

- **Attach a clip** as the reliable fallback;
- a native **Mark work** composer that adds a calendar activity and a room note but no
  media;
- a camera path that only works where the host grants the permission.

Do not claim that in-app recording works in Basecamp until the host app declares those
usage descriptions and permission prompts are verified. Recorded or attached clips are
never uploaded.

## Verification

The offscreen harness disables the web studio and exercises the native page, wallet
sync and bridge event handling:

```sh
export QML2_IMPORT_PATH=/Applications/LogosBasecamp.app/Contents/Resources/qt/qml
export QT_PLUGIN_PATH=/Applications/LogosBasecamp.app/Contents/Resources/qt/plugins
export DYLD_FRAMEWORK_PATH=/Applications/LogosBasecamp.app/Contents/Frameworks
export QT_QPA_PLATFORM=offscreen

/nix/store/fn7iqppsl6z7ikbspxnjirwdz345w8mj-qtdeclarative-6.9.2/bin/qml \
  -I qml tests/Flow.qml
```

QtWebView itself is not part of the offscreen harness. Embedded mode was smoke-tested
in a separate Cocoa run with the Basecamp Qt frameworks: the bundled `file://` studio
loaded, answered `snapshot` with the wallet role and 12 activities, and dispatched all
five studio events to the QML page. The Google satellite path was verified in both
Chrome and the embedded web view with a runtime key; the key was cleared afterwards.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Studio offline | Basecamp must bundle QtWebView; press **Reconnect**; otherwise use the native desk |
| Local plan view, no satellite | Open the key dialog and add a Maps key; check that Maps JavaScript API is enabled |
| “Google Maps rejected this key” | Website-referrer restriction on a `file://` page; use API restrictions only or local server mode |
| Blank page in Browser | Run `scripts/serve-map.sh`; the Browser button expects port 8788 |
| Map loads but search finds nothing | Local search is limited to the seeded catalogue; Google search needs a key and a geocodable query |
| Camera button fails | Host permission is missing; use **Attach a clip** or the native composer |
| Purchases do not appear in the market | Field purchases use the shared offer state; field orders are recorded in the wallet state |

## Data honesty

The seeded catalogue, farmer names, stock, prices, plots, activities and updates are
fictional rehearsal data for Chak Gulabpura. Google tiles and geocoding are real network
responses when a key and connection are present; everything else is local. Never
present this map as a live source of farmer inventory or verified conservation data.
