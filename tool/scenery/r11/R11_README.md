# FPVManager v0.20.0 — Rüdersdorf R11: geodetically calibrated DGM1 ground underlay

## Status: implemented, **experimental / opt-in**, real-device validation pending

R11 adds an **independent** continuous bare-earth GLB and matching FPC collider derived from the supplied Brandenburg DGM1 and BKG GCG2016 data. This is not a new synthetic replacement for R8 buildings, elevated industrial floors, the roof gangway, or the two-opening chimney. The R8 `local_reference.glb` and `local_reference.fpc` are **unchanged**, as are horizontal position, scale, heading and the existing live-terrain height adjustment.

The DGM underlay is only made visible and physically active **after** every safety gate passes. The previous 16 individually certified R8 ground patches remain as conservative fallbacks. The new ground is disabled by default: the field `clipTerrain` is still `false` in the catalog.

## Generated geometry and reference

- Georeferenced asset: `web/assets/scenery/ruedersdorf_r11_ground.glb`
- Matching physical asset: `web/assets/scenery/ruedersdorf_r11_ground.fpc`
- **77,520 vertices**, **153,928 triangles**, **32,767 BVH nodes**; FPC approximately 3.65 MiB.
- Certified candidate clipping region: **75,809.38 m²** (~7.58 ha). The underlying underlay extends ~0.96 m outside that candidate mask to make all boundary sweep samples numerically well-defined. This slim extension can still cause minor visual overlap; see limitations.
- Absolute ellipsoidal height at model anchor: DGM1 **40.949489589 m NHN** + GCG2016 **38.871142785 m** = **79.820632374 m** ETRS89 ellipsoidal, corresponding to existing R8 model root **112.279767886 m** when `groundReferenceLocalUp = -2.02575` and scale `16.023268178233355`.
- Underlay has a smooth, **at most 10 cm model-interior visual clearance** beneath the surveyed DGM reference to reduce exact Z-fighting with photographed ground. This is a rendering adjustment, **not a survey correction**. At the surveyed outer scan border, that clearance fades to zero. The reconstructed building floors are preserved, not flattened to bare earth.
- The separate underlay material is a simple neutral rendering placeholder, **not phototextured satellite imagery**.

## Safety / lifecycle architecture

1. Select **`Karte & Ansicht → Reale 3D-Umgebungen → Geprüfte Gelände-Ersatzflächen inkl. DGM1 (Test)`**. The DGM asset is loaded lazily only when the experimental regional terrain is active, a compatible unmodified R8 alignment is used, and the extra R11 polygon is included in the requested regions.
2. The R8 and R11 collider assets must independently pass SHA-256 verification. R11's own GLB/FPC are never substituted for the main collision model.
3. The currently loaded live terrain provider is sampled on the polygon boundary (R11 **372 points**, 3 m nominal spacing). A **maximum deviation of 0.25 m** must be met. All 16 R8 certificates retain their previous **0.50 m** tolerance (536 additional samples).
4. The Cesium clipping collection **must actually be owned and active** on the regional terrain's globe. R11 is hidden otherwise. The R11 FPC is used for physical ground contact only when the same owned terrain mask is active and the entire tested segment lies inside its certified region. The main R8 collider continues to handle buildings, floors, windows and obstacles.
5. Provider change, internet/offline mode, disabled scenery, manual alignment edits, wrong hashes, unavailable height data, clipping unsupported or failed loading all fall back to the earlier terrain/collision behavior. Stale loads and old seam approvals are invalidated. When the full R11 mask is approved, it *replaces* the 16 smaller R8 masks; if it is rejected, independently approved old R8 patches may remain.
6. The extra asset is not included in the normal startup GPU workload when the option is off. `groundUnderlayState`, `groundUnderlayVisible` and `terrainSeamChecks` are exposed in scenery status.

**A mathematically continuous DGM1 mesh is not the same as a real-world proven seamless match to BKG's separate DGM5 beta terrain service.** The clipping approval gate makes no unconditional promise of runtime availability. It may reasonably fail, and must never be bypassed just to display the underlay.

## Installation

This is an **incremental ZIP**, install *after* the R8 main model and R9/R10 reference work. It includes the new DGM-derived GLB/FPC and changed application source/tests but **not** the R8 GLB/FPC nor the raw DGM/GCG rasters.

