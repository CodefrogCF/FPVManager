# Coordinates and heights

## Coordinate systems

Application positions use WGS84 decimal-degree `latitude` and `longitude`.
GeoJSON and Cesium's `fromDegrees` use **longitude, latitude**. Swiss LV95
(CH1903+, EPSG:2056) uses **easting, northing** in metres. A horizontal CRS does
not define the height reference.

`GeoCoordinateService` uses swisstopo's approximate WGS84/LV95 formulas for map
navigation within a conservative Swiss bounding box. These bounds are not a
border or coverage guarantee. Explicit REFRAME conversion returns its own LV95
coordinates, labelled separately from the local approximation.

## Height references

| Value | Meaning |
|---|---|
| `wgs84Ellipsoid` | Metres above the WGS84 ellipsoid; not AMSL |
| `besselEllipsoid` | Metres above the Swiss Bessel ellipsoid; intermediate conversion value |
| `ln02` | Swiss LN02 national map/levelling heights |
| `lhn95` | Swiss LHN95 orthometric heights; distinct from LN02 |
| `unverified` | Unknown reference; excluded from height conversion/AGL arithmetic |
| AGL | Vertical offset above terrain at the same position; not a datum |

Terrain queries return WGS84 ellipsoidal heights. Picked mesh heights may use
coarser terrain detail; flat fallback heights are unverified. Camera altitude
and camera-to-target distance are visualization values, not aircraft AGL.
UAS limits retain their source units and AGL/AMSL labels; the app does not infer
an unspecified AMSL datum or combine mismatched lower/upper references.

**Convert to Swiss height (LN02)** explicitly sends the selected position and
height to REFRAME: `wgs84tolv95` returns LV95 and Bessel height, then
`besseltoln02` returns LN02. WGS84 input longitude/latitude use the first endpoint's
`easting`/`northing` parameter names. Requests have finite-input/region checks,
bounded responses and 15-second timeouts. Failure retains the original height;
no fixed geoid offset or substitute AMSL value is used. See [privacy](privacy_and_permissions.md).

The local calculator uses `absolute height = ground height + AGL`, or the inverse
subtraction, at one horizontal position. Ground and absolute heights must share
the **same known reference**. Entered AGL must be finite and nonnegative; the
inverse can be negative. Mixed datums, unknown references and overflow are rejected.
The result does not establish obstacle clearance or improve terrain accuracy.

### 3D Swiss aviation obstacles — AGL-accurate point heights

The BAZL/Skyguide Swiss Obstacle Data Set KML specification (DPS 1.0.1,
section 15.2.7) states that `maxHeightAGL` and `topElevationAMSL` both apply
**at the same location for a point obstacle**. For linear/polygon obstacles,
the maximum AGL height may be located **anywhere** along/across the shape.
It must **not** be applied to each line vertex or polygon marker.

For an isolated KML `Point` with a finite, plausible `maxHeightAGL`, Cesium
computes **both** the foot and the rendered tip from the **same visible
terrain tile**:

```
footEllipsoid = globe.getHeight(longitude, latitude)
renderedTipEllipsoid = footEllipsoid + maxHeightAGL
renderedStemLength = maxHeightAGL
```

The marker and stem use dynamic Cesium properties. Whenever the terrain
mesh is refined or the camera changes the loaded LOD, **both endpoints
move together**, so a published 50 m crane is drawn 50 m tall rather than
an arbitrary distance from the terrain. If terrain is not available, both
the AGL-derived point marker and its stem are hidden instead of displaying
an uncertain height. This is display geometry, not a resurvey of the site.

The original LN02 top elevation remains untouched in the source attributes;
this 3D marker may therefore differ from the converted absolute elevation.
Its vertical *extent* is based on the published AGL and the currently
rendered terrain, whose accuracy varies with the terrain tiles and source.
An isolated Point **without** a valid AGL remains at its published absolute
3D elevation if available, but no fabricated vertical stem is drawn.

The KML schema may also supply an additional `Point` to label each line or
polygon (DPS section 15.2.9). Those synthetic label coordinates are no
longer rendered as separate flying obstacle markers; the corresponding
line/polygon remains pickable. **Cables and power lines retain their
source-provided 3D vertex elevations without terrain clamping**; cable sag
is not reconstructed and `maxHeightAGL` is not misapplied to vertices.

The KML dataset is a visualization source and the BAZL/Skyguide product
specification explicitly limits use in real-world operation/testing.
Neither geometry nor terrain sampling guarantees obstacle clearance.

## Technical sources

- [swisstopo coordinate formulas](https://www.swisstopo.admin.ch/dam/en/sd-web/KLRCX9XIdXDu/ch1903wgs84-EN.pdf)
- [REFRAME overview](https://www.swisstopo.admin.ch/en/rest-api-geoservices-reframe-web) and [API manual](https://www.swisstopo.admin.ch/dam/en/sd-web/3xmcWvfxgG6X/Report16-03.pdf)
- [Terrain service](https://docs.geo.admin.ch/visualize-data/terrain-service.html) and [Cesium terrain-sampling contract](https://cesium.com/learn/cesiumjs/ref-doc/global.html#sampleTerrain)
- [swisstopo geoid and heights](https://www.swisstopo.admin.ch/en/geoid-en)
- [BAZL/Skyguide Swiss Obstacle Data Set product specification, sections 15.2.6–15.2.9](https://www.bazl.admin.ch/dam/de/sd-web/CpfHnV604RSJ/dps_obstacle_datenset_aixm.pdf)
