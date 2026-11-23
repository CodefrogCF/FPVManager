# Rüdersdorf R34 — southern courtyard building restored (NOT the green-roof site)

## Diagnosis

The site model's local axes are **+X = south, +Y = east**. R29 restored the
original 2022 photogrammetry at **negative X** (the separate former green-roof
area). R30 subsequently removed **2,328 triangles** from the older R25
production building at **positive X**, by mistakenly treating it as an overlay
on the *northern* building. These are two different footprints.

The missing R25 geometry was still contained in the R33.1 GLB as complete
POSITION, NORMAL and TEXCOORD_0 arrays; R30 had unreferenced it only by
shortening the four triangle index buffers. R34 safely reinstates the **exact
original R25 indices**, rather than guessing new building geometry or importing
the discontinued R27 green-roof replacement.

The restored southern building is local X **4.29…5.48** (south), local Y
**0.99…2.76** (east). Its geometry remains an **unsurveyed approximation**:
1,104 brick, 636 concrete, 276 roof and 312 steel triangles. Upper skylights
and actual entrance apertures remain open and collidable geometry elsewhere is
preserved. The model currently retains R30's 15 certified terrain rectangles:
we do not automatically certify a building roof as bare-earth terrain.

R34 changes **only** local_reference.glb, local_reference.fpc and the matching
collision SHA-256 in catalog.json; it does not modify web/globe.js or the
user's **−16.90 m BKG-beta height offset**. The 15 original RAWscan meshes,
R26 southwest ruin building, model coordinates, scale and rotation are untouched.

## Apply

Unzip the R34 patch over the **R33.1** project (overwrite existing files).
Generate a BKG test APK with:

```powershell
powershell -ExecutionPolicy Bypass -File tool/build_android_ruedersdorf_test.ps1
```

To regenerate these assets from an unmodified R33.1 GLB and the installed
project tooling:

```bash
PYTHONPATH=tool/scenery python tool/scenery/restore_ruedersdorf_r34_south_building.py \
  /path/to/R33.1/local_reference.glb \
  web/assets/scenery/local_reference.glb \
  web/assets/scenery/local_reference.fpc \
  tool/scenery/r34/refinement_R34_report.json
```

This script requires the exact R33.1 input checksum
`0c3d1c5627d525ce1b8daa1117da7e573c8d9d3f97eb72e3bdd49d54072205ef`.
It will intentionally refuse any different input. It does not require the
original RAWscan package or the prior R29 GLB to rebuild.

## Verification

- 947 / 947 JavaScript tests passed (`node --test test/js/*.test.cjs`).
- R34 Python checks passed (`python tool/scenery/test_ruedersdorf_r34.py`).
- Output collision file SHA-256:
  `c2d2bc56e148997bfa5cf16b063fe6e14de6482d01ec8cf5b9f18a5bd41033d8`.
- `FPC` geometry matches the GLB (976,109 unique collision triangles).
- North scanned building / deleted low green roof are checked independently.
- The new geometry has **not yet been visually checked on the S25 Ultra**.