```powershell
flutter pub get
flutter analyze
flutter test
node --test test/js/*.test.cjs
node --test tool/scenery/test_ruedersdorf_r2.cjs tool/scenery/test_ruedersdorf_r3.cjs tool/scenery/test_ruedersdorf_r4.cjs tool/scenery/test_ruedersdorf_r5.cjs tool/scenery/test_ruedersdorf_r6.cjs tool/scenery/test_ruedersdorf_r7.cjs tool/scenery/test_ruedersdorf_r8.cjs tool/scenery/r9/test_reference.cjs tool/scenery/r10/test_r10_reference.cjs
flutter build apk --dart-define=FPV_REGIONAL_3D_TEST=true
```

After installing, the existing Drift-stored scenery edit may contain only the old 16 polygons. **Reset scenery settings to catalog defaults before switching on the ground option** if R11 cannot appear in the status.

### Android/Windows manual test matrix

- In Rüdersdorf verify the unmodified R8 facilities, two-sided chimney and roof gangway, then enable terrain replacement. Check `DGM1 underlay: ready · Visible: yes` **only if** active regional 3D and clipping pass.
- Fly low over the courtyard and near a site edge. Verify no ground holes, floating ground, hidden wall or sudden collision at the mask transition; repeat in Legacy and Advanced modes.
- Verify windows and elevated floors in the large hall remain physically independent of the DGM1 bare-earth ground.
- Toggle terrain replacement off while not flying: DGM layer and mask must both disappear. Then restart and repeat.
- Switch region/provider, disable mobile connectivity, use offline maps and return to Switzerland. There must be no Rüdersdorf ground artifact away from the site.
- Observe GPU frame time, physics frame time and memory on S25 Ultra, S22 and Windows. The underlay currently adds 153,928 triangles when enabled, not zero cost.
- If status reports `terrainSeamState: checked` with zero approved regions or `unavailable`, **do not force clipping**. Obtain a screenshot of status and network requests for provider-specific calibration.

## Verified tests (local development environment)

- All **894/894 JavaScript tests** passed on the sequentially layered source baseline (R8 + R9 + R10 + R11), including three new R11 tests.
- **348/349 model and reference tests** passed; **one old R3 block is intentionally skipped**. Historical R7 and R8 tests were updated solely to account for the additional *optional* catalog polygon.
- **5/5 GCG2016 Python unit tests** passed.
- A full Windows/Android native build, an actual CesiumJS WebGL render test and live BKG-beta seam approval **have not been run here**. Device behavior remains unconfirmed.

## Known limits and remaining work

- The **full-site ground mesh** covers the certified rectangle continuously, but old photogrammetric scan borders/vegetation/black mesh artifacts were **not all removed**. R8's conservative 291-triangle fringe cleanup is preserved. Enlarging cleanup requires distinguishing real riverbanks, structures and scan error triangles; blanket deletion is unsafe.
- The R11 ground has **no photorealistic textures**. A later refinement could use properly licensed aerial images or calibrated photographs for surface texturing without changing the geographic mesh.
- The underlay is a bare-earth surface, not a measured indoor or suspended floor model. Several R8 building floors remain 1–4 m above bare earth; these differences are not errors that can be eliminated by lowering buildings.
- The live BKG DGM5 beta service's height reference and exact edge match have not been checked on the user devices. The **0.25 m seam gate** may refuse the entire large underlay. The user may still use the individually approved R8 patches.
- The clipping polygon is rectangular; it covers non-scanned or poorly scanned outside patches too. These are survey-derived, but visual quality may look artificial until ground textures and edge transitions are upgraded.

## Source credits

- Original industrial reconstruction: Andrea Spognetta (*Abandoned Chemical plant Rüdersdorf – RAWscan*), **CC BY-NC 4.0**. https://sketchfab.com/3d-models/abandoned-chemical-plant-rudersdorf-rawscan-d2464ec36fb644f28e904e5517f1da64
- Digital terrain model DGM1: **© GeoBasis-DE/LGB**, Datenlizenz Deutschland – Namensnennung 2.0, modified. https://data.geobasis-bb.de/geobasis/daten/dgm/tif/dgm_33417-5815.zip
- Height anomaly grid GCG2016: **© BKG**, CC BY 4.0, modified. https://cdn.proj.org/de_bkg_gcg2016.tif
- The external BKG 3D-Beta live terrain service has distinct **test-only** conditions; its data are not redistributed or persisted by this patch.
