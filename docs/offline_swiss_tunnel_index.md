# Swiss tunnel catalogue and build pipeline

The app bundles a generated Swiss OSM tunnel index in
`web/data/tunnels/ch_tunnels_v1.json`. The committed asset is a real, nonempty
catalogue, not the builder's placeholder. Verify it before packaging a release:

```sh
python tool/build_ch_tunnel_index.py --verify
```

## Rebuild the catalogue

This is a developer/release step. The app does not download a country-wide PBF
onto a user's phone.

```sh
python -m pip install "osmium>=4,<5"
python tool/build_ch_tunnel_index.py --download
python tool/build_ch_tunnel_index.py --verify
flutter pub get --enforce-lockfile
flutter build apk --release
```

`--download` reads the Geofabrik Switzerland PBF and caches it under the developer's
home `.cache/fpvmanager`. The PBF is not included in the app; only the compact JSON
index is bundled through `pubspec.yaml`. A cached PBF is reused. For a new extract,
provide a newly downloaded file with `--pbf path/to/switzerland-latest.osm.pbf` or
explicitly replace the cached file before rebuilding. Download size varies.

The Windows builder chooses a supported disk-backed `sparse_file_array` location
index, falling back to `flex_mem`. If disk-backed indexing fails locally, retry
with `--location-index=flex_mem` and adequate free RAM. The manual **Prepare Swiss
tunnel offline index** CI workflow can also produce an artifact for release
preparation; it is not an automatic app update.

## Data and runtime behavior

- Only road/rail ways explicitly tagged as tunnel or covered corridors are
  included; ordinary roads are not inferred to be tunnels. Connected road/bridge
  approaches are retained as portal-height evidence. Source coordinates, way IDs,
  types and the catalogue's snapshot metadata remain available.
- The spatial index returns at most 160 candidate routes for a viewport and marks
  truncated results incomplete. A valid catalogue, including an empty local query,
  avoids live tunnel lookup. Missing, invalid or placeholder assets are reported;
  the legacy online fallback may then query external services.
- Render budgets govern resident automatic tubes separately from discovery:
  Quality 96, Balanced 56, Performance 16 and Compatibility 10. Unsupported height
  or geometry evidence can produce fewer models; a positive axis count does not
  guarantee a visible or flyable tube.
- Connected ways, original portal anchors and underground junctions stay linked
  through long-tunnel handoffs. A rendered window has at most 96 sections and
  2.2 km length; adjacent windows overlap. The active corridor remains available
  while its replacement is prepared. Source catalogue coverage is not a survey.
- The user enables models under **Karte & Ansicht → 3D & Licht → 3D-Tunnel
  automatisch laden**. Catalogue search, model import and diagnostics are under
  **Tunnelwerkzeuge** and **Tunnelstatus & Daten**. The retired surface-axis overlay
  and schematic surface exploration switches are no longer exposed.

Terrain-derived approaches, bridge profiles and slope-aware cutouts improve
simulated entrances. Widths, heights, portal positions and interiors remain
estimated. Exact collision against a generated tube is not a real clearance
measurement. See [architecture](architecture.md) and [renderer fixtures](cesium_assets.md)
for the visual/collision tests; [performance](performance.md) describes bounded
background work and device-measurement limits.

## Validation and provenance

```sh
python -m unittest discover -s test/tool -p "test_build_ch_tunnel_index.py" -v
node --test test/js/*.test.cjs
flutter analyze --no-pub
flutter test --no-pub
```

The source is the [Geofabrik Switzerland extract](https://download.geofabrik.de/europe/switzerland.html)
of OpenStreetMap. Preserve `web/data/tunnels/ODBL_NOTICE.txt`: data © OpenStreetMap
contributors, extract © Geofabrik, derived database under ODbL 1.0. This dataset is
separate from Apache-2.0 application code and from independently licensed swisstopo
products. See [map sources and attribution](map_sources_and_attribution.md).

`snapshotDateUtc` records the local source-file modification time. It is not a
certified survey or per-tunnel revision date. Rebuilding from an updated extract
can change coverage; record the catalogue shipped with each release.
