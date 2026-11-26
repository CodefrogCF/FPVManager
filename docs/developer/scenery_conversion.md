# External geospatial and photogrammetry conversion

The developer CLI at [tool/scenery/conversion](../../tool/scenery/conversion)
creates a complete [scenery package v1](scenery_package.md) from trusted local
files. No reconstruction or Python dependencies enter the mobile app. No
provider streaming service or cache is used, and the tool never downloads
source data or PROJ grids automatically. Do not use this developer tool as a
public upload service: the native geospatial/image/mesh parsers process trusted
inputs only. The existing app package validator remains the import boundary.

## Install and reproduce the synthetic example

Python 3.13 is the reference interpreter; a separate virtual environment is
recommended. The tested Python library versions are in
[requirements.txt](../../tool/scenery/conversion/requirements.txt). Install on
Windows from the repository root:

```powershell
python -m venv .venv-scenery
.\.venv-scenery\Scripts\python.exe -m pip install -r tool/scenery/conversion/requirements.txt
.\.venv-scenery\Scripts\python.exe tool/scenery/conversion/convert.py tool/scenery/conversion/examples/open_wall.json open-wall.fpvscenery
```

On Linux replace the interpreter path with `.venv-scenery/bin/python`.
The output must not already exist and its parent directory must exist (use a
local hardlink-capable filesystem, e.g. NTFS). Both the synthetic CityGML file
and recipe are CC0-1.0 test data. They describe a 10 m by 6 m wall with a 2 m
by 2 m aperture, not a real building. The wall is geographically anchored
near longitude 9°, latitude 47.85334°. Expected surface area is approximately
56 m², with eight triangles; the projected UTM scale is correctly transformed
to local metres. The small reference archive in
[test fixtures](../../test/fixtures/scenery) is an independently checked-in
output for the Dart import test. Repeated conversion within the same library
and data environment is deterministic. Different GDAL/PROJ/GEOS builds can
change the tessellation or transformed coordinates; no cross-platform
bit-identical promise is made. Keep the recipe, source files, dataset edition,
source SHA-256, dependency versions and datum grid versions for reproduction.

In FPVManager: Manage scenery → Import scenery package → select file → review
license → confirm → enable after checking placement. Test a collision at the
wall and passage through the opening. The reference frame is absolute WGS84
ellipsoid, not a terrain-relative height. The base terrain/imagery still
requires its own available source; package import does not create a basemap.

## Library choices

| Library / tool | Purpose and decision |
| --- | --- |
| NumPy / existing FPC builder | Local mesh arrays, exact attribute welding, median BVH, existing FPC1 format |
| pyproj / PROJ | Strict horizontal and compound CRS transformations; require installed best-operation grids |
| lxml / Shapely 2.1+ | No-network XML and constrained polygon triangulation, including concave outlines and holes |
| Rasterio / GDAL, Pillow | Georeferenced DEM and orthophoto pixels, texture resampling, embedded PNG/JPEG |
| laspy + lazrs, SciPy | Read LAS/LAZ, bounded classified-ground triangulation |
| trimesh | Static mesh import with scene transforms and base-color UVs |
| Blender, MeshLab, CloudCompare | Optional external mesh cleanup, LOD authoring, interiors and review |
| COLMAP, Meshroom, OpenDroneMap | Optional external reconstruction, not mobile or CLI runtime dependencies |

PDAL is appropriate for large point-cloud clipping, classification and
reprojection before this tool. This initial tool uses laspy to avoid a hard PDAL
runtime dependency. The converter deliberately does not implement a generic
point-cloud-to-building or photogrammetric reconstruction algorithm.

## Recipe

A JSON recipe defines one package. Start from
[open_wall.json](../../tool/scenery/conversion/examples/open_wall.json).
`id`, `name`, `anchor`, `source`, `redistributionAllowed` and `visual` are
required; optional `description`, positive `revision`, `lods`, `collision`,
`replacementEnu` extend it. `anchor` is `[longitude, latitude, WGS84 ellipsoid
height in metres]`. An arbitrary but nearby ellipsoidal anchor is valid: source
coordinates are transformed to absolute ECEF before subtracting the anchor.
It is not an instruction to place source vertices at that height.

