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
| `lib/features/settings/`, `lib/features/help/` | Grouped settings, shared map-menu entry and bundled help |
| `lib/features/` | Globe, airspace, spots and equipment UI/controllers |
| `lib/core/database/` | Drift tables, repositories and migrations |
| `lib/core/models/`, `lib/core/geo/` | Typed routes, preferences, coordinates and heights |
| `lib/core/osint/` | External dataset contracts, provenance and cache lifecycle |
| `web/` | Renderer, bridge, providers, terrain, shared navigation input, flight/ground controllers and route editing |
| `test/`, `integration_test/` | Unit/widget/tooling tests and native renderer integration |

Web embeds `globe.html` in a same-origin iframe. Native adapters use an app-owned
loopback asset server for Workers/Wasm: `webview_flutter` on Android/iOS and
WebView2 on Windows. `GlobeController`
validates events and publishes coherent state; commands require acknowledgement.
See [bridge protocol](globe_bridge.md) and [renderer assets](cesium_assets.md).

Raw points, saved spots and UAS zones are mutually exclusive selections. Closing
a panel does not restore an earlier selection. Raw-point terrain actions and
Add Spot defaults read only the current raw point.

## Database and repositories

`FpvDatabase.open()` opens persistent Drift/SQLite storage on native platforms or Web.
The home screen opens it lazily and closes only resources it created. Injected
repositories/databases remain caller-owned. Tests use isolated databases.
Web uses bundled `sqlite3.wasm` and `drift_worker.js`.

Schema version is **10**. Tables cover spots/photos/tags, drones/parameter sources,
battery packs/types and assignments, radio equipment/drone assignments, flight
plans/waypoints, separate ground routes, preflight checklists/templates, raw telemetry and settings.
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
The shared **Karte & Ansicht** menu owns display/layer controls; the general
settings route links to that same hub. Long technical/source details are disclosed
on demand while current failures, validity and restricted-use status stay visible.
Retired axis-overlay and surface-exploration flags are ignored on restore;
automatic 3D tunnels still load the underlying axes internally.

Route transfer follows [RFC 7946](https://www.rfc-editor.org/rfc/rfc7946.html)
and [GPX 1.1](https://www.topografix.com/GPX/1/1/). Versioned `fpvmanager` GeoJSON
properties / `https://codefrog.ch/fpvmanager/routes/1` GPX extensions retain AGL,
named vertical references and airspeed; unspecified GPX elevation stays unverified.
Imports are size/depth/count bounded and commit all new copies in one transaction.

## Synthetic tunnels and bridge supports

The bundled OSM tunnel catalogue supplies source axes, not surveyed interiors.
`FPVTunnelInfrastructure` discovers bounded viewport candidates;
`FPVTunnelFlythrough` resolves road/bridge approach samples and constructs opaque
sections. Connected source ways and underground junctions share floor anchors,
render openings and collision geometry. Long ways use bounded overlapping windows
while retaining their original outer endpoint evidence. The current occupied
corridor remains resident until its replacement contains the flight position.

Portal cutouts use direction/grade-aware masks with a face-inclination check:
steep rock inside the opening can be discarded while horizontal road/floor
surfaces survive. Curve masks update existing material uniforms. Synthetic wall,
ceiling and floor collision is exact for the generated mesh; approximate loaded
model-height checks are separately opt-in and cannot certify real clearance.

Bridge supports use mapped support points or schematic spacing below a verified
deck profile. Native swissTLM3D discovery classifies the selected feature and
samples its geometry; road-axis names do not establish deck height. Ground
samples determine support foundations. A confirmed native profile is reused,
and GPU depth probes/geometry creation are distributed across render opportunities.
These models remain simulation estimates. See the [offline catalogue build](offline_swiss_tunnel_index.md),
[renderer fixtures](cesium_assets.md) and [performance guide](performance.md).

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

`SwissOfflineSources` discovers bounded regional download inputs through STAC v1:
the newest supported map sheet (combined Swiss Map Raster 1:25,000) and 2 m
swissALTI3D tiles, with SHA-256, edition/update/retrieval times and explicit
LV95/LN02 references. Source rasters require preparation before globe import;
discovery is not an offline coverage/completeness result. The laptop tool converts
checked source rasters and the bundled LN02 height grid into complete PNG and
quantized-mesh pyramids. Stored-ZIP v1 packages (64 MiB) carry per-file integrity,
provenance and explicit bounds. Import validates paths, sizes, PNG dimensions,
mesh arrays and exact coverage; native publication is transactional and Web stages
a new namespace before publishing the region pointer. Direct preparation uses
the bundled GeoTIFF.js worker on Android and Web: bounded HTTP ranges, LRU raster
blocks, published Swiss Map Raster/SWISSIMAGE/swissALTI3D sources, and CHGeo2004
height conversion. New regions support multiple image styles, circular selection
up to 25 km and, on Web, a national area. Completed tiles are staged with a
resumable job; the active pointer changes last. Per-download limits and browser
quota checks replace the small viewed-cache budget for generated data. NoData
vertices are omitted rather than filled with assumed terrain. Source indexes
preserve edition/checksum metadata; partial reads do not verify full-file hashes.
Prepared resources never
fall back to the network. It does not prefetch WMTS or terrain-rendering services.

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
and report missing information. Startup validates all global root tiles (only the
packaged root for a prepared region) and retains those few tiles for the viewer,
so a repeated root download cannot leave an empty globe after a successful probe.
Failed initialization or offline mode without a cache uses a labelled ellipsoid
fallback. Transient startup failures get at most two background retries, after
750 ms and 2 seconds; manual retry, offline mode and disposal cancel that budget.
Later network restoration still requires explicit retry. Explicit retry replaces
the provider and refreshes the selected imagery style. Terrain
generations invalidate pending samples, raw picked heights and route geometry.
Late results cannot restore obsolete terrain. Ground mode ends on terrain loss.

Windows page transitions animate the live page without snapshotting external
WebView2 textures. This avoids an engine crash when leaving a selected map point
for a full-screen tool such as the saved-place list.

During flight, pending terrain refinement briefly uses a looser screen-space
error budget after rapid turns or low-altitude frame stalls. It returns to the
normal flight budget in small steps after the view settles. Resolution, physics
and collision sweeps keep their existing settings. Opt-in scene diagnostics count
long in-flight stalls separately from idle/background gaps.

See [coordinates and heights](coordinates_and_heights.md) for calculation
contracts, [privacy](privacy_and_permissions.md) for requests and permissions,
and [map sources](map_sources_and_attribution.md) for attribution.
