# Rüdersdorf local GLB / CesiumJS visual smoke test

**Purpose:** test whether the locally supplied Sketchfab/Zenodo GLB actually loads
and renders using FPVManager's **bundled CesiumJS 1.145** runtime.

**License:** original `Abandoned Chemical plant Rüdersdorf – RAWscan` by
Andrea Spognetta (spogna), **Creative Commons Attribution–NonCommercial**.
Do not copy the GLB into a public repository, release, web host or
commercial distribution without checking all applicable rights.

1. Copy the locally downloaded `d2464ec36fb644f28e904e5517f1da64.glb`
   into `tool/scenery/local_reference.glb` **only in your local checkout**.
2. From the FPVManager repository root, start a local HTTP server:
   `python -m http.server 8765`.
3. Open `http://localhost:8765/tool/scenery/cesium_glb_probe.html` in a
   WebGL-enabled browser. The status overlay shows loading errors or a
   successful model load. The probe waits up to 45 seconds for `Model.ready`
   before accessing `boundingSphere`; an arbitrary fixed wait was insufficient.
4. To change the tentative placement, use `?lat=52.484197&lon=13.789789&height=80&scale=1`.
   **Height 80, scale 1 and the provided geographic point are illustrative**,
   not surveyed or calibrated. The globe is deliberately hidden so that bad
   geolocation cannot be mistaken for a verified real-world fit.
5. For an actual on-globe integration test, survey at least 2–3 reference
   points, calibrate scale / model rotation / height, enable appropriate terrain,
   and measure model loading and framerate on Windows, S22 and S25 Ultra.

The prototype intentionally **does not** load remote imagery, assign physics
collision geometry, or create reusable scenery resources. It is a diagnostic
for Issue #144, not the complete Scenery Manager planned in #145+.

**Status (2026-11-21):** synthetic inspector tests pass; the user-supplied GLB
passed MD5 and offline geometry inspection. Actual local browser WebGL
rendering was not executed: the evaluation environment blocked Chromium
navigation to its local HTTP endpoint (`ERR_BLOCKED_BY_ADMINISTRATOR`).
