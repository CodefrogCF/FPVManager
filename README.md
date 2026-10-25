# FPVManager

FPVManager is a local-first Flutter prototype for exploring Swiss FPV flying
locations on a CesiumJS globe. Android and Web are supported.

## Features

- Swiss terrain, satellite/topographic/relief maps and official UAS zone data.
- Horizontal UAS-zone intersection checks for saved spots and route segments.
- Independent Swiss obstacle imagery and selectable, locally cached 3D obstacles.
- Local spots with photos, search, tags and favorites.
- Portable local backups with optional password protection and checked restoration.
- Region-based caching of supported swisstopo maps and terrain for offline use.
- Drone profiles, battery inventory and radio/video equipment profiles.
- First-person terrain inspection and map-based editing of multiple local routes.
- Local GPS, Angle and Acro flight exploration with shared touch, keyboard and controller input.
- Adjustable FPV camera tilt, including an in-flight control.
- Driving routes to spots/parking, optional traffic and aircraft snapshots, aerodrome/heliport and wildfire layers.
- Configurable waypoint heights/airspeeds, drone and battery assignments.
- Local preflight checklists/templates, terrain LOS/Fresnel screening and telemetry model calibration.
- Sampled terrain profiles, distance/duration analysis and configurable energy/reserve estimates.
- Advisory obstacle buffers, route constraint checks and local GeoJSON/GPX route import/export.
- MeteoSwiss/Open-Meteo forecasts, configurable weather comparisons and sampled wind/rain overlays.

Personal records stay in local storage. Online maps and data services require
network access. This prototype does not determine permission to fly or verify
obstacle clearance. The flight simulation uses approximate movement
and terrain contact only. Offline regions cache viewed tiles and may remain
incomplete; live data needs a connection and separate verification.

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