Every input object has `type`, `path` (relative to recipe directory or local
absolute path), `crs`, `vertical`, `author`, `license`, `attribution`, and an
explicit `redistributionAllowed: true`. The package has its own aggregate
source author/license/attribution and optional safe HTTPS URL. Individual
credits and CRS/vertical declarations are appended to the attribution; too
long an attribution fails rather than dropping credit. Ensure all licenses
are compatible with the actual derivative and redistribution. A true flag is
not proof of permission. Keep download/caching-restricted sources outside
complete packages and use the existing reference-only export in the app.

`visual` is a list of compatible data sources merged into GLB primitives in
a single common frame; `lods` maps `low`, `balanced`, `high` to independent
lists in the same frame; `collision` is a list of lists, each inner list
produces a separate FPC1 collider. Visual and physical sources are entirely
independent. For an interior, include a separate local mesh for the interior
in the appropriate visual and collision lists. Do not merge an uncut original
wall with a replacement wall containing a new opening: both would remain
physical. The converter does not automatically boolean-subtract or deduplicate
coincident surfaces from distinct source meshes.

### Coordinate references and control points

All projected data stays float64 through the source-to-WGS84-to-ECEF-to-local
ENU transform; float32 only after subtracting the anchor. The local basis
matches the current Cesium renderer (normal at the ECEF anchor). Geometry is
quantized to a binary millimetre lattice (1/1024 m) before export to eliminate
submillimetre noise and ensure stable GLB bound encoding; at long local
baselines float32 spacing is larger. The package format has no runtime
coordinate transformations beyond the anchor and identity rotation/scale.

- `vertical: "ellipsoidal"`: `crs` is the source horizontal CRS; the third
  coordinate must already be **WGS84 ellipsoid metres**, not arbitrary source
  ellipsoid heights or AMSL. `axisOrder: "xyz"` is easting/northing/height or
  lon/lat/height for GML, `"yxz"` explicitly swaps the first two coordinates.
- `vertical: "compound"`: use an explicit compound CRS, for instance
  `EPSG:25833+7837` for ETRS89/UTM 33N + DHHN2016 height. A true 3D geographic
  CRS is also accepted. Install the appropriate grid files locally in PROJ's
  search path. Missing best-operation grids, unknown or ballpark transforms
  fail rather than silently interpreting orthometric heights as ellipsoid.
  PROJ network access remains disabled. Verify datum edition, units and
  operation accuracy with independent surveyed control points.
- `crs: "LOCAL_ENU"`, `vertical: "local"`: explicitly set
  `alreadyAligned: true` for known metre coordinates relative to the anchor,
  or supply `controls` with at least three non-collinear pairs of
  `{"local":[x,y,z], "wgs84":[lon,lat,h]}`. A proper 3D similarity transform
  estimates scale, rotation and translation, rejecting RMS residual >0.5 m.
  Control coordinates are in the source's selected axis convention after any
  mesh axis conversion. RMS is fit error, not independent absolute accuracy.
  Include additional surveyed check points and review their errors manually.

Imported local meshes may specify `axisConvention: "enu"` (default, source
x=east, y=north, z=up), `"cesium_gltf"` (source x=north, y=up, z=east), or
`"y_up_east"` (source x=east, y=up, z=south). Choose this based on source
metadata, not filename. Generated GLB coordinates are `(north, up, east)`
so Cesium's default axis correction yields ENU; FPC1 stores ENU directly.

### CityGML LoD2

Set `type: "citygml"`, `path` to a CityGML 1/2 GML file containing explicit
LoD2 `gml:Polygon` surfaces and 3D LinearRing `pos` / `posList` elements.
Local ID references are resolved, external XLinks and DTDs rejected.
Constrained polygon triangulation preserves inner rings and concavities;
nonplanar (>0.10 m) or invalid polygons fail. GML 3.2/CityGML 3, curved
surfaces, arbitrary appearance/texture themes and fully semantic conversion
are not supported. Preprocess them with appropriate CityGML tools and inspect
results before converting. LoD2 roofs and walls are generalised geometry,
not measured interior structure. Do not infer flyable openings from a façade
texture; author them as actual mesh geometry.

