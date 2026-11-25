# Real-world scenery: Rüdersdorf, heights and collisions

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
| FPC collisions | `web/assets/scenery/local_reference.fpc`, `web/features/scenery/scenery_collision.js` |
| Experimental BKG buildings and regional 3D selection | `web/features/terrain/regional_3d.js`, `web/features/scenery/scenery_bridge_calibration.js` |
| Workbench view and local data relay | `tool/scenery/cesium_georeference_workbench.html`, `tool/scenery/serve_workbench.py` |
| Reproducible reconstructions, measurement reports and regressions | `tool/scenery/`, `test/js/scenery_*.test.cjs`, `tool/scenery/test_ruedersdorf_*.py` |

The **main GLB and FPC are built together**: physical collisions must match the
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
Other providers/formats can be defined and stored; a scene remains
**unavailable** without a matching loader or when its minimum app version is too
high. Front-/back-only collision and newly tilted, previously terrain-calibrated
scenes remain unavailable until implemented or recalibrated appropriately.
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
format; model bytes and provider caches are not exported as an exchangeable
scenery package. Older backups remain readable. Arbitrary 3D Tiles services and
`.fpvscenery` packages remain separate follow-up features. The reference-scene
and BKG limitations below still apply.

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
during navigation. Existing scenery loading remains sequential.

Native models are atomically written under application support `scenery/v1/`,
named by SHA-256, and served through a fixed same-origin loopback route with at
most two coalesced reads. Web models use app-scoped CacheStorage on HTTPS or
localhost; the renderer verifies the checksum and uses a revocable Blob URL,
without HTTP fallback. Cancellation before confirmation commits nothing; database
failure rolls back new unreferenced bytes, while bridge failure retains committed
definitions and files. Removing the last scene reference removes its file.
Browser storage can be evicted or cleared; missing/corrupt files report a
reimport error. Definitions in backups do **not** transfer model bytes to another
device; portable packages belong to #152.

Placement uses a WGS84 ellipsoid height or a height relative to the displayed
terrain, then local ENU heading/pitch/roll and uniform scale. Generic relative
placement samples the model anchor; it does not reuse reference-site ground
controls. Missing terrain hides the model until alignment succeeds; a stalled
height request reaches an explicit recoverable error. Newly imported visuals do
not create collision geometry (#149), replacement regions (#150) or RF obstacles
(#153). Existing collision-backed reference scenes retain their own behavior.

Regression coverage includes synthetic imports, unsafe/missing resources,
allocation limits, database/file restart, rollback and shutdown, UI cancellation,
loopback serving, cache-only reads and Blob disposal. ECEF bounds are compared
against the pinned Cesium matrices. The real Chromium regression uploads and
renders a georeferenced PNG-textured transparent GLB, reloads the page, and checks
that the model comes from cache without another model HTTP request. Device smoke
tests and hardware performance measurements remain separate release checks.

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
