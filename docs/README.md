# FPVManager documentation

Choose **one maintained entry point for your audience**. Feature guides live under `docs/user/`, implementation references under `docs/developer/`. The [Changelog](../CHANGELOG.md) is the single historical change record. Old increment-specific `README_R*.md` files are not current documentation.

## Users

Start with the [User handbook](user_guide.md) or the [Deutscher Schnellstart](user/schnellstart.de.md).

| Task | Guide |
|---|---|
| Preparation, routes, signal/terrain analysis | [Preflight and analysis](user/preflight.md) |
| GPS/Angle/Acro, recording, modeled RF and GPS Rescue | [Flight simulation](user/flight_simulation.md) |
| Battery, motor and ESC configuration | [Battery and power](user/battery_and_power.md) |
| Terrain heights, WGS84, AGL and Swiss datums | [Coordinates and heights](user/coordinates_and_heights.md) |
| Forecasts, wind and radar | [Weather](user/weather.md) |
| Ground navigation, mobility and other data | [Mobility and information layers](user/mobility_osint.md) |
| Experimental Rüdersdorf scene and ground comparison | [Real-world scenery](user/scenery.md) |
| Personal data, permissions and external requests | [Privacy and permissions](user/privacy_and_permissions.md) |
| Map providers, credits and third-party rights | [Map sources](user/map_sources_and_attribution.md) |

## Developers

Start with the [Developer guide](developer_guide.md) and [Contributing](../CONTRIBUTING.md).

| Topic | Reference |
|---|---|
| Flutter structure, persistence, external data and backups | [Architecture](developer/architecture.md) |
| Flutter ↔ Cesium messages and lifecycle | [Globe bridge](developer/globe_bridge.md) |
| Real-world scenery, raw scan, BKG, heights and collision | [3D scenery and georeferencing](developer/scenery.md) |
| Simulated RC/video, terrain LoS and Rescue | [Radio and Rescue](developer/radio_and_rescue.md) |
| Source battery chemistry and current limitations | [Battery model](developer/battery_model.md) |
| Motor/propeller model and hardware limitations | [Motor and propeller](developer/motor_propeller_model.md) |
| Simulation / collision architecture | [Simulation and collision](developer/simulation_and_collision.md) |
| Frame-independent Advanced physics | [Flight physics architecture](developer/flight_physics_architecture.md) |
| Individual advanced aerodynamic and control mechanisms | [Advanced physics references](developer/advanced/README.md) |
| Device-specific validation and benchmark evidence | [Advanced physics validation](developer/advanced_physics_validation.md) |
| Local Cesium resources and browser harnesses | [Cesium assets](developer/cesium_assets.md) |
| Diagnostics, benchmarks and performance claims | [Performance](developer/performance.md) |
| Swiss offline tunnel index and data provenance | [Tunnel catalogue](developer/offline_swiss_tunnel_index.md) |

## Other canonical records

[Privacy policy / Datenschutzerklärung](../PRIVACY.md) · [Third-party notices](../THIRD_PARTY_NOTICES.md) · [License](../LICENSE) · [Changelog](../CHANGELOG.md) · [Showcase credits](showcase_credits.txt)

The JSON fixtures in `docs/performance/` and `docs/examples/` are reference/test data, not current app results. The app includes **Settings → Help / Einstellungen → Hilfe** for in-app guidance.

## Documentation maintenance and ZIP installation

Keep user instructions in `docs/user/`, developer contracts in `docs/developer/`, and cross-audience entry points only in this index and the two main handbooks. Do not copy complete feature descriptions into multiple pages. Update links and run `python tool/check_docs.py` before merging.

**Changed-files ZIPs cannot delete older files.** After applying a documentation patch to an existing checkout, inspect the checksum-gated removal plan and then delete **unchanged** obsolete files:

```sh
python tool/clean_obsolete_docs.py
python tool/clean_obsolete_docs.py --apply
python tool/check_docs.py
```

`docs/obsolete_files.json` records precise paths and known hashes. The cleanup script preserves locally modified files; review any reported differences yourself. In a Git checkout, also verify `git status` before committing.
