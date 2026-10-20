# Architecture

## Current boundaries

FPVManager is a Flutter application with a CesiumJS rendering surface. Flutter
owns application navigation, personal data and observable map state. Cesium owns
terrain/imagery rendering, picking and camera movements. The implementation is a
prototype. See [the bridge protocol](globe_bridge.md) for reliability boundaries
and [coordinates and heights](coordinates_and_heights.md) for geospatial references.

`FPVHomeScreen` composes the globe, layer controls and spot navigation. It opens a
local `FpvDatabase` lazily and watches `SpotRepository` to synchronize saved
markers. Tests may inject a repository; the home screen closes only a database
that it created itself.

## Renderer communication

- Web embeds `web/globe.html` in an iframe. Flutter sends JSON using `postMessage`;
  the Flutter listener checks the origin. The renderer checks origin and parent.
- Android uses `webview_flutter`, loading bundled files from an app-owned loopback
  asset server with a real origin for Workers and Wasm.
  Flutter sends typed commands through `window.FPVManager.receive`; events return
  through the `FPVBridge` JavaScript channel.
- `GlobeController` validates recognized events, updates state and notifies its
  Flutter listeners. Layer visibility is confirmed by renderer status events.
- Large JSON commands are transferred in chunks. Terrain requests use IDs,
  a 30-second timeout and cancellation when detached/disposed. Marker revisions
  help ignore older marker datasets.

The bridge uses protocol version 1, per-page sessions, command acknowledgements,
configurable timeouts and bounded transfer buffers. It restores requested map
style, UAS visibility/opacity and markers on reload/resume. Camera and transient
selection return to the initial state. See [protocol details](globe_bridge.md).

## Selection semantics

Raw map points, saved spots and UAS features are mutually exclusive selections:

| New selection | Active state | Cleared state |
|---|---|---|
| Map point | `selectedPoint` | `selectedSpotId`, `selectedUasZone` |
| Saved spot | `selectedSpotId` | `selectedPoint`, `selectedUasZone` |
| UAS feature | `selectedUasZone` | `selectedPoint`, `selectedSpotId` |

Closing a saved-spot or UAS panel clears that selection without restoring a
previous raw point. Raw-point terrain queries and Add Spot defaults read only
`selectedPoint`. Consequently, terrain queries are disabled while a saved spot
is selected, and Add Spot opens without unrelated prior point coordinates.
The saved-spot Fly to action uses the spot's own coordinates.

The layer sheet displays confirmed renderer opacity, with a local preview only
while the user is adjusting the slider.

## Local data

Drift/SQLite stores spots, photos, drones, batteries, radio equipment, flight
plans, waypoints and settings. Current schema version: 3. Migrations preserve v1
spots and all v2 records while adding the indexed photo table in v3. Foreign keys
are enabled before use. Photo BLOBs are separate from spot/marker list queries;
spot edits and photo changes commit together. See [photos and location](spot_photos_and_location.md).

Typed repository interfaces cover spots, drones, batteries, radio equipment,
flight plans/waypoints and preferences. Route snapshots retain explicit height
references and separate AGL offsets. Plan creation, waypoint replacement and
preference saves are transactional. Only spots currently have editing/list
screens; map preference persistence is not yet wired to the controls. See
[local data contracts and remaining feature scope](local_data.md).

Web uses the checked-in `sqlite3.wasm` / `drift_worker.js` resources. Native
repository tests use independent in-memory databases and a temporary file-backed
reopen test. Migration snapshots and fixtures live in `drift_schemas/` and
`test/generated_migrations/`.

## External data and geospatial services

`OsintProvider<T>` separates fetching from the controller. `OsintDataset<T>` records
provider identity, source URL, fetch time and optional HTTP Last-Modified.
`SwissUasProvider` validates downloaded GeoJSON, deduplicates in-flight requests,
provides a one-hour in-memory cache and retains a previous dataset on failed
refresh. A renderer layer can currently be reused without checking that TTL.
Persistent cache/freshness states are tracked in #51.

`GeoCoordinateService` implements approximate Swiss WGS84/LV95 transformations and
defines explicit height references. Terrain responses carry a required WGS84
ellipsoid reference. The terrain dialog offers opt-in REFRAME conversion through
Bessel to LN02, retaining the original value on failure. Its AGL calculator adds
a relative offset to ground in the same datum. Datum mismatches and unknown
references are rejected; no fixed geoid offset is assumed. See
[reference contracts, calculations and limits](coordinates_and_heights.md).

Current external dependencies include:

| Purpose | Host / source |
|---|---|
| CesiumJS code, styles and related assets | Local pinned `web/cesium/` bundle |
| Swiss imagery and map styles | `wmts.geo.admin.ch` |
| Swiss terrain | `3d.geo.admin.ch` |
| FOCA/BAZL UAS GeoJSON | `data.geo.admin.ch` |
| REFRAME transformation services, when invoked | `geodesy.geo.admin.ch` |

The documented Web build uses `--no-web-resources-cdn` to load Flutter renderer
resources locally as well. This list is an architecture inventory, not a completed
privacy/license audit; #5/#44 cover that documentation. Map requests disclose the viewed area to their
providers; REFRAME requests contain supplied positions and elevations.

## Verification

Unit tests cover providers, coordinate services, database migration, repositories
and controller behavior. Widget tests cover home-screen selection effects and
layer controls, including cached overlay reactivation and renderer metadata.
CI runs formatting, analysis and tests before separate Web/Android build jobs.

The separately run [native integration test](../integration_test/globe_runtime_test.dart)
and local browser smoke harness start the real renderer with offline fixtures.
They do not validate current official airspace restrictions, assess iOS
compatibility or measure physical-device performance.
