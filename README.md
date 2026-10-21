# FPVManager

FPVManager is a local-first Flutter prototype for exploring Swiss FPV flying
locations on a CesiumJS globe. Android and Web are supported.

## Features

- Swiss terrain, satellite/topographic/relief maps and official UAS zone data.
- Local spots with photos, search, tags and favorites.
- Drone profiles, battery inventory and radio/video equipment profiles.
- First-person terrain inspection and map-based editing of multiple local routes.
- Optional 3D route previews at 30 m above terrain at each waypoint.

Personal records stay in local storage. Online maps and data services require
network access. This prototype does not determine permission to fly or verify
obstacle clearance. Weather, simulation, backups and offline map downloads are
not implemented.

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
| Developers | [Contributing, checks and builds](CONTRIBUTING.md) |
| Developers | [Architecture and storage](docs/architecture.md) |
| Developers | [Globe bridge](docs/globe_bridge.md) |
| Developers | [Bundled renderer assets](docs/cesium_assets.md) |

Report bugs and discuss features in the
[issue tracker](https://github.com/CodefrogCF/FPVManager/issues).
