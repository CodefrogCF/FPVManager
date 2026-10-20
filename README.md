# FPVManager

FPVManager is a local-first Flutter prototype for exploring Swiss FPV flying
locations. Its current core is an interactive CesiumJS globe with swisstopo
terrain and imagery, official Swiss UAS geographical zones, and a personal
spot library stored with Drift/SQLite.

## Current functionality

- Switzerland-centered globe, camera navigation and satellite/topographic/relief styles.
- UAS overlay with visibility, fill opacity, raw zone attributes and download metadata.
- Saved map preferences, separate spot visibility and configurable overlay order.
- Terrain elevation queries with explicit WGS84 ellipsoidal heights, optional
  Swiss LN02 conversion and a local AGL height calculator.
- WGS84/LV95 coordinate services with documented reference systems.
- Local spot creation, editing and deletion with coordinates and notes.
- Spot photos with local thumbnails, image normalization and a zoomable gallery.
- Opt-in device location in the editor, with manual coordinates as fallback.
- Saved spot markers, a selection panel and terrain-aware camera focus.
- Search, categories, tags, favorites and spot details with paged list queries.
- Drone profiles with dimensions, propellers, propulsion and power/performance
  parameters, with measured/estimated/unspecified provenance per value.
- Database schema snapshots and tested v1/v2/v3/v4/v5-to-v6 migrations.
- Typed local repositories for spots, drones, batteries, radio equipment,
  flight plans/waypoints and map preferences, with transactional route storage.

The [local data layer](docs/local_data.md) provides the storage foundation for future
features. Battery/radio screens, weather, route planning, simulation,
backups and offline map downloads are not implemented yet. See the
[issue backlog](https://github.com/CodefrogCF/FPVManager/issues).

See [spot photos and location](docs/spot_photos_and_location.md) for image limits,
local storage, foreground permissions and platform requirements.
See [spot search and classification](docs/spot_search.md) for filter semantics,
pagination and large-collection validation.
See [drone profiles](docs/drone_profiles.md) for units, provenance, migration and
the distinction between recording parameters and calculating flight performance.
See [map preferences](docs/map_preferences.md) and the
[foundation issue audit](docs/foundation_issue_audit.md) for the remaining #2/#4/#5/#7/#8 work.
The [privacy and permission policy](docs/privacy_and_permissions.md) records
location consent, personal storage and current external request data flows.

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

Online imagery, terrain and UAS downloads require network access. CesiumJS 1.145.0
is bundled locally, including workers, textures and Wasm. The renderer can start
with an offline grid/ellipsoid when online map resources are unavailable. See
[asset packaging](docs/cesium_assets.md) and [bridge protocol](docs/globe_bridge.md).

## Quality checks and builds

```sh
dart run tool/check_format.dart
python tool/vendor_cesium.py --check
python -m unittest discover -s test/tool -p 'test_*.py'
node --test test/js/globe_bridge.test.cjs
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub --no-web-resources-cdn
python tool/prepare_sqlite_android.py
flutter build apk --debug --no-pub
```

The format helper checks hand-written Dart in `lib/`, `test/`, `integration_test/` and `tool/`, without
changing files. Generated `.g.dart` and `test/generated_migrations/` sources are
excluded. Format edited files with `dart format <path>`.

Vendor verification needs Python 3.9+; JavaScript receiver tests need Node.js 20+.
The native integration test can be run with
`flutter test integration_test/globe_runtime_test.dart -d <android-device-id>`.
It uses an offline renderer and local fixtures without opening the personal database.

GitHub Actions runs on pull requests, pushes to `main` and manual dispatches.
Formatting, analysis and tests gate the separate Web and Android build jobs.
Build success does not verify interactive WebGL/WebView behavior or device
performance. The Android job creates a debug APK; production signing and release
validation are separate work.
Android CI prepares hash-verified SQLite libraries with bounded download retries;
see [the reported failure and verification procedure](docs/android_sqlite_downloads.md).

## Project structure

| Path | Responsibility |
|---|---|
| `lib/main.dart` | App theme, home screen, navigation and spot synchronization |
| `lib/core/database/` | Drift tables, repository contracts, persistence and migrations |
| `lib/core/models/` | Typed route, waypoint-height and preference models |
| `lib/core/geo/` | Coordinate and explicit height-reference services |
| `lib/core/osint/` | Provider contract and dataset provenance |
| `lib/features/globe/` | Map controller, platform views and layer controls |
| `lib/features/airspace/` | Swiss UAS data adapter |
| `lib/features/spots/` | Spot repository and editing/list UI |
| `web/globe.html`, `web/globe.js`, `web/globe_bridge.js` | Renderer entry point, Cesium commands and bridge protocol |
| `test/` | Unit, migration and widget regression tests |
| `drift_schemas/` | Versioned database schema snapshots |

See [architecture](docs/architecture.md) for data flow, selection semantics and
known boundaries, and [contributing](CONTRIBUTING.md) for coding conventions,
database generation and the branching workflow.

## Data and limitations

Personal records are stored locally, without a mandatory account or an
automatic publishing feature. Maps and external data services still perform
network requests. The terrain dialog sends the selected coordinates and elevation
to swisstopo REFRAME only when Swiss LN02 conversion is explicitly requested.

UAS download time is a retrieval timestamp, not proof of official validity or
completeness. Zone attributes currently remain largely unclassified. Terrain
ellipsoid heights, Swiss LN02 heights and AGL offsets remain explicitly separate;
see [coordinates and heights](docs/coordinates_and_heights.md) for transformations,
sources and limitations. Do not treat this prototype as flight authorization or a
verified obstacle-clearance calculation.

Map credits are displayed directly beside the map, including SWISSIMAGE's
third-party notices and an explicit terrain source. The checked endpoints,
attribution evidence and applicable service terms are recorded in
[map sources and attribution](docs/map_sources_and_attribution.md) (#8).
The broader source/dependency and release documentation audit remains #44;
current privacy/permission behavior is documented above.

Terrain initialization and runtime tile/network failures show a labelled flat
fallback with disabled height queries. **Retry terrain** reconnects within the
existing viewer, preserving camera and layer settings. See
[terrain failures and recovery](docs/terrain_recovery.md) for deadlines,
late-response protection, synthetic HTTP fault tests and device-check limits (#7).

OSINT adapters expose source/licence metadata, explicit cache and update status,
typed failures and optional official validity. The Layer dialog retains the
provenance of the data actually displayed after a failed update. Imagery and
terrain factories live behind a replaceable adapter boundary. See
[provider contracts and provenance](docs/osint_providers.md) (#4).

**Battery inventory** in the navigation drawer manages individual packs and
reusable type templates, explicit V/mAh/Wh/g specifications, optional manual
condition/availability records and assignments to saved drones/flight plans.
See [battery inventory](docs/battery_inventory.md) for template semantics,
schema-v6 migration and validation (#14).
