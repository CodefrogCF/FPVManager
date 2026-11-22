# Rüdersdorf – GLB visual georeferencing on FPVManager's real map

**Scope:** Issue #144 validation and alignment experiment. This is **not** Issue #145's reusable import system or Issue #149's collision integration.

## Result

The original user-supplied photogrammetry GLB has already been confirmed to render in **CesiumJS 1.145.0**. It has no surveyed geographic anchor and no reliable meter scale. The existing `web/map_providers.js` (previous Issue #144 patch) already provides an **official Berlin/Brandenburg DOP20c imagery overlay**. This workbench combines both on one georeferenced globe, with Cesium's flat ellipsoid as a temporary elevation reference.

The starting coordinate **52.484197, 13.789789** is the *published location of the site*, not the exact model origin. Starting `scale:10`, `rotationDeg:0`, `ellipsoidHeightM:0` are **guesses for editing**, NOT calibrated values.

## Start the workbench

1. Apply the earlier Issue #144 Berlin/Brandenburg map patch if you have not already done so. Then apply the georeferencing patch from this change.
2. Keep the original third-party model **out of Git**. Copy the already obtained original GLB as `tool/scenery/local_reference.glb`.
3. From the **repository root** run:

   ```bash
   python -m http.server 8765
   ```

4. Open **http://localhost:8765/tool/scenery/cesium_georeference_workbench.html**. Internet access is needed for the LGB orthophoto service. The GLB is loaded from your machine.
5. Use **Draufsicht**. Start with **Maßstab** and **Rotation**, then nudge the model onto matching building roofs, silos and the chimney visible in the satellite image. Lower **Deckkraft** to 0.3–0.6 to compare edges. Prefer three or more well-separated matching features, and check the match again in **Schrägansicht**.
6. **Anker setzen** enables a one-click map anchor; the four nudge buttons and arrow keys move by approximately 1 meter. **Strecke messen** measures a ground distance. Its approximate scale button assumes the measurement corresponds to approximately 16.8 local units along the GLB's main planar axis—this is only a rough starting estimate.
7. Adjust **ellipsoidHeightM** last. This is an origin offset above the **WGS84 ellipsoid**, not AGL and not a surveyed elevation. The demo globe has **no real Brandenburg terrain provider**.
8. **JSON herunterladen** writes `reference_alignment.json` containing longitude, latitude, ellipsoid height, scale, clockwise local rotation and opacity. The browser also saves the current settings in localStorage under a namespaced key. The export explicitly marks the placement `surveyVerified:false` and collisions `false`.

## Optional preview in the actual FPVManager globe

This is a temporary **developer-only** integration, not a user-facing scenery manager:

1. Create `web/assets/scenery/` in the repository (the model and JSON in it are ignored by Git).
2. Copy the original GLB to `web/assets/scenery/local_reference.glb`.
3. Copy the JSON exported from the workbench to `web/assets/scenery/reference_alignment.json`.
4. On a development web server, open `web/globe.html?sceneryPreview=1` to opt into the model alongside the app's normal map and overlays. When running the full **Flutter Web** project, build/run with `--dart-define=FPV_SCENERY_PREVIEW=true` to pass this flag to its globe iframe.
5. The preview must not be used for actual flight physics: **no collision mesh**, no terrain carving, no radio obstructions. It only renders the local visual geometry. It does not activate unless `sceneryPreview=1` is set.

**Native Android/Windows note:** the native asset server serves only manifest-listed Flutter assets. The ignored, locally supplied GLB and JSON are *not* included in `pubspec.yaml` so that they cannot accidentally enter public builds. The opt-in native flag alone is insufficient to load the unbundled model. Use the browser workbench / Flutter Web for this experiment; native local-asset import belongs to the upcoming generic scenery architecture.

## Important calibration limitations

- This GLB was reconstructed from video around 2018. The current orthophoto may show later modifications/demolitions. Choose unchanged landmarks.
- The model footprint is not a surveyed orthomosaic: local geometric distortion can prevent a single similarity transform (one uniform scale, one rotation, one translation) from perfectly matching all buildings.
- We have not established the true minimum ground elevation or vertical datum at the site. A correct *horizontal* match does **not** imply a correct *vertical* fit.
- Model transparency is for comparison only; terrain will not be cut away. The official DOP20c is **imagery only** and cannot serve as a 3D elevation provider.
- Visual alignment cannot certify accuracy suitable for collision response, drone clearance margins or real-world navigation.
- Large local meshes may cause long loading times or memory pressure, especially on mobile devices. Test with Windows first.

## Sources and licensing

- Model: **Andrea Spognetta (spogna)**, *Abandoned Chemical plant Rüdersdorf – RAWscan*, [Sketchfab](https://sketchfab.com/3d-models/abandoned-chemical-plant-rudersdorf-rawscan-d2464ec36fb644f28e904e5517f1da64), [Zenodo record](https://zenodo.org/records/10288797), **CC BY-NC** per original Sketchfab model page. The model is **not distributed** in this patch.
- Orthophotos: **© GeoBasis-DE/LGB**, DOP20c, [official WMS](https://isk.geobasis-bb.de/mapproxy/dop20c/service/wms?), 20 cm resolution, attribution presented by the regional map adapter.

## Validation

- The original user-side GLB smoke test already displayed a detailed model in CesiumJS 1.145.0.
- `node --test test/js/scenery_alignment.test.cjs` validates configurations, ENU transforms, nudges, export metadata, preview gating, cleanup, failure behavior and structural wiring.
- `node --test test/js/*.test.cjs` checks the complete JavaScript regression suite.
- A live browser test of the new *georeferenced overlay*, including official WMS imagery, is **still required** on the user's machine. No visual location/scale/height calibration is claimed before that test.
