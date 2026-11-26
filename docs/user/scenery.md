# Real-world scenery and model imports

This chapter covers imported models, external 3D Tiles providers and the
experimental Rüdersdorf reference scene. Standard map and simulation features are covered by
the [user handbook](../user_guide.md). Technical reproducibility is documented in
[Scenery and heights](../developer/scenery.md).

## What is displayed

- Andrea Spognetta's photogrammetric **RAWscan "Abandoned Chemical plant
  Rüdersdorf"**, with additional approximate industrial reconstruction. Geometry,
  site condition and surfaces do not all represent the same acquisition year.
- A separate FPC collision mesh for the simulator. It can detect contacts with
  modeled surfaces, but **does not guarantee real-world obstacle clearance**.
- Optional official buildings and terrain from **BKG 3D Beta**. This mode is
  enabled only by a special test build; it is not approved for real flight planning.
- Author and data-source credits in the map's sources panel and
  [Map sources and attribution](map_sources_and_attribution.md).

## Display and settings

1. Open the map near Rüdersdorf, east of Berlin.
2. Open **Map & view → Map → Real-world scenery**. Enable the local scene if its
   assets are included in the build.
3. Use **Refresh status** to query the scene again when needed. The normal menu
   shows loading state and readable errors; internal collision, height and mask
   values are reserved for diagnostics.
4. Scene configuration controls overlap with BKG LoD2. The advanced developer
   mask and alignment editors remain hidden in regular builds.

### Manage scenery

Use **Manage scenery** to create a scene definition from an existing model
template, name it, edit its placement or remove it. New definitions start disabled;
enable them in the scene list. Position, altitude reference, heading, pitch, roll,
scale and loading distances are saved and restored through the normal backup.
Changes require navigation to be stopped. **Cancel** discards unsubmitted form
changes.

Templates use bundled or previously imported models and retain their source credits.
A copied template does not inherit verified terrain replacement regions.
Unsupported data sources remain explicitly unavailable.

### Import a local GLB or glTF model

1. Open **Manage scenery → Import GLB / glTF** and choose a static glTF 2.0 model.
   Keep separate `.bin`, PNG and JPEG resources beside a native `.gltf` file.
   On platforms without directory access, select each resource when prompted;
   the prompt shows the exact relative model reference.
2. Enter longitude, latitude, height, altitude reference, heading, pitch, roll and
   scale. Heights are metres above the **WGS84 ellipsoid** or relative to the
   displayed terrain; a sea-level height must be converted before absolute use.
3. Check the author, license and attribution, then save. **Cancel** saves nothing.
   The model activates when the camera/aircraft enters its loading distance.
   Missing terrain delays relative placement; errors can be retried from status.

Imports retain core materials, transparency and PNG/JPEG textures. Compressed
Draco, Meshopt and KTX2 models, animations, skins, morph targets and sparse meshes
are not supported by this importer; export an uncompressed static model first.
The import screen reports progress and validation errors. Files are limited to
64 MiB including resources, textures to 4096 pixels per side; models also have
decoded geometry/texture limits to keep allocations bounded.

Imported models remain on this device after restart and their resources are
self-contained for offline use. Web requires HTTPS/localhost and available
browser storage; clearing or evicting that storage requires reimport. Current
backups transfer the **definitions only**, not the model files. Removing the last
definition using a managed model removes its local file. Portable scenery
packages remain a later feature.

New imports are **visual only by default**. Attach or generate physical geometry
through **Collision geometry** below. Terrain/building replacement and scenery RF
obstruction remain separate features.

### Add an external 3D Tiles provider

1. Open **Manage scenery → Add 3D Tiles provider**. Enter a complete public HTTPS
   tileset URL, or select the **Brandenburg example**.
2. Select **Check provider**. This checks the header and geographic bounds;
   individual tiles may still fail later. The service must support browser CORS.
3. Review name, source, license and attribution. Choose maximum screen-space
   error (smaller means more detail and more loading), loading/unloading distances
   and HTTP caching policy. Save, then enable the scene if needed.

