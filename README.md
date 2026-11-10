# FPVManager

FPVManager is a local-first Flutter app for Swiss map exploration, FPV planning
and flight simulation. Personal records stay on the device; online providers
supply maps, forecasts and other public information.

## Main features

- A CesiumJS globe with Swiss terrain, imagery, 3D buildings, vegetation,
  schematic tunnels and bridge supports.
- Local places and photos, flight routes, walking/cycling routes and equipment
  libraries, with import/export and portable backups.
- Official UAS zones and published aviation obstacles, plus independent outdoor,
  traffic, aircraft, weather, radar and observation layers.
- Ground inspection and GPS, Angle and Acro flight simulation with touch,
  keyboard or external controllers, flight recording and optional wind.
- Android road navigation, offline-region preparation, and activity profiles
  that keep frequently used tools together.

**Karte & Ansicht** is the shared map-settings hub. Less-used controls and source
metadata are expandable; active errors and data limitations remain visible.
The **Quellen** control opens the map's full attribution information.

The map and simulator are planning/visualization tools. Approximate terrain,
model geometry and sampled checks do not establish permission to fly or obstacle
clearance. Retrieval time, source validity and data completeness remain separate.

## Run from source

Use **Flutter 3.47.0 stable / Dart 3.13.0**, matching the build configuration.
Web needs WebGL; Android needs the Android SDK and Java 17.

```sh
flutter doctor -v
flutter pub get --enforce-lockfile
flutter run -d chrome
```

For Android, accept SDK licences with `flutter doctor --android-licenses`, find
the device with `flutter devices`, then run `flutter run -d <device-id>`.
Automated builds cover Android and Web; other platform runners need their own
validation. Build, test and contribution instructions are in [CONTRIBUTING](CONTRIBUTING.md).

## Documentation

The [documentation overview](docs/README.md) links the current guides and explains
how to clean up retired documents after applying a changes ZIP.

| Task | Guide |
|---|---|
| Use menus, maps, records, simulation and offline tools | [User guide](docs/user_guide.md) |
| Understand coordinates, AGL and Swiss height references | [Coordinates and heights](docs/coordinates_and_heights.md) |
| Understand local storage, permissions and external requests | [Privacy and permissions](docs/privacy_and_permissions.md) |
| Check map-data terms and attribution | [Sources and attribution](docs/map_sources_and_attribution.md) |
| Use forecasts, radar, wind and measured observations | [Weather](docs/weather.md) |
| Use checklists, radio-path checks and telemetry | [Preflight and signal analysis](docs/preflight.md) |
| Use routing, navigation and supplementary information layers | [Navigation and OSINT](docs/mobility_osint.md) |
| Build, test or extend the app | [Contributing](CONTRIBUTING.md), [architecture](docs/architecture.md) and [performance checks](docs/performance.md) |

The app also bundles **Einstellungen → Hilfe** for offline reading.

## License

FPVManager's original code and documentation are licensed under
[Apache-2.0](LICENSE). See [NOTICE](NOTICE) and
[third-party notices](THIRD_PARTY_NOTICES.md). Bundled libraries, map/OSM data,
other provider datasets and imported personal content retain their own rights
and conditions; the project licence does not replace them.
