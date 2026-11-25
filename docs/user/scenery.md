# Real-world scenery and Rüdersdorf (experimental)

This chapter describes **the current Rüdersdorf test scene**, not a generally
available surveyed 3D city. Standard map and simulation features are covered by
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

Templates use models already bundled with the app and retain their source credits.
A copied template does not inherit verified terrain replacement regions. Importing
model files and exchanging scenery packages are not yet part of this management
workflow. Unsupported data sources remain explicitly unavailable.

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
