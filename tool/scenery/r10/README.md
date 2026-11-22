# R10 – DGM1 + GCG2016: corrected height datum (additive reference patch)

The uploaded official height grids permit **correct absolute height conversion** for the Rüdersdorf site, but do **not automatically** make the entire photogrammetric site terrain continuous or collision-safe. R10 deliberately remains a separate reproducible reference. It does not overwrite R8 production GLB/FPC or edit the regional terrain provider.

## Sources and licensing

- `dgm_33417-5815.tif`, supplied in `dgm_33417-5815.zip`, © GeoBasis-DE/LGB, **Datenlizenz Deutschland – Namensnennung 2.0**, changed data. https://data.geobasis-bb.de/geobasis/daten/dgm/tif/dgm_33417-5815.zip
- `de_bkg_gcg2016.tiff`, uploaded BKG/PROJ GeoTIFF; attribution embedded in GeoTIFF: **Derived from work by BKG, CC BY 4.0**, https://creativecommons.org/licenses/by/4.0/ ; source transformation https://cdn.proj.org/de_bkg_gcg2016.tif.
- FPVManager R8 visual/collision geometry is based on Andrea Spognetta (spogna), *Abandoned Chemical plant Rüdersdorf – RAWscan*, **CC BY-NC 4.0**. Not part of this additive zip.

## Coordinate reference systems and exact calculation

DGM1: `ETRS89 / UTM zone 33N + DHHN2016 height (EPSG:25833 + EPSG:7837)`, 1 m spacing. GCG2016 grid: `ETRS89/DREF91/2016 -> DHHN2016`, `EPSG:10283` to `EPSG:7837`, vertical correction grid, accessed using PROJ `vgridshift`. The grid represents the height anomaly `ζ`; therefore **ellipsoidal height `h` = DHHN2016 normal height `H` + ζ**. The sign has been checked with an explicit PROJ forward vertical-grid shift.

At the *unaltered* R8 anchor 13.789853720999993° E / 52.48411904363446° N:

- Bilinear DGM1 elevation `H`: **40.949489588990 m NHN**.
- PROJ-interpolated GCG2016 anomaly `ζ`: **38.871142784910 m**.
- Terrain ellipsoid height `h`: **79.820632373900 m (ETRS89/GRS80)**.
- R8 model ground reference: **−2.02575 local units**, scale **16.023268178233355**.
- Required root ellipsoid height to place this exact local ground point at the DGM1 datum: **112.279767885956 m**.

Do not confuse `112.280 m` (the **model origin**) with `79.821 m` (the **physical terrain height**). ETRS89 and WGS84 are approximated as coincident for this local graphics calculation, not survey-grade. The GCG2016 correction varies by only **0.01250049 m (1.25 cm)** over the R9 reference mesh. The previous 4 m discrepancies are therefore **not** caused by a missing geoid shift: several elevated building floors simply are not bare-earth DGM terrain.

**IMPORTANT:** The existing FPVManager `scenery_manager.js` already calls `terrainAligned(item, sampleGround(...))` with an ellipsoid height returned from the live terrain provider, and computes `height - groundReferenceLocalUp * scale`. Do not set the catalogue's legacy 32.25 m root to 79.82 m or 112.28 m as an extra additive offset while retaining the live auto alignment: that would risk applying the correction twice or changing behaviour of the flat-ellipsoid preview. The production catalogue is left unchanged.

## Reference output

- `height_calibration.json`: traceable raster checksums, precise anchor heights, source attributions, mesh hashes, conversion limits and 16 R8 seam status summaries.
- `dgm_ellipsoid_reference.glb`: independent terrain surface with the **relative** GCG2016 variation; loads alongside the R8 scan at the calculated model-root height.
- `dgm_ellipsoid_reference.fpc`: matching BVH collision geometry. **For reference testing only**, never replace `local_reference.fpc` with this file.
- `seam_comparison_ellipsoid.csv`: 536 recalculated boundaries in ellipsoid coordinates.
- `R10_height_calibration.png`: terrain raster plus seam status.
- `index.html` / `preview.js`: optional offline-file-served Cesium comparison, still no production terrain clipping.

Seven of the 16 R8 rectangles have max absolute seam residual <= 0.5 m relative to the calibrated DGM1 surface; nine exceed that tolerance. This is an **offline datum-corrected audit**, not validation of the experimental BKG 3D Beta provider datum or actual Android runtime clearance. Zero-mesh-gap assurance for the entire perimeter is not supported.

## Installation and tests

Unzip this package into the FPVManager repository **with the R8 and R9 reference packages already installed**. It only adds files under `tool/scenery/r10/`.

From the repository root:

```powershell
python tool/scenery/r10/calibrate_gcg2016.py C:\path\to\dgm_33417-5815.zip C:\path\to\de_bkg_gcg2016.tiff
python -m unittest tool/scenery/r10/test_gcg2016.py -v
node --test tool/scenery/r10/test_r10_reference.cjs tool/scenery/r9/test_reference.cjs
python -m http.server 8765
```

Then open `http://localhost:8765/tool/scenery/r10/index.html` (the local glTF preview requires the existing bundled CesiumJS). A real browser/WebGL device validation has **not** been performed in the preparation environment.

The Python test discovers the original GCG file from `R10_GCG_GRID`, if provided; if it is missing, only the direct grid reproduction test is skipped, while the numeric report tests still run.

## Remaining work towards fully seamless site terrain

1. Use the datum-corrected field as reference to classify open-ground versus building floors and ruins; preserve floors and both-sided chimney, hall, and gangway.
2. Repair unobserved boundary triangles conservatively; triangulate genuine ground strips toward verified DGM1 contour, without producing an overlay through built structures.
3. Build a merged render/collision model with verified boundary transitions at every enabled replacement polygon.
4. Validate crossings, suspended/indoor areas, tunnel portal masks, 3D Beta provider vertical reference, unavailable terrain fallback and load/unload cycles before turning on whole-site clipping.

These are *not* claimed as completed by this patch.