**Real-world candidate: Brandenburg LoD2.** The [LGB product page](https://geobasis-bb.de/lgb/de/geodaten/3d-produkte/3d-gebaeudemodelle/)
and [metadata](https://geoportal.brandenburg.de/detailansichtdienst/render?url=https%3A%2F%2Fgeoportal.brandenburg.de%2Fgs-json%2Fxml%3Ffileid%3D0414a37a-a749-4ee6-9f59-a41226919c58)
identify CityGML, EPSG:25833 and DHHN2016, with attribution `© GeoBasis-DE/LGB,
dl-de/by-2-0, Daten geändert`. Use the official download for a small area in
Rüdersdorf or another test site and verify the downloaded edition, CRS,
axis order, license and extent. The [PROJ grid](https://cdn.proj.org/de_bkg_gcg2016.tif)
is required for the DHHN2016-to-ellipsoid operation in the tested PROJ build;
install it locally and verify the transformation. Start from the [Brandenburg recipe template](../../tool/scenery/conversion/examples/brandenburg_lod2.json),
place your locally cropped file alongside it as `lod2.gml` (or change the
paths), review the declared `EPSG:25833+7837` / `compound` reference and
credits/rights. Choose a nearby anchor and your own ID/name. Then run:

```powershell
python tool/scenery/conversion/convert.py tool/scenery/conversion/examples/brandenburg_lod2.json brandenburg-lod2.fpvscenery
```

No automatic source download is included. Crop to a small
building group first and review the LoD2 surfaces against photographs and
control points. Real-dataset conversion and device acceptance remain unverified. Do not redistribute the existing BKG test streaming service cache.

### LAS/LAZ and DEM

For LAS/LAZ choose `type: "las"`, declare header CRS, `groundOnly: true`,
and `maxEdgeM` (0–100 m, exclusive of zero). Input must contain classification
2 (ground). XY Delaunay plus edge threshold produces a 2.5D ground TIN;
classification is not performed and narrow voids can be bridged. It is not
appropriate for walls, ceilings, multilevel interiors or overhangs. Crop and
classify using PDAL or CloudCompare before conversion; inspect the result.

For GeoTIFF select `type: "dem"`, declare the horizontal/vertical CRS and
optional integer `stride` (1 = all samples). Raster cells are triangulated at
pixel centers; missing/NoData samples prevent cells from being filled, including
across coarser stride blocks. A `low` LOD can use stride 4; a `balanced` LOD
stride 2; a `high` LOD stride 1. The endpoints of rows/columns are retained.
Choose collision mesh resolution independently; terrain replacement remains
disabled until separately calibrated with the existing replacement workflow.

Use an optional cropped byte RGB GeoTIFF as `orthophoto` with an
`orthophotoSource` object (`author`, `license`, `attribution`,
`redistributionAllowed`). UVs are mapped using the two actual CRS transforms
and raster geotransforms; the orthophoto must cover the mesh. `textureMaxSize`
(1–4096 pixels) controls resampling per LOD. Alpha in an RGB(A) orthophoto is
not used; the workflow expects valid RGB coverage. Orthophotos and DEMs are
not building interior textures. In QGIS or GDAL crop the input GeoTIFF to a
small window before running the converter. Do not merely assign a new CRS or
vertical datum without reprojecting and checking the data.

### Photogrammetry and manual interiors

Use rights-cleared imagery with sufficient overlap, calibrated cameras and
control points. Retain original images, alignment reports and processing
settings; the source license and privacy requirements apply to derivatives.

1. COLMAP: run feature extraction, matching and sparse mapping, then image
   undistortion, dense stereo and fusion. Use the mesh stage or an external
   mesh/texture authoring tool. Export a static triangle mesh (OBJ/PLY etc.)
   plus its authorized texture. COLMAP's reconstruction frame is usually not
   a geographic CRS; align with known controls.
2. Meshroom: build the camera/SfM, dense reconstruction, meshing, filtering and
   texturing graph; export the final textured mesh and keep the source graph.
   Validate axes, scale and texture seams.
3. OpenDroneMap: process images with verified GCPs and appropriate camera
   metadata; export the georeferenced DSM/orthophoto or the textured model.
   Check the actual model's CRS, height reference and any offsets before use.
   The raster adapter can process a cropped DSM/DTM; overhangs require a mesh.
4. In Blender/MeshLab/CloudCompare, remove floaters, build separate wall/deck/
   stair/roof collision geometry, retain open portals and windows. Avoid voxel
   remeshing/hole closing on the physical geometry. Export explicit Low and
   High visual alternatives in the same frame using validated simplification
   and texture downsampling. For interior replacement remove any original
   collision surface in the passage. Run the tool separately from Blender;
   no device reconstruction is needed.

Use `type: "mesh"` for static OBJ, PLY, STL, GLB or glTF from these tools.
Scene node transforms are flattened. Base-color textures with UVs are embedded
as JPEG (or PNG for alpha); non-textured geometry is neutral unlit. Vertex/face
colors and extra material maps are not faithfully retained (explicit
`allowUntextured` / `allowBaseColorOnly` options where applicable). Review
complex appearances and multi-material photogrammetry in external tools;
full PBR, material semantics and animation are outside scope. External
texture resources must be local authorized source files. For generic meshes,
LOD geometry simplification is deliberately externally authored rather than
an automatic topology-changing operation. Exact vertex attribute welding,
unused/degenerate removal, local coordinates and indexed triangles produce
compact canonical GLB without altering openings beyond the stated resolution.

### Compression, bounds and limits

Draco (`KHR_draco_mesh_compression`) reduces geometry transfer but introduces
decoder work; Meshopt (`EXT_meshopt_compression`) supports fast decode and
GPU-oriented data layouts; KTX2/Basis (`KHR_texture_basisu`) reduces texture
transfer and potentially GPU memory. These extensions are rejected by the
current managed GLB validator. Evaluate decoder support, peak memory and
browser/mobile compatibility separately before enabling them in the portable
format. The current tool uses indexed uncompressed geometry and embedded
JPEG/PNG (and ZIP STORE), never emits unsupported compression extensions.

The converter derives geographic bounds from asset local bounds, writes the
versioned package manifest and checksums, and optionally converts exact
`replacementEnu` polygons (arrays of `[east,north]` local metre vertices) to
WGS84 building replacement regions. These are manually supplied reviewed
footprints; never cut an entire bounding box by default. Building replacement
requires collision geometry. Terrain cut regions require the app's existing
seam and physical-ground validation and are not generated here.

Caps: 512 MiB per trusted input file, 4 million DEM pixels, 500k LAS/LAZ points,
2 million vertices/triangles per output mesh, 2 million entries per GLB
accessor (maximum 666,666 indexed triangles per primitive), 4096 px textures, local geometry
within 100 km of its anchor, 128 MiB decoded visual estimate, 16 independent
colliders and a 64 MiB total `.fpvscenery` package. Limits are not a guarantee
of peak conversion memory. Crop and split large datasets into multiple
independent packages before conversion. Source file parsing/cleanup can use
more RAM than the output; run on a suitable desktop. No runtime setting or
existing renderer code is changed.

## Verification and acceptance

```powershell
python -m unittest discover -s test/tool -p test_scenery_conversion.py -v
flutter test test/features/scenery/scenery_conversion_fixture_test.dart
```

The Python tests exercise projected-to-local precision, control point
alignment, CityGML triangulation/openings and local XLinks, ZIP/sha256 and
reproducibility, raster LOD and texture creation, external mesh conversion and
explicit rights checks. The generated FPC is checked with the real JS collision
parser and RF path tests. The LAS/LAZ test requires laspy/lazrs; the dedicated
CI job installs those dependencies. The Dart test opens a generated package
using the actual app importer. Hardware and real public dataset import must
still be verified, including georeferencing, visible textures, independent
collision/LOD and license display on Windows and Android. No performance or
accuracy results from real devices or public datasets are claimed here.
