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

The local route library opens a separate map/editor controller. Flutter owns
the unsaved waypoint draft and atomic persistence; the renderer owns its
numbered markers, terrain picking and drag gestures. Ground inspection is a
separate cancellable camera mode. See [ground view and routes](ground_view_and_routes.md).

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
plans, waypoints and settings. Current schema version: 6. Migrations preserve v1
through v5 records, adding photos in v3, spot classification in v4, drone profile
fields/provenance in v5 and battery inventory/condition/assignments in v6. Foreign keys
are enabled before use. Photo BLOBs are separate from spot/marker list queries;
spot edits, tags and photo changes commit together. Paged list queries select a
short notes preview; marker streams select only ID, name and coordinates and
suppress unchanged projections. See [spot search](spot_search.md) and
[photos and location](spot_photos_and_location.md).

Typed repository interfaces cover spots, drones, batteries, radio equipment,
flight plans/waypoints and preferences. Route snapshots retain explicit height
references and separate AGL offsets. Plan creation, waypoint replacement and
preference saves are transactional. Battery specifications, condition and
drone/plan links also commit together; type deletion preserves individual packs.
See [battery inventory](battery_inventory.md). Spots and drone profiles have editing/list
and detail screens; map preferences are restored and saved by the controller. See
[local data contracts and remaining feature scope](local_data.md).

The layer sheet also controls saved-spot visibility and the two overlay sources'
order. Preference loads gate editing; writes are serialized atomic snapshots.
See [map preferences and recovery](map_preferences.md).

Web uses the checked-in `sqlite3.wasm` / `drift_worker.js` resources. Native
repository tests use independent in-memory databases and a temporary file-backed
reopen test. Migration snapshots and fixtures live in `drift_schemas/` and
`test/generated_migrations/`.

## External data and geospatial services

`OsintProvider<T>` separates fetching and normalization from the controller, with
source/licence metadata, typed failures and listenable cache/update state.
`CachedOsintProvider<T>` shares the memory-cache lifecycle; `SwissUasProvider`
configures the normalized GeoJSON adapter. The controller preserves the provenance
of the actually displayed dataset and replaces expired layers on reactivation.
Imagery/terrain factories and source configuration live in `web/map_providers.js`.
See [provider contracts and provenance](osint_providers.md) for time/validity
semantics and substitution. Persistent caches remain #51.

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
resources locally as well. The current imagery/terrain source notices and service
terms are recorded in [map sources and attribution](map_sources_and_attribution.md)
(#8); the complete source/dependency release audit remains #44. The
[privacy and permission policy](privacy_and_permissions.md) records current request triggers and data flows.
Map requests disclose the viewed area to their providers; REFRAME requests contain supplied positions and elevations.

## Verification

Unit tests cover providers, coordinate services, database migration, repositories
and controller behavior. Widget tests cover home-screen selection effects and
layer controls, including cached overlay reactivation and renderer metadata.
CI runs formatting, analysis and tests before separate Web/Android build jobs.

The separately run [native integration test](../integration_test/globe_runtime_test.dart)
and local browser smoke harness start the real renderer with offline fixtures.
They do not validate current official airspace restrictions, assess iOS
compatibility or measure physical-device performance.
