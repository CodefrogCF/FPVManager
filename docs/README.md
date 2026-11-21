# FPVManager documentation

Choose a guide by **audience and task**, rather than by implementation date.

## For app users

Start with the [English user handbook](user_guide.md) or the
[German quick start / Deutscher Schnellstart](user/schnellstart.de.md).

| Task | Maintained guide |
|---|---|
| Start flying, control the drone, interpret terrain coverage, configure radio and Rescue | [Flight simulation, radio and GPS Rescue](user/flight_simulation.md) |
| Enter LiPo/Li-ion and other batteries, C-ratings, ESC and motor limits | [Battery, motor and ESC profiles](user/battery_and_power.md) |
| Work with LV95, WGS84, AGL or other Swiss height references | [Coordinates and heights](user/coordinates_and_heights.md) |
| Prepare flights, check routes and inspect signal paths | [Preflight and analysis](user/preflight.md) |
| Use weather/radar forecasts and observations | [Weather](user/weather.md) |
| Use navigation, other routes and OSINT information layers | [Mobility and OSINT](user/mobility_osint.md) |
| Understand stored data, location and online requests | [Privacy and permissions](user/privacy_and_permissions.md) |
| Verify external map-data rights and on-map credits | [Map sources and attribution](user/map_sources_and_attribution.md) |

FPVManager also provides **Einstellungen → Hilfe** with in-app guidance.
The [privacy policy](../PRIVACY.md) and [showcase credits](showcase_credits.txt)
remain separate from the feature manuals.

## For developers and contributors

Start with [Developer guide](developer_guide.md). It links the
[contribution workflow](../CONTRIBUTING.md) and the maintained technical
references:

| Subject | Maintained reference |
|---|---|
| Code organization, storage, providers and backup | [Architecture](developer/architecture.md) |
| Flutter ↔ Cesium protocol and commands | [Globe bridge](developer/globe_bridge.md) |
| 50-km adaptive terrain LoS, RF profiles, simulated RC failsafe, GPS Rescue | [Radio and Rescue model](developer/radio_and_rescue.md) |
| Chemistry source of truth, power equations, current warnings and migrations | [Battery/energy model](developer/battery_model.md) |
| Flight physics, collision exclusions, missing tiles and analog HUD | [Simulation and collision model](developer/simulation_and_collision.md) |
| Advanced v0.19 model boundaries, fixed-step architecture, capture command | [Flight physics architecture](developer/flight_physics_architecture.md) |
| Synthetic tests, S25 Ultra observations, Windows follow-up and Blackbox comparison | [Advanced physics validation and provisional close-out](developer/advanced_physics_validation.md) |
| Local Cesium assets and browser test harnesses | [Cesium assets](developer/cesium_assets.md) |
| CPU benchmarks, device comparisons and diagnostics | [Performance](developer/performance.md) |
| Preparation and interpretation of the offline Swiss tunnel catalogue | [Tunnel index](developer/offline_swiss_tunnel_index.md) |

## Reference material and history

- [Performance fixture data](performance/scenarios.json) and dated JSON reports
  are **observations and test inputs**, not measurements of the current release.
- [Example tunnel mesh](examples/tunnel_georeferenced_trimesh_v2_demo.json)
  provides a developer fixture, not verified terrain geometry.
- [Archived implementation notes](archive/README.md) preserve earlier design
  decisions and rollout details. They can describe superseded limits such as
  6-km live LoS and earlier GPS Rescue behavior. **Do not use them as the
  current guide or current feature specification.**
- [Change history](../CHANGELOG.md), [license](../LICENSE) and
  [third-party notices](../THIRD_PARTY_NOTICES.md) are separate project records.

## Applying a documentation update ZIP

A ZIP with only added/modified files cannot remove older tracked files by
itself. After extracting the documentation update, run:

```sh
python tool/cleanup_legacy_docs.py                # preview only
python tool/cleanup_legacy_docs.py --apply       # remove unchanged retired copies
python tool/check_docs.py
```

`docs/obsolete_files.json` lists each retired path, its successor, and the
original SHA-256. The cleanup utility removes **only copies whose bytes still
match that checksum**; locally edited notes are kept and reported. Reorganizing
docs does not require running the cleanup command to use the new guides.

For a normal Git checkout, review `git status` before committing any file
moves/deletions, and keep edits to historical files if they are still needed.
