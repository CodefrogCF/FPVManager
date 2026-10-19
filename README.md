# FPVManager

FPVManager is a local-first Flutter prototype for exploring Swiss FPV flying
locations. Its current core is an interactive CesiumJS globe with swisstopo
terrain and imagery, official Swiss UAS geographical zones, and a personal
spot library stored with Drift/SQLite.

## Current functionality

- Switzerland-centered globe, camera navigation and satellite/topographic/relief styles.
- UAS overlay with visibility, fill opacity, raw zone attributes and download metadata.
- Terrain elevation queries and WGS84/LV95 coordinate services.
- Local spot creation, editing and deletion with coordinates and notes.
- Saved spot markers, a selection panel and terrain-aware camera focus.
- Database schema snapshots and a tested v1-to-v2 migration.

Drone, battery, radio-equipment and flight-plan tables are foundations for future
features. Equipment screens, weather, route planning, simulation, spot photos/GPS,
backups and offline map downloads are not implemented yet. See the
[issue backlog](https://github.com/CodefrogCF/FPVManager/issues).

## Development setup

Use **Flutter 3.47.0 stable / Dart 3.13.0**, matching the version pinned in
[CI](.github/workflows/ci.yml). Run these commands from the repository root:

```sh
flutter doctor -v
flutter pub get --enforce-lockfile
flutter run -d chrome
```

Web requires a browser with WebGL support. For Android, install the Android SDK,
accept its licenses with `flutter doctor --android-licenses`, and select a device
from `flutter devices` before running `flutter run -d <device-id>`. CI uses Java 17;
the Android source/bytecode target is also Java 17. Check local Android Studio
setups with `flutter doctor -v`.

Android and Web are the current build targets. The native view contains an iOS
code path, but an iOS runner and compatibility validation are still pending (#2).
Other native platforms show a globe fallback message.

Online imagery, terrain and UAS downloads require network access. CesiumJS itself
currently loads from jsDelivr; local bundling is tracked in #49.

## Quality checks and builds

```sh
dart run tool/check_format.dart
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub
flutter build apk --debug --no-pub
```

The format helper checks hand-written Dart in `lib/`, `test/` and `tool/`, without
changing files. Generated `.g.dart` and `test/generated_migrations/` sources are
excluded. Format edited files with `dart format <path>`.

GitHub Actions runs on pull requests, pushes to `main` and manual dispatches.
Formatting, analysis and tests gate the separate Web and Android build jobs.
Build success does not verify interactive WebGL/WebView behavior or device
performance. The Android job creates a debug APK; production signing and release
validation are separate work.

## Project structure

| Path | Responsibility |
|---|---|
| `lib/main.dart` | App theme, home screen, navigation and spot synchronization |
| `lib/core/database/` | Drift tables, persistence and migrations |
| `lib/core/geo/` | Coordinate and explicit height-reference services |
| `lib/core/osint/` | Provider contract and dataset provenance |
| `lib/features/globe/` | Map controller, platform views and layer controls |
| `lib/features/airspace/` | Swiss UAS data adapter |
| `lib/features/spots/` | Spot repository and editing/list UI |
| `web/globe.html` | Cesium renderer and the JavaScript side of the bridge |
| `test/` | Unit, migration and widget regression tests |
| `drift_schemas/` | Versioned database schema snapshots |

See [architecture](docs/architecture.md) for data flow, selection semantics and
known boundaries, and [contributing](CONTRIBUTING.md) for coding conventions,
database generation and the branching workflow.

## Data and limitations

Personal spot records are stored locally, without a mandatory account or an
automatic publishing feature. Maps and external data services still perform
network requests. REFRAME service code sends supplied coordinates and elevations
when invoked; it is not yet wired into the terrain information dialog.

UAS download time is a retrieval timestamp, not proof of official validity or
completeness. Zone attributes currently remain largely unclassified. Terrain
height reference verification and end-to-end AGL/absolute-height handling remain
open in #10. Do not treat this prototype as flight authorization or a verified
obstacle-clearance calculation.

Map credits are displayed in the renderer. A complete source/license inventory
and privacy policy remain tracked under #5, #8 and #44.
