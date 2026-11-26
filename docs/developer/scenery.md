# Real-world scenery: providers, placement and collisions

**Status:** experimental local reference scene, current geometry revision **R35**.
This is the current technical reference; chronological changes belong in the
[changelog](../../CHANGELOG.md). Operation and safety limits are described in
[Real-world scenery](../user/scenery.md).

## System boundaries and data flow

| Responsibility | Implementation |
|---|---|
| Persistent definitions, manifest v1 and asset providers | `lib/features/scenery/`, Drift table `sceneries` (schema 13) |
| Flutter/Cesium communication and map menu | `lib/features/globe/`, `web/globe.js`, `web/core/globe_bridge.js` |
| Scene catalog, activation, height state, collisions and credits | `web/features/scenery/scenery_manager.js`, `web/assets/scenery/catalog.json` |
| Reference and transformation | `web/features/scenery/scenery_alignment.js`, `web/assets/scenery/reference_alignment.json` |
| GLB rendering | `web/assets/scenery/local_reference.glb` |
| External 3D Tiles transport and validation | `web/features/scenery/scenery_tileset_provider.js`, `web/features/scene/scene_tile_loading.js` |
| FPC collisions | `web/assets/scenery/local_reference.fpc`, `web/features/scenery/scenery_collision.js` |
| Experimental BKG buildings and regional 3D selection | `web/features/terrain/regional_3d.js`, `web/features/scenery/scenery_bridge_calibration.js` |
| Workbench view and local data relay | `tool/scenery/cesium_georeference_workbench.html`, `tool/scenery/serve_workbench.py` |
| Reproducible reconstructions, measurement reports and regressions | `tool/scenery/`, `test/js/scenery_*.test.cjs`, `tool/scenery/test_ruedersdorf_*.py` |

The **bundled reference GLB and FPC are built together**: physical collisions must match the
rendered triangles exactly. `catalog.json` and every terrain certificate must
contain the SHA-256 of the current FPC. When scan/replacement geometry changes,
certificates must not continue pointing to a different FPC unchanged. An updated
geometry model does not replace physical calibration.

### Provenance and non-commercial conditions

