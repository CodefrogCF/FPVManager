# Developer guide

Use Flutter **3.47.0** / Dart **3.13.0**, Node.js **20+**, Python **3.12** (CI version) and the
platform SDK. Android uses Java 17. See [Contributing](../CONTRIBUTING.md) for CI
and release checks; [tool/README.md](../tool/README.md) lists maintenance commands.

```sh
flutter doctor -v
flutter pub get --enforce-lockfile
flutter run -d chrome
```

Run on a physical device with `flutter run -d <device-id>`. Measure device
performance in profile mode; Node timings are not device FPS.

## Repository map

| Area | Location / reference |
|---|---|
| Flutter features and shared models | `lib/features/`, `lib/core/` |
| Persistence, migrations, providers and backups | [Architecture](developer/architecture.md) |
| Renderer modules and protocol | `web/core/`, `web/features/`, [globe bridge](developer/globe_bridge.md) |
| Advanced/Legacy physics, controls and collision | [Simulation](developer/simulation_and_collision.md) |
| Live LoS, modeled RC/video and Rescue | [Radio and Rescue](developer/radio_and_rescue.md) |
| Battery chemistry and electrical limits | [Battery model](developer/battery_model.md) |
| Motor/propeller assumptions | [Propulsion model](developer/motor_propeller_model.md) |
| Rüdersdorf, BKG and source geometry | [Scenery](developer/scenery.md) |
| Offline Cesium resources | [Cesium assets](developer/cesium_assets.md) |
| Offline tunnel catalogue | [Tunnel index](developer/offline_swiss_tunnel_index.md) |
| Reproducible measurements and device gates | [Performance](developer/performance.md) |
| Tests and grouped scripts | `test/`, [tool index](../tool/README.md) |

## Development rules

- Edit `.arb` sources and run `flutter gen-l10n`; isolated widget tests must
  register the generated `FpvStrings` delegates. Regenerate legacy browser
  translations with `python tool/quality/check_localizations.py --write`.
- For database changes, add migrations and snapshots, preserve old data and
  backup compatibility, then run
  `dart run build_runner build --delete-conflicting-outputs`.
- Battery chemistry originates in `assets/battery/chemistries.json`; regenerate
  both platforms with `python tool/data/generate_battery_chemistries.py`.
- Keep WGS84 ellipsoid, AGL and regional vertical references distinct. Missing
  terrain, incomplete coverage and unsupported datums remain explicit.
- Validate external service data and WebView messages. Keep credentials, consent,
  provider caches and local performance output out of portable exports.
- Keep current behavior in the canonical feature guide and history in the
  [changelog](../CHANGELOG.md). Update all callers when moving a tool.

## Internal diagnostics

Public builds keep implementation diagnostics hidden. A private development
build can enable them with:

```sh
flutter run --dart-define=FPV_DEVELOPER_MENUS=true
```

This defaults to false and is independent of `FPV_REGIONAL_3D_TEST`. User-facing
warnings, source credits and licensing remain visible. See [scenery](developer/scenery.md)
for the separate opt-in BKG/Rüdersdorf test build.

## Validation

```sh
python tool/quality/check_docs.py
python tool/quality/check_repository_layout.py
python -m unittest discover -s test/tool -p 'test_*.py'
node --test test/js/*.test.cjs
node tool/benchmarks/performance_suite.cjs --check
flutter analyze
flutter test
```

Follow the platform build and browser-input checks in [Contributing](../CONTRIBUTING.md)
when affected. A source ZIP or synthetic benchmark is not a device release test.
