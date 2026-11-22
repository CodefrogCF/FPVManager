# R27.x – terrain placement in normal Android releases

## Diagnosis

The local Rüdersdorf scenery has a calibrated `groundReferenceLocalUp`.
`FPVSceneryManager.terrainAligned` computes a model height from an actual
terrain sample at the scene anchor. Previously `web/globe.js` handed the
terrain provider to the scenery manager **only** while BKG 3D-Beta was active.
A normal release without `FPV_REGIONAL_3D_TEST` therefore used the base
`ellipsoidHeightM` of 32.25 m, allowing regular 3D terrain to cover most of the
plant even if the GLB was packaged and loaded.

The provider key now follows **any ready real terrain provider**. It changes
when the terrain provider changes; stale samples are ignored by the scenery
manager. If no reliable terrain sample is available, the existing fail-safe
behavior is preserved. The georeferenced model and FPC assets are unchanged.

## BKG LoD2 in experimental release APKs

The BKG 3D-Beta service is intentionally opt-in and identified as test-only.
An ordinary `flutter build apk --release` omits the `regional3DTest=1` runtime
parameter and therefore does not request that experimental LoD2 layer.

For a **private test APK** with BKG LoD2 enabled, run from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File tool/build_android_ruedersdorf_test.ps1
```

Equivalent build command:

```powershell
flutter build apk --release --dart-define=FPV_REGIONAL_3D_TEST=true
python tool/check_release_artifacts.py --apk build/app/outputs/flutter-apk/app-release.apk
```

The script verifies that the local GLB, FPC and R11 underlay are present before
building, and that the resulting APK includes byte-for-byte matching assets.
Enable the **Gebäude** layer in `3D & Licht` when using the BKG test mode.
Do **not** silently enable the experimental BKG service for publicly
redistributed release APKs without confirming the service terms.

## Device verification

1. Build/install the test APK and open Rüdersdorf.
2. In **Reale 3D-Umgebungen**, check `ready` and collision state. The scene
   should no longer be buried; both chimneys and buildings should be visible.
3. With **Gebäude** enabled, verify that BKG LoD2 tiles are present outside
   the replacement area. They may be masked inside it when the local scenery
   is ready, as intended.
4. Compare the `effectiveAlignment.ellipsoidHeightM` from the scenery status
   with the old 32.25 m catalog anchor. For a sampled elevated terrain it
   should differ in the direction of the height correction.

Terrain samples are not surveyed elevation guarantees. This patch has only
source-level and automated test verification, not a real-device run.
