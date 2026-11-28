# FPVManager

**FPVManager** is an open-source, local-first application for FPV flight preparation, Swiss map exploration and flight simulation. It combines a CesiumJS 3D globe with offline personal records, terrain and airspace information, route tools, and configurable simulation physics.

**Current source version:** `0.20.1+58` (published downloads may differ).

[Project showcase](https://youtu.be/S1XSDf-Mf1A) · [Latest releases](https://github.com/CodefrogCF/FPVManager/releases/latest)

## What you can do

- **Explore and plan:** Swiss terrain, imagery, airspace restrictions, published obstacles, saved spots, editable routes, route playback, location and equipment libraries.
- **Prepare:** terrain-dependent checks, weather/radar, environmental conditions and data-source status, including explicit unknown or incomplete coverage.
- **Simulate:** GPS, Angle and Acro modes; selectable Advanced/Legacy physics; touch, keyboard and supported external controls; recordings, modelled battery/propulsion behavior, wind, collisions, modeled RC/video links and optional GPS Rescue.
- **Custom scenery:** import, align and stream local models or external 3D Tiles; configure collision and RF materials, exchange licensed `.fpvscenery` packages.
- **Work offline:** keep personal records locally, export portable backups and prepare selected public map data for offline use.
- **Use optional information layers:** public transport, road navigation, POIs, EV charging, shared mobility and other observation sources, subject to the availability of each provider.

The **Rüdersdorf real-world scenery** is an **experimental test scene** based on third-party photogrammetry. Its BKG 3D-Beta terrain/building integration is separately gated; it must not be treated as surveyed clearance or validated radio planning. See [Rüdersdorf for users](docs/user/scenery.md) and [technical reference](docs/developer/scenery.md).

## Get started

**Install:** Download an appropriate platform build from [GitHub Releases](https://github.com/CodefrogCF/FPVManager/releases/latest). The exact platforms available depend on the release.

**From source:** Use the Flutter/Dart version pinned for this repository (Flutter **3.47.0**, Dart **3.13.0**), a working Flutter SDK and the platform tooling. Web requires WebGL; Android requires the Android SDK and Java 17.

```sh
flutter doctor -v
flutter pub get --enforce-lockfile
flutter run -d chrome
```

For Android, run `flutter devices` and `flutter run -d <device-id>`. Platform-specific builds, test commands, required tools and release checks are documented in [Contributing](CONTRIBUTING.md).

## Documentation

| Audience | Start here |
|---|---|
| App users | [User handbook](docs/user_guide.md) · [German quick start](docs/user/schnellstart.de.md) |
| Developers and contributors | [Developer guide](docs/developer_guide.md) · [Contributing](CONTRIBUTING.md) |
| All topics and limitations | [Documentation index](docs/README.md) |

The app includes **Settings → Help** and optional **Developer options → Performance overlay**. Feature details are maintained in the audience-specific guides; historical changes belong in the [Changelog](CHANGELOG.md).

## Safety and data

FPVManager is a planning and visualization tool, **not** an aviation authorization or a substitute for current official information and real-world obstacle surveys. Simulated RF quality, route estimates and approximate collision meshes are not measured telemetry. Terrain or source gaps remain unknown rather than being treated as safe clearance.

Personal data are stored locally; optional internet functions contact third-party providers. See [Privacy policy](PRIVACY.md).

## Licenses

Original FPVManager code and documentation are [Apache-2.0](LICENSE). See [NOTICE](NOTICE) and [Third-party notices](THIRD_PARTY_NOTICES.md) for the rights of bundled software, external datasets and imported models. The Rüdersdorf scan has a separate **CC BY-NC 4.0** license: it is **not** covered by Apache-2.0 and may not be used commercially without appropriate permission.
