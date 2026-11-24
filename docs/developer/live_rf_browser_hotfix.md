# Live RF browser timer regression — corrective hotfix

Date: 2026-11-24. This hotfix applies to the current source containing the
previous live-RF reliability patch. The original checkout was accessed only
for reading. Apply the repository-relative replacement files from the ZIP,
then rebuild the app so the corrected JavaScript assets enter the APK/build.

## Confirmed cause

The previous patch introduced default timer facades in both live-radio
sampling and the detailed terrain tile cache:

```js
timers = {setTimeout, clearTimeout};
timers.setTimeout(callback, delay);
```

In a browser, these functions are native `Window` methods. Calling a stored
reference as a method of the plain `timers` object changes its receiver.
Chromium throws `TypeError: Illegal invocation`. The live sampler reports
`SAMPLING_ERROR` before it can return a valid terrain profile. The tile cache
can also mistake this programming error for a tile failure and unnecessarily
enter its native sampling fallback. This is a regression introduced by the
previous patch, not evidence of missing terrain or excessive flight distance.

The former Node tests used Node timers or injected fake timers, which accept
different receivers. They therefore passed without exercising the actual
browser host-function constraint. The screenshots' immediate failures with
13/25 samples motivated this additional runtime coverage.

The BKG `CC BY 4.0` attribution in the screenshots belongs to the raster
overlay and alone does not establish that the separate BKG beta terrain is
active. Its existing vertical-datum restriction remains unchanged.

## Correction

Both production files now use small closures for the default timer facade:

```js
timers = {
    setTimeout: (fn, ms) => setTimeout(fn, ms),
    clearTimeout: id => clearTimeout(id),
};
```

These wrappers call native timers in their global context and preserve the
existing dependency injection for deterministic clocks. No timeout, sampling
resolution, terrain provider, RF calculation, failsafe policy or flight
physics is changed by this hotfix.

## Regression evidence

The real-browser fixture loads bundled Cesium, the actual terrain manager,
live-radio adapter, tile cache and JSON bridge. Only terrain data is analytic
and local; the browser timers are native. It verifies:

- Native Window timers reject the old plain-object receiver.
- The terrain manager becomes ready and 13/25-point profiles cross the bridge.
- Completed sampling releases the active request slot.
- A new coordinate reuses the detailed terrain tile.
- A valid RF observation reaches the consumer.
- A standalone tile cache returns its precise detailed height without an
  unnecessary fallback.

Serving the unmodified previous JavaScript from the read-only checkout through
this fixture **fails** with `SAMPLING_ERROR: Illegal invocation`. Serving the
corrected files **passes all nine checks**, with zero fallback calls. The run
used Headless Chrome 158 on Windows x64. Two additional Node regressions use
receiver-sensitive host shims and exercise both timer functions independently.

```powershell
node --test test/js/live_radio_browser.test.cjs
node --test test/js/live_radio.test.cjs test/js/live_terrain_tile_cache.test.cjs
```

The browser test auto-detects Chrome/Edge/Chromium; `FPV_CHROME` can specify a
binary. It explicitly skips if no compatible browser is installed. On this
machine it ran and passed; it was not skipped. To reproduce the expected
failure against a prior source tree without modifying it, set
`FPV_RF_RUNTIME_SOURCE_ROOT` to that tree for the browser-test process.

## Files and delivery

- Production: `web/features/signal/live_radio.js` and
  `web/features/signal/live_terrain_tile_cache.js`.
- Receiver regressions: their two existing `test/js/` test files.
- Real runtime regression: new `test/js/live_radio_browser.test.cjs` and
  `test/web/live_radio_runtime_smoke.html`.
- This report and a delivery manifest with baseline/replacement SHA-256 hashes.

Final validation on Windows x64, Flutter 3.47.0 / Dart 3.13.0:

| Check | Result |
|---|---|
| `flutter analyze` | Passed; no issues found. |
| `flutter test` | Passed; 999 tests. |
| `node --test test/js/*.test.cjs` | Passed; 981 tests, zero skipped. |
| Scoped sampler/tile-cache tests | Passed; 42 tests. |
| Native Chromium runtime / JSON bridge | Passed; all nine checks. |
| Same browser fixture against the prior JavaScript | Expected failure reproduced: `SAMPLING_ERROR: Illegal invocation`. |

The full validation details are recorded in the delivery manifest. All 1,552
files represented by the current original-source snapshot matched their
baseline SHA-256 hashes after investigation. Generated dependency/build files,
temporary browser profiles and raw test logs are excluded from the ZIP.

This validates the browser integration failure and correction. It is not a
new Android device flight test or a real-provider performance measurement.
