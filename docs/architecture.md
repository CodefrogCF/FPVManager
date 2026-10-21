# Architecture and storage

## Components

Flutter owns navigation, personal records, selections and route drafts. CesiumJS
owns imagery/terrain rendering, picking and camera interaction.

| Path | Responsibility |
|---|---|
| `lib/main.dart` | Home composition, navigation and spot synchronization |
| `lib/features/` | Globe, airspace, spots and equipment UI/controllers |
| `lib/core/database/` | Drift tables, repositories and migrations |
| `lib/core/models/`, `lib/core/geo/` | Typed routes, preferences, coordinates and heights |
| `lib/core/osint/` | External dataset contracts, provenance and cache lifecycle |
| `web/` | Renderer, bridge, providers, terrain, ground navigation and route editing |
| `test/`, `integration_test/` | Unit/widget/tooling tests and native renderer integration |

Web embeds `globe.html` in a same-origin iframe. Android uses `webview_flutter`
and an app-owned loopback asset server for Workers/Wasm. `GlobeController`
validates events and publishes coherent state; commands require acknowledgement.
See [bridge protocol](globe_bridge.md) and [renderer assets](cesium_assets.md).

Raw points, saved spots and UAS zones are mutually exclusive selections. Closing
a panel does not restore an earlier selection. Raw-point terrain actions and
Add Spot defaults read only the current raw point.

## Database and repositories

`FpvDatabase.open()` opens persistent Drift/SQLite storage on Android or Web.
The home screen opens it lazily and closes only resources it created. Injected
repositories/databases remain caller-owned. Tests use isolated databases.
Web uses bundled `sqlite3.wasm` and `drift_worker.js`.

Schema version is **7**. Tables cover spots/photos/tags, drones/parameter sources,
battery packs/types and assignments, radio equipment/drone assignments, flight
plans/waypoints and settings. Foreign keys are enabled. Historical schemas are
in `drift_schemas/`; migration fixtures are in `test/generated_migrations/`.
See [Contributing](../CONTRIBUTING.md) for generation and migration requirements.

Repository interfaces accept an injected database. `SpotRepository` is under
`lib/features/spots/data/`; equipment, route and preference repositories are under
`lib/core/database/repositories/`. Full-profile saves replace optional fields
and commit specifications, provenance and associations atomically. Legacy basic
drone/radio updates preserve advanced fields.

Spot list queries page summaries without photo BLOBs; marker streams project only
ID/name/coordinates. Photos and thumbnails load separately. Spot metadata, tags
and photo edits commit together. Drone deletion preserves flight plans with a
null assignment; plan deletion cascades to waypoints. Battery type deletion
clears template links while preserving packs. Association deletion preserves
the equipment and other linked records.

`FlightPlanRepository.saveRoute` saves metadata and ordered points atomically.
Waypoint replacement assigns new IDs and contiguous sequence numbers; use the
returned route snapshot rather than retaining old waypoint IDs. Typed heights
are position-only (`null`), absolute with an explicit reference, or AGL offsets.
Unknown stored references/modes raise `FormatException`; no datum is inferred.
The map's fixed 30 m AGL preview is independent of stored heights.

Map preferences own five keys: `map.style`, `map.uas.visible`,
`map.uas.fillOpacity`, `map.spots.visible` and `map.overlayOrder`. Defaults are
Satellite, false, 0.20, true and `["uasZones","savedSpots"]` (back to front).
Reads do not write defaults. Saves are serialized atomic snapshots; reset
deletes only these keys. Only successful user commands persist changes.

## External providers

`OsintProvider<T>` exposes source metadata, fetch with `forceRefresh`, listenable
status and disposal. `CachedOsintProvider<T>` shares concurrent fetches, retains
the last good snapshot on failure and rejects late results after disposal.
Retrieval time, cache expiry, HTTP Last-Modified and optional official validity
are distinct. An ordinary cache hit does not clear a failed refresh.

`GeoJsonOsintProvider` accepts EPSG:4326 FeatureCollections and rejects explicit
incompatible CRSs. `SwissUasProvider` supplies the source descriptor; compatible
providers can be injected into `GlobeController`. Other formats need normalizing
adapters. Imagery/terrain factories are in `web/map_providers.js`; local composition
can supply `window.FPVMapProviderConfig` before `globe.js`.

The controller tracks the dataset acknowledged by the renderer separately from
the latest download. UAS structural checks identify unusable geometry, partial
counts and missing details; unusable features are counted and excluded. Entirely
unusable nonempty replacements fail while retaining displayed data/provenance.
Explicit retry bypasses rejected snapshots. These checks do not prove coverage,
topology, currency or legal applicability. Caches are memory-only; tile services
do not acquire a fabricated whole-dataset retrieval time.

`PolygonIntersectionIndex` checks horizontal Polygon/MultiPolygon geometry,
including holes, boundary contact and all overlapping features, with bounding-box
filtering. `UasAirspaceChecker` uses the shared provider independently of renderer
visibility and reports the snapshot checked. Route segments are straight in WGS84
coordinates; antimeridian-crossing geometry must be split. Unsupported geometry
and source gaps remain explicit. Native checks run in an isolate; Web uses the
browser thread. Height/time applicability is outside the intersection check.

`web/terrain_service.js` bounds initialization/probe to 8 seconds and tile/sample
requests to 12 seconds. Tile failures/offline events install a labelled ellipsoid
fallback. Explicit retry replaces the provider within the viewer and refreshes
the selected imagery style; there is no automatic reconnect loop. Terrain
generations invalidate pending samples, raw picked heights and route geometry.
Late results cannot restore obsolete terrain. Ground mode ends on terrain loss.

See [coordinates and heights](coordinates_and_heights.md) for calculation
contracts, [privacy](privacy_and_permissions.md) for requests and permissions,
and [map sources](map_sources_and_attribution.md) for attribution.
