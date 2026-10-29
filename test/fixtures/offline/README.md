`dem-small.tif`, `palette-small.tif` and `jpeg-small.tif` are synthetic 64 × 64
EPSG:2056 rasters for on-device decoding: LZW Float32 heights with NoData,
LZW palette colours with NoData and JPEG/YCbCr with shared JPEG tables. They
contain no downloaded imagery. Tests compare known values in bounded windows.

Quantized-mesh regression fixture: western level-zero tile and layer metadata
from the official swisstopo terrain service, retrieved 2026-10-25.

- Tile: https://3d.geo.admin.ch/ch.swisstopo.terrain.3d/v1/20250101/0/0/0.terrain?v=1.43646.0
- Metadata: https://3d.geo.admin.ch/ch.swisstopo.terrain.3d/v1/layer.json
- Attribution: © swisstopo. [Free geodata terms](https://www.swisstopo.admin.ch/en/terms-of-use-free-geodata-and-geoservices).

The tiny root mesh includes availability extension 4. The offline renderer must
remove that extension while preserving the height geometry and other extensions.

`prepared.fpvregion` is a synthetic package produced by
`test/tool/test_prepare_offline_region.py` (constant 1,000 m LN02 terrain and a
palette test image, with the bundled height grid). Its source URLs identify test
fixtures, not real downloads. It is never installed as application data or used
as a live/offline fallback. Regenerate with `FPV_WRITE_OFFLINE_FIXTURE=1` when
running that test with `tool/offline_region_requirements.txt` installed.
