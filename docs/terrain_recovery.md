# Terrain failures and recovery (#7)

FPVManager treats an unavailable terrain service as a recoverable map condition.
The viewer stays usable, with a clearly labelled **flat ellipsoid map** and no
terrain-height results. It does not silently present a flat height as measured
ground elevation. This is a conservative response to a failed advertised tile;
it does not claim that the remaining loaded terrain provides complete coverage.

## Runtime behavior

`web/terrain_service.js` owns terrain initialization, error subscription, bounded
height sampling and explicit retry. The same local module is packaged for Web
and the native WebView. It uses the existing swisstopo endpoint and credits.

| Condition | Result |
|---|---|
| Initial metadata or root-tile request fails | Start the viewer with the flat fallback and a terrain warning |
| Initial connection/probe takes longer than 8 seconds | Discard the attempt and show the flat fallback |
| A rendered terrain tile fails after initialization | Handle the provider's `errorEvent`, disable automatic tile retry, replace terrain with the flat fallback and report the outage |
| A real tile request remains pending for 12 seconds | Enter the fallback, cancel the Cesium request where available and reject the request; this also works without a height query |
| Browser reports offline | Invalidate current terrain work, switch to flat and report offline |
| Browser reports online again | Offer an explicit retry; the event is only a connectivity hint |
| Height sampling fails or takes longer than 12 seconds | Reject the correlated query and enter the terrain fallback |
| User cancels a height query | Reject it without degrading otherwise healthy terrain |
| User selects **Retry terrain** | Share one bounded connection/probe attempt; on success install a fresh provider and refresh the selected base style |
| Offline diagnostic mode (`globe.html?offline=1`) | Use the local grid/ellipsoid, with no terrain/imagery I/O or recovery request |

A provider is accepted only after its metadata and an actual level-zero tile
have been read successfully. This establishes basic service access, not the
availability or accuracy of every future tile. A later tile failure can return
the app to the warning state. Cesium's normal availability-based subdivision and
upsampling remain in use; areas the provider marks unavailable are different
from an advertised tile that fails to load.

Retries replace terrain inside the existing viewer, preserving the camera,
saved-spot/UAS data sources, visibility, order and requested base style. The
renderer is not reloaded and personal records/settings are not rewritten by a
terrain retry. There is no automatic reconnection loop. A full renderer reload
continues to follow the separate [bridge recovery contract](globe_bridge.md).

## Heights and state consistency

Every terrain replacement invalidates pending samples. A timed-out request may
finish in the browser's underlying network stack, but its response cannot install
an obsolete provider or return a height from an earlier terrain generation.
Command cancellation and page disposal detach listeners and invalidate work.
The public provider instance's tile-request method preserves Cesium's `undefined`
scheduling-deferral contract while bounding actual request promises; no vendored
runtime code is changed. In-flight network operations without an exposed Cesium
request handle may still finish, with their late results ignored.
Renderer-cancelled tile requests retain Cesium's cancellation path instead of
becoming timeout outages. The request cancellation fields are tied to the pinned
1.145 runtime and must be rechecked with the provider contract on a vendor upgrade.

The renderer publishes `terrain-status` with a validated `state` and `reason`.
The controller distinguishes `loading`, `ready`, `unavailable` and `offline`.
Unknown states, incompatible reasons, old sessions and out-of-order envelopes
cannot update terrain state. Existing `globe-ready.terrainAvailable` remains
supported, followed by the current detailed terrain status on each hello.

On a terrain state transition the controller clears a raw picked point and
invalidates its height epoch before notifying the UI. It rejects a late height
response even if a later retry has already recovered the service. Saved-spot
and UAS selections remain independent. Picks on the flat fallback have an
`unverified` height reference; the terrain action is disabled there. A fresh
point must be selected after recovery. See [height references](coordinates_and_heights.md).

The persistent Flutter terrain banner sits outside the WebView/iframe and stays
visible even when a saved spot or UAS detail panel is open. Its retry control and
message use a vertical layout on narrow screens. The native coordinate footer
continues to sit outside the map credits. Recoverable terrain conditions do not
use the fatal `globe-error` path that replaces a native map with an error screen.

## Verification