Existing provider coordinates and transforms are preserved. Leave **Optional
positioning correction** at its defaults unless a correction is needed. East/north/up offsets,
rotation and scale act around the absolute WGS84 correction pivot. A wide
dataset's initial pivot can be below ground; it does not relocate the source by
itself. Loading distance is measured from coverage to the camera or aircraft,
with a larger unloading distance to avoid repeated loading at the boundary.

**Runtime only, no browser disk cache** is the default. **HTTP cache according to provider rules**
uses the provider's normal browser caching rules. These are online services;
offline map modes stop external requests. Definitions, settings and credits
survive restart and backup restore, but backups do not contain provider tiles.
Recheck the URL if the provider changes its coverage. Respect its licensing and
caching terms; the Brandenburg example uses DL-DE-BY 2.0 with LGB attribution.

A failed provider does not stop the globe or simulator. Status reports header
errors and degraded tile streaming; already loaded tiles remain available after
individual tile errors. Check internet access, URL, service availability and CORS,
then use the scene retry control. Credentials-based provider sign-in is not
supported. At most four remote tilesets are active at once. Like new model imports,
external tiles are **visual only by default**; independently prepared local
collision geometry can be attached. RF obstruction remains a separate feature.

### Align scenery directly on the globe

1. In **Manage scenery**, select **Align on globe** beside a scene, or **Select
   and align on globe** and tap a loaded model. Navigation must be stopped. A
   disabled scene is temporarily enabled for editing; its saved switch is retained.
2. Use longitude, latitude, height, heading, pitch, roll and scale, or drag the
   **E/N/U** handles. The yellow ring/knob rotates around local up. Choose
   **Top down** or **Perspective** and adjust opacity to compare against imagery
   or existing buildings. Collapse the panel for more viewing space.
3. **Snap anchor to terrain** places the origin on the available terrain surface.
   Absolute heights use the WGS84 ellipsoid; terrain-relative heights preserve
   their offset when moving horizontally. Enable and load terrain-relative scenes
   before opening the editor. Missing terrain produces an error, not zero height.
4. For a local model, expand **Control points and bounds**. Pick a model surface
   point, then its matching terrain/building point. Repeat with at least three
   spread-out, noncollinear pairs and select **Fit control points**. Numeric pairs
   can also be entered in the shown JSON format; target `heightM` is ellipsoidal.
   The fit changes position, all three rotation angles and uniform scale. Inspect
   the RMS, maximum and individual residuals; inconsistent points do not fit exactly.
5. Use **Undo**, **Redo** or **Reset** as needed. **Apply** saves the confirmed
   placement. **Cancel** discards the draft and restores the original model,
   appearance, activation setting and camera. Changes made elsewhere are protected
   against an obsolete editor overwriting them.

The editor displays origin, bounds and a projected geographic footprint for local
models; other assets use their available coverage bounds. Source/target surface
picking requires device support for depth picking and loaded geometry. History
and control points belong to the current editing session. Definitions and
confirmed placement survive restart and backup restore; model-byte backup limits
remain unchanged. Legacy reference scenes should use full opacity for flight under
their existing collision/replacement policy. Independently imported colliders remain
active when visual geometry is transparent or its LOD is unavailable.

Georeferenced 3D Tiles retain their source coordinate system. Their numeric and
graphical corrections transform the provider in its source ENU frame. Control-point
fitting is currently for local models; regional provider datasets use correction
controls. Alignment is a simulator placement, not a surveyed accuracy guarantee.

### Configure physical collision geometry

1. Open **Manage scenery → Collision geometry** beside a scene. Enable physical
   collisions and select double-sided, front-only or back-only thin surfaces.
   Front/back follow the authored triangle normals, not the camera direction.
2. **Import collision mesh** accepts FPC1, or static GLB/glTF through the existing
   local resource selector. **Generate from visual model** uses a compatible local
   GLB. Remote tile geometry is not scraped or used as a changing physics LOD.
3. The physical mesh must share the visible model's local origin and metre units.
   Node transforms are baked; scenery placement, rotation and scale are shared.
   Keep real windows, doors and pipe bores in the mesh. No simplification or hole
   filling is applied. Texture transparency alone does not create a physical gap.
