# Developer guide

This is the main entry point for maintainers and contributors. For app operation,
see the [user guide](user_guide.md). The [contribution guidelines](../CONTRIBUTING.md)
contain the canonical repository checks and release requirements; this guide
explains where to start and where implementation contracts live.

## Prerequisites and local setup

Use the Flutter/Dart versions pinned by the project README/CI (currently
Flutter 3.47.0 stable / Dart 3.13.0). Tool checks additionally require
Python 3.9+ and Node.js 20+. Android requires an Android SDK and Java 17.

```sh
flutter doctor -v
flutter pub get --enforce-lockfile
flutter run -d chrome
```

For a physical Android device, use `flutter devices`, then
`flutter run -d <device-id>`. For device performance runs use **profile** mode;
synthetic Node.js timings must not be described as Android/Windows FPS.

## Where the code lives

| Area | Location / contract |
|---|---|
| Flutter screens and controllers | `lib/features/` |
| Shared models, repository/data contracts | `lib/core/` |
| Cesium globe / JS flight and HUD modules | `web/globe.html`, `web/globe.js`, `web/*.js` |
| App ↔ renderer protocol | [Globe bridge](developer/globe_bridge.md) |
| SQLite / Drift and migrations | [Architecture](developer/architecture.md), `lib/core/database/` |
| Battery chemistry source of truth | `assets/battery/chemistries.json` |
| Cesium assets and local browser harnesses | [Cesium assets](developer/cesium_assets.md) |
| Georeferenced tunnel import | [Offline tunnel index](developer/offline_swiss_tunnel_index.md) |
| Geometry/coordinates conventions | [Coordinates and heights](user/coordinates_and_heights.md) |

Always distinguish WGS84 ellipsoid heights, AGL clearance and Swiss
vertical references. Treat tile/service responses and app↔WebView messages as
untrusted external input. Preserve data provenance, especially for airspace,
RF estimates and unsupported terrain coverage.

## Architecture and implementation references

- [Architecture and storage](developer/architecture.md): Flutter modules, database,
  provider integrations and offline assets.
- [App ↔ Cesium bridge](developer/globe_bridge.md): commands, message lifecycle,
  error handling and renderer contracts.
- [Radio/LoS and failsafe model](developer/radio_and_rescue.md): live 50-km terrain
  sampler, uncertainty, separate RC/video models and GPS Rescue handoff.
- [Battery/energy model](developer/battery_model.md): generated chemistry catalog,
  equations, current-limit diagnostics and schema v11/v12 compatibility.
- [Simulation, collisions and terrain](developer/simulation_and_collision.md):
  thrust-based manual flight, missing rendered tiles, visual-only LoS geometry
  and analog overlay behavior.
- [Flight physics architecture](developer/flight_physics_architecture.md) and
  [Advanced physics validation](developer/advanced_physics_validation.md): reproducible
  reference scenarios, local telemetry comparison and target-device release gate.
- [Performance measurement](developer/performance.md): repeatable scenarios,
  instrumentation, benchmarks, measurement interpretation and limitations.

Historical implementation notes from individual increments are retained under
[archive](archive/README.md), but **must not** be treated as the current API
contract or current default settings.

## Changes and generated sources

### Flutter localization

Edit the `.arb` files under `lib/l10n/`, not generated messages. Regenerate with:

```sh
flutter gen-l10n
```

Check both German and English content, including tests that create isolated
`MaterialApp` widget trees: these must register the generated `FpvStrings`
localization delegate. Browser and native test harnesses are separate.

### Drift schema

For schema changes, increment `schemaVersion`, implement the migration,
preserve earlier snapshots/fixtures, and regenerate the Dart code:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Validate upgrades from older supported databases, battery/drone field
preservation and backup restore. Do not hand-edit `.g.dart` output or generated
migration snapshots.

### Shared battery chemistry

Edit `assets/battery/chemistries.json` and regenerate both Dart and JavaScript
artifacts; do not update one platform's numbers alone:

```sh
python tool/generate_battery_chemistries.py
python tool/generate_battery_chemistries.py --check
```

### Browser/Cesium

Use the [asset/renderer checks](developer/cesium_assets.md), and keep simulation-only
HUD visualizations separate from collision, link assessment and failsafe state.
Check the dedicated browser iframe/modal input tests after dialog or overlay
changes.

## Recommended validation before a PR

```sh
dart run tool/check_format.dart
python tool/check_docs.py
python tool/vendor_cesium.py --check
python -m unittest discover -s test/tool -p 'test_*.py'
node --test test/js/*.test.cjs
node tool/performance_suite.cjs --check
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --platform chrome test/web/globe_input_test.dart test/web/offline_storage_test.dart
```

The Chrome test requires a supported Chrome runtime. Also validate Android
and Windows manually where renderer timing, input focus, GPU loading, location,
permissions, backup or 3D contact behavior changed. See [Contributing](../CONTRIBUTING.md)
for CI builds, release artifacts and platform-specific checks.

## Contributing to documentation

- Put **how to operate a feature** in `docs/user/` or the main `user_guide.md`.
- Put **current internal contracts/model limitations** in `docs/developer/`.
- Keep the repository overview short: [README](../README.md) → [documentation](README.md)
  → the appropriate audience guide.
- Keep older historical notes in `docs/archive/`, clearly marked as superseded.
- Update both the originating and destination links when moving a page.
- Run `python tool/check_docs.py`; the [documentation migration instructions](README.md#applying-a-documentation-update-zip)
  explain how to remove retired files safely after a ZIP delivery.