Deterministic tests cover failed initialization/probe, tile errors, offline and
online transitions, shared retries, deadlines, cancellation, disposal and stale
responses. Controller/widget tests cover status validation, height invalidation,
disabled actions, retry feedback, preservation of the map widget and 320-pixel
layout with enlarged text.

```sh
node --test test/js/globe_bridge.test.cjs test/js/map_attribution.test.cjs test/js/terrain_service.test.cjs
python tool/serve_globe_smoke.py
```

Open `http://127.0.0.1:8765/terrain-smoke` for the real Cesium/WebGL test with
**synthetic local** heightmap tiles. The server supplies HTTP 503 metadata errors,
HTTP 404/500 tile errors and delayed HTTP responses. The test verifies real
terrain decoding, flat fallback (including stalled render tiles without a height
query), correlated errors, explicit recovery, camera/layer preservation and
rejection of a late response. Offline/online browser
events are simulated by the fixture; they are not a physical Wi-Fi test. No real
swisstopo data or personal database is used by this harness.

`/smoke` retains the original deterministic offline renderer/bridge check;
`/smoke?online=1` checks the live services and source notices. `--port 0` chooses
a free loopback port. `--build` serves `build/web` to verify compiled app assets.
`--terrain-fixture` additionally injects the synthetic provider into the app's
`globe.html` preview.
`--fault metadata-fail-once` makes the first metadata request fail and subsequent
requests succeed, so the built app's visible **Retry terrain** action can be
checked directly.
The fixture script and test pages live under `test/web`; they are not Flutter
assets and are not included in the production builds.
The explicit fixture server's control endpoint accepts only same-origin local
requests and has no effect on a normally deployed app.

### Recorded local checks (2026-10-20)

- Dependency resolution with the enforced lockfile, format check for 76
  hand-written Dart files and analysis with fatal warnings/infos passed.
- The complete Flutter suite passed **182 tests**, including the new controller
  and narrow-layout/widget recovery cases. The renderer JavaScript suite passed
  **21 tests**; the Python tooling suite passed **4 tests**.
- Vendor verification passed for all **395** pinned Cesium files, including
  hashes and Flutter asset paths. No vendored runtime files were edited.
- The Web release build passed with local renderer resources
  (`flutter build web --release --no-pub --no-web-resources-cdn`). Its renderer
  scripts matched the working sources at both the Web root and Flutter asset
  paths; original Cesium hashes, local CanvasKit and fixture exclusion passed.
- The compiled Web app showed the persistent warning after a local HTTP 503,
  then recovered through its actual **Retry terrain** button without replacing
  the map. The synthetic HTTP fault harness passed all scenarios against the
  built renderer, including a stalled render tile without a height query and
  the ignored late response after recovery.
- The built renderer also passed the live swisstopo smoke: loaded terrain,
  complete credits for all three styles, local geometry worker, overlays,
  ordering/visibility and restored settings after an actual iframe reload.
- The Android debug build passed (`flutter build apk --debug --no-pub`). The
  resulting APK passed ZIP integrity, current renderer/terrain-script comparison,
  original Cesium hashes and fixture exclusion. Its SQLite libraries were
  verified as ARMv7, ARM64 and x86_64 ELF binaries.

An Android device still needs an acceptance check: lose/recover the connection,
move to an uncached area, retry terrain, select a fresh point, change orientation
and inspect credits and the terrain banner. Local builds and synthetic browser
faults do not establish physical-device network behavior or frame-rate budgets.

Implementation follows the pinned CesiumJS **1.145.0** APIs:
[terrain provider](https://cesium.com/learn/cesiumjs/ref-doc/CesiumTerrainProvider.html),
[tile error and retry](https://cesium.com/learn/cesiumjs/ref-doc/TileProviderError.html),
and the actual [tile-error propagation in 1.145](https://github.com/CesiumGS/cesium/blob/1.145/packages/engine/Source/Scene/GlobeSurfaceTile.js).
Vendored runtime files and their licences remain unchanged. This work does not
implement downloaded regions or automatic cross-provider fallback. Snapshot
provenance and in-memory freshness follow the [OSINT contracts](osint_providers.md)
(#4); persistent/offline cache policies remain #40/#51.