The source is **Andrea Spognetta (spogna)**'s original RAWscan, *Abandoned Chemical
plant Rüdersdorf – RAWscan*, [original model](https://sketchfab.com/3d-models/abandoned-chemical-plant-rudersdorf-rawscan-d2464ec36fb644f28e904e5517f1da64),
**CC BY-NC 4.0**. Restored raw-scan surfaces retain their original positions,
normals and UV coordinates; additional buildings and collision surfaces are
**photo-informed simulation**, not surveyed geometry. Original RAWscan sources
and high-resolution textures must not be redistributed without checking their
terms or relabeled as Apache-2.0. Mobile assets may use a smaller texture atlas.
DGM1, GCG2016 and BKG provenance is documented in the
[third-party notices](../../THIRD_PARTY_NOTICES.md) and asset credits at
`web/assets/scenery/ATTRIBUTION.md`.

## Persistent scenery architecture

The renderer supplies its already loaded bundled catalog once through
`scenery-catalog` as the initial definitions. `SceneryRepository` imports these
into the Drift table `sceneries` once; a stored initialization marker prevents
intentionally removed templates from reappearing after restart or backup restore.
Existing activation and alignment settings are imported transactionally. Invalid
existing data is reported as an error and retained. Database schema 13 adds only
this table; existing tables are not restructured for it.

`SceneryManifest` defines JSON format **schemaVersion 1**:

| Field | Contract |
|---|---|
| `id`, `name`, `description` | Stable identifier and description |
| `source` | `author`, optional HTTPS `url` (null for local files), `license`, `attribution` |
| `anchor` | `longitude`, `latitude`, `heightM`, `reference`: `WGS84_ELLIPSOID` or `TERRAIN_RELATIVE` |
| `bounds` | Geographic region `west`, `south`, `east`, `north`; west > east indicates an antimeridian crossing |
| `rotation`, `scale` | `headingDeg`, `pitchDeg`, `rollDeg`, uniform scale in the local ENU frame |
| `assets` | Identifier, `visual`/`collision` role, `provider`, `format`, `uri` for each asset |
| `collision` | `enabled`, references through `assetIds`, `sidedness` |
| `visibility` | `enabled`, `loadRadiusM`, `unloadRadiusM` with hysteresis |
| `minimumAppVersion` | Minimum semantic version `major.minor.patch` |
| `extensions` | Provider options; the Cesium compatibility adapter retains existing height/terrain certificates |

Definitions are immutable snapshots. Limits are 64 scenes, 128 KiB per
definition, 1 MiB per catalog, and at most 16 visual and 16 collision assets.
Template bounds are conservative coverage regions. Managed model imports store
local mesh bounds and recalculate transformed ECEF bounds and a conservative
geographic footprint when placement changes; these are mathematical bounds, not
surveyed accuracy. Terrain-relative absolute bounds require a real ground height.

`SceneryAssetProvider` resolves logical references. The current `bundled`
provider supports self-contained GLB and FPC within the scenery asset root. The
`managed` provider resolves verified, content-addressed local GLBs.
The `remote-tiles` provider resolves checked HTTPS 3D Tiles endpoints.
Other providers/formats can be defined and stored; a scene remains
**unavailable** without a matching loader or when its minimum app version is too
high. Newly tilted, previously terrain-calibrated scenes remain unavailable until
recalibrated appropriately.
Unsupported formats are never presented as GLB or valid collision geometry.

The bridge message `replace-scenery-catalog` transfers a complete resolved catalog.
Unchanged entries retain their models and collision data; removed/changed entries
invalidate in-flight loads. Invalid optional scenes receive their own error state.
All collision assets of a scene must be loaded before physical collisions become
active. Visual and collision geometry share the same ENU rotation, including
pitch and roll. Changed placement invalidates old building/terrain replacement
masks. The base map and optional scenes are restored independently. Obsolete
restore generations do not transmit a catalog. Changes during navigation are
rejected. The current database state is replayed after renderer reconnection.

Scene definitions and initialization state are included in the existing backup
format; model bytes and provider caches are not included in personal-data backups.
Older backups remain readable. Licensed managed assets can be exchanged using
[portable `.fpvscenery` packages](scenery_package.md) (#152); keep these separately
for cross-device restore. The reference-scene and BKG limitations below still apply.

## Local model import (#146)

`scenery_import_files.dart` uses the existing platform file selector. Safe relative
resources beside a native model are resolved within its directory, including a
canonical-path check. Where directory access is unavailable, the user selects
each requested resource explicitly. Absolute/network paths, traversal, encoded
separators, query strings and fragments are rejected; no resource is downloaded.

`SceneryModelImporter` accepts static **glTF 2.0 JSON and GLB 2.0**, validates
buffer ranges, strides, indices, node hierarchy/transforms and PNG/JPEG headers,
and combines all buffers and images into one self-contained GLB. POSITION bounds
are recomputed from the actual vertices. Core PBR materials, alpha blending/masks,
embedded textures, `KHR_materials_unlit` and `KHR_texture_transform` are retained.
Sparse accessors, animations, skins, morph targets and other extensions fail
explicitly. External glTF resources and bounded base64 data URIs are supported.

The importer follows the [Khronos glTF 2.0 specification](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html).
Compression evaluation: [Draco](https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_draco_mesh_compression)
compresses mesh data, [Meshopt](https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Vendor/EXT_meshopt_compression)
compresses buffer views, and [KTX2/Basis](https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_texture_basisu)
requires texture transcoding. The pinned Cesium distribution contains Draco and
Basis Wasm decoders, but the import validator has no corresponding bounded CPU
decoders for checking geometry bounds and decoded allocation. These compression
extensions are therefore rejected, including optional declarations. Export an
uncompressed static glTF/GLB with PNG/JPEG textures for this import path. Renderer
decoder availability alone is not import validation.

Limits: **64 MiB** combined input/output, **4 MiB** JSON, **128** external resources,
**1,024** nodes, **2 million** scanned positions/drawn triangles, **4,096 × 4,096**
per texture, **128 MiB** estimated decoded resources across active managed models,
and **512 MiB** managed storage. Geometry and texture limits are enforced before
commit. These limits bound resource use; they are not measured device performance
budgets. Native validation/checksums run off the UI isolate; Web uses asynchronous
Web Crypto and periodically yields during position scans. Import is disabled
during navigation. Local model loading remains sequential.

Native models are atomically written under application support `scenery/v1/`,
named by SHA-256, and served through a fixed same-origin loopback route with at
most two coalesced reads. Web models use app-scoped CacheStorage on HTTPS or
localhost; the renderer verifies the checksum and uses a revocable Blob URL,
without HTTP fallback. Cancellation before confirmation commits nothing; database
failure rolls back new unreferenced bytes, while bridge failure retains committed
definitions and files. Removing the last scene reference removes its file.
Browser storage can be evicted or cleared; missing/corrupt files report a
reimport error. Definitions in backups do **not** transfer model bytes to another
device; use the separate [scenery package format](scenery_package.md) (#152).

Placement uses a WGS84 ellipsoid height or a height relative to the displayed
terrain, then local ENU heading/pitch/roll and uniform scale. Generic relative
placement samples the model anchor; it does not reuse reference-site ground
controls. Missing terrain hides the model until alignment succeeds; a stalled
height request reaches an explicit recoverable error. Newly imported visuals do
not automatically create collision geometry, replacement regions (#150) or RF
obstacles (#153). The collision workflow below attaches physical meshes explicitly. Existing collision-backed reference scenes retain their own behavior.

Regression coverage includes synthetic imports, unsafe/missing resources,
allocation limits, database/file restart, rollback and shutdown, UI cancellation,
loopback serving, cache-only reads and Blob disposal. ECEF bounds are compared
against the pinned Cesium matrices. The real Chromium regression uploads and
renders a georeferenced PNG-textured transparent GLB, reloads the page, and checks
that the model comes from cache without another model HTTP request. Device smoke
tests and hardware performance measurements remain separate release checks.

## External 3D Tiles providers (#147)

`SceneryTilesetDialog` checks a public HTTPS endpoint through
`probe-scenery-tileset` before saving. The probe creates a temporary Cesium tileset
to validate the header, version and geographic bounds, then destroys it without
adding geometry to the scene. The existing database, backup and catalog-replay
paths persist its definition; there is no provider-specific database table.
`SceneryAsset.tileset` stores version, maximum screen-space error, caching policy,
ECEF bounding sphere and optional placement correction. Definitions use an
absolute WGS84 ellipsoid pivot. See the
[OGC 3D Tiles 1.1 specification](https://docs.ogc.org/cs/22-025r4/22-025r4.pdf) and
the pinned [Cesium3DTileset API](https://cesium.com/learn/cesiumjs/ref-doc/Cesium3DTileset.html).

Default placement is the **identity matrix**: the provider's root transform,
georeferencing, nested transforms and region bounds are retained. An optional
correction composes `ENU(pivot) × localCorrection × inverse(ENU(pivot))` with the
original tileset model matrix. It does not reinterpret tile heights as local GLB
coordinates. The initial pivot is the coverage-sphere center, whose ellipsoid
height can be below ground for a wide dataset; changing that pivot alone does
not move a tileset with identity correction. Corrections recalculate conservative
stored bounds. Runtime activation uses the loaded tileset's current sphere when
available, otherwise its checked sphere, and the nearest camera/aircraft distance
to that coverage. Load/unload radii provide hysteresis.

OGC 1.0 and 1.1 content supported by **Cesium 1.145.0** is delegated to Cesium,
including supported extensions, implicit subtrees and multiple contents. A
cooperative validator checks header structure, volumes, transforms and HTTPS
resource references. The shared explicit-tree partitioner yields during large
header preparation. The scoped transport retains Cesium's request scheduler,
removes its private ownership marker before network requests, and does not copy
inherited URL query parameters to another origin. Requests omit browser
credentials and referrers. Signed URLs are supported; provider-specific sign-in
is not. Inline binary/image resources remain local; arbitrary inline documents
and unsafe schemes are rejected.

The default **no-store** policy avoids persistent HTTP caching. The alternative
uses normal provider HTTP cache headers. Neither downloads an offline package;
offline map modes stop external scenery requests. Attribution/license metadata
remains in management, the map sources panel and active Cesium credits. Providers
must permit client access and the chosen use; no CORS proxy is introduced.

One external header load can progress alongside local-only scenery loading.
There are at most **four active remote tilesets**, with a shared **128 MiB Cesium
tile-cache target** and no configured overflow. These bound concurrency/cache
targets, not total GPU allocation or a measured device budget. Individual
responses are limited to **64 MiB**, hierarchies to **300,000 tiles / 128 levels**,
and each request has a **15-second abortable timeout** with at most two retries
for transient failures. The existing **60-second** scene-load deadline releases
a stuck slot. Removal, replacement, offline mode and disposal abort owned
requests; generation checks reject late results.

Root failures are explicit, recoverable scene errors. A later tile failure keeps
already loaded geometry, reports degraded streaming, and clears the current error
after successful tile delivery. Repeated error bridge notifications are throttled
to once per second per scene. HTTP errors retain their status; browsers cannot
reliably distinguish CORS, TLS and network failures, so these share an actionable
`NETWORK_OR_CORS` category. URLs/query secrets are omitted from generic errors.
External loads are asynchronous and do not run inside physics ticks.

### Brandenburg evaluation and regression evidence

On **2026-11-25**, the official
[LGB 3D mesh endpoint](https://isk.geobasis-bb.de/geodienste/lgb/3d_sentinel/3dmeshes/tileset.json)
returned an OGC **1.1** header, HTTP 200, permissive CORS and `Cache-Control:
no-cache`, with 22 regional children. Its
[LGB-published metadata](https://www.distributions.informationgrid.eu/trefferanzeige?docuuid=f5a6d881-f36a-473c-a33a-4c1d1f982cf5)
identifies **DL-DE-BY 2.0** and `© GeoBasis-DE/LGB, dl-de/by-2-0`.
The optional UI preset includes this source and attribution. Regional coverage
is not a guarantee of full-state or Rüdersdorf coverage. The
[LGB service announcement](https://geobasis-bb.de/lgb/de/presse/pressemitteilungen/~17-06-2026-brandenburg-in-3d-entdecken)
describes an aerial photogrammetric surface, not surveyed flyable interiors.

An explicit headless Chromium/Cesium check at **13.05° E / 52.4° N** loaded **20
real tiles**, verified visible geometry and identity placement while timer ticks
continued. Reproduce separately from deterministic CI:

```sh
node tool/browser/check_scenery_tileset.cjs
```

Automated synthetic tests cover real 1.0 b3dm and 1.1 GLB rendering, texture and
credits, CORS/HTTP failures, timeout/cancellation, partial-tile recovery,
activation/aircraft priority, bounds/transforms, resource release, persistence,
backup, UI cancellation and bridge replay. The live check is integration evidence,
not a hardware performance benchmark. Android/iOS and native UI smoke tests remain
release checks. Remote tiles are visual by default; attach independent local
collision meshes through the workflow below. Replacement is configured separately below; packages (#152) and scenery RF
obstruction (#153) remain separate.

## Interactive alignment editor (#148)

`SceneryManagementPage` opens the renderer editor by identifier or in globe-pick
mode, then closes management so the globe remains interactive. The modules
`scenery_editor.js` and `scenery_editor_math.js` are loaded only as code; their
DOM panel, input listeners and Cesium entities exist only during a session.
Numerical edits and ENU handles use the same normalized draft and matrix path.
Camera snapshots, input flags, preview entities and loaded-model ownership are
restored/released on cancellation or teardown. Draft edits retain GPU models;
late model completions inherit the current transform.

The manager's transient `beginAlignment` / `previewAlignment` / `endAlignment`
API pins the selected entry without changing activation preferences or storage.
It temporarily suspends replacement masks and height fitting. Local GLB and FPC
assets use the same effective ENU transformation. In mixed scenes the first
remote asset defines a world correction composed with the shared local frame;
other tilesets retain their relative corrections. Source tileset root matrices
remain intact. Existing opacity-based collision/replacement policy is preserved.

`SceneryAlignmentSession` handles short start/result commands and token-guarded
submit/cancel events; no bridge request waits for a human editing session.
`saveAlignment` serially compares the original definition with the current DB
record, checks session freshness, validates placement-only fields and persists
before catalog synchronization. An alignment token distinguishes its own catalog
commit from an external replacement. Renderer loss invalidates the session. A
database failure retains a retryable draft; synchronization failure explicitly
reports that the definition has already been saved. A missing save acknowledgement
unlocks the UI after a bounded wait and explicitly reports that the write may
already have completed; closing the editor does not undo an applied DB commit.
Residuals are remeasured when the draft changes. Source metadata, asset
references and collision policy cannot be replaced by an editor submission.
Placement changes invalidate old terrain/replacement calibration; opacity-only
changes retain it. Manifest schema and database version remain unchanged.

Control points use post-glTF-axis-conversion local metres and WGS84 ellipsoid
targets. A Horn quaternion similarity fit solves a proper 3D rotation, positive
uniform scale and translation in a local tangent frame; output rotation is
converted to the new anchor's ENU frame. At least three noncollinear points are
required. Limits are 64 pairs, 10 km target distance, 64 KiB UI input and 80 undo
entries. Individual residuals, RMS and maximum are shown; this is visual alignment,
not geodetic adjustment. Regional 3D Tiles use correction controls rather than
local-mesh point fitting. Terrain snap uses the current terrain sampling path with
a recoverable deadline and revision/provider guards. Relative scenes need a
resolved anchor before editing; stale/missing samples never become zero height.

Regressions cover math, non-exact/degenerate control sets, antimeridian/polar
coordinates, mixed visual/collision transforms, cancellation and late loads,
persistence/restart, real bridge replay and conflicts. Headless Chromium exercises
the actual Cesium editor with numerical fields, mouse/touch PointerEvents,
rotation, views, snapping, fitting and geometry picking. These synthetic gestures
do not replace Android/iOS device interaction tests or hardware benchmarks.

## Selective base-world replacement (#150)

The optional manifest-v1 `replacement` member has `schemaVersion: 1`, independent
`buildings`/`terrain` objects and explicit geographic polygons. Building settings
contain `enabled`, `regions` (arrays of `[longitude, latitude]`) and `features`
(`provider`, `property`, string `id`). Terrain settings contain `enabled` and
`regions` with `polygon`, `minimumUpM`, `maximumUpM`, `seamToleranceM`.
`scenery_replacement.dart` and `scenery_replacement.js` validate equivalent limits:
24 regions per kind, 3–64 vertices, 1 km anchor distance, simple polygons of
1–250,000 m², at most 128 stable building selectors and finite local ground bands.
Regions near the antimeridian use local unwrapped longitude. The existing manifest
size limit remains authoritative. No DB migration or new asset format is needed.

The dedicated Flutter dialog saves through the serial catalog controller with a
stored-definition conflict check and navigation guard. Source/assets are preserved.
DB restart and normal definition backups retain settings; copies drop them and
placement edits disable them. The globe alignment editor displays optional saved
building/terrain outlines without activating draft cuts.

The replacement coordinator owns only its own Cesium polygon collections on the
Globe and the normal/BKG base-building tilesets. Existing tunnel/portal code was
evaluated: its aperture shader is appropriate for directional portal openings;
whole geographic regions reuse public `ClippingPolygonCollection` with the same
foreign-ownership guards. Foreign polygon collections, globe materials and clipping
planes are not replaced. The BKG wrapper delegates ownership to this coordinator;
its legacy terrain certificates remain restricted to BKG mode.

Actual Cesium 1.145 browser testing found loaded tile models retaining a collection
after tileset detachment. Release/update therefore disables and empties the owned
collection first. No vendor patch or provider reload is needed. Feature-ID rules
use `tileVisible`, recurse through composite contents and restore original `show`
values when removed. `tileUnload` releases retained feature references. Selectors
are indexed by property/ID; feature hiding does not affect other layers. See the
[Cesium clipping contract](https://cesium.com/downloads/cesiumjs/releases/1.145/Build/Documentation/ClippingPolygonCollection.html)
and [feature lifecycle](https://cesium.com/learn/cesiumjs/ref-doc/Cesium3DTileFeature.html).

Generic terrain cuts require ready visuals at full opacity, resolved stable height,
loaded physical geometry and level placement. The declared local height band
selects physical ground through BVH sweeps. Provider-scoped perimeter checks sample
edges at up to 3 m spacing, at most 2,048 points total, in 128-point terrain batches;
physical evaluation yields every 32 points. Missing data, >0.05–0.5 m configured
seam mismatch and bounded timeout retain terrain. Old/provider-obsolete responses
cannot approve new regions. Explicit retry is available. This checks sampled seams,
not every interior point or a watertight mesh; intentional interior openings remain.

Physics trusts only an enabled, non-inverse, still-owned clipping collection from
the current terrain provider. Polygon-edge interval partitioning retains all
outside terrain segments, including concavities/disconnected regions. Rendered
height uses the highest actual physical ground across approved overlapping regions;
missing interior physical ground stays unknown rather than falling back to the
invisible base surface. Building mask/ID revisions invalidate approximate roof
collision caches. Existing physical scenery contacts, roads, bridges and tunnel
collisions remain independent; no RF/failsafe state is synthesized.

Regression coverage includes configuration, persistence, cancellation/conflicts,
placement invalidation, overlaps, provider changes, missing ground/seams, timeout
recovery, both flight modes and actual rendered globe/building cuts, stable feature
IDs, CPU terrain exemptions, restoration and editor outlines. Device-specific
clipping support and real-world seam quality still require release smoke tests.

## Custom collision meshes (#149)

`scenery_collision_import.dart` validates FPC1 or builds a deterministic median-split
triangle BVH from the default scene validated by `SceneryModelImporter`. GLB node
transforms, strips/fans and the existing glTF-to-ENU axis conversion are reused;
mirrored nodes retain authored front winding. Generation removes only zero-area
triangles, without simplification, capping or hole filling. Texture alpha does not
remove physical triangles. Prepared bytes/metadata are immutable snapshots.

FPC1 is little-endian: four uint32 header fields (`FPC1`, vertex count, triangle
count, node count), float32 XYZ vertices, uint32 triangle indices, six float32 bounds
per node and two int32 links per node. Nodes are depth-first; leaves encode
`[-firstTriangle-1, count]`, with at most 16 triangles. Validators enforce finite
local coordinates within 100 km, byte/index bounds, contiguous triangle coverage,
parent containment and depth at most 48. Independent FPC imports reject degenerate
faces. Geometry remains in model-local metres, separate from world placement.

Managed `.fpc` keys reuse content-addressed storage, checksum verification,
loopback/cache-only transport and shared-file cleanup. Collision settings preserve
source/visual assets, compare the stored definition before commit, roll back new
unreferenced files on DB failure and retain committed data on bridge failure.
Legacy bundled collider bounds are validated before adding them to a managed
collision configuration. Schema 13/manifest v1 remain unchanged. Backups contain
definitions, not the physical files.

Custom `collisionIndependent` entries start physical loading separately from visuals.
One physical load progresses at a time alongside visual loading; queued entries,
deadlines, cancellation and separate physical/visual generations prevent stuck
slots or late attachment. Supported browsers validate in an owned worker and
transfer the buffer back; the main thread makes typed views without another BVH
walk. Malformed worker replies and transfer errors reject and release ownership.
Targets are 64 MiB per file, 128 MiB active custom collision data and 512 MiB shared
local storage, not a total CPU/GPU-memory or device performance guarantee.

`collisionAvailability` is separate from triangle contact. A proposed sweep into
requested but unready geometry pauses translation with an explicit simulator reason;
it does not fabricate a surface, change the RC observation or trigger failsafe.
Known local bounds use a swept AABB check; unresolved height/provider cases use
conservative geographic coverage, including antimeridian crossings. Required
unavailable definitions retain this protection. Retry or disable after stopping
navigation. Loaded custom meshes remain active across texture errors, visual LOD
and opacity changes; legacy reference calibration/replacement policy is preserved.

Actual contact reuses the existing swept-sphere triangle narrow phase and BVH,
with double/front/back winding selection and shared ENU transforms. Advanced
physics retains its fixed-step collision response. Legacy keeps its existing
integration/response; new custom-mesh contacts use time of impact and the existing
1 cm backoff, checking terrain along the shortened movement. Terrain, bridge and
tunnel collision paths remain in use. Physical wireframes are optional owned
primitives, separate from the CPU geometry and disabled by default.

Regression fixtures are synthetic CC0: a room with door/window gaps, floors,
ceiling, columns, beams and an open cylindrical pipe, plus a 9,800-triangle grid.
Dart-generated FPC fixtures are consumed by the JS parser/sweeps. Tests cover
transforms/winding, storage/backup/rollback, worker cancellation, corrupt cache,
missing-data recovery, both physics modes and 30/60/120 render FPS. Chromium
renders the actual physical wireframe and reloads FPC from cache without HTTP
fallback. Physical-device and hardware performance checks remain release work.

```sh
node tool/benchmarks/scenery_collision.cjs
```

This optional CPU microbenchmark compares the existing BVH against an
unaccelerated traversal of identical triangles, reporting latency and candidate
counts. It is not an application before/after or mobile/GPU benchmark. Update
synthetic binary fixtures explicitly with `flutter test --update-goldens
test/features/scenery/scenery_collision_import_test.dart`.

## Geometry and orientation

- Model scale is `16.023268178233355`; rotation about the local vertical is
  `99.7993823133657°`; the geographic anchor is
  **13.789853720999993° E / 52.48411904363446° N**.
- In the site's local coordinate frame, **−X points north** and **+Y points east**.
  Cesium/GLB transformation matrices and the FPC transformation axis must not
  be changed independently.
- The northern original-scan building group and the southern reconstructed
  production buildings **are different locations**. Reconstruction changes must
  use explicitly checked local bounding boxes; a desired compass direction alone
  does not sufficiently define a mask.
- **R29** restored missing raw-scan triangles from the original archive. **R34**
  restored accidentally removed southern reconstruction surfaces. **R35** removed
  only the artificial R24 gantry that partly extended into the northern scan.
  Individual steps are recorded in machine-readable `refinement_*_report.json`
  files and the changelog; old incremental release READMEs are not the current
  specification.
- The long hall's external ladder platform is **outside** the hall, not inside
  an artificially opened roof. Actual roof openings, such as those in the central
  silos, must not be confused with other silo buildings during modeling.

## Height references: avoid double correction

Distinguish **(a)** the flat workbench preview, **(b)** the locally sampled scan
ground height, **(c)** a source's vertical reference frame, and **(d)** the terrain
provider actually being rendered.

| Reference | Value / meaning |
|---|---|
| Workbench export (flat ellipsoid) | **34.25 m** anchor height; visual preview, not a transferable terrain anchor height |
| DGM1 at the geographic anchor | **40.949489589 m NHN** (DHHN2016), interpolated from the official raster |
| GCG2016 anomaly | **+38.871142785 m**; normal/ellipsoidal height conversion |
| Resulting ellipsoidal ground height | **79.820632374 m** |
| Local ground reference | `groundReferenceLocalUp = -2.02575` |
| Model anchor for this DGM1 check | **112.279767886 m**, before further comparison with the terrain actually rendered |
| User-confirmed BKG-specific visual offset | **−16.90 m**; experimental BKG variant only, not a geoid constant |

For a **known** ellipsoidal ground height:

`rootEllipsoidHeightM = groundEllipsoidHeightM - groundReferenceLocalUp * scale`

The current catalog uses `heightAlignmentMode: "terrain"`,
`requireGroundCalibration: true` and a separate `bkgHeightOffsetM`. Automatic
calibration reads rendered terrain heights at several control positions and
robustly combines them into a model anchor height. Missing tiles are **not** zero,
and the dynamic BKG correction must not additionally be treated as a general
geoid offset. Saved user settings may override catalog defaults. When diagnosing
problems, record runtime state (`heightState`, `groundHeightM`,
`effectiveAlignment`, `bkgHeightOffsetM`) before changing constants.

### User-assisted ground alignment

`web/features/scenery/scenery_bridge_calibration.js` picks the scan surface, hides
the scan, then picks the **same open ground**. It checks horizontal separation and
calculates the signed height difference. Only explicit confirmation stores the
result as a **BKG-only** setting. Do not compare LoD2 roofs/vegetation with scan
ground points. The visually confirmed offset is a reproducible operating setting,
not a survey measurement.

## BKG LoD2 workbench

The workbench requires an HTTP server rather than `file://`. Its local relay route
is provided only by `serve_workbench.py`; `python -m http.server` does **not**
provide it.

```powershell
python tool/scenery/serve_workbench.py --port 8765
```

Then [open the workbench](http://localhost:8765/tool/scenery/cesium_georeference_workbench.html?lod2=relay).
A relay `404` may indicate the wrong server or an upstream 404; a `502` indicates
failed communication between the local relay and BKG. Read the local console
first, then check the official service separately with `curl.exe` and Python
`urllib.request` if needed. The relay restricts upstream paths, uses no
credentials and does not store downloaded BKG assets in the project.

**BKG Beta uses its own height/model state and is not equivalent to the normal
Swiss map.** The URL `lod2_4326_null.json` selects the LoD2 variant without the
DGM5 height offset; it does not by itself establish the actual terrain height.

## Android test build and validation

```powershell
powershell -ExecutionPolicy Bypass -File tool/build/build_android_ruedersdorf_test.ps1
```

This enables `--dart-define=FPV_REGIONAL_3D_TEST=true`, checks required GLB/FPC
files and produces an **experimental** test APK. The public release configuration
does not enable BKG mode by default. Normal app builds follow
[Contributing](../../CONTRIBUTING.md).

```sh
node --test test/js/*.test.cjs
python -m unittest discover -s test/tool -p 'test_*.py'
python tool/quality/check_docs.py
```

Maintained JavaScript regressions include `scenery_site_integrity.test.cjs`
(original scan, southern buildings, openings and FPC), `scenery_underlay.test.cjs`
(optional terrain replacement), `scenery_rendered_ground.test.cjs`
(rendered-height samples), and `scenery_ground_calibration.test.cjs` (BKG-only
ground alignment and Android asset). Revision-numbered filenames may still be
active geometry regressions and must not be removed indiscriminately. For old
paths after a ZIP update, use the checked
[repository cleanup](../README.md#applying-a-changed-files-zip).

Also run the relevant `test_ruedersdorf_*.py` geometry check and compare the model
on an actual device from different camera angles. Raw-triangle, BVH-hash and code
tests do **not** prove correct vertical placement in the BKG globe. Geometry
changes require checking both the edited area and collidable openings; height
changes require checking the top/ground in several parts of the view and after
provider changes.

## Safety, data gaps and limitations

- Rüdersdorf FPC collisions are experimental simulation surfaces, not real
  obstacle measurements.
- The optional separate **DGM1 underlay** (`ruedersdorf_r11_ground.glb/.fpc`) is
  distinct from the main model. Display and clipping require valid assets,
  matching certificates, real terrain samples and active renderer-owned clipping
  masks. `clipTerrain` is disabled by default.
- Regional BKG buildings can overlap scan surfaces visually. Building masking
  is separate from the optional verified terrain mask.
- **Live RF/LoS analysis for BKG Beta is blocked** until its terrain queries and
  3D obstacle handling are validated. Missing heights must not be presented as
  clear visibility or signal loss. See [Radio/Rescue](radio_and_rescue.md).
- UI attribution and external usage rights must be retained with every model
  change. Check the **CC BY-NC 4.0** restriction before publishing derived RAWscan
  geometry.

## Regional 3D service boundary

BKG 3D Beta is an independently gated online test source. Its transport omits
credentials, uses no-store semantics for root/descendant requests, and fails closed
when that transport cannot be installed. FPVManager does not persist these tiles;
embedding/browser/proxy caches require separate host review. Keep official on-screen
credits and test-license change notices. Raster/hillshade have distinct CC BY 4.0 /
DL-DE BY 2.0 terms: see [map sources](../user/map_sources_and_attribution.md) and
[third-party notices](../../THIRD_PARTY_NOTICES.md).

Rendered BKG geometry does not validate the height datum or certify RF/route
clearance. Unknown tiles remain unknown. Copernicus GLO-30 is not an active fallback
or a ready-made Quantized Mesh endpoint; hosting, conversion, datum and rights would
need independent verification. The existing local DGM/geoid alignment is separate.

## Scenery streaming, LOD and resource management (#151)

The scenery manager evaluates camera and aircraft WGS84 positions (including
ellipsoid height) every 500 ms. It releases distant/disabled entries before
admitting new entries, gives priority to the active aircraft and camera, and
uses separate catalog `loadRadiusM` and `unloadRadiusM` thresholds. Existing
alignment, terrain certificates, attribution, source policy and flight safety
checks remain in force. Short movement extrapolation predicts at most 3 s / 300 m
and rejects teleports (>150 m/s or stale samples). Active route replay also
provides three rate-aware lookahead points (1, 3 and 5 s); hints must remain
within 1 km of the current position and cannot activate beyond the unload radius.
Prefetching does not fetch or persist a complete route. Collision loading is
prioritized before visual admission; existing FPC collision sweeps remain CPU
only, and no network promise is awaited in a physics substep.

### Quality presets and budgets

| Preset | Remote tile cache target | Local decoded admission estimate | FPC budget | Concurrent visual entries | Default tileset SSE multiplier |
| --- | ---: | ---: | ---: | ---: | ---: |
| low | 64 MiB | 128 MiB | 128 MiB | 1 | 2 |
| balanced (default) | 128 MiB | 128 MiB | 128 MiB | 2 | 1 |
| high | 256 MiB | 256 MiB | 128 MiB | 2 | 0.5 |

Select a preset per renderer session with `?sceneryPreset=low` (or `balanced`,
`high`). For Flutter on Android, Windows and web use e.g.
`flutter run --dart-define=FPV_SCENERY_PRESET=low`. The default URL remains
unchanged; no change to existing flight graphics settings is needed. For tests,
`FPVSceneryManager.create(..., {streaming: {preset, remoteCacheBytes,
localBudgetBytes, collisionBudgetBytes, maxVisualLoads, sseFactor}})` accepts
bounded explicit overrides. There is not yet an in-app preset selector.

Cesium performs frustum culling and per-tile screen-space-error LOD selection;
cache targets are shared across active remote scenery. Override the per-asset
SSE by adding `qualityScreenSpaceError: {"low": 32, "balanced": 16, "high": 8}`
to that tileset's existing options. Values are validated in Dart and JS.
Tileset texture resolution depends on provider content/LOD, not a global
texture resizing operation. For self-contained bundled GLBs, optional authored
alternatives can select both mesh complexity and texture resolution. Add to the
scenery entry (or manifest `extensions.cesium`):

```json
{
  "visualLods": {
    "site.glb": {
      "low": {"path": "site_low.glb", "estimatedBytes": 16777216},
      "high": {"path": "site_high.glb", "estimatedBytes": 67108864}
    }
  }
}
```

All alternatives must be authored with identical local coordinates/origin,
scale and orientation. Missing levels use the original model. Managed imports
retain their validated single-file model; arbitrary unmanaged alternatives are
not allowed for them. GLB variant selection is session-level; live, distance-
based GLB mesh swaps and runtime texture downsampling are not implemented.
OGC 3D Tiles provides continuous distance-based LOD instead. The Rüdersdorf
assets are unchanged and no lower-resolution files have been generated.

Visual load admission permits one local GLB batch at a time, including an
unsettled cancelled factory; a permanently stalled non-cancellable GLB factory
can require renderer restart. Cesium schedules descendant tile requests itself.
Independent imported FPCs remain loaded even if visual LOD loading fails or
remote visual streaming is unavailable. Existing bundled/calibrated scenes
retain their visual/terrain-readiness gating for physical activation and
replacement masks. The same FPC is used across visual presets; collision
geometry is not simplified or swapped by visual LOD. Underlay loading shares
local and collision admission and discards failed/unverified resources.

Budgets are **admission estimates**, not hard limits on process or GPU memory.
Managed GLB estimates are supplied by the importer; unknown bundled GLBs use a
64 MiB fallback, with 16 MiB reserved for the optional underlay. Unknown FPCs
use 32 MiB (legacy) or 64 MiB (independent) per asset; known FPC sizes and
resident bytes are preferred. Actual decoded size can exceed an estimate and
Cesium can temporarily exceed its tile cache target for visible tiles. New
visual loads wait for released capacity; active collision geometry is not
forcibly evicted merely to admit lower-priority visual assets. Full JS/native
heap and GPU allocations require device profilers.

### Diagnostics

Use the existing `scene-performance` bridge command (`start`, `snapshot`,
`stop`) or the existing build-time validation logging
`--dart-define=FPV_PHYSICS_VALIDATION=true`. Start before approaching a scene
for load timings. The snapshot adds `scenery`, `gpuRenderMs` and `flightPhysics`:

- At most 128 recent GLB/tileset samples (elapsed factory load, GLB model
  readiness, texture-ready event when provided, first tile, all currently
  required tiles ready). Texture readiness is wall-clock time to the Cesium
  event, not isolated texture upload/decode time. Per-tile texture timings
  are unavailable. Null means not observed or not supported.
- Resident model count, in-flight local batches, decoded geometry/texture
  estimates, cache targets, selected tile triangles, shown GLB model triangles,
  resident FPC bytes and active collision triangle count. Triangle estimates
  are selected/submitted geometry, not exact visible pixel coverage. Stats
  availability counters distinguish absent Cesium resource statistics.
- Existing bounded CPU render callback and fixed physics-step times, frame
  pacing, queued/dropped simulation time. No physics integrator changes.
- GPU elapsed time via non-blocking WebGL2 `EXT_disjoint_timer_query_webgl2`
  when available; at most eight pending queries, dropped on context loss or
  GPU disjoint, deleted on stop. Unsupported devices report no samples.
  Timing spans the render callbacks, not all GPU work in the process.

Diagnostics are local/on-demand; no per-frame bridge traffic or external
telemetry. Load timing records contain no asset URLs or scenery identities.

### Repeatable verification

Run `node --test test/js/*.test.cjs` (Chromium required for browser cases) and:

```bash
node --expose-gc tool/benchmarks/benchmark_scenery_streaming.cjs 200 low
node --expose-gc tool/benchmarks/benchmark_scenery_streaming.cjs 200 balanced
node --expose-gc tool/benchmarks/benchmark_scenery_streaming.cjs 200 high
```

The synthetic benchmark uses real scenery scheduling and fixed-step runtime,
with mock visual/collision factories and a trivial integration callback. The
reference in `tool/benchmarks/reference/scenery_streaming_synthetic_reference.json`
records 200 activations per preset, matching creates/destroys, zero retained
models/credits/collider bytes, bounded diagnostics and zero dropped/queued time.
This is **not** a model decode, GPU, or real flight performance measurement.

For physical device acceptance, use the same Rüdersdorf scene, terrain and
saved approach/exit route on a representative Windows device and Android
(e.g. S22 and S25 Ultra). For each preset, keep the physics rate, flight graphics
profile, resolution and route speed constant. Start outside the unload radius,
fly in, perform an identical collision-safe pass near buildings, exit beyond
unload distance, and repeat at least five times. Repeat with cold and warm
cache, record thermal/power state, and check the same openings/collision
contacts across presets. Collect validation logs while approaching, and sample
process memory before loading, at peak and after each unload/settling period
using Android Studio/ADB or Windows profiling tools. Record results in
`tool/benchmarks/reference/scenery_streaming_device_template.json`. Compare p95
CPU/GPU/physics times, dropped and maximum queued time, resource counts and the
post-unload memory trend. Compare with the unchanged source commit using the
same conditions. Hardware-specific FPS targets and memory plateaus remain
pending until physical measurements exist; do not treat synthetic results as
proof of device performance.
