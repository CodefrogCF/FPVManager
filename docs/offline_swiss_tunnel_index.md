# Swiss tunnel axes: offline build pipeline

**Status:** JS reader, viewport spatial index, fallback control and regression
suite implemented. The included `web/data/tunnels/ch_tunnels_v1.json` is an
**explicit placeholder**, not a geographical dataset. **Build the real file
before testing an APK**; otherwise the app attempts legacy live lookup and
reports that no bundled dataset is available when offline.

## Build once, then bundle for every platform

This is a **developer/release preparation step**, not a download on user
phones. In Windows PowerShell, from the FPVManager project root:

```powershell
py -3 -m pip install "osmium>=4,<5"
py -3 tool/build_ch_tunnel_index.py --download
py -3 tool/build_ch_tunnel_index.py --verify
flutter pub get
flutter build apk --release
```

`--download` obtains the Swiss OSM PBF from Geofabrik (roughly **523 MB** as of
November 2026) and writes it to the developer's home `.cache/fpvmanager`.
The PBF is **not** packaged in the application. The generated compact index is
written to `web/data/tunnels/ch_tunnels_v1.json` and is bundled automatically
using `pubspec.yaml`. The file is also served through the existing
manifest-restricted loopback asset server on Android, iOS and Windows.

On macOS/Linux use `python3 -m pip install 'osmium>=4,<5'` followed by
`python3 tool/build_ch_tunnel_index.py --download`. Alternatively pass
`--pbf path/to/switzerland-latest.osm.pbf` if a file already exists.
On Windows the builder automatically checks which osmium node-location indexes
are compiled into the installed wheel. It prefers a disk-backed
`sparse_file_array` (temporary files are deleted afterwards), otherwise
uses the in-memory `flex_mem` index. It does not require `sparse_mmap_array`.
If disk-backed indexing causes a local error, rerun with
`--location-index=flex_mem` (requires sufficient free RAM). The already-downloaded
PBF under `%USERPROFILE%\.cache\fpvmanager` will be reused.

For a fresh source extract, delete the cached `.osm.pbf` or supply a new PBF;
`--download` does not silently redownload a cached extract.

If local internet downloads are inconvenient, run the manual GitHub Actions
workflow **Prepare Swiss tunnel offline index**, download its artifact and
place `web/data/tunnels/ch_tunnels_v1.json` in the project before building.
This is a manual developer action, **not** a background service or automatic
app update.

## App behavior

- Enabled schematic tunnels query the **bundled** index first, offline.
- A valid index, even with zero tunnels in an area, does not call Overpass.
- For each viewport, only indexed candidate routes are considered; at most
  48 route segments are passed to the existing Cesium pipeline and at most
  six tunnel meshes are generated near the camera.
- Coordinates, OSM way IDs and route types remain in the indexed dataset.
  Long ways are split into continuous parts without dropping vertices.
- Rendering, WebView reload and camera motion do not cause new online tunnel
  requests while a valid local index is present.
- If the index is missing or still a placeholder, the app **reports the
  error** and may attempt the legacy online fallback; no fake routes appear.
- The terrain and collision logic is unchanged in this patch. **A detected
  axis is not proof of a visible, navigable portal.** Test geometry separately.

## Validation

```powershell
python -m unittest discover -s test/tool -p "test_build_ch_tunnel_index.py" -v
node --test test/js/*.test.cjs
flutter analyze --no-pub
flutter test
```

To test on the Galaxy S25 Ultra, prepare and install a **new release APK**
after the index has been generated. At a well-mapped tunnel position, inspect
`Tunnelachsen gefunden` and `Automatisch dargestellte schematische Tunnel`.
The first count confirms successful catalog lookup; the second confirms
successful 3D preparation. A zero second count after a positive first count
indicates a remaining terrain, clipping, mesh or elevation problem, not a
missing source dataset.

## Provenance, completeness, limitations and license

The initial reproducible source is the full-country [Geofabrik Switzerland
OSM PBF](https://download.geofabrik.de/europe/switzerland.html). Only
road/rail ways explicitly tagged `tunnel=yes`, `building_passage`,
`avalanche_protector` or `covered=yes` are included. Other ways are **not**
inferred to be tunnels. This is an OSM-derived dataset; coverage is not
complete or equivalent to swissTLM3D. The asset must retain attribution:
© OpenStreetMap contributors; extract © Geofabrik; derived data under ODbL 1.0.
See `web/data/tunnels/ODBL_NOTICE.txt`. Keep this derived database separable
from independently licensed swisstopo datasets.

The recorded `snapshotDateUtc` in this first version is based on the local
source-file modification time; it is **not a certified survey or revision
timestamp** for individual tunnels. Mesh width, height, altitudes and
portals are schematic and only for simulation, never safety clearance.
