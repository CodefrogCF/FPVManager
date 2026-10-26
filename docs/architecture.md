# Architecture and storage

## Components

Flutter owns navigation, personal records, selections and route drafts. CesiumJS
owns imagery/terrain rendering, picking and camera interaction.

| Path | Responsibility |
|---|---|
| `lib/main.dart` | App startup and theme |
| `lib/features/home/` | Navigation, map actions, selections and spot synchronization |
| `lib/features/routes/analysis/` | Bounded sampling, profile/flight/energy models and constraint/proximity checks |
| `lib/features/routes/transfer/` | Bounded GeoJSON/GPX codecs and explicit local file selection/export |
| `lib/features/simulation/` | Flight settings/profile defaults and coalesced Android input transport |
| `lib/features/` | Globe, airspace, spots and equipment UI/controllers |
| `lib/core/database/` | Drift tables, repositories and migrations |
| `lib/core/models/`, `lib/core/geo/` | Typed routes, preferences, coordinates and heights |
| `lib/core/osint/` | External dataset contracts, provenance and cache lifecycle |
| `web/` | Renderer, bridge, providers, terrain, shared navigation input, flight/ground controllers and route editing |
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

Schema version is **9**. Tables cover spots/photos/tags, drones/parameter sources,
battery packs/types and assignments, radio equipment/drone assignments, flight
plans/waypoints, preflight checklists/templates, raw telemetry and settings.
Foreign keys are enabled. Historical schemas are
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

`FlightPlanRepository.saveRoute` saves metadata, ordered points, battery assignments
and versioned planning assumptions atomically.
Waypoint replacement assigns new IDs and contiguous sequence numbers; use the
returned route snapshot rather than retaining old waypoint IDs. Typed heights
are position-only (`null`), absolute with an explicit reference, or AGL offsets.
Unknown stored references/modes raise `FormatException`; no datum is inferred.
Waypoint speed is outgoing airspeed in m/s; null remains unknown. AGL and WGS84
ellipsoid heights drive the map. Missing/incompatible heights use marked 30 m AGL
previews and are excluded from clearance calculations. Profile sampling uses
sequential batches of at most 256 positions and 4,096 positions per route;
draft/terrain/renderer changes invalidate pending results and warning highlights.

Map preferences store base style, UAS/spot visibility, overlay order and obstacle
WMS visibility/opacity plus vector visibility/categories. Defaults keep both
obstacle options and advisory hazard areas disabled; horizontal buffer distance
and visibility are stored independently. Reads do not write defaults; serialized atomic saves
and reset preserve unrelated settings. Obstacle settings retain the requested
state through network failures so an explicit retry or renderer reload can recover.

Route transfer follows [RFC 7946](https://www.rfc-editor.org/rfc/rfc7946.html)
and [GPX 1.1](https://www.topografix.com/GPX/1/1/). Versioned `fpvmanager` GeoJSON
properties / `https://codefrog.ch/fpvmanager/routes/1` GPX extensions retain AGL,
named vertical references and airspeed; unspecified GPX elevation stays unverified.
Imports are size/depth/count bounded and commit all new copies in one transaction.

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
topology, currency or legal applicability. `OsintDatasetStore<T>` adds optional
persistence in `fpvmanager_osint_cache`; adapters supply storage terms explicitly.
UAS uses a one-hour local lifetime and 30-day disk retention. ETag/Last-Modified
revalidation preserves retrieval time and records a separate source-check time;
HTTP dates never become publication/validity dates. Invalid envelopes are removed,
failed updates retain prior data, and disk-write failures leave downloaded data
usable in memory. Map layers can clear the UAS cache. Public-data cache migration
preserves obstacle generations and does not touch personal records or map tiles.
The UAS endpoint currently rejects CORS preflights for conditional headers. Its
Web adapter therefore uses ordinary GET refreshes; native clients use validators.

`SwissObstacleProvider` discovers the full KMZ through STAC and stages normalized
records in the separate `fpvmanager_osint_cache` SQLite database. A transaction
publishes a complete generation and removes superseded rows. Failed imports keep
the active generation; orphaned staging rows are cleared on reopen. Import uses
bounded ZIP inflation and XML events, rejects unsafe paths/DTDs and never follows
external KML resources. Viewport/category queries send at most 1,200 objects,
4,000 parts and 40,000 vertices; the renderer builds batches of 80 objects with
revision-based cancellation. Nearby batches are retained across small camera moves;
unchanged entities/models survive reconciliation. Terrain anchors retain known
heights across tile eviction and invalidate when the terrain provider changes.
WMS imagery has its own non-fatal status/retry and
does not share UAS or vector visibility. For offline KMZ validation use
`dart run tool/check_obstacle_kmz.dart <full.kmz>`.
Optional obstacle GLBs are Y-up, unit-height meshes scaled by trusted source AGL
and anchored to the shared terrain sample. Regenerate with
`python tool/generate_obstacle_models.py`; use `--check` to verify bundled files.

## Portable backups and offline maps

Backup format v1 starts with `FPVBK001`, followed by flag (1 byte), salt (16) and
nonce (12). Password exports use AES-256-GCM with the header as AAD, a 16-byte
authentication tag and PBKDF2-HMAC-SHA256 (600,000 iterations). Unprotected exports
use a SHA-256 payload checksum for accidental damage, without authenticity.
JSON includes format/database versions and raw typed rows with base64 BLOBs.
Restore validates known tables/columns, image dimensions and references; it uses
one transaction and supports earlier database layouts through defaults/derived
field migration. Limits are 64 MiB and 100,000 rows. Only explicitly permitted
settings enter backups; credentials and provider caches are excluded.

Public-cache schema v3 adds offline region/tile tables on Android. The loopback
asset server exposes only fixed official topographic/relief and terrain tile
paths. Web uses Cache Storage with a scoped app service worker. Both retain
viewed tiles inside configured regions, deduplicate requests, bound responses
to 4 MiB and tile payloads to 256 MiB, and honor `no-store`/`private`. Terrain
metadata retains its dated template; cached-only availability is rebuilt from
stored tiles. After a Web build, `python tool/prepare_offline_web.py` creates an
integrity manifest. The worker verifies a complete staged application snapshot
before activation; failed installs retain the previous snapshot. Updates wait
until existing app tabs close. Development without this manifest supports map
caching but does not promise an offline application shell.

`PolygonIntersectionIndex` checks horizontal Polygon/MultiPolygon geometry,
including holes, boundary contact and all overlapping features, with bounding-box
filtering. `UasAirspaceChecker` uses the shared provider independently of renderer
visibility and reports the snapshot checked. Route segments are straight in WGS84
coordinates; antimeridian-crossing geometry must be split. Unsupported geometry
and source gaps remain explicit. Native checks run in an isolate; Web uses the
browser thread. Height/time applicability is outside the intersection check.

`web/terrain_service.js` bounds initialization/probe to 8 seconds and tile/sample
requests to 12 seconds. Map downloads use eight active slots and a bounded queue;
cache hits bypass downloads. Individual tile/sample failures retain loaded terrain
and report missing information. Failed initialization or offline mode without a
cache uses a labelled ellipsoid fallback. Explicit retry replaces the provider and refreshes
the selected imagery style; there is no automatic reconnect loop. Terrain
generations invalidate pending samples, raw picked heights and route geometry.
Late results cannot restore obsolete terrain. Ground mode ends on terrain loss.

See [coordinates and heights](coordinates_and_heights.md) for calculation
contracts, [privacy](privacy_and_permissions.md) for requests and permissions,
and [map sources](map_sources_and_attribution.md) for attribution.
