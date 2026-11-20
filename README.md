# FPVManager

FPVManager is a local-first Flutter app for Swiss map exploration, FPV planning
and flight simulation. Personal records stay on the device; online providers
supply maps, forecasts and other public information.

[Showcase Video on Youtube](https://youtu.be/S1XSDf-Mf1A)

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

## Download

[Releases](https://github.com/CodefrogCF/FPVManager/releases/latest)

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

FPVManager documentation is organized by audience:

- **App users:** [User handbook](docs/user_guide.md) (English),
  [Schnellstart](docs/user/schnellstart.de.md) (Deutsch),
  [flight simulation and GPS Rescue](docs/user/flight_simulation.md),
  and [battery/equipment profiles](docs/user/battery_and_power.md).
- **Developers:** [Developer guide](docs/developer_guide.md),
  [Contributing](CONTRIBUTING.md),
  [architecture](docs/developer/architecture.md),
  and [performance validation](docs/developer/performance.md).

The [documentation index](docs/README.md) has all maintained guides, privacy,
map data references and instructions for cleaning up retired docs after ZIP
updates. Historical implementation notes are kept in an
[archive](docs/archive/README.md) so superseded limits are not mistaken for
current behavior. The app also bundles **Settings → Help** for offline reading.

[Privacy policy · Datenschutzerklärung](PRIVACY.md)

## License

FPVManager's original code and documentation are licensed under
[Apache-2.0](LICENSE). See [NOTICE](NOTICE) and
[third-party notices](THIRD_PARTY_NOTICES.md). Bundled libraries, map/OSM data,
other provider datasets and imported personal content retain their own rights
and conditions; the project licence does not replace them.
