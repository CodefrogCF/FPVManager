# Documentation

Start with the [user handbook](user_guide.md), [German quick start](user/schnellstart.de.md)
or [developer guide](developer_guide.md). The [changelog](../CHANGELOG.md) records
changes; individual revision and delivery reports are not maintained guides.

| Task | Reference |
|---|---|
| Prepare spots, routes and analysis | [Preflight](user/preflight.md) |
| Fly the simulator, configure RF and GPS Rescue | [Flight simulation](user/flight_simulation.md) |
| Configure aircraft and batteries | [Battery and power](user/battery_and_power.md) |
| Understand height references | [Coordinates and heights](user/coordinates_and_heights.md) |
| Use weather, wind and radar | [Weather](user/weather.md) |
| Navigate and inspect information layers | [Mobility and OSINT](user/mobility_osint.md) |
| Use the experimental local scene | [Scenery](user/scenery.md) |
| Review personal data and external requests | [Privacy and permissions](user/privacy_and_permissions.md) |
| Check map sources and rights | [Map sources](user/map_sources_and_attribution.md) |

Developer contracts are linked from the [developer guide](developer_guide.md).
Commands and tool groups are indexed in [tool/README.md](../tool/README.md).
Dated measurements live with [benchmark references](../tool/benchmarks/reference/);
they are evidence for their recorded build/device, not current performance claims.
The [tunnel example](examples/tunnel_georeferenced_trimesh_v2_demo.json) is format data.

[Privacy policy](../PRIVACY.md) · [Third-party notices](../THIRD_PARTY_NOTICES.md) ·
[License](../LICENSE) · [Showcase credits](showcase_credits.txt)

## Applying a changed-files ZIP

Extract the ZIP into the project, then preview and apply its exact cleanup plan:

```sh
python tool/maintenance/cleanup_repository.py
python tool/maintenance/cleanup_repository.py --apply
python tool/quality/check_docs.py
python tool/quality/check_repository_layout.py
```

The plan removes only checksum-matched obsolete paths after their replacements
are present. Locally edited files are retained and reported. Git users should
also inspect the resulting diff. No recursive directory deletion is used.