4. **Apply** saves definitions and local collision files. **Cancel** discards newly
   prepared geometry. Imported files remain available after restart/offline on this
   device; backups transfer definitions, not the model/collision bytes.

The scene status displays physical loading errors and offers retry after stopping
navigation. A sweep entering the bounds of requested but unavailable collision
geometry pauses movement with a HUD reason until the geometry is ready. This is
not an RC failsafe or a fabricated wall contact; unrelated areas remain usable.
Physical meshes remain independent of visual texture errors, opacity and LOD.
Advanced and Legacy modes use the same swept triangle checks.

In the scenery layer menu, **Show collision mesh (debug)** displays the actual
loaded physical wireframe. It is off by default and does not replace the collider.
Use it to inspect alignment and openings before flying. Base terrain, standard
buildings, bridges and tunnels still have their own collisions; attaching a mesh
does not automatically remove overlapping world geometry.

Limits: 64 MiB per collision file, 128 MiB active custom collision data and 512 MiB
shared local scenery storage. These are allocation limits, not hardware performance
guarantees. Larger reconstructions should use a separately prepared physical mesh
that preserves important passages. Compressed/animated glTF import limits still
apply; FPC geometry is static, local and texture-free.

### Height reference and ground alignment

Scene height in the normal globe is not taken directly from the workbench export.
A workbench value on a **flat ellipsoid surface** is not the eventual absolute
model height above the terrain actually rendered. The current scene uses terrain
samples and accounts for the photogrammetry model's local ground offset.

For the current Rüdersdorf test version, **−16.90 m** was confirmed as a BKG-specific
visual correction using two matching ground surfaces. It is **not an official
surveyed height**. Other local settings can take precedence; this correction must
not be transferred to the regular Cesium terrain provider.

The following comparison is available **only in a private developer build** with
`--dart-define=FPV_DEVELOPER_MENUS=true`. It is not part of normal flight preparation.

For a new check:

1. In the developer build's BKG test mode, select **Compare ground heights**.
2. Tap a recognizable, reasonably level, open **ground surface** in the scan.
   Do not select a roof, floor slab, bridge or vegetation.
3. After the scan is hidden, tap the same location on the **map terrain actually
   rendered**, as closely as possible.
4. Review the proposed difference, horizontal separation and visual result before
   selecting **Apply ground height**.

The comparison must not confuse terrain slope with a height error; points too far
apart are rejected. A displaced or floating model indicates a **calibration
problem**, not safe overflight clearance.

## Flight and analysis

The scan model contains walkable/flyable openings and experimental contacts.
A visible opening is **not** permission or a guarantee that a real FPV aircraft
can pass through it. FPC data is for simulation only.

**Live RF/terrain LoS analysis is explicitly blocked in BKG Beta mode** because
its underlying terrain data has not been validated for this use. Missing analysis
is neither a clear line of sight nor confirmed signal loss. The normal Swiss
terrain source provides its supported functions separately. See
[Preflight and signal analysis](preflight.md) and
[Flight simulation](flight_simulation.md).

## Troubleshooting

| Observation | Check |
|---|---|
| Model does not appear | Scene enabled, assets loaded, ground calibration ready and camera in range? Use **Refresh status**. |
| Model floats or intersects the ground | Check the active terrain provider, tile status and confirmed BKG offset. Do not add another generic geoid offset. |
| Duplicate building or gantry in the scan | Scan and reconstructed surfaces may overlap. Capture the view direction and mark the affected building in a screenshot. |
| Buildings look flat or simplified | LoD2 is a separate source; buildings may be missing or may have changed since the scan. |
| RF analysis unavailable | It is intentionally disabled in BKG Beta mode. |

**Privacy and usage rights:** the scan and BKG data have separate terms. The scan
is subject to **CC BY-NC 4.0**, including its non-commercial restriction. See
[Map sources and attribution](map_sources_and_attribution.md) and
[Third-party notices](../../THIRD_PARTY_NOTICES.md).
