# Developer tools

Run commands from the repository root. Tools are grouped by purpose; executable
scripts/configuration do not belong directly in `tool/`. Use each script's usage
text for optional arguments. Python tooling dependencies are pinned in
[data/offline_region_requirements.txt](data/offline_region_requirements.txt).

| Directory | Purpose |
|---|---|
| `quality/` | Formatting, documentation/layout, localization, release and obstacle checks |
| `build/` | Cesium vendoring, offline Web snapshot, SQLite Android preparation and opt-in test APK |
| `data/` | Battery/obstacle/tree/height/forest generation, tunnel catalogue and offline-region preparation |
| `benchmarks/` | Synthetic performance runners, reports, comparison, physics scenarios and dated reference data |
| `browser/` | Local globe/smoke server, offline preparation and live 3D Tiles checks |
| `maintenance/` | Checksum-protected ZIP cleanup and legacy migration helpers |
| `scenery/` | Source-dependent scenery processing, collision generation, [conversion pipeline](../docs/developer/scenery_conversion.md) and local workbench |

## Routine validation

Run the canonical [pre-push checks](../CONTRIBUTING.md#checks-and-builds).

## Generation and packaging

```sh
python tool/data/generate_battery_chemistries.py --check
python tool/data/build_ch_tunnel_index.py --verify
python tool/build/prepare_sqlite_android.py
python tool/build/prepare_offline_web.py
python tool/quality/check_release_artifacts.py --web build/web
```

Preparation/build commands retain their prerequisites and download behavior; the
validation commands do not implicitly launch them. See
[Contributing](../CONTRIBUTING.md), [Cesium](../docs/developer/cesium_assets.md),
[tunnel index](../docs/developer/offline_swiss_tunnel_index.md) and
[performance](../docs/developer/performance.md). Preserve source-reproduction data and provenance.

The optional live provider check is separate from deterministic CI. It streams
official Brandenburg tiles in headless Chromium without packaging provider assets:

```sh
node tool/browser/check_scenery_tileset.cjs
```

Use `--url=`, `--longitude=` and `--latitude=` for another permitted HTTPS provider.
See [Scenery providers](../docs/developer/scenery.md#external-3d-tiles-providers).

## After extracting a changed-files ZIP

```sh
python tool/maintenance/cleanup_repository.py
python tool/maintenance/cleanup_repository.py --apply
```

The default is a preview. The versioned
[cleanup plan](maintenance/repository_cleanup.json) contains exact old paths,
known hashes and verified replacements. Only matching old files are removed;
locally edited content is retained. Empty obsolete subdirectories are removed
only when empty. The older migration helpers are retained for previous overlay
formats; the current plan is applied with `cleanup_repository.py`.
