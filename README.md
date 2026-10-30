# FPVManager

FPVManager is a local-first Flutter prototype for exploring Swiss FPV flying
locations on a CesiumJS globe. Android and Web are supported.

## Features

- Swiss 3D terrain, satellite/topographic/relief maps, optional roads and independent place/street labels.
- Opt-in current location with accuracy/freshness and foreground following; combined coordinate, place and street search.
- Official UAS zones with structured details, overlapping-zone selection and spatial spot/route checks.
- Independent aviation obstacle imagery and selectable cached vectors, with optional scaled mast/crane models.
- Optional streamed buildings/vegetation, real sun/moon positions and fixed route/simulation times.
- Local spots with a continuous lazy list, photos, tags and favorites; drone, battery and radio/video profiles.
- Editable activity profiles (FPV, hiking, cycling, photography, family and exploration), custom workspaces and map shortcuts; portable profile import/export and inclusion in personal backups. All tools remain accessible from every profile.
- Grouped app settings and bundled Guides & Help, with contextual shortcuts.
- Multiple waypoint routes with configurable heights, speeds, terrain profiles and energy/reserve estimates; GeoJSON/GPX import/export.
- First-person ground inspection and GPS, Angle and Acro flight simulation using touch, keyboard or controllers; configurable rates, throttle neutral point, camera angle and flight HUD.
- Simulated flight recording converted to planning routes, with optional live radio line-of-sight screening.
- Android road navigation with voice guidance, smooth GPS follow camera, compass, rerouting and independent 3D environment settings; destination search, traffic/counter data and optional TMC location-table import.
- Aircraft snapshots, aerodromes/heliports, wildfire information and an independent SLF avalanche bulletin map with freshness information.
- MeteoSwiss/Open-Meteo forecasts, weather comparisons, 3D wind/rain overlays and optional wind influence in the flight simulator.
- Local preflight checklists/templates, terrain LOS/Fresnel analysis, obstacle buffers, route constraints and telemetry calibration.
- On-device offline region preparation up to 25 km radius; Web additionally supports the whole of Switzerland. Choose detail, terrain and topographic/satellite/neutral-relief imagery; mark the centre on the globe.
- Portable personal-data backups with optional password protection and validated restoration; optional prepared-map package import and laptop preparation.

Personal records stay in local storage. Online maps and data services require
network access. This prototype does not determine permission to fly or verify
obstacle clearance. The flight simulation uses approximate movement
and terrain contact only. Offline preparation uses official download assets;
source gaps and the selected detail limit coverage. Large downloads need free
storage and the app kept open. Browser storage can be evicted. Public snapshots
retain their source dates; live information needs a connection and verification.

## Run from source

Use **Flutter 3.47.0 stable / Dart 3.13.0**, matching
[CI](.github/workflows/ci.yml). Web needs WebGL; Android needs the Android SDK
and Java 17.

```sh
flutter doctor -v
flutter pub get --enforce-lockfile
flutter run -d chrome
```

For Android, accept SDK licenses with `flutter doctor --android-licenses`, find
your device with `flutter devices`, then run `flutter run -d <device-id>`.
An iOS runner is not included.

## Documentation

| For | Guide |
|---|---|
| Users | [Using FPVManager](docs/user_guide.md) |
| Users and developers | [Coordinates and heights](docs/coordinates_and_heights.md) |
| Users and developers | [Privacy and permissions](docs/privacy_and_permissions.md) |
| Users and developers | [Map sources and attribution](docs/map_sources_and_attribution.md) |
| Users and developers | [Weather sources, controls and limits](docs/weather.md) |
| Users and developers | [Preflight, signal analysis and telemetry CSV](docs/preflight.md) |
| Users and developers | [Mobility, OSINT sources and access limits](docs/mobility_osint.md) |
| Developers | [Contributing, checks and builds](CONTRIBUTING.md) |
| Developers | [Architecture and storage](docs/architecture.md) |
| Developers | [Globe bridge](docs/globe_bridge.md) |
| Developers | [Bundled renderer assets](docs/cesium_assets.md) |

Report bugs and discuss features in the
[issue tracker](https://github.com/CodefrogCF/FPVManager/issues).
