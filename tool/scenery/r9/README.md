# R9 – DGM1 reference surface and ground discrepancy audit (preparation)

This patch is deliberately additive: no R8 visual or collision asset, catalogue, scenery replacement masks or simulator source is overwritten. It **does not** activate a site-wide terrain replacement or complete the outer seam. The DGM shows that blindly flattening the scan or enabling all 16 R8 masks would be inappropriate.

## Data

Source: `dgm_33417-5815.zip`, `dgm_33417-5815.tif`, Landesvermessung und Geobasisinformation Brandenburg. © GeoBasis-DE/LGB, dl-de/by-2-0, Daten geändert. https://www.govdata.de/dl-de/by-2-0 — https://data.geobasis-bb.de/geobasis/daten/dgm/tif/dgm_33417-5815.zip. Metadata: LiDAR 2018-11-28, photogrammetric processing 2023-05-04, released 2026-01-26. Raster EPSG:25833 + DHHN2016 height, 1 m pixel centers, 1,000 x 1,000. No raster or provider requests are made by the preview. Source scan: Andrea Spognetta, CC BY-NC 4.0, original and R8 unchanged.

The R8 collider bounds project to UTM East 417668.79–417977.82, North 5815414.66–5815730.90. All vertices are inside the tile. A 5 m margin in model-local axes is also covered. Anchor NHN bilinear interpolation: 40.94949 m. DGM reference surface 34.46–45.21 m NHN. Grid 287 × 274, spacing <= 1 m in model-local metric coordinates, bilinearly interpolated from raster pixel centers. Terrain heights are expressed relative to the NHN value at the current model anchor and existing local reference -2.02575, not as ellipsoidal heights. No GCG2016 grid is installed; never set anchor ellipsoidHeightM to 40.95. Obtain the grid and verify provider datum separately for absolute conversion. https://cdn.proj.org/de_bkg_gcg2016.tif (download attempt failed due to DNS in the development environment). ETRS89 and WGS84 treated as coincident for this local visual comparison; not survey-grade.

## Results

Using the actual R8 FPC, 536 boundary sample positions from all 16 masks compared to DGM1, anchored relatively (the same anchor height on both surfaces). Seven masks (1,9,11,12,13,14,16) have all sampled absolute discrepancies <= 0.5 m. Nine have at least one greater discrepancy. Largest positive residual 4.145 m; minimum -0.494 m. Elevated hall floors can legitimately be above bare earth, and different acquisition dates can contribute. These residuals are not evidence that buildings are wrong. Local seam acceptance is still a live-provider decision, not inferred from this comparison. The independent reference mesh has 78,638 vertices, 156,156 triangles and 32,767 FPC BVH nodes. It must NOT be installed as `local_reference.glb` or `local_reference.fpc`: that would remove buildings. Preview overlay can exhibit intersections and is for diagnosis only.

## Installation / preview

Extract patch into current FPVManager root with R8 installed. Start `python -m http.server 8765`; open `http://localhost:8765/tool/scenery/r9/index.html`. Toggle scan/DGM and scan opacity to view ground. This isolated page uses a common arbitrary vertical reference and hides the globe. No flight or terrain clipping, no external provider. Browser rendering untested here. `dgm_comparison.png` and `seam_comparison.csv` are available directly. `report.json` describes source, hashes and results. `dgm_reference.glb` and `dgm_reference.fpc` are separate reference assets for the next transition mesh workflow.

## Reproduction and tests

Requires Python numpy, scipy, rasterio, pyproj, matplotlib and existing `tool/scenery/build_collision.py`; Node for actual R8 sweep sampling. From repo root:

```
python tool/scenery/r9/prepare_dgm.py /path/to/dgm_33417-5815.tif
node --test tool/scenery/r9/test_reference.cjs tool/scenery/test_ruedersdorf_r8.cjs
```

Executed: 26/26 tests passed (4 new reference tests + 22 R8 tests), including 121 swept-sphere ground contacts on the independent DGM FPC; exact unique triangle parity and vertex equality between generated GLB and FPC also verified separately with Python. No native builds or browser test. No new production replacement geometry activated.

## Next work

Use the measured raster field to distinguish bare earth, elevated building floors and shoreline. Segment genuine scan ground vs. structure/vegetation; protect all floors and openings from global warping. Construct matched continuous transition strips between selected scan ground edges and DGM, with appropriate vertical datum, then regenerate a unified visual/collision asset, certify unions and test horizontal boundary crossings before turning on clipping. The supplied reference mesh is a ground field, not yet a seamless transition or a guarantee of safe flight.
